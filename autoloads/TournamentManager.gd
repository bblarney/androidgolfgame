extends Node

# Owns a 4-day stroke-play tournament: the field of opponents, their simulated scores, the
# per-day cut, day progression and persistence. Mirrors the GameState / SaveManager singleton
# pattern -- GameState still owns a single round; this drives it once per day. A day's
# in-progress round is stashed in our own slot (round_state) so it never collides with a casual
# 9/18 round's round_in_progress slot in GameState. All state lives under SaveManager.data
# ["tournament"]; every mutation persists immediately, like the rest of the save model.

signal standings_changed

const FIELD_SIZE      := 100        # you + 99 opponents on Thursday
const CUT_PER_ROUND   := 25         # bottom 25 fall after each of days 1-3
const TOTAL_DAYS      := 4
const TOURNAMENT_HOLES := 18
const USER_NAME       := "YOU"
const DAY_NAMES       := ["Thursday", "Friday", "Saturday", "Championship Sunday"]
const PRIZE_BALL_CHANCE := 0.35     # a Mythic prize is a ball this often, otherwise a club

# Weighted score-vs-par tables, peaked at par with a slight bogey lean so the field reads like
# real golf rather than a flat spread. Spread is ±1 for par 3, ±2 for par 4/5 -- which yields
# the requested ranges (par 3: 2-4, par 4: 2-6, par 5: 3-7).
const DELTA_WEIGHTS_NARROW := {-1: 2, 0: 5, 1: 3}              # par 3
const DELTA_WEIGHTS_WIDE   := {-2: 1, -1: 4, 0: 6, 1: 5, 2: 2} # par 4 and 5

var state: Dictionary = {}

func _ready() -> void:
	_load()

func _load() -> void:
	var saved: Dictionary = SaveManager.data.get("tournament", {})
	if saved.is_empty() or not saved.get("active", false):
		state = _inactive_state()
		return
	# Numbers round-trip through JSON as floats; rebuild the field with clean ints. Guard against
	# a corrupted save where "opponents" isn't an array of dicts so the load degrades gracefully.
	var opponents: Array = []
	var saved_opponents = saved.get("opponents", [])
	if saved_opponents is Array:
		for o in saved_opponents:
			if o is Dictionary:
				opponents.append({"name": str(o.get("name", "Player")), "total": int(o.get("total", 0)), "round": int(o.get("round", 0))})
	state = {
		"active":            true,
		"complete":          saved.get("complete", false),
		"missed_cut":        saved.get("missed_cut", false),
		"day":               int(saved.get("day", 1)),
		"round_seed":        int(saved.get("round_seed", 0)),
		"round_in_progress": saved.get("round_in_progress", false),
		"round_state":       saved.get("round_state", {}),
		"pending_results":   saved.get("pending_results", false),
		"user_total":        int(saved.get("user_total", 0)),
		"user_round":        int(saved.get("user_round", 0)),
		"opponents":         opponents,
		"prize":             saved.get("prize", {}),
		"prize_won":         saved.get("prize_won", false),
	}

func _inactive_state() -> Dictionary:
	return {
		"active": false, "complete": false, "missed_cut": false, "day": 1,
		"round_seed": 0, "round_in_progress": false, "round_state": {},
		"pending_results": false, "user_total": 0, "user_round": 0, "opponents": [],
		"prize": {}, "prize_won": false,
	}

func _persist() -> void:
	SaveManager.data["tournament"] = state
	SaveManager.save()

# --- Queries ---------------------------------------------------------------

func has_active_tournament() -> bool:
	return state.get("active", false)

func is_complete() -> bool:
	return state.get("complete", false)

func missed_cut() -> bool:
	return state.get("missed_cut", false)

func has_pending_results() -> bool:
	return state.get("pending_results", false)

func round_in_progress() -> bool:
	return state.get("round_in_progress", false)

func current_day() -> int:
	return state.get("day", 1)

func day_name() -> String:
	return DAY_NAMES[clampi(current_day() - 1, 0, TOTAL_DAYS - 1)]

# Whether a cut still looms (no cut follows Championship Sunday).
func has_cut_ahead() -> bool:
	return has_active_tournament() and not is_complete() and current_day() < TOTAL_DAYS

# --- Lifecycle -------------------------------------------------------------

func start_new_tournament() -> void:
	var opponents: Array = []
	for i in range(1, FIELD_SIZE):   # 99 opponents; the user is the 100th seat
		opponents.append({"name": "Player %d" % i, "total": 0, "round": 0})
	state = _inactive_state()
	state["active"]     = true
	state["day"]        = 1
	state["round_seed"] = randi()
	state["opponents"]  = opponents
	state["prize"]      = _roll_prize()   # the Mythic on the line for these four days
	_persist()

# Rolls the Mythic club or ball staked on this tournament. Held in our state (not the inventory)
# until the player wins it -- see _award_prize.
func _roll_prize() -> Dictionary:
	var is_ball: bool = randf() < PRIZE_BALL_CHANCE
	var item: Dictionary = ItemGenerator.generate_mythic_ball() if is_ball else ItemGenerator.generate_mythic_club()
	return {"kind": "ball" if is_ball else "club", "item": item}

# Tees up the current day's round in GameState and stashes it so Continue can resume it.
func begin_day() -> void:
	GameState.start_round("tournament", int(state["round_seed"]))
	state["user_round"]        = 0
	for o in state["opponents"]:
		o["round"] = 0
	state["round_in_progress"] = true
	state["pending_results"]   = false
	state["round_state"]       = GameState.snapshot()
	_persist()

# Resumes a day left mid-play (pulls the stashed round back into GameState).
func resume_day() -> void:
	GameState.restore(state.get("round_state", {}))

# Called by hole_manager after each completed hole: simulate the field's score on that hole and
# re-stash the round so a later Continue restarts from here.
func record_player_hole(par: int) -> void:
	for o in state["opponents"]:
		o["round"] = int(o["round"]) + _roll_opponent_delta(par)
	state["user_round"]  = GameState.get_score_vs_par()
	state["round_state"] = GameState.snapshot()
	_persist()
	standings_changed.emit()

# Called from the in-game exit so Continue resumes the exact day state.
func save_round_snapshot() -> void:
	state["user_round"]        = GameState.get_score_vs_par()
	state["round_state"]       = GameState.snapshot()
	state["round_in_progress"] = true
	_persist()

# Folds the finished day's scores into the running totals and flags the hub to show results +
# (for days 1-3) the cut. The cut itself is applied later by apply_cut_and_advance so the
# leaderboard can show who is about to fall.
func finish_day() -> void:
	state["user_total"] = int(state["user_total"]) + int(state["user_round"])
	state["user_round"] = 0
	for o in state["opponents"]:
		o["total"] = int(o["total"]) + int(o["round"])
		o["round"] = 0
	state["round_in_progress"] = false
	state["round_state"]       = {}
	state["pending_results"]   = true
	_persist()

# Applies the day's cut (days 1-3) and advances, or crowns the champion after Sunday. After
# finish_day the day scores are already in the totals, so we rank on totals alone.
func apply_cut_and_advance() -> void:
	state["pending_results"] = false
	if current_day() >= TOTAL_DAYS:
		state["complete"] = true
		if champion_name() == USER_NAME:
			_award_prize()
		_persist()
		return

	var ranked: Array = _ranked_totals()                # ascending; lower is better
	var target: int   = ranked.size() - CUT_PER_ROUND   # how many survive
	if target < 1:
		target = 1
	var cutoff: int = int(ranked[target - 1]["score"])  # worst surviving score; ties at it advance

	if int(state["user_total"]) > cutoff:
		# Missed the cut -- the tournament is over for the player.
		state["active"]     = false
		state["missed_cut"] = true
		_persist()
		return

	var survivors: Array = []
	for o in state["opponents"]:
		if int(o["total"]) <= cutoff:
			survivors.append(o)
	state["opponents"] = survivors
	state["day"]       = current_day() + 1
	state["round_seed"] = randi()
	_persist()

func withdraw() -> void:
	state = _inactive_state()
	_persist()

# Clears the one-shot missed-cut flag after the hub has shown the elimination notice.
func acknowledge_missed_cut() -> void:
	state["missed_cut"] = false
	_persist()

# --- Prize -----------------------------------------------------------------

# The Mythic staked on this tournament: {kind, item}, or {} when none is active.
func get_prize() -> Dictionary:
	return state.get("prize", {})

func prize_won() -> bool:
	return state.get("prize_won", false)

# Winning the tournament grants the Mythic for keeps (registered + added to the bag). Missing the
# cut or withdrawing never calls this, so the prize is simply forfeited with the tournament.
func _award_prize() -> void:
	var item: Dictionary = state.get("prize", {}).get("item", {})
	if item.is_empty():
		return
	EquipmentManager.register_generated_item(item)
	EquipmentManager.add_to_inventory(item.get("id", ""))
	state["prize_won"] = true

# --- Standings -------------------------------------------------------------

# Full field sorted best-to-worst, each entry: {name, score, rank, is_user, in_danger}.
# in_danger marks the projected cut (bottom CUT_PER_ROUND, tie-protected) while a cut still
# looms. Used by the live scorebug (top 5), the hub leaderboard and the results view.
func get_standings() -> Array:
	var entries: Array = _ranked_totals()
	# A live round adds the in-progress day's running score on top of the banked totals.
	var ranked: Array = []
	var n: int = entries.size()
	var cut_score: int = 0
	var have_cut: bool = false
	if has_cut_ahead() and n > CUT_PER_ROUND:
		cut_score = int(entries[n - CUT_PER_ROUND - 1]["score"])  # worst still safe
		have_cut  = true
	for i in range(n):
		var e: Dictionary = entries[i]
		ranked.append({
			"name":      e["name"],
			"score":     int(e["score"]),
			"rank":      i + 1,
			"is_user":   e["is_user"],
			"in_danger": have_cut and int(e["score"]) > cut_score,
		})
	return ranked

# Combined field (user + opponents) on banked total + current-day running score, sorted
# ascending. The user row carries is_user for highlighting.
func _ranked_totals() -> Array:
	var entries: Array = [{"name": USER_NAME, "score": int(state["user_total"]) + int(state["user_round"]), "is_user": true}]
	for o in state["opponents"]:
		entries.append({"name": o["name"], "score": int(o["total"]) + int(o["round"]), "is_user": false})
	entries.sort_custom(_compare_entries)
	return entries

# Lower score first; the user breaks ties upward so a tied player never appears "below" a bot.
func _compare_entries(a: Dictionary, b: Dictionary) -> bool:
	if a["score"] == b["score"]:
		return a["is_user"] and not b["is_user"]
	return a["score"] < b["score"]

# Golf-style vs-par label: even par is "E", otherwise a signed number.
static func format_score(score: int) -> String:
	if score == 0:
		return "E"
	return ("+%d" % score) if score > 0 else str(score)

# How many players the looming cut will actually remove. Tie-protection means this is usually
# CUT_PER_ROUND but fewer when players tied at the line all advance. Zero when no cut looms.
func projected_cut_count() -> int:
	if not has_cut_ahead():
		return 0
	var count: int = 0
	for e in get_standings():
		if e["in_danger"]:
			count += 1
	return count

func champion_name() -> String:
	var ranked: Array = _ranked_totals()
	return ranked[0]["name"] if not ranked.is_empty() else USER_NAME

# Center-weighted score-vs-par for one opponent on one hole, clamped to the spec ranges.
func _roll_opponent_delta(par: int) -> int:
	var table: Dictionary = DELTA_WEIGHTS_NARROW if par <= 3 else DELTA_WEIGHTS_WIDE
	var total: int = 0
	for w in table.values():
		total += w
	var roll: int = randi() % total
	for delta in table.keys():
		roll -= table[delta]
		if roll < 0:
			return delta
	return 0
