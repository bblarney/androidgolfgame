extends Node

const CELL        : float = 2.0
const TERRAIN_W   : float = 80.0
const FAIRWAY_W   : float = 22.0
const GREEN_DEPTH : float = 22.0
const BOTTOM_WALL : float = -8.0

const COL_ROUGH  : Color = Color(0.22, 0.46, 0.14)
const COL_FAIR   : Color = Color(0.28, 0.68, 0.20)
const COL_GREEN  : Color = Color(0.16, 0.80, 0.30)
const COL_SAND   : Color = Color(0.88, 0.82, 0.48)
const COL_WATER  : Color = Color(0.16, 0.40, 0.82, 0.90)
const COL_FLAG   : Color = Color(0.95, 0.18, 0.18)

var rng := RandomNumberGenerator.new()

# ── Public API ────────────────────────────────────────────────────────────────

func generate_hole(seed: int) -> Dictionary:
	rng.seed = seed

	var length    : float = rng.randf_range(110.0, 260.0)
	var segs_x    : int   = int(TERRAIN_W / CELL)
	var segs_z    : int   = int(length    / CELL)
	var pts_x     : int   = segs_x + 1
	var pts_z     : int   = segs_z + 1

	var heights   : PackedFloat32Array = _gen_heights(pts_x, pts_z, length)
	var cup_x_off : float = rng.randf_range(-8.0, 8.0)

	var tee_h : float = _h(heights, pts_x, pts_x / 2, 2)
	var cup_h : float = _h(heights, pts_x, pts_x / 2, pts_z - 2)

	var tee_pos := Vector3(0.0,         tee_h + 0.45, 5.0)
	var cup_pos := Vector3(cup_x_off,   cup_h + 0.05, length - 5.0)
	var par     : int = _calc_par(length)
	var hazards : Array = _place_hazards(length, heights, pts_x, pts_z)

	return {
		"length"      : length,
		"pts_x"       : pts_x,
		"pts_z"       : pts_z,
		"heights"     : heights,
		"tee_position": tee_pos,
		"cup_position": cup_pos,
		"par"         : par,
		"hazards"     : hazards,
		"cup_x_off"   : cup_x_off,
	}

func build_terrain(data: Dictionary, parent: Node3D) -> void:
	var pts_x   : int               = data["pts_x"]
	var pts_z   : int               = data["pts_z"]
	var heights : PackedFloat32Array = data["heights"]
	var length  : float              = data["length"]
	var cup_x   : float              = data["cup_x_off"]
	var green_z : float              = length - GREEN_DEPTH

	# Ground collision (HeightMapShape3D)
	var hms := HeightMapShape3D.new()
	hms.map_width = pts_x
	hms.map_depth = pts_z
	hms.map_data  = heights

	var terrain_body := StaticBody3D.new()
	terrain_body.name = "Terrain"
	var col := CollisionShape3D.new()
	col.shape    = hms
	# Center heightmap so it spans X:[-W/2..+W/2], Z:[0..length]
	col.position = Vector3(0.0, 0.0, length * 0.5)
	col.scale    = Vector3(CELL, 1.0, CELL)
	terrain_body.add_child(col)

	# Visual mesh with vertex colors
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _build_mesh(pts_x, pts_z, heights, green_z, cup_x)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mesh_inst.material_override = mat
	terrain_body.add_child(mesh_inst)
	parent.add_child(terrain_body)

	# Hazards
	for h: Dictionary in data["hazards"]:
		if h["type"] == "water":
			parent.add_child(_make_water(h["pos"], h["radius"]))
		elif h["type"] == "sand":
			parent.add_child(_make_sand_disk(h["pos"], h["radius"]))

	# Flag + cup marker
	parent.add_child(_make_flag(data["cup_position"]))
	parent.add_child(_make_cup_marker(data["cup_position"]))

# ── Height map ────────────────────────────────────────────────────────────────

func _gen_heights(pts_x: int, pts_z: int, length: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(pts_x * pts_z)

	# Random control points along Z axis
	var ctrl_count : int = rng.randi_range(5, 10)
	var ctrl_y     : Array[float] = []
	ctrl_y.resize(ctrl_count + 1)
	ctrl_y[0] = 0.0
	for i in range(1, ctrl_count + 1):
		ctrl_y[i] = ctrl_y[i - 1] + rng.randf_range(-1.8, 1.8)
		ctrl_y[i] = clampf(ctrl_y[i], -4.0, 4.0)

	for zi in range(pts_z):
		var t_z    : float = float(zi) / float(pts_z - 1)
		var seg_t  : float = t_z * float(ctrl_count)
		var seg_i  : int   = int(seg_t)
		var seg_f  : float = seg_t - float(seg_i)
		seg_i = mini(seg_i, ctrl_count - 1)
		var row_h  : float = lerpf(ctrl_y[seg_i], ctrl_y[seg_i + 1], seg_f)

		for xi in range(pts_x):
			var x_world : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
			# Slight lateral wobble in rough areas
			var lat_bump : float = sin(float(xi) * 0.6 + float(zi) * 0.4) * 0.3
			out[zi * pts_x + xi] = row_h + lat_bump

	return out

func _h(heights: PackedFloat32Array, pts_x: int, xi: int, zi: int) -> float:
	xi = clampi(xi, 0, pts_x - 1)
	return heights[zi * pts_x + xi]

# ── Mesh ──────────────────────────────────────────────────────────────────────

func _build_mesh(pts_x: int, pts_z: int, heights: PackedFloat32Array, green_z: float, cup_x: float) -> ArrayMesh:
	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors  := PackedColorArray()
	var indices := PackedInt32Array()

	for zi in range(pts_z):
		for xi in range(pts_x):
			var x : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
			var z : float = float(zi) * CELL
			var y : float = heights[zi * pts_x + xi]
			verts.append(Vector3(x, y, z))
			normals.append(_calc_normal(heights, pts_x, pts_z, xi, zi))
			colors.append(_terrain_color(x, z, y, green_z, cup_x))

	for zi in range(pts_z - 1):
		for xi in range(pts_x - 1):
			var tl : int = zi * pts_x + xi
			var tr : int = tl + 1
			var bl : int = tl + pts_x
			var br : int = bl + 1
			indices.append_array(PackedInt32Array([tl, bl, tr, tr, bl, br]))

	var arr := Array()
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR]  = colors
	arr[Mesh.ARRAY_INDEX]  = indices

	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _calc_normal(h: PackedFloat32Array, pts_x: int, pts_z: int, xi: int, zi: int) -> Vector3:
	var l : float = _h(h, pts_x, maxi(xi - 1, 0),        zi)
	var r : float = _h(h, pts_x, mini(xi + 1, pts_x - 1), zi)
	var d : float = _h(h, pts_x, xi, maxi(zi - 1, 0))
	var u : float = _h(h, pts_x, xi, mini(zi + 1, pts_z - 1))
	return Vector3(l - r, 2.0 * CELL, d - u).normalized()

func _terrain_color(x: float, z: float, _y: float, green_z: float, cup_x: float) -> Color:
	var dist_from_center : float = absf(x - cup_x * (z / (green_z + GREEN_DEPTH)))
	if z >= green_z and dist_from_center < FAIRWAY_W * 0.6:
		return COL_GREEN
	if dist_from_center < FAIRWAY_W:
		return COL_FAIR
	return COL_ROUGH

# ── Hazard placement ──────────────────────────────────────────────────────────

func _place_hazards(length: float, heights: PackedFloat32Array, pts_x: int, pts_z: int) -> Array:
	var out        : Array = []
	var num_water  : int   = rng.randi_range(0, 2)
	var num_sand   : int   = rng.randi_range(1, 3)

	for _i in range(num_water):
		var tz    : float = rng.randf_range(0.25, 0.70)
		var tx    : float = rng.randf_range(0.25, 0.75)
		var zi    : int   = int(tz * float(pts_z - 1))
		var xi    : int   = int(tx * float(pts_x - 1))
		var gnd   : float = heights[zi * pts_x + xi]
		var x_w   : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
		var z_w   : float = float(zi) * CELL
		out.append({"type":"water","pos": Vector3(x_w, gnd + 0.05, z_w), "radius": rng.randf_range(3.5, 7.0)})

	for _i in range(num_sand):
		var tz    : float = rng.randf_range(0.15, 0.80)
		var tx    : float = rng.randf_range(0.20, 0.80)
		var zi    : int   = int(tz * float(pts_z - 1))
		var xi    : int   = int(tx * float(pts_x - 1))
		var gnd   : float = heights[zi * pts_x + xi]
		var x_w   : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
		var z_w   : float = float(zi) * CELL
		out.append({"type":"sand","pos": Vector3(x_w, gnd + 0.02, z_w), "radius": rng.randf_range(2.5, 5.5)})

	return out

# ── Node factories ────────────────────────────────────────────────────────────

func _make_water(pos: Vector3, radius: float) -> Area3D:
	var area := Area3D.new()
	area.name = "Water"
	area.set_meta("hazard_type", "water")

	var col   := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 2.5
	col.shape    = shape
	col.position = pos + Vector3(0.0, 1.0, 0.0)
	area.add_child(col)

	var vis   := MeshInstance3D.new()
	var cyl   := CylinderMesh.new()
	cyl.top_radius    = radius
	cyl.bottom_radius = radius
	cyl.height        = 0.18
	vis.mesh          = cyl
	var mat           := StandardMaterial3D.new()
	mat.albedo_color  = COL_WATER
	mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	vis.material_override = mat
	vis.position      = pos + Vector3(0.0, 0.09, 0.0)
	area.add_child(vis)

	return area

func _make_sand_disk(pos: Vector3, radius: float) -> MeshInstance3D:
	var vis  := MeshInstance3D.new()
	vis.name = "Sand"
	var cyl  := CylinderMesh.new()
	cyl.top_radius    = radius
	cyl.bottom_radius = radius
	cyl.height        = 0.12
	vis.mesh          = cyl
	var mat           := StandardMaterial3D.new()
	mat.albedo_color  = COL_SAND
	vis.material_override = mat
	vis.position      = pos + Vector3(0.0, 0.06, 0.0)
	return vis

func _make_flag(cup_pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = "Flag"

	# Pole (thin cylinder)
	var pole     := MeshInstance3D.new()
	var pole_cyl := CylinderMesh.new()
	pole_cyl.top_radius    = 0.04
	pole_cyl.bottom_radius = 0.04
	pole_cyl.height        = 3.2
	pole.mesh     = pole_cyl
	var pole_mat  := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.85, 0.85, 0.85)
	pole.material_override = pole_mat
	pole.position = cup_pos + Vector3(0.0, 1.6, 0.0)
	node.add_child(pole)

	# Flag (flat box)
	var flag     := MeshInstance3D.new()
	var flag_box := BoxMesh.new()
	flag_box.size = Vector3(1.0, 0.55, 0.04)
	flag.mesh     = flag_box
	var flag_mat  := StandardMaterial3D.new()
	flag_mat.albedo_color = COL_FLAG
	flag.material_override = flag_mat
	flag.position = cup_pos + Vector3(0.52, 2.95, 0.0)
	node.add_child(flag)

	return node

func _make_cup_marker(cup_pos: Vector3) -> MeshInstance3D:
	var vis  := MeshInstance3D.new()
	vis.name = "CupMarker"
	var cyl  := CylinderMesh.new()
	cyl.top_radius    = 0.55
	cyl.bottom_radius = 0.55
	cyl.height        = 0.08
	vis.mesh = cyl
	var mat  := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.06, 0.06)
	vis.material_override = mat
	vis.position = cup_pos + Vector3(0.0, 0.04, 0.0)
	return vis

# ── Par ───────────────────────────────────────────────────────────────────────

func _calc_par(length: float) -> int:
	if length < 130.0:
		return 3
	elif length < 200.0:
		return 4
	return 5
