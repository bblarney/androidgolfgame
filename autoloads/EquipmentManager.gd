extends Node

var clubs: Dictionary = {}
var balls: Dictionary = {}

func _ready() -> void:
	clubs = _load_json("res://data/clubs.json")
	balls = _load_json("res://data/balls.json")

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

func equip_ball(id: String) -> void:
	if owns_item(id) and balls.has(id):
		SaveManager.data["equipped"]["ball"] = id
		SaveManager.save()

func owns_item(id: String) -> bool:
	return id in SaveManager.data.get("inventory", [])

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
	return {"id": "driver_default", "name": "Driver", "power": 1500.0, "spread": 10.0, "spin": 0.1}

func _fallback_ball() -> Dictionary:
	return {"id": "ball_default", "name": "Ball", "distance_modifier": 1.0, "air_resistance": 0.08, "roll_resistance": 1.2}
