extends Node

const SAVE_PATH    := "user://save.json"
const BACKUP_PATH  := "user://save.bak.json"
const CORRUPT_PATH := "user://save.corrupt.json"

var data: Dictionary = {}

func _ready() -> void:
	load_save()

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = _default_save()
		save()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		# An existing save we can't open (lock/permissions). Run on defaults this session but
		# DON'T overwrite it -- the original is preserved until the player deliberately saves.
		push_error("SaveManager: could not open %s (err %d); using defaults this session." % [SAVE_PATH, FileAccess.get_open_error()])
		data = _default_save()
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		# Corrupt save: quarantine it for recovery instead of silently wiping all progress.
		_quarantine_corrupt_save(text)
		data = _default_save()
		return
	data = parsed
	_ensure_stats()
	_ensure_starter_items()
	_ensure_loadout()
	_ensure_shop()
	_ensure_settings()

func _quarantine_corrupt_save(text: String) -> void:
	var dump := FileAccess.open(CORRUPT_PATH, FileAccess.WRITE)
	if dump != null:
		dump.store_string(text)
		dump.close()
	push_error("SaveManager: %s was corrupt; copied to %s and loaded defaults (progress NOT overwritten yet)." % [SAVE_PATH, CORRUPT_PATH])

func _ensure_stats() -> void:
	# Backfill the career-stats block (and any keys added after a save was created) so the
	# stats screen and recorders can rely on every counter existing.
	var defaults : Dictionary = _default_save()["stats"]
	var stats : Dictionary = data.get("stats", {}) if data.get("stats", null) is Dictionary else {}
	var changed := false
	for key: String in defaults:
		if not stats.has(key):
			stats[key] = defaults[key]
			changed = true
	if changed:
		data["stats"] = stats
		save()

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

func _ensure_loadout() -> void:
	# Older saves only stored a single "equipped.club"; the clubhouse uses a per-type
	# loadout (driver/iron/wedge/putter). Backfill it from the owned defaults.
	if data.get("loadout", null) is Dictionary and not (data["loadout"] as Dictionary).is_empty():
		return
	data["loadout"] = {
		"driver": "driver_default",
		"iron":   "iron_default",
		"wedge":  "wedge_default",
		"putter": "putter_default"
	}
	save()

func _ensure_shop() -> void:
	# Pro-shop / procedural-item state. Backfilled so older saves gain the new fields
	# (generated item definitions live in the save, not the JSON data files).
	if not (data.get("generated_clubs", null) is Dictionary):
		data["generated_clubs"] = {}
	if not (data.get("generated_balls", null) is Dictionary):
		data["generated_balls"] = {}
	if not (data.get("shop", null) is Dictionary):
		data["shop"] = {"offerings": []}
	elif not ((data["shop"] as Dictionary).get("offerings", null) is Array):
		data["shop"]["offerings"] = []
	if not (data.get("gen_counter", null) is float or data.get("gen_counter", null) is int):
		data["gen_counter"] = 0
	save()

func _ensure_settings() -> void:
	# Audio volumes (0..1), read by AudioManager on boot. Backfilled so saves made before audio
	# existed gain sensible defaults instead of muting the game.
	var defaults := {"master_volume": 0.8, "music_volume": 0.8, "sfx_volume": 0.8}
	var settings : Dictionary = data.get("settings", {}) if data.get("settings", null) is Dictionary else {}
	var changed := false
	for key: String in defaults:
		if not settings.has(key):
			settings[key] = defaults[key]
			changed = true
	if changed:
		data["settings"] = settings
		save()

func get_volume(key: String) -> float:
	return data.get("settings", {}).get(key, 0.8)

func set_volume(key: String, value: float) -> void:
	if not (data.get("settings", null) is Dictionary):
		data["settings"] = {}
	data["settings"][key] = value
	save()

func save() -> void:
	# Keep one generation of backup so a botched write or later corruption stays recoverable.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not write %s (err %d); progress not persisted." % [SAVE_PATH, FileAccess.get_open_error()])
		return
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
	elif diff == 1:
		stats["bogeys"] = stats.get("bogeys", 0) + 1
	if strokes - par < stats.get("best_hole_vs_par", 99):
		stats["best_hole_vs_par"] = strokes - par
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
		"loadout": {
			"driver": "driver_default",
			"iron":   "iron_default",
			"wedge":  "wedge_default",
			"putter": "putter_default"
		},
		"inventory": ["driver_default", "iron_default", "wedge_default", "putter_default", "ball_default"],
		"stats": {
			"rounds_played": 0,
			"holes_completed": 0,
			"best_round_score": 9999,
			"best_hole_vs_par": 99,
			"total_strokes": 0,
			"eagles": 0,
			"birdies": 0,
			"bogeys": 0,
			"hole_in_ones": 0
		},
		"current_round_seed": 0,
		"current_hole": 1,
		"holes_per_round": 9,
		"game_mode": "9",
		"hole_scores": [],
		"hole_pars": [],
		"round_in_progress": false,
		"generated_clubs": {},
		"generated_balls": {},
		"shop": {"offerings": []},
		"gen_counter": 0,
		"settings": {"master_volume": 0.8, "music_volume": 0.8, "sfx_volume": 0.8}
	}
