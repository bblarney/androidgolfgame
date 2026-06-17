extends Node

var current_round_seed: int = 0
var current_hole: int = 1
const HOLES_PER_ROUND: int = 9

var hole_scores: Array[int] = []
var hole_pars: Array[int] = []

func new_round() -> void:
	current_round_seed = randi()
	current_hole = 1
	hole_scores.clear()
	hole_pars.clear()
	SaveManager.data["current_round_seed"] = current_round_seed
	SaveManager.data["current_hole"] = 1
	SaveManager.save()

func get_hole_seed() -> int:
	return current_round_seed + current_hole

# The biome (visual theme) for the current hole. Built deterministically from the round
# seed so it is stable across saves/replays, and laid out for GUARANTEED variety: the
# three biomes are shuffled and repeated to fill the round, reshuffling each cycle and
# avoiding a repeat across the seam, so every round shows all three and consecutive holes
# differ. The generator stays a pure function of (seed, biome) -- this round-spanning
# logic lives here, where the round seed and hole index do.
func get_hole_biome() -> String:
	const BIOMES := ["parkland", "links", "fescue"]
	var brng := RandomNumberGenerator.new()
	brng.seed = current_round_seed
	var order: Array[String] = []
	var prev := ""
	while order.size() < HOLES_PER_ROUND:
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

func record_hole(strokes: int, par: int) -> void:
	hole_scores.append(strokes)
	hole_pars.append(par)
	current_hole += 1
	SaveManager.data["current_hole"] = current_hole
	SaveManager.save()

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

func is_round_complete() -> bool:
	return current_hole > HOLES_PER_ROUND

func resume_from_save() -> void:
	current_round_seed = SaveManager.data.get("current_round_seed", 0)
	current_hole = SaveManager.data.get("current_hole", 1)
	if current_round_seed == 0:
		new_round()
