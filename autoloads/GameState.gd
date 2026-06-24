extends Node

const DEFAULT_HOLES := 9
# Practice rounds are endless; holes_per_round is set to this sentinel so is_round_complete()
# never trips and the HUD knows to hide the "/ N" denominator.
const INFINITE := -1

var current_round_seed: int = 0
var current_hole: int = 1
var holes_per_round: int = DEFAULT_HOLES
var game_mode: String = "9"        # "practice" | "9" | "18"
var award_points: bool = true

var hole_scores: Array[int] = []
var hole_pars: Array[int] = []

func _ready() -> void:
	# Boot now lands on the menu, NOT in a hole, so we do NOT start a round here. We only pull
	# any persisted in-progress round into memory so the menu's CONTINUE button can detect it
	# (has_resumable_round) and resume_round() can restore it. A round actually begins only via
	# start_round() (new) or resume_round() (continue). SaveManager is autoloaded before us, so
	# its data is already on disk-in-memory by now.
	_load_from_save()

# Begins a brand-new round in the given mode and persists it as in-progress.
func start_round(mode: String) -> void:
	game_mode = mode
	match mode:
		"practice":
			holes_per_round = INFINITE
			award_points    = false
		"18":
			holes_per_round = 18
			award_points    = true
		_:  # "9"
			game_mode       = "9"
			holes_per_round = 9
			award_points    = true
	current_round_seed = randi()
	current_hole = 1
	hole_scores.clear()
	hole_pars.clear()
	_persist_round(true)

# Used after a round completes when the old code looped straight into another round; kept so
# any remaining callers behave, but the menu/scorecard now route back to the main menu instead.
func new_round() -> void:
	start_round(game_mode)

func get_hole_seed() -> int:
	return current_round_seed + current_hole

# The biome (visual theme) for the current hole. Built deterministically from the round
# seed so it is stable across saves/replays, and laid out for GUARANTEED variety: all
# five biomes are shuffled and repeated to fill the round, reshuffling each cycle and
# avoiding a repeat across the seam, so every biome appears with equal frequency and
# consecutive holes differ. The generator stays a pure function of (seed, biome) -- this round-spanning
# logic lives here, where the round seed and hole index do.
func get_hole_biome() -> String:
	const BIOMES := ["parkland", "links", "fescue", "alpine", "autumn"]
	# Practice has no fixed length; fill enough of the cycle that the modulo below always has a
	# value, and so 18-hole rounds get a full layout too.
	var fill_to : int = max(holes_per_round, 18)
	var brng := RandomNumberGenerator.new()
	brng.seed = current_round_seed
	var order: Array[String] = []
	var prev := ""
	while order.size() < fill_to:
		var cycle := BIOMES.duplicate()
		# Fisher-Yates shuffle with the seeded RNG (Array.shuffle uses the global RNG).
		for i in range(cycle.size() - 1, 0, -1):
			var j := brng.randi_range(0, i)
			var tmp = cycle[i]
			cycle[i] = cycle[j]
			cycle[j] = tmp
		# Avoid the same biome straddling the cycle boundary.
		if cycle[0] == prev and cycle.size() > 1:
			cycle.append(cycle.pop_front())
		for b in cycle:
			order.append(b)
		prev = order[order.size() - 1]
	return order[(current_hole - 1) % order.size()]

# Reproduces ONLY the par roll from hole_generator._roll_blueprint: par is the FIRST
# rng.randf() after rng.seed = current_round_seed + hole. Uses an INDEPENDENT RNG so it
# never perturbs the generator's shared stream. Lets the scorecard show the par of holes
# the player has not reached yet. Thresholds MUST stay in sync with _roll_blueprint:
#   roll < 0.30 -> par 3 ; roll < 0.75 -> par 4 ; else par 5
func get_par_for_hole(n: int) -> int:
	var prng := RandomNumberGenerator.new()
	prng.seed = current_round_seed + n
	var roll := prng.randf()
	if roll < 0.30:
		return 3
	elif roll < 0.75:
		return 4
	else:
		return 5

func record_hole(strokes: int, par: int) -> void:
	hole_scores.append(strokes)
	hole_pars.append(par)
	current_hole += 1
	_persist_round(true)

func get_score_vs_par() -> int:
	var total := 0
	for i in range(hole_scores.size()):
		total += hole_scores[i] - hole_pars[i]
	return total

func get_total_strokes() -> int:
	var total := 0
	for s in hole_scores:
		total += s
	return total

func get_total_par() -> int:
	var total := 0
	for p in hole_pars:
		total += p
	return total

func is_round_complete() -> bool:
	if holes_per_round == INFINITE:
		return false
	return current_hole > holes_per_round

# --- Resume support ---------------------------------------------------------

func has_resumable_round() -> bool:
	return SaveManager.data.get("round_in_progress", false)

# Pulls a saved in-progress round back into memory (called by the menu's CONTINUE).
func resume_round() -> void:
	_load_from_save()

# Persists the current round exactly as it stands (called by the in-game exit so the player
# can pick CONTINUE later).
func save_progress() -> void:
	_persist_round(true)

# Marks the round finished so CONTINUE no longer offers it (called on normal 9/18 completion).
func clear_round() -> void:
	SaveManager.data["round_in_progress"] = false
	SaveManager.save()

func _persist_round(in_progress: bool) -> void:
	SaveManager.data["current_round_seed"] = current_round_seed
	SaveManager.data["current_hole"]       = current_hole
	SaveManager.data["holes_per_round"]    = holes_per_round
	SaveManager.data["game_mode"]          = game_mode
	SaveManager.data["hole_scores"]        = hole_scores.duplicate()
	SaveManager.data["hole_pars"]          = hole_pars.duplicate()
	SaveManager.data["round_in_progress"]  = in_progress
	SaveManager.save()

func _load_from_save() -> void:
	current_round_seed = SaveManager.data.get("current_round_seed", 0)
	current_hole       = SaveManager.data.get("current_hole", 1)
	holes_per_round    = SaveManager.data.get("holes_per_round", DEFAULT_HOLES)
	game_mode          = SaveManager.data.get("game_mode", "9")
	award_points       = game_mode != "practice"
	# JSON arrays come back as untyped Array[Variant]; copy into our typed arrays.
	hole_scores.clear()
	for s in SaveManager.data.get("hole_scores", []):
		hole_scores.append(int(s))
	hole_pars.clear()
	for p in SaveManager.data.get("hole_pars", []):
		hole_pars.append(int(p))
