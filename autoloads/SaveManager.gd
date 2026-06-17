extends Node

const SAVE_PATH := "user://save.json"

var data: Dictionary = {}

func _ready() -> void:
	load_save()

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = _default_save()
		save()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	data = parsed if parsed is Dictionary else _default_save()
	_ensure_starter_items()

func _ensure_starter_items() -> void:
	# Backfills clubs added after a save was already created, so existing
	# saves don't get silently locked out of new starter equipment.
	var inv     : Array = data.get("inventory", [])
	var changed : bool  = false
	for id: String in ["driver_default", "iron_default", "wedge_default", "putter_default", "ball_default"]:
		if not id in inv:
			inv.append(id)
			changed = true
	if changed:
		data["inventory"] = inv
		save()

func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func add_points(amount: int) -> void:
	data["points"] = data.get("points", 0) + amount
	data["lifetime_points"] = data.get("lifetime_points", 0) + amount
	save()

func spend_points(amount: int) -> bool:
	if data.get("points", 0) < amount:
		return false
	data["points"] -= amount
	save()
	return true

func record_hole_complete(strokes: int, par: int) -> int:
	var stats: Dictionary = data.get("stats", {})
	stats["holes_completed"] = stats.get("holes_completed", 0) + 1
	stats["total_strokes"] = stats.get("total_strokes", 0) + strokes
	var diff := strokes - par
	if strokes == 1:
		stats["hole_in_ones"] = stats.get("hole_in_ones", 0) + 1
	elif diff <= -2:
		stats["eagles"] = stats.get("eagles", 0) + 1
	elif diff == -1:
		stats["birdies"] = stats.get("birdies", 0) + 1
	data["stats"] = stats
	var points := _points_for_score(strokes, par)
	add_points(points)
	return points

func record_round_complete(total_strokes: int, total_par: int) -> void:
	var stats: Dictionary = data.get("stats", {})
	stats["rounds_played"] = stats.get("rounds_played", 0) + 1
	var best: int = stats.get("best_round_score", 9999)
	var score := total_strokes - total_par
	if score < best:
		stats["best_round_score"] = score
	data["stats"] = stats
	save()

func _points_for_score(strokes: int, par: int) -> int:
	if strokes == 1:
		return 500
	match strokes - par:
		_ when strokes - par <= -2:
			return 300
		-1:
			return 150
		0:
			return 75
		1:
			return 25
		2:
			return 10
		_:
			return 5

func _default_save() -> Dictionary:
	return {
		"version": 1,
		"points": 0,
		"lifetime_points": 0,
		"equipped": {
			"club": "driver_default",
			"ball": "ball_default"
		},
		"inventory": ["driver_default", "iron_default", "wedge_default", "putter_default", "ball_default"],
		"stats": {
			"rounds_played": 0,
			"holes_completed": 0,
			"best_round_score": 9999,
			"total_strokes": 0,
			"eagles": 0,
			"birdies": 0,
			"hole_in_ones": 0
		},
		"current_round_seed": 0,
		"current_hole": 1
	}
