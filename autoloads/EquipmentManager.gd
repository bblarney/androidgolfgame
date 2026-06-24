extends Node

# Emitted when the equipped club changes, so the on-course club visual can re-skin itself
# immediately instead of waiting for the next shot/aim to trigger a rebuild.
signal club_changed(id: String)

var clubs: Dictionary = {}
var balls: Dictionary = {}

func _ready() -> void:
	clubs = _load_json("res://data/clubs.json")
	balls = _load_json("res://data/balls.json")
	_merge_generated()

# Procedurally generated (pro-shop) items aren't in the JSON data files -- their full
# definitions are stored in the save. Merging them into the same `clubs`/`balls` dicts on
# boot means every other system (gameplay, loadout, clubhouse, equip/save) keeps looking
# items up by id with no changes; they just see "more items in the dict".
func _merge_generated() -> void:
	for id: String in SaveManager.data.get("generated_clubs", {}):
		clubs[id] = SaveManager.data["generated_clubs"][id]
	for id: String in SaveManager.data.get("generated_balls", {}):
		balls[id] = SaveManager.data["generated_balls"][id]

# Commit a freshly generated item (from ItemGenerator) so it persists and is usable. Stores
# it both in the save's generated dict and the live lookup dict. Does NOT grant ownership --
# the caller adds it to the inventory after payment.
func register_generated_item(def: Dictionary) -> void:
	var id: String = def.get("id", "")
	if id == "":
		return
	if item_kind(def) == "ball":
		balls[id] = def
		SaveManager.data["generated_balls"][id] = def
	else:
		clubs[id] = def
		SaveManager.data["generated_clubs"][id] = def
	SaveManager.save()

# "club" if it carries a club `type`, otherwise "ball" (balls have distance_modifier).
func item_kind(def: Dictionary) -> String:
	return "club" if def.has("type") else "ball"

func get_equipped_club() -> Dictionary:
	var id: String = SaveManager.data.get("equipped", {}).get("club", "driver_default")
	return clubs.get(id, clubs.get("driver_default", _fallback_club()))

func get_equipped_ball() -> Dictionary:
	var id: String = SaveManager.data.get("equipped", {}).get("ball", "ball_default")
	return balls.get(id, balls.get("ball_default", _fallback_ball()))

func equip_club(id: String) -> void:
	if owns_item(id) and clubs.has(id):
		SaveManager.data["equipped"]["club"] = id
		SaveManager.save()
		club_changed.emit(id)

func equip_ball(id: String) -> void:
	if owns_item(id) and balls.has(id):
		SaveManager.data["equipped"]["ball"] = id
		SaveManager.save()

func owns_item(id: String) -> bool:
	return id in SaveManager.data.get("inventory", [])

# --- Loadout (per-type equipped clubs, used by the clubhouse) ---------------

func get_loadout() -> Dictionary:
	return SaveManager.data.get("loadout", {})

func get_loadout_club(type: String) -> String:
	return get_loadout().get(type, "")

func set_loadout_club(type: String, id: String) -> void:
	if not owns_item(id) or not clubs.has(id):
		return
	if clubs[id].get("type", "") != type:
		return
	var loadout: Dictionary = SaveManager.data.get("loadout", {})
	loadout[type] = id
	SaveManager.data["loadout"] = loadout
	# Keep the active (in-course) club in sync if the player is editing the slot
	# that's currently selected, so the on-course club re-skins immediately.
	var active: String = SaveManager.data.get("equipped", {}).get("club", "")
	if clubs.has(active) and clubs[active].get("type", "") == type:
		SaveManager.data["equipped"]["club"] = id
		SaveManager.save()
		club_changed.emit(id)
	else:
		SaveManager.save()

func get_owned_clubs_by_type(type: String) -> Array:
	var result: Array = []
	for id: String in clubs:
		if owns_item(id) and clubs[id].get("type", "") == type:
			result.append(clubs[id])
	return result

func get_owned_balls() -> Array:
	var result: Array = []
	for id: String in balls:
		if owns_item(id):
			result.append(balls[id])
	return result

func add_to_inventory(id: String) -> void:
	var inv: Array = SaveManager.data.get("inventory", [])
	if not id in inv:
		inv.append(id)
		SaveManager.data["inventory"] = inv
		SaveManager.save()

func get_all_clubs() -> Dictionary:
	return clubs

func get_all_balls() -> Dictionary:
	return balls

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var result = JSON.parse_string(file.get_as_text())
	file.close()
	return result if result is Dictionary else {}

func _fallback_club() -> Dictionary:
	return {"id": "driver_default", "name": "Driver", "power": 85.0, "spread": 10.0, "spin": 0.1, "launch_angle": 20.0, "backspin": 0.0}

func _fallback_ball() -> Dictionary:
	return {"id": "ball_default", "name": "Ball", "distance_modifier": 1.0, "air_resistance": 0.08, "roll_resistance": 1.2}
