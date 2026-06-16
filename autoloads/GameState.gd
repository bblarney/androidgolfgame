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
