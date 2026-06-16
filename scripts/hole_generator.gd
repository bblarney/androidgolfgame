extends Node

const COLOR_ROUGH   : Color = Color(0.22, 0.48, 0.14)
const COLOR_FAIRWAY : Color = Color(0.30, 0.68, 0.20)
const COLOR_GREEN   : Color = Color(0.18, 0.80, 0.32)
const COLOR_SAND    : Color = Color(0.90, 0.84, 0.50)
const COLOR_WATER   : Color = Color(0.18, 0.42, 0.82, 0.88)
const COLOR_FLAG    : Color = Color(0.95, 0.20, 0.20)

const BOTTOM_Y      : float = 1200.0
const BASE_Y        : float = 520.0
const SURFACE_STEPS : int   = 10
const GREEN_LENGTH  : float = 360.0
const TEE_LENGTH    : float = 220.0

var rng := RandomNumberGenerator.new()

func generate_hole(seed: int) -> Dictionary:
	rng.seed = seed

	var length: float = rng.randf_range(2800.0, 4800.0)
	var num_ctrl: int = rng.randi_range(7, 13)
	var surface: Array[Vector2] = _generate_surface(length, num_ctrl)
	var par: int = _calculate_par(length)
	var hazards: Array = _place_hazards(surface, length)
	var tee_pos := Vector2(TEE_LENGTH * 0.5, _surface_y_at(surface, TEE_LENGTH * 0.5) - 20.0)
	var cup_pos := Vector2(length - 60.0, _surface_y_at(surface, length - 60.0) - 22.0)

	return {
		"surface": surface,
		"length": length,
		"tee_position": tee_pos,
		"cup_position": cup_pos,
		"par": par,
		"hazards": hazards,
		"green_start_x": length - GREEN_LENGTH
	}

func build_terrain(hole_data: Dictionary, parent: Node2D) -> void:
	var surface: Array[Vector2] = hole_data["surface"]
	var length: float = hole_data["length"]
	var green_x: float = hole_data["green_start_x"]

	var rough_poly := _build_ground_polygon(surface, length)
	parent.add_child(_make_surface_body(rough_poly, COLOR_ROUGH, "rough", 0.95, 0.08))

	var fairway_poly := _build_partial_polygon(surface, TEE_LENGTH, green_x)
	parent.add_child(_make_surface_body(fairway_poly, COLOR_FAIRWAY, "fairway", 0.60, 0.20))

	var green_poly := _build_partial_polygon(surface, green_x, length)
	parent.add_child(_make_surface_body(green_poly, COLOR_GREEN, "green", 0.30, 0.10))

	for h: Dictionary in hole_data["hazards"]:
		if h["type"] == "water":
			parent.add_child(_make_water_hazard(h["position"], h["radius"]))
		elif h["type"] == "sand":
			parent.add_child(_make_sand_patch(h["position"], h["radius"]))

	parent.add_child(_make_cup_marker(hole_data["cup_position"]))
	parent.add_child(_make_flag(hole_data["cup_position"]))

# ── Surface generation ────────────────────────────────────────────────────────

func _generate_surface(length: float, num_ctrl: int) -> Array[Vector2]:
	var ctrl: Array[Vector2] = []
	ctrl.append(Vector2(0.0, BASE_Y))
	for i in range(1, num_ctrl):
		var x: float = (float(i) / float(num_ctrl)) * length
		var prev_y: float = ctrl[-1].y
		var dy: float = rng.randf_range(-130.0, 130.0)
		var y: float = clampf(prev_y + dy, 260.0, 780.0)
		ctrl.append(Vector2(x, y))
	ctrl.append(Vector2(length, BASE_Y + rng.randf_range(-80.0, 80.0)))

	var result: Array[Vector2] = []
	for i in range(ctrl.size() - 1):
		for j in range(SURFACE_STEPS):
			var t: float = float(j) / float(SURFACE_STEPS)
			result.append(ctrl[i].lerp(ctrl[i + 1], t))
	result.append(ctrl[-1])
	return result

func _surface_y_at(surface: Array[Vector2], x: float) -> float:
	for i in range(surface.size() - 1):
		if surface[i].x <= x and surface[i + 1].x >= x:
			var denom: float = surface[i + 1].x - surface[i].x
			if denom == 0.0:
				return surface[i].y
			var t: float = (x - surface[i].x) / denom
			return lerpf(surface[i].y, surface[i + 1].y, t)
	return BASE_Y

# ── Polygon builders ──────────────────────────────────────────────────────────

func _build_ground_polygon(surface: Array[Vector2], length: float) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for p: Vector2 in surface:
		poly.append(p)
	poly.append(Vector2(length + 80.0, BOTTOM_Y))
	poly.append(Vector2(-80.0, BOTTOM_Y))
	return poly

func _build_partial_polygon(surface: Array[Vector2], x_start: float, x_end: float) -> PackedVector2Array:
	var top_pts: Array[Vector2] = []
	for p: Vector2 in surface:
		if p.x >= x_start - 1.0 and p.x <= x_end + 1.0:
			top_pts.append(p)

	if top_pts.is_empty() or top_pts[0].x > x_start:
		top_pts.insert(0, Vector2(x_start, _surface_y_at(surface, x_start)))
	if top_pts[-1].x < x_end:
		top_pts.append(Vector2(x_end, _surface_y_at(surface, x_end)))

	var poly := PackedVector2Array()
	for p: Vector2 in top_pts:
		poly.append(p)
	poly.append(Vector2(x_end, BOTTOM_Y))
	poly.append(Vector2(x_start, BOTTOM_Y))
	return poly

# ── Node factories ────────────────────────────────────────────────────────────

func _make_surface_body(polygon: PackedVector2Array, color: Color, surface_id: String, friction: float, bounce: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = surface_id.capitalize()
	body.set_meta("surface_type", surface_id)

	var mat := PhysicsMaterial.new()
	mat.friction = friction
	mat.bounce = bounce
	body.physics_material_override = mat

	var col := CollisionPolygon2D.new()
	col.polygon = polygon
	body.add_child(col)

	var vis := Polygon2D.new()
	vis.polygon = polygon
	vis.color = color
	body.add_child(vis)

	return body

func _make_water_hazard(center: Vector2, radius: float) -> Area2D:
	var area := Area2D.new()
	area.name = "Water"
	area.set_meta("hazard_type", "water")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	col.position = center
	area.add_child(col)

	var vis := Polygon2D.new()
	vis.polygon = _circle_polygon(center, radius, 28)
	vis.color = COLOR_WATER
	area.add_child(vis)

	return area

func _make_sand_patch(center: Vector2, radius: float) -> StaticBody2D:
	return _make_surface_body(_circle_polygon(center, radius, 24), COLOR_SAND, "sand", 1.6, 0.04)

func _make_cup_marker(cup_pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = "CupMarker"
	var vis := Polygon2D.new()
	vis.polygon = _circle_polygon(cup_pos + Vector2(0.0, 10.0), 22.0, 20)
	vis.color = Color(0.08, 0.08, 0.08)
	node.add_child(vis)
	return node

func _make_flag(cup_pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = "Flag"
	var pole := Line2D.new()
	pole.add_point(cup_pos)
	pole.add_point(cup_pos + Vector2(0.0, -110.0))
	pole.width = 4.0
	pole.default_color = Color(0.85, 0.85, 0.85)
	node.add_child(pole)
	var tip := cup_pos + Vector2(0.0, -110.0)
	var flag := Polygon2D.new()
	flag.polygon = PackedVector2Array([tip, tip + Vector2(55.0, 20.0), tip + Vector2(0.0, 40.0)])
	flag.color = COLOR_FLAG
	node.add_child(flag)
	return node

# ── Hazard placement ──────────────────────────────────────────────────────────

func _place_hazards(surface: Array[Vector2], length: float) -> Array:
	var hazards: Array = []
	var num_water: int = rng.randi_range(0, 2)
	var num_sand: int  = rng.randi_range(1, 3)

	for _i in range(num_water):
		var x: float = rng.randf_range(0.28, 0.72) * length
		var y: float = _surface_y_at(surface, x) + rng.randf_range(30.0, 70.0)
		hazards.append({"type": "water", "position": Vector2(x, y), "radius": rng.randf_range(60.0, 115.0)})

	for _i in range(num_sand):
		var x: float = rng.randf_range(0.20, 0.82) * length
		var y: float = _surface_y_at(surface, x) + rng.randf_range(10.0, 45.0)
		hazards.append({"type": "sand", "position": Vector2(x, y), "radius": rng.randf_range(45.0, 85.0)})

	return hazards

# ── Par + Utility ─────────────────────────────────────────────────────────────

func _calculate_par(length: float) -> int:
	if length < 1100.0:
		return 3
	elif length < 1900.0:
		return 4
	return 5

func _circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for i in range(segments):
		var angle: float = (float(i) / float(segments)) * TAU
		poly.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return poly
