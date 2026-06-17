extends Node

# ── Course dimensions ─────────────────────────────────────────────────────────
const CELL        : float = 2.0
const TERRAIN_W   : float = 110.0   # widened from 80 so doglegs have lateral room
const OVERRUN     : float = 35.0    # run-off behind the green

# ── Surface colours ───────────────────────────────────────────────────────────
const COL_ROUGH    : Color = Color(0.22, 0.46, 0.14)
const COL_FAIR     : Color = Color(0.28, 0.68, 0.20)
const COL_GREEN    : Color = Color(0.16, 0.82, 0.30)
const COL_FRINGE   : Color = Color(0.22, 0.58, 0.22)   # collar around the green
const COL_SAND     : Color = Color(0.88, 0.82, 0.48)
const COL_WATER    : Color = Color(0.16, 0.42, 0.82, 0.78)
const COL_WATERBED : Color = Color(0.10, 0.28, 0.34)   # lakebed under the translucent plane
const COL_FLAG     : Color = Color(0.95, 0.18, 0.18)
# Biome-specific rough tints (parkland keeps the default lush COL_ROUGH).
const COL_ROUGH_LINKS  : Color = Color(0.40, 0.50, 0.26)   # pale, dry seaside turf
const COL_ROUGH_FESCUE : Color = Color(0.52, 0.54, 0.28)   # golden tall-grass rough

# ── Cup well (unchanged machinery: a self-contained collar + walls + floor object
#    dropped into the flat green pad). See _make_cup_well for the full rationale. ──
const CUP_RADIUS    : float = 0.6
const CUP_DEPTH     : float = 0.55
const CUP_GATHER_R  : float = 1.2
const CUP_GATHER_D  : float = 0.10
const CUP_COLLAR_R  : float = 4.2
const COL_CUP       : Color = Color(0.90, 0.88, 0.82)
const COL_CUP_FLOOR : Color = Color(0.80, 0.78, 0.72)

# ── Green pad shaping ─────────────────────────────────────────────────────────
const GREEN_RAISE   : float = 0.5    # pad sits this far above the surrounding turf (the lip)
const GREEN_LIP_END : float = 1.28   # normalized ellipse dist where the bank finishes blending out

# ── Tee box ───────────────────────────────────────────────────────────────────
const TEE_RAISE    : float = 0.3     # tee pad sits this far above the surrounding turf
const TEE_HALF_LEN : float = 5.5     # pad half-extent along the line of play
const TEE_HALF_W   : float = 3.2     # pad half-extent across the line of play
const TEE_LIP      : float = 1.6     # blend band from pad down to natural turf
const TEE_PEG_H    : float = 0.35    # height the tee peg lifts the ball above the pad
const COL_TEE      : Color = Color(0.20, 0.56, 0.18)   # neat mown tee, a touch darker than fairway
const COL_TEE_MARK : Color = Color(0.92, 0.92, 0.95)   # white tee markers
const COL_PEG      : Color = Color(0.86, 0.74, 0.52)   # wooden tee peg
# Kept in sync with ball.gd BALL_RADIUS so the ball rests exactly on the peg top.
const BALL_R       : float = 0.117

const WIND_SHADER : Shader = preload("res://shaders/wind.gdshader")

var rng := RandomNumberGenerator.new()

# ── Public API ────────────────────────────────────────────────────────────────

func generate_hole(seed: int, biome: String = "parkland") -> Dictionary:
	rng.seed = seed

	var bp : Dictionary = _roll_blueprint(biome)

	var length         : float = bp["length"]
	var terrain_length : float = length + OVERRUN
	var segs_x         : int   = int(TERRAIN_W      / CELL)
	var segs_z         : int   = int(terrain_length / CELL)
	var pts_x          : int   = segs_x + 1
	var pts_z          : int   = segs_z + 1

	var fairway_half : float = bp["fairway_half"]
	var spine        : PackedVector2Array = _gen_spine(length, bp["template"], fairway_half)

	var heights : PackedFloat32Array = _gen_heights(pts_x, pts_z, terrain_length, bp)
	var tee     : Dictionary = _flatten_tee(heights, pts_x, pts_z, spine)

	# Defined, raised green pad with a lip. Returns the green footprint + pad height.
	var green : Dictionary = _shape_green(heights, pts_x, pts_z, spine, bp)

	# Shaped water bodies (carves basins into the heightmap, returns footprints).
	var water_bodies : Array = _build_water(heights, pts_x, pts_z, spine, fairway_half, green, bp)

	var cup_h_surface : float = green["pad_h"]
	var cup_x_off     : float = green["center"].x
	var cup_z_w       : float = green["center"].y

	# Rim sits CUP_GATHER_D below the green; cup well is placed on the flat pad.
	var rim_h : float = cup_h_surface - CUP_GATHER_D

	# Ball rests on top of the tee peg, which sits on the raised pad.
	var tee_pos         := Vector3(tee["center"].x, tee["pad_h"] + TEE_PEG_H + BALL_R, tee["center"].y)
	var cup_pos         := Vector3(cup_x_off, rim_h - CUP_DEPTH * 0.5, cup_z_w)
	var cup_pos_surface := Vector3(cup_x_off, cup_h_surface + 0.02,    cup_z_w)

	# Carved sand traps: gathering depressions the ball falls into (footprints only;
	# the basin is in the heightmap and the cells are coloured sand).
	var sand : Array = _build_sand(heights, pts_x, pts_z, spine, fairway_half, green, water_bodies)

	# Decorative vegetation (trees, grass tufts, scrub) scattered through the rough per
	# biome. Placement only -- the meshes are instanced in build_terrain. Computed here so
	# it shares the seeded rng and is fully deterministic for a given hole.
	var vegetation : Array = _build_vegetation(heights, pts_x, pts_z, spine, fairway_half, green, water_bodies, sand, tee, bp)

	return {
		"length"          : length,
		"terrain_length"  : terrain_length,
		"pts_x"           : pts_x,
		"pts_z"           : pts_z,
		"heights"         : heights,
		"tee_position"    : tee_pos,
		"tee"             : tee,
		"cup_position"    : cup_pos,
		"cup_pos_surface" : cup_pos_surface,
		"cup_base_h"      : cup_h_surface,
		"par"             : bp["par"],
		"sand"            : sand,
		"water_bodies"    : water_bodies,
		"cup_x_off"       : cup_x_off,
		"cup_z_w"         : cup_z_w,
		"spine"           : spine,
		"fairway_half"    : fairway_half,
		"green"           : green,
		"half_width"      : TERRAIN_W * 0.5,
		"biome"           : bp["biome"],
		"vegetation"      : vegetation,
	}

func build_terrain(data: Dictionary, parent: Node3D) -> void:
	var terrain_mesh : ArrayMesh = _build_mesh(data)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = terrain_mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	parent.add_child(mesh_inst)

	var terrain_body := StaticBody3D.new()
	terrain_body.name = "Terrain"
	var ground_pm := PhysicsMaterial.new()
	ground_pm.friction = 1.0
	ground_pm.bounce   = 0.0
	terrain_body.physics_material_override = ground_pm
	var col   := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(terrain_mesh.get_faces())
	shape.backface_collision = true
	col.shape = shape
	terrain_body.add_child(col)
	parent.add_child(terrain_body)

	# Shaped water: an organic translucent surface mesh. The hazard is detected by ball
	# position each frame (hole_manager) via water_at() -- no collider needed.
	for body: Dictionary in data["water_bodies"]:
		parent.add_child(_make_water_surface(body))

	# Sand traps are carved into the heightmap and coloured by the terrain mesh -- no
	# separate nodes; the ball detects them by position via get_surface_type.

	# Cup well + flag.
	parent.add_child(_make_cup_well(data["cup_x_off"], data["cup_z_w"], data["cup_base_h"]))
	parent.add_child(_make_flag(data["cup_pos_surface"]))

	# Tee box: a defined pad, two markers, and the peg the ball is teed up on.
	parent.add_child(_make_tee_box(data["tee"]))

	# Biome vegetation: trees, grass tufts and scrub, drawn with MultiMesh (one draw call
	# per type). Lives under `course`, so the per-hole teardown clears it like everything else.
	_build_vegetation_nodes(data, parent)

# ── Blueprint ─────────────────────────────────────────────────────────────────

func _roll_blueprint(biome: String = "parkland") -> Dictionary:
	# Par first (weighted), then length per par, shape, elevation theme, water feature.
	var par_roll : float = rng.randf()
	var par      : int
	var length   : float
	if par_roll < 0.30:
		par    = 3
		length = rng.randf_range(100.0, 150.0)
	elif par_roll < 0.75:
		par    = 4
		length = rng.randf_range(180.0, 255.0)
	else:
		par    = 5
		length = rng.randf_range(280.0, 360.0)

	# Shape template. S-curves only on the longer par 4/5 holes; par 3 stays mostly straight.
	var template : String
	if par == 3:
		template = ["straight", "straight", "dogleg_left", "dogleg_right"][rng.randi_range(0, 3)]
	else:
		var pool := ["straight", "dogleg_left", "dogleg_right"]
		if par == 5:
			pool.append("s_curve")
			pool.append("s_curve")
		else:
			pool.append("s_curve")
		template = pool[rng.randi_range(0, pool.size() - 1)]

	# Elevation theme. "cliff" is a signature drop reserved mostly for par 3s.
	var theme    : String = "rolling"
	var elev_a   : float  = 0.0
	var elev_break : float = 0.18
	var er : float = rng.randf()
	if par == 3 and er < 0.22:
		theme      = "cliff"
		elev_a     = rng.randf_range(8.0, 14.0)
		elev_break = rng.randf_range(0.14, 0.24)
	elif er < 0.30:
		theme  = "uphill"
		elev_a = rng.randf_range(3.0, 6.0)
	elif er < 0.55:
		theme  = "downhill"
		elev_a = rng.randf_range(3.0, 7.0)
	# else: rolling

	# Water feature. Bodies are large now and present on most holes.
	var water : String = "none"
	var wr : float = rng.randf()
	if theme == "cliff":
		# A cliff hole reads best clean; only an occasional lake below.
		water = "side_pond" if wr < 0.40 else "none"
	else:
		if wr < 0.32:
			water = "side_pond"
		elif wr < 0.62:
			water = "river"
		elif wr < 0.74 and par >= 4:
			water = "island_green"

	return {
		"par"          : par,
		"length"       : length,
		"template"     : template,
		"theme"        : theme,
		"elev_a"       : elev_a,
		"elev_break"   : elev_break,
		"water"        : water,
		"biome"        : biome,
		"fairway_half" : rng.randf_range(9.0, 12.0),
	}

# ── Spine (centerline polyline, world XZ) ─────────────────────────────────────

func _gen_spine(length: float, template: String, fairway_half: float) -> PackedVector2Array:
	var z_tee : float = 5.0
	var z_cup : float = length - 5.0
	var lim   : float = TERRAIN_W * 0.5 - fairway_half - 6.0   # keep fairway inside the course

	var pts := PackedVector2Array()
	pts.append(Vector2(0.0, z_tee))

	match template:
		"dogleg_left", "dogleg_right":
			var dir   : float = -1.0 if template == "dogleg_left" else 1.0
			var cf    : float = rng.randf_range(0.50, 0.62)
			var cx    : float = -dir * rng.randf_range(4.0, 10.0)   # landing favours the outside of the bend
			var swing : float = rng.randf_range(16.0, 26.0)
			pts.append(Vector2(clampf(cx * 0.5, -lim, lim), lerpf(z_tee, z_cup, cf * 0.6)))
			pts.append(Vector2(clampf(cx,        -lim, lim), lerpf(z_tee, z_cup, cf)))
			pts.append(Vector2(clampf(cx + dir * swing, -lim, lim), z_cup))
		"s_curve":
			var a : float = rng.randf_range(12.0, 20.0)
			var b : float = rng.randf_range(12.0, 20.0)
			pts.append(Vector2(clampf( a, -lim, lim), lerpf(z_tee, z_cup, 0.33)))
			pts.append(Vector2(clampf(-b, -lim, lim), lerpf(z_tee, z_cup, 0.66)))
			pts.append(Vector2(clampf(rng.randf_range(-5.0, 5.0), -lim, lim), z_cup))
		_:  # straight (with a slight drift so it's never a dead-straight line)
			pts.append(Vector2(clampf(rng.randf_range(-5.0, 5.0), -lim, lim), lerpf(z_tee, z_cup, 0.5)))
			pts.append(Vector2(clampf(rng.randf_range(-6.0, 6.0), -lim, lim), z_cup))

	return pts

func _dist_to_spine(x: float, z: float, spine: PackedVector2Array) -> float:
	var p    := Vector2(x, z)
	var best : float = INF
	for i in range(spine.size() - 1):
		var a  : Vector2 = spine[i]
		var b  : Vector2 = spine[i + 1]
		var ab : Vector2 = b - a
		var d  : float   = ab.dot(ab)
		var t  : float   = 0.0
		if d > 0.0001:
			t = clampf((p - a).dot(ab) / d, 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

func _spine_sample(spine: PackedVector2Array, frac: float) -> Vector2:
	# Point at `frac` of the spine's total length (0=tee, 1=cup).
	var total : float = 0.0
	for i in range(spine.size() - 1):
		total += spine[i].distance_to(spine[i + 1])
	var target : float = total * clampf(frac, 0.0, 1.0)
	var acc    : float = 0.0
	for i in range(spine.size() - 1):
		var seg : float = spine[i].distance_to(spine[i + 1])
		if acc + seg >= target and seg > 0.0001:
			return spine[i].lerp(spine[i + 1], (target - acc) / seg)
		acc += seg
	return spine[spine.size() - 1]

func _spine_tangent(spine: PackedVector2Array, frac: float) -> Vector2:
	var a : Vector2 = _spine_sample(spine, clampf(frac - 0.02, 0.0, 1.0))
	var b : Vector2 = _spine_sample(spine, clampf(frac + 0.02, 0.0, 1.0))
	var d : Vector2 = b - a
	return d.normalized() if d.length() > 0.0001 else Vector2(0.0, 1.0)

# ── Height map ────────────────────────────────────────────────────────────────

func _gen_heights(pts_x: int, pts_z: int, _terrain_length: float, bp: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(pts_x * pts_z)

	# Gentle rolling base from control points down the length, plus a lateral ripple.
	var ctrl_count : int = rng.randi_range(5, 10)
	var ctrl_y     : Array[float] = []
	ctrl_y.resize(ctrl_count + 1)
	ctrl_y[0] = 0.0
	for i in range(1, ctrl_count + 1):
		ctrl_y[i] = clampf(ctrl_y[i - 1] + rng.randf_range(-1.5, 1.5), -3.5, 3.5)

	for zi in range(pts_z):
		var t_z   : float = float(zi) / float(pts_z - 1)
		var seg_t : float = t_z * float(ctrl_count)
		var seg_i : int   = mini(int(seg_t), ctrl_count - 1)
		var seg_f : float = seg_t - float(seg_i)
		var row_h : float = lerpf(ctrl_y[seg_i], ctrl_y[seg_i + 1], seg_f)
		var elev  : float = _elev_profile(t_z, bp)

		for xi in range(pts_x):
			var lat_bump : float = sin(float(xi) * 0.6 + float(zi) * 0.4) * 0.3
			out[zi * pts_x + xi] = row_h + lat_bump + elev

	return out

func _elev_profile(t_z: float, bp: Dictionary) -> float:
	match bp["theme"]:
		"uphill":
			return bp["elev_a"] * t_z
		"downhill":
			return -bp["elev_a"] * t_z
		"cliff":
			# High tee bench, sharp drop, low green bench -- always shooting DOWN.
			var brk : float = bp["elev_break"]
			var s   : float = smoothstep(brk, brk + 0.12, t_z)
			return bp["elev_a"] * (1.0 - s)
		_:
			return 0.0

func _sample_height(heights: PackedFloat32Array, pts_x: int, pts_z: int, x_world: float, z_world: float) -> float:
	var xi : int = clampi(int(round((x_world + TERRAIN_W * 0.5) / CELL)), 0, pts_x - 1)
	var zi : int = clampi(int(round(z_world / CELL)), 0, pts_z - 1)
	return heights[zi * pts_x + xi]

# ── Public analytic surface (smooth, continuous) ──────────────────────────────
# The terrain mesh is collided as a faceted ConcavePolygonShape, which deflects the
# ball unpredictably off triangle edges. The ball instead reads the surface here --
# bilinearly interpolated height and a continuous normal -- so its bounce is computed
# against the smooth shape the player actually sees, not the raw facets.

func height_at(x_world: float, z_world: float, hole_data: Dictionary) -> float:
	var heights : PackedFloat32Array = hole_data.get("heights", PackedFloat32Array())
	if heights.is_empty():
		return 0.0
	var pts_x : int = hole_data["pts_x"]
	var pts_z : int = hole_data["pts_z"]
	# Continuous grid coordinates, clamped a hair inside so the +1 corner is always valid.
	var gx : float = clampf((x_world + TERRAIN_W * 0.5) / CELL, 0.0, float(pts_x - 1) - 0.0001)
	var gz : float = clampf(z_world / CELL,                      0.0, float(pts_z - 1) - 0.0001)
	var x0 : int = int(gx)
	var z0 : int = int(gz)
	var fx : float = gx - float(x0)
	var fz : float = gz - float(z0)
	var h00 : float = heights[z0 * pts_x + x0]
	var h10 : float = heights[z0 * pts_x + x0 + 1]
	var h01 : float = heights[(z0 + 1) * pts_x + x0]
	var h11 : float = heights[(z0 + 1) * pts_x + x0 + 1]
	var top : float = lerpf(h00, h10, fx)
	var bot : float = lerpf(h01, h11, fx)
	return lerpf(top, bot, fz)

func surface_normal_at(x_world: float, z_world: float, hole_data: Dictionary) -> Vector3:
	# Central differences of the bilinear height, in world units. Sign convention matches
	# _calc_normal so it points up out of the turf.
	var hl : float = height_at(x_world - CELL, z_world, hole_data)
	var hr : float = height_at(x_world + CELL, z_world, hole_data)
	var hd : float = height_at(x_world, z_world - CELL, hole_data)
	var hu : float = height_at(x_world, z_world + CELL, hole_data)
	return Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized()

func _flatten_tee(heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array) -> Dictionary:
	# A defined, slightly raised rectangular tee pad aligned down the line of play
	# (rather than a bare circle), with a short lip blending out to the natural turf.
	var center : Vector2 = spine[0]
	var dir    : Vector2 = (spine[1] - center).normalized() if spine.size() >= 2 else Vector2(0.0, 1.0)
	var across : Vector2 = Vector2(-dir.y, dir.x)
	var pad_h  : float   = _sample_height(heights, pts_x, pts_z, center.x, center.y) + TEE_RAISE

	for zi in range(pts_z):
		for xi in range(pts_x):
			var x : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
			var z : float = float(zi) * CELL
			var d : Vector2 = Vector2(x - center.x, z - center.y)
			# Distance outside the rectangle (0 when inside the pad).
			var ol : float = maxf(absf(d.dot(dir))    - TEE_HALF_LEN, 0.0)
			var op : float = maxf(absf(d.dot(across)) - TEE_HALF_W,   0.0)
			var outside : float = sqrt(ol * ol + op * op)
			var idx : int = zi * pts_x + xi
			if outside <= 0.0:
				heights[idx] = pad_h
			elif outside < TEE_LIP:
				var t : float = outside / TEE_LIP
				heights[idx] = lerpf(pad_h, heights[idx], t * t * (3.0 - 2.0 * t))

	return { "center": center, "dir": dir, "pad_h": pad_h }

# ── Green: raised pad with a lip ──────────────────────────────────────────────

func _shape_green(heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, bp: Dictionary) -> Dictionary:
	var center : Vector2 = spine[spine.size() - 1]
	# Bigger greens (~50%+ larger) with a wider spread of size and aspect, plus more
	# rotation, so holes vary from broad shallow shelves to deep angled ones.
	var rz     : float   = rng.randf_range(12.0, 18.0)   # depth (along the line of play)
	var rx     : float   = rng.randf_range(10.5, 15.5)   # width (across)
	var rot    : float   = rng.randf_range(-0.5, 0.5)
	if bp["water"] == "island_green":
		rx = rng.randf_range(12.0, 15.0)
		rz = rng.randf_range(13.5, 18.0)
		rot = 0.0

	var pad_h : float = _sample_height(heights, pts_x, pts_z, center.x, center.y) + GREEN_RAISE

	for zi in range(pts_z):
		for xi in range(pts_x):
			var x  : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
			var z  : float = float(zi) * CELL
			var nd : float = _green_norm_dist(x, z, center, rx, rz, rot)
			if nd <= 1.0:
				heights[zi * pts_x + xi] = pad_h
			elif nd <= GREEN_LIP_END:
				# Short bank from the raised pad down to the natural turf -> a defined lip.
				var t : float = (nd - 1.0) / (GREEN_LIP_END - 1.0)
				heights[zi * pts_x + xi] = lerpf(pad_h, heights[zi * pts_x + xi], t * t * (3.0 - 2.0 * t))

	return { "center": center, "rx": rx, "rz": rz, "rot": rot, "pad_h": pad_h }

func _green_norm_dist(x: float, z: float, center: Vector2, rx: float, rz: float, rot: float) -> float:
	var dx : float = x - center.x
	var dz : float = z - center.y
	var lx : float =  dx * cos(rot) + dz * sin(rot)
	var lz : float = -dx * sin(rot) + dz * cos(rot)
	return sqrt((lx / rx) * (lx / rx) + (lz / rz) * (lz / rz))

# ── Water: shaped bodies (carve basin + footprint) ────────────────────────────

func _build_water(heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, fairway_half: float, green: Dictionary, bp: Dictionary) -> Array:
	var bodies : Array = []
	match bp["water"]:
		"side_pond":
			# Water running alongside the fairway: a band that hugs the fairway edge
			# (following the spine, so it never merges into the corridor) and fills
			# outward to the play-area boundary. May appear on one or both sides.
			bodies.append_array(_build_side_water(heights, pts_x, pts_z, spine, fairway_half, green))
		"river":
			# A river crossing the hole, running clean off both edges of the scene.
			bodies.append(_build_river(heights, pts_x, pts_z, spine, green))
		"island_green":
			# The green ringed by water on its back and both sides, open at the front.
			bodies.append(_build_island_water(heights, pts_x, pts_z, spine, green))
	return bodies

# ── Water: a river crossing the hole, running off both edges of the scene ─────
# A river is a meandering band whose long axis crosses the line of play. Unlike a pond it
# never tapers to a point: the channel keeps its width all the way to the lateral edges of
# the course, so it reads as flowing in from off-screen and out the far side. Same render
# safeguards as the side water -- the surface level sits below the lowest point of either
# bank, and the dry cells right at the shore are lifted to the waterline -- so the flat
# plane never floats or clips.

func _build_river(heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, green: Dictionary) -> Dictionary:
	var t   : float   = rng.randf_range(0.42, 0.60)
	var c   : Vector2 = _spine_sample(spine, t)
	var tng : Vector2 = _spine_tangent(spine, t)
	var rot : float   = atan2(tng.y, tng.x) + PI * 0.5   # long axis perpendicular to play
	var hb  : float   = rng.randf_range(5.0, 8.0)        # channel half-width
	var body : Dictionary = {
		"kind": "river", "center": c, "rot": rot, "hb": hb, "green": green,
		"z_max": float(pts_z - 1) * CELL,
		"m_amp": hb * rng.randf_range(0.4, 0.8), "m_freq": rng.randf_range(0.04, 0.09), "m_phase": rng.randf_range(0.0, TAU),
		"w_freq": rng.randf_range(0.06, 0.13),   "w_phase": rng.randf_range(0.0, TAU),
	}
	# Flat surface must sit below the lowest point of either bank along the whole length, or
	# the plane floats over any dip. Walk both banks across the course and take the lowest.
	var axis : Vector2 = Vector2(cos(rot), sin(rot))
	var perp : Vector2 = Vector2(-sin(rot), cos(rot))
	var lowest : float = INF
	var stations : int = 96
	for k in range(stations + 1):
		var lu : float = lerpf(-TERRAIN_W, TERRAIN_W, float(k) / float(stations))
		var rp : Dictionary = _river_profile(lu, body)
		for sgn in [-1.0, 1.0]:
			var bank : Vector2 = c + axis * lu + perp * (rp["center"] + sgn * (rp["half_w"] + CELL))
			if absf(bank.x) <= TERRAIN_W * 0.5 and bank.y >= 0.0 and bank.y <= body["z_max"]:
				lowest = minf(lowest, _sample_height(heights, pts_x, pts_z, bank.x, bank.y))
	if lowest == INF:
		lowest = _sample_height(heights, pts_x, pts_z, c.x, c.y)
	body["water_y"] = lowest - 0.4
	body["basin_y"] = body["water_y"] - 1.6
	_carve_river(heights, pts_x, pts_z, body)
	return body

# River centerline meander and (rippling, never-tapering) half-width at distance `lu` along
# the long axis. Kept as one function so carve, surface and hazard test agree exactly.
func _river_profile(lu: float, body: Dictionary) -> Dictionary:
	var ripple : float = 0.85 + 0.15 * sin(lu * body["w_freq"] + body["w_phase"])
	return {
		"center": body["m_amp"] * sin(lu * body["m_freq"] + body["m_phase"]),
		"half_w": body["hb"] * ripple,
	}

func _river_local(x: float, z: float, body: Dictionary) -> Vector2:
	var dx  : float = x - body["center"].x
	var dz  : float = z - body["center"].y
	var rot : float = body["rot"]
	return Vector2(dx * cos(rot) + dz * sin(rot), -dx * sin(rot) + dz * cos(rot))   # (lu, lv)

func _in_river_body(x: float, z: float, body: Dictionary) -> bool:
	var g : Dictionary = body["green"]
	if _green_norm_dist(x, z, g["center"], g["rx"], g["rz"], g["rot"]) <= GREEN_LIP_END:
		return false
	var luv : Vector2 = _river_local(x, z, body)
	var rp  : Dictionary = _river_profile(luv.x, body)
	return absf(luv.y - rp["center"]) <= rp["half_w"]

func _carve_river(heights: PackedFloat32Array, pts_x: int, pts_z: int, body: Dictionary) -> void:
	var water_y : float = body["water_y"]
	var basin_y : float = body["basin_y"]
	var g       : Dictionary = body["green"]
	var shore   : float = 2.5
	for zi in range(pts_z):
		for xi in range(pts_x):
			var x : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
			var z : float = float(zi) * CELL
			if _green_norm_dist(x, z, g["center"], g["rx"], g["rz"], g["rot"]) <= GREEN_LIP_END:
				continue
			var luv : Vector2 = _river_local(x, z, body)
			var rp  : Dictionary = _river_profile(luv.x, body)
			var din : float = rp["half_w"] - absf(luv.y - rp["center"])
			var idx : int = zi * pts_x + xi
			if din <= 0.0:
				# Just outside the bank: guarantee the dry cell sits at/above the waterline so
				# the surface strip's edge never floats over a lower bit of ground.
				if din > -1.5 * CELL:
					heights[idx] = maxf(heights[idx], water_y + 0.15)
				continue
			if din >= shore:
				heights[idx] = minf(heights[idx], basin_y)
			else:
				heights[idx] = minf(heights[idx], lerpf(water_y, basin_y, din / shore))

func _make_river_surface(body: Dictionary) -> MeshInstance3D:
	var rot  : float   = body["rot"]
	var axis : Vector2 = Vector2(cos(rot), sin(rot))
	var perp : Vector2 = Vector2(-sin(rot), cos(rot))
	var c    : Vector2 = body["center"]
	var wy   : float   = body["water_y"] + 0.02
	var hw   : float   = TERRAIN_W * 0.5
	var zmax : float   = body["z_max"]
	var seg  : int     = 80
	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in range(seg + 1):
		var lu : float = lerpf(-TERRAIN_W, TERRAIN_W, float(i) / float(seg))
		var rp : Dictionary = _river_profile(lu, body)
		var bl : Vector2 = c + axis * lu + perp * (rp["center"] + rp["half_w"])
		var br : Vector2 = c + axis * lu + perp * (rp["center"] - rp["half_w"])
		# Clamp the banks to the playfield so the strip ends exactly at the scene edge.
		bl.x = clampf(bl.x, -hw, hw); bl.y = clampf(bl.y, 0.0, zmax)
		br.x = clampf(br.x, -hw, hw); br.y = clampf(br.y, 0.0, zmax)
		verts.append(Vector3(bl.x, wy, bl.y))
		verts.append(Vector3(br.x, wy, br.y))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
	for i in range(seg):
		var l0 : int = i * 2
		indices.append_array(PackedInt32Array([l0, l0 + 1, l0 + 2, l0 + 2, l0 + 1, l0 + 3]))
	return _water_surface_node(verts, normals, indices)

# ── Water: an island-style green ringed by water on the back and both sides ───
# The green sits on the near shore of a large lake. Water fills everything behind a front
# shoreline (a line just ahead of the green) out to the back and lateral edges of the
# course; the approach in front stays dry. The raised green pad stands above the water
# level, so the flat lake surface simply passes UNDER it -- no hole needs to be cut.

func _build_island_water(heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, green: Dictionary) -> Dictionary:
	var gc  : Vector2 = green["center"]
	var pd  : Vector2 = _spine_tangent(spine, 1.0)        # play direction at the green
	# Front shoreline sits a touch behind the green's front edge, so the approach in front
	# stays dry land while water wraps the full sides and the back of the green.
	var front_inset : float = rng.randf_range(1.5, 3.5)
	var water_y     : float = green["pad_h"] - rng.randf_range(1.0, 1.8)
	var body : Dictionary = {
		"kind": "island", "center": gc, "pd": pd, "green": green,
		"s_thresh": -green["rz"] + front_inset,           # front shoreline, in play-dir space
		"water_y": water_y, "basin_y": water_y - 1.6,
		"pts_x": pts_x, "pts_z": pts_z,
		"m_amp": rng.randf_range(1.0, 2.2), "m_freq": rng.randf_range(0.06, 0.12), "m_phase": rng.randf_range(0.0, TAU),
	}
	_carve_island(heights, pts_x, pts_z, body)
	return body

# Forward distance from the green centre along the play direction (negative = in front of
# the green), with a gentle meander so the front shoreline isn't a dead-straight cut.
func _island_s(x: float, z: float, body: Dictionary) -> float:
	var pd   : Vector2 = body["pd"]
	var perp : Vector2 = Vector2(-pd.y, pd.x)
	var d    : Vector2 = Vector2(x - body["center"].x, z - body["center"].y)
	return d.dot(pd) + body["m_amp"] * sin(d.dot(perp) * body["m_freq"] + body["m_phase"])

func _in_island_body(x: float, z: float, body: Dictionary) -> bool:
	var g : Dictionary = body["green"]
	if _green_norm_dist(x, z, g["center"], g["rx"], g["rz"], g["rot"]) <= GREEN_LIP_END:
		return false
	return _island_s(x, z, body) >= body["s_thresh"]

func _carve_island(heights: PackedFloat32Array, pts_x: int, pts_z: int, body: Dictionary) -> void:
	var water_y  : float = body["water_y"]
	var basin_y  : float = body["basin_y"]
	var g        : Dictionary = body["green"]
	var s_thresh : float = body["s_thresh"]
	var edge_r   : float = minf(g["rx"], g["rz"])
	var shore    : float = 3.0
	for zi in range(pts_z):
		for xi in range(pts_x):
			var x : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
			var z : float = float(zi) * CELL
			var nd : float = _green_norm_dist(x, z, g["center"], g["rx"], g["rz"], g["rot"])
			if nd <= GREEN_LIP_END:
				continue
			var s : float = _island_s(x, z, body)
			var idx : int = zi * pts_x + xi
			if s < s_thresh:
				# Dry approach in front: lift the cells right at the shore so the lake's front
				# edge always meets ground at/above the water surface.
				if s > s_thresh - 1.5 * CELL:
					heights[idx] = maxf(heights[idx], water_y + 0.15)
				continue
			# Shelve the bank by the nearer of the front shoreline and the green's edge, so the
			# lake slopes down both at the approach and all around the island.
			var din : float = minf(s - s_thresh, (nd - GREEN_LIP_END) * edge_r)
			if din >= shore:
				heights[idx] = minf(heights[idx], basin_y)
			else:
				heights[idx] = minf(heights[idx], lerpf(water_y, basin_y, din / shore))

func _make_island_surface(body: Dictionary) -> MeshInstance3D:
	# A flat lake quilt: a quad for every terrain cell whose centre lies in the water region.
	# Built on the terrain grid, so it is inherently clamped to the playfield and aligned to
	# the carved cells; the raised green pad occludes the plane where it crosses.
	var pts_x : int   = body["pts_x"]
	var pts_z : int   = body["pts_z"]
	var wy    : float = body["water_y"] + 0.02
	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for zi in range(pts_z - 1):
		for xi in range(pts_x - 1):
			var xc : float = (-TERRAIN_W * 0.5) + (float(xi) + 0.5) * CELL
			var zc : float = (float(zi) + 0.5) * CELL
			if not _in_island_body(xc, zc, body):
				continue
			var x0 : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
			var z0 : float = float(zi) * CELL
			var x1 : float = x0 + CELL
			var z1 : float = z0 + CELL
			var b  : int = verts.size()
			verts.append(Vector3(x0, wy, z0))
			verts.append(Vector3(x1, wy, z0))
			verts.append(Vector3(x0, wy, z1))
			verts.append(Vector3(x1, wy, z1))
			for _n in range(4):
				normals.append(Vector3.UP)
			indices.append_array(PackedInt32Array([b, b + 2, b + 1, b + 1, b + 2, b + 3]))
	return _water_surface_node(verts, normals, indices)

# ── Water: side bands (follow the fairway edge, fill out to the play-area edge) ──
# A "side" body is defined RELATIVE TO THE SPINE rather than as a straight blob, so it
# tracks the fairway as it curves and can never drift into the corridor. Membership: a
# point on the chosen side of the spine whose perpendicular distance is past the
# fairway edge (plus a clearance) and within the band's along-hole range -- filled all
# the way out to the lateral edge of the course.

func _build_side_water(heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, fairway_half: float, green: Dictionary) -> Array:
	var out : Array = []
	var cup_x : float = green["center"].x
	# Primary side hugs AWAY from the cup so the route to the pin stays dry. With the
	# spine running up the hole, side = +1 puts water on the -x side (see _spine_project).
	var primary : float = (1.0 if cup_x >= 0.0 else -1.0)
	if absf(cup_x) < 3.0:
		primary = 1.0 if rng.randf() > 0.5 else -1.0
	out.append(_make_side_body(heights, pts_x, pts_z, spine, fairway_half, green, primary))
	# Occasionally water down BOTH sides, leaving the fairway as a dry causeway.
	if rng.randf() < 0.22:
		out.append(_make_side_body(heights, pts_x, pts_z, spine, fairway_half, green, -primary))
	return out

func _make_side_body(heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, fairway_half: float, green: Dictionary, side: float) -> Dictionary:
	var clearance : float = rng.randf_range(1.5, 3.5)   # dry rough between fairway and shore
	var inner     : float = fairway_half + clearance
	var frac0     : float = rng.randf_range(0.10, 0.20)   # starts past the tee
	var frac1     : float = rng.randf_range(0.82, 0.95)   # runs up toward the green
	var r_amp     : float = rng.randf_range(2.5, 5.0)
	var r_freq    : float = rng.randf_range(6.0, 13.0)
	var r_phase   : float = rng.randf_range(0.0, TAU)
	# Spine length so the mesh can clamp its outer edge to the playfield in z.
	var spine_len : float = 0.0
	for i in range(spine.size() - 1):
		spine_len += spine[i].distance_to(spine[i + 1])
	# A flat lake needs a level BELOW its whole shoreline, or the plane's edge floats over
	# any stretch of bank that happens to sit lower. Walk the inner shoreline (plus a step
	# either side of it, to cover the boundary grid cells) and take the lowest turf.
	var lowest : float = INF
	var stations : int = 64
	for k in range(stations + 1):
		var frac : float   = lerpf(frac0, frac1, float(k) / float(stations))
		var p    : Vector2 = _spine_sample(spine, frac)
		var t    : Vector2 = _spine_tangent(spine, frac)
		var nrm  : Vector2 = Vector2(-t.y, t.x) * side
		var off  : float   = inner + r_amp * sin(frac * r_freq + r_phase)
		for d in [-2.0 * CELL, -CELL, 0.0, CELL]:
			var pt : Vector2 = p + nrm * (off + d)
			lowest = minf(lowest, _sample_height(heights, pts_x, pts_z, pt.x, pt.y))
	var water_y : float = lowest - 0.5
	var body : Dictionary = {
		"kind": "side", "spine": spine, "spine_len": spine_len, "side": side,
		"inner": inner, "outer": TERRAIN_W,   # outer reach = fill to the course edge (mid-band)
		"frac0": frac0, "frac1": frac1, "fade": 0.16,
		"water_y": water_y, "basin_y": water_y - 1.6,
		"r_amp": r_amp, "r_freq": r_freq, "r_phase": r_phase,
		"green": green,
	}
	_carve_side(heights, pts_x, pts_z, body)
	return body

# Project a point onto the spine: unsigned distance, side-signed distance, and the
# fraction along the spine's length (0 = tee, 1 = cup).
func _spine_project(p: Vector2, spine: PackedVector2Array) -> Dictionary:
	var total : float = 0.0
	for i in range(spine.size() - 1):
		total += spine[i].distance_to(spine[i + 1])
	var best_d2  : float = INF
	var best_sgn : float = 0.0
	var best_arc : float = 0.0
	var acc      : float = 0.0
	for i in range(spine.size() - 1):
		var a  : Vector2 = spine[i]
		var b  : Vector2 = spine[i + 1]
		var ab : Vector2 = b - a
		var d  : float   = ab.dot(ab)
		var t  : float   = 0.0
		if d > 0.0001:
			t = clampf((p - a).dot(ab) / d, 0.0, 1.0)
		var closest : Vector2 = a + ab * t
		var dd      : float   = p.distance_squared_to(closest)
		if dd < best_d2:
			best_d2 = dd
			var cross : float = ab.x * (p.y - a.y) - ab.y * (p.x - a.x)
			best_sgn = sqrt(dd) * signf(cross)
			best_arc = acc + ab.length() * t
		acc += ab.length()
	var frac : float = (best_arc / total) if total > 0.0 else 0.0
	return { "dist": sqrt(best_d2), "signed": best_sgn, "frac": frac }

# The inner shoreline offset (from the spine) at a given along-hole fraction: the base
# clearance plus an organic ripple so the bank is not a dead-straight line.
func _side_inner_edge(frac: float, body: Dictionary) -> float:
	return body["inner"] + body["r_amp"] * sin(frac * body["r_freq"] + body["r_phase"])

# The outer reach at a given fraction. The band fills out to the course edge in the
# middle but tapers shut at both ends (outer -> inner), so the lake is a leaf shape with
# no long straight end edge to float over the bank.
func _side_outer_edge(frac: float, body: Dictionary) -> float:
	var f0 : float = body["frac0"]
	var f1 : float = body["frac1"]
	var fd : float = body["fade"]
	var e  : float = smoothstep(f0, f0 + fd, frac) * (1.0 - smoothstep(f1 - fd, f1, frac))
	return lerpf(_side_inner_edge(frac, body), body["outer"], e)

func _in_side_body(x: float, z: float, body: Dictionary) -> bool:
	var pr   : Dictionary = _spine_project(Vector2(x, z), body["spine"])
	var frac : float = pr["frac"]
	if frac <= body["frac0"] or frac >= body["frac1"]:
		return false
	var sp : float = body["side"] * pr["signed"]   # perpendicular distance on the chosen side
	if sp < _side_inner_edge(frac, body) or sp > _side_outer_edge(frac, body):
		return false
	var g : Dictionary = body["green"]
	# Keep clear of the green pad and its lip (lip finishes at GREEN_LIP_END = 1.28).
	if _green_norm_dist(x, z, g["center"], g["rx"], g["rz"], g["rot"]) <= 1.45:
		return false
	return true

func _carve_side(heights: PackedFloat32Array, pts_x: int, pts_z: int, body: Dictionary) -> void:
	var spine     : PackedVector2Array = body["spine"]
	var side      : float = body["side"]
	var f0        : float = body["frac0"]
	var f1        : float = body["frac1"]
	var water_y   : float = body["water_y"]
	var basin_y   : float = body["basin_y"]
	var g         : Dictionary = body["green"]
	var shore     : float = 3.0   # underwater bank slope width (world units)
	for zi in range(pts_z):
		for xi in range(pts_x):
			var x : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
			var z : float = float(zi) * CELL
			var pr : Dictionary = _spine_project(Vector2(x, z), spine)
			var frac : float = pr["frac"]
			if frac <= f0 or frac >= f1:
				continue
			if _green_norm_dist(x, z, g["center"], g["rx"], g["rz"], g["rot"]) <= 1.45:
				continue
			var sp : float = side * pr["signed"]
			var inner_eff : float = _side_inner_edge(frac, body)
			var outer_eff : float = _side_outer_edge(frac, body)
			var idx : int = zi * pts_x + xi
			if sp < inner_eff or sp > outer_eff:
				# Just outside the inner shoreline: lift the immediate dry cell to a hair
				# above the water level so the plane edge (which lands on the boundary)
				# always meets ground at/above the surface -- a hard no-float guarantee.
				if sp >= inner_eff - 1.5 * CELL and sp < inner_eff:
					heights[idx] = maxf(heights[idx], water_y + 0.15)
				continue
			# Distance inside the banks: from the inner shoreline and from the (tapered) outer
			# edge. In the wide middle the outer term is huge, so only the inner bank slopes;
			# at the pinched ends both terms shrink, giving a naturally tapered shore.
			var din : float = minf(sp - inner_eff, outer_eff - sp)
			if din >= shore:
				heights[idx] = minf(heights[idx], basin_y)
			else:
				heights[idx] = minf(heights[idx], lerpf(water_y, basin_y, din / shore))

func _make_side_surface(body: Dictionary) -> MeshInstance3D:
	# A translucent strip from the inner shoreline out to the course edge, walked along
	# the spine so it follows the same curve the carve used.
	var seg     : int   = 64
	var spine   : PackedVector2Array = body["spine"]
	var side    : float = body["side"]
	var f0      : float = body["frac0"]
	var f1      : float = body["frac1"]
	var wy      : float = body["water_y"] + 0.02
	var hw      : float = TERRAIN_W * 0.5
	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in range(seg + 1):
		var frac : float   = lerpf(f0, f1, float(i) / float(seg))
		var p    : Vector2 = _spine_sample(spine, frac)
		var t    : Vector2 = _spine_tangent(spine, frac)
		var nrm  : Vector2 = Vector2(-t.y, t.x) * side
		var wi   : Vector2 = p + nrm * _side_inner_edge(frac, body)   # inner shoreline
		var wo   : Vector2 = p + nrm * _side_outer_edge(frac, body)   # outward, tapered at the ends
		wo.x = clampf(wo.x, -hw, hw)
		wo.y = clampf(wo.y, 0.0, float(body["spine_len"]) + OVERRUN)
		verts.append(Vector3(wi.x, wy, wi.y))
		verts.append(Vector3(wo.x, wy, wo.y))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
	for i in range(seg):
		var l0 : int = i * 2
		indices.append_array(PackedInt32Array([l0, l0 + 1, l0 + 2, l0 + 2, l0 + 1, l0 + 3]))

	return _water_surface_node(verts, normals, indices)

# Wrap raw arrays in a translucent water MeshInstance3D -- one material/look shared by every
# water body (side, river, island) so they all read identically.
func _water_surface_node(verts: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> MeshInstance3D:
	var arr := Array()
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_INDEX]  = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	var mi  := MeshInstance3D.new()
	mi.name  = "WaterSurface"
	mi.mesh  = mesh
	var mat  := StandardMaterial3D.new()
	mat.albedo_color = COL_WATER
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness    = 0.1
	mat.metallic     = 0.2
	mat.cull_mode    = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi

func _in_body(x: float, z: float, body: Dictionary) -> bool:
	match body.get("kind", "side"):
		"river":  return _in_river_body(x, z, body)
		"island": return _in_island_body(x, z, body)
		_:        return _in_side_body(x, z, body)

func _in_water(x: float, z: float, water_bodies: Array) -> bool:
	for b: Dictionary in water_bodies:
		if _in_body(x, z, b):
			return true
	return false

# Is any water body within `r` of `c`? Tests the centre plus a ring of rim points, so a
# whole footprint (e.g. a sand bowl) can be kept clear of the shoreline.
func _water_within(c: Vector2, r: float, water_bodies: Array) -> bool:
	if _in_water(c.x, c.y, water_bodies):
		return true
	for a in range(8):
		var ang : float = TAU * float(a) / 8.0
		var p   : Vector2 = c + Vector2(cos(ang), sin(ang)) * r
		if _in_water(p.x, p.y, water_bodies):
			return true
	return false

# Public: is this point in (and at/under the surface of) a water body? Used by
# hole_manager each physics frame to trigger the water penalty (no Area3D needed).
func water_at(x: float, z: float, y: float, hole_data: Dictionary) -> bool:
	for b: Dictionary in hole_data.get("water_bodies", []):
		if y <= b["water_y"] + 0.2 and _in_body(x, z, b):
			return true
	return false

# ── Sand: carved gathering traps ──────────────────────────────────────────────

func _build_sand(heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, fairway_half: float, green: Dictionary, water: Array) -> Array:
	var out      : Array = []
	var num_sand : int   = rng.randi_range(1, 3)
	for _i in range(num_sand):
		var t   : float   = rng.randf_range(0.30, 0.92)
		var c   : Vector2 = _spine_sample(spine, t)
		var tng : Vector2 = _spine_tangent(spine, t)
		var nrm : Vector2 = Vector2(-tng.y, tng.x)
		var side: float   = 1.0 if rng.randf() > 0.5 else -1.0

		# Greenside traps hug the pad (small + deep); fairway traps sit out wide
		# (large + shallow). "Greenside" is judged by proximity to the green centre.
		var near_green : bool = c.distance_to(green["center"]) < (green["rz"] + 14.0)
		var radius : float
		var depth  : float
		var off    : float
		if near_green:
			radius = rng.randf_range(2.0, 3.5)
			depth  = rng.randf_range(0.8, 1.3)
			off    = green["rx"] + rng.randf_range(2.0, 5.0)   # just off the pad edge
		else:
			radius = rng.randf_range(3.5, 6.0)
			depth  = rng.randf_range(0.4, 0.7)
			off    = fairway_half * rng.randf_range(0.5, 1.2)

		var pos2 : Vector2 = c + nrm * side * off
		# Keep traps off the green pad and out of any water body.
		if _green_norm_dist(pos2.x, pos2.y, green["center"], green["rx"] + 1.0, green["rz"] + 1.0, green["rot"]) <= 1.0:
			continue
		# Reject if the bowl (rim + a small buffer) would touch water -- otherwise the trap
		# carves the dry shoreline the water plane rests on and the edge appears to float.
		if _water_within(pos2, radius + 2.0, water):
			continue
		_carve_sand(heights, pts_x, pts_z, pos2, radius, depth)
		out.append({"center": pos2, "radius": radius})
	return out

func _carve_sand(heights: PackedFloat32Array, pts_x: int, pts_z: int, center: Vector2, radius: float, depth: float) -> void:
	# Smooth paraboloid bowl: rim meets the surrounding turf, centre is deepest, so the
	# ball rolls in and gathers at the bottom. min() keeps the carve from ever raising land.
	var base : float = _sample_height(heights, pts_x, pts_z, center.x, center.y)
	var r0   : int   = maxi(int(round((center.x + TERRAIN_W * 0.5 - radius) / CELL)), 0)
	var r1   : int   = mini(int(round((center.x + TERRAIN_W * 0.5 + radius) / CELL)), pts_x - 1)
	var z0   : int   = maxi(int(round((center.y - radius) / CELL)), 0)
	var z1   : int   = mini(int(round((center.y + radius) / CELL)), pts_z - 1)
	for zi in range(z0, z1 + 1):
		for xi in range(r0, r1 + 1):
			var x    : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
			var z    : float = float(zi) * CELL
			var dist : float = Vector2(x - center.x, z - center.y).length()
			if dist >= radius:
				continue
			var f : float = dist / radius
			var target : float = base - depth * (1.0 - f * f)
			var idx : int = zi * pts_x + xi
			heights[idx] = minf(heights[idx], target)

func _in_sand(x: float, z: float, sand: Array) -> bool:
	for s: Dictionary in sand:
		if Vector2(x - s["center"].x, z - s["center"].y).length() <= s["radius"]:
			return true
	return false

# ── Vegetation: per-biome scatter (placement only; meshes built in build_terrain) ──
# Each entry is {type, pos (world Vector3 at ground), yaw, scale}. Vegetation only ever
# lands on "rough" turf (so it stays off the fairway, green, fringe, water and sand) and
# clear of the tee pad. Counts below are caps -- lower them if a target device chugs.

func _build_vegetation(heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, fairway_half: float, green: Dictionary, water: Array, sand: Array, tee: Dictionary, bp: Dictionary) -> Array:
	var out   : Array = []
	var z_max : float = float(pts_z - 1) * CELL
	match bp["biome"]:
		"parkland":
			# Tree-lined: a dense gallery of trees hugging both fairway edges, plus a light
			# carpet of short grass.
			_veg_line_trees(out, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, 0.55, Vector2(2.0, 13.0), 1.0, 1.7)
			_veg_scatter(out, "grass", 220, 0.4, 0.8, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, z_max)
		"links":
			# Open seaside links: almost no trees, low gorse-like scrub and wispy short grass.
			_veg_line_trees(out, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, 0.04, Vector2(4.0, 16.0), 0.9, 1.4)
			_veg_scatter(out, "scrub", 90,  0.7, 1.3, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, z_max)
			_veg_scatter(out, "grass", 280, 0.3, 0.6, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, z_max)
		"fescue":
			# Tall fescue: the rough is a sea of grass. Tufts are half-height now but twice as
			# dense, so the sea reads thicker without any single blade towering over the ball.
			_veg_scatter(out, "grass", 4400, 0.7, 1.3, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, z_max)
			_veg_line_trees(out, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, 0.12, Vector2(3.0, 14.0), 1.0, 1.6)
	return out

# Is (x, z) a valid spot for vegetation: rough turf, clear of the tee pad.
func _veg_ok(x: float, z: float, spine: PackedVector2Array, fairway_half: float, green: Dictionary, water: Array, sand: Array, tee: Dictionary) -> bool:
	if _classify(x, z, spine, fairway_half, green, water, sand) != "rough":
		return false
	if Vector2(x, z).distance_to(tee["center"]) < 8.0:
		return false
	return true

# Walk down the spine and line both fairway edges with trees (probability `density` per
# side per station). `band` is the offset range beyond the fairway edge.
func _veg_line_trees(out: Array, heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, fairway_half: float, green: Dictionary, water: Array, sand: Array, tee: Dictionary, density: float, band: Vector2, smin: float, smax: float) -> void:
	var stations : int = 70
	for k in range(stations + 1):
		var frac : float   = float(k) / float(stations)
		var c    : Vector2 = _spine_sample(spine, frac)
		var tng  : Vector2 = _spine_tangent(spine, frac)
		var nrm  : Vector2 = Vector2(-tng.y, tng.x)
		for side in [-1.0, 1.0]:
			if rng.randf() > density:
				continue
			var off : float   = fairway_half + rng.randf_range(band.x, band.y)
			var p   : Vector2 = c + nrm * side * off
			if not _veg_ok(p.x, p.y, spine, fairway_half, green, water, sand, tee):
				continue
			var y : float = _sample_height(heights, pts_x, pts_z, p.x, p.y)
			out.append({"type": "tree", "pos": Vector3(p.x, y, p.y), "yaw": rng.randf() * TAU, "scale": rng.randf_range(smin, smax)})

# Random rejection-sample `count` props of `type` across the rough.
func _veg_scatter(out: Array, type: String, count: int, smin: float, smax: float, heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, fairway_half: float, green: Dictionary, water: Array, sand: Array, tee: Dictionary, z_max: float) -> void:
	var hw       : float = TERRAIN_W * 0.5 - 2.0
	var placed   : int   = 0
	var attempts : int   = 0
	var max_att  : int   = count * 4
	while placed < count and attempts < max_att:
		attempts += 1
		var x : float = rng.randf_range(-hw, hw)
		var z : float = rng.randf_range(0.0, z_max)
		if not _veg_ok(x, z, spine, fairway_half, green, water, sand, tee):
			continue
		var y : float = _sample_height(heights, pts_x, pts_z, x, z)
		out.append({"type": type, "pos": Vector3(x, y, z), "yaw": rng.randf() * TAU, "scale": rng.randf_range(smin, smax)})
		placed += 1

# ── Mesh ──────────────────────────────────────────────────────────────────────

func _build_mesh(data: Dictionary) -> ArrayMesh:
	var pts_x   : int                = data["pts_x"]
	var pts_z   : int                = data["pts_z"]
	var heights : PackedFloat32Array = data["heights"]
	var spine   : PackedVector2Array = data["spine"]
	var fhalf   : float              = data["fairway_half"]
	var green   : Dictionary         = data["green"]
	var water   : Array              = data["water_bodies"]
	var sand    : Array              = data["sand"]
	var cup_x   : float              = data["cup_x_off"]
	var cup_z_w : float              = data["cup_z_w"]
	var rough_col : Color            = _rough_color(data.get("biome", "parkland"))

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
			var kind : String = _classify(x, z, spine, fhalf, green, water, sand)
			colors.append(rough_col if kind == "rough" else _color_for(kind))

	for zi in range(pts_z - 1):
		for xi in range(pts_x - 1):
			# Remove every quad overlapping the void under the cup (hidden by the collar).
			var x0 : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
			var z0 : float = float(zi) * CELL
			var nx : float = clampf(cup_x,   x0, x0 + CELL)
			var nz : float = clampf(cup_z_w, z0, z0 + CELL)
			if Vector2(nx - cup_x, nz - cup_z_w).length() < CUP_GATHER_R:
				continue
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

func _h(heights: PackedFloat32Array, pts_x: int, xi: int, zi: int) -> float:
	return heights[zi * pts_x + xi]

# ── Surface classification (shared by colour + physics) ───────────────────────

func _classify(x: float, z: float, spine: PackedVector2Array, fairway_half: float, green: Dictionary, water: Array, sand: Array) -> String:
	# Green pad wins first so an island green reads as green, not water.
	var nd : float = _green_norm_dist(x, z, green["center"], green["rx"], green["rz"], green["rot"])
	if nd <= 1.0:
		return "green"
	if _in_water(x, z, water):
		return "water"
	if _in_sand(x, z, sand):
		return "sand"
	if nd <= GREEN_LIP_END:
		return "fringe"
	if _dist_to_spine(x, z, spine) < fairway_half:
		return "fairway"
	return "rough"

func _rough_color(biome: String) -> Color:
	match biome:
		"links":  return COL_ROUGH_LINKS
		"fescue": return COL_ROUGH_FESCUE
		_:        return COL_ROUGH

func _color_for(kind: String) -> Color:
	match kind:
		"water":   return COL_WATERBED
		"sand":    return COL_SAND
		"green":   return COL_GREEN
		"fringe":  return COL_FRINGE
		"fairway": return COL_FAIR
		_:         return COL_ROUGH

# Used by ball.gd for per-surface rolling friction.
func get_surface_type(x: float, z: float, hole_data: Dictionary) -> String:
	var spine : PackedVector2Array = hole_data.get("spine", PackedVector2Array())
	if spine.size() < 2:
		return "fairway"
	var kind : String = _classify(x, z, spine, hole_data["fairway_half"], hole_data["green"], hole_data["water_bodies"], hole_data["sand"])
	match kind:
		"sand":    return "sand"
		"green":   return "green"
		"fringe":  return "green"
		"fairway": return "fairway"
		"water":   return "rough"   # physics value is irrelevant; the hazard resets the ball
		_:         return "rough"

# ── Node factories ────────────────────────────────────────────────────────────

func _make_water_surface(body: Dictionary) -> MeshInstance3D:
	match body.get("kind", "side"):
		"river":  return _make_river_surface(body)
		"island": return _make_island_surface(body)
		_:        return _make_side_surface(body)

func _make_cup_well(cx: float, cz: float, base_h: float) -> Node3D:
	# One self-contained object built around the cup centre (cx, cz): a green collar
	# ring that covers the blocky terrain opening, vertical off-white walls, and a
	# floor. One StaticBody3D carries collision so the ball rolls over the rim and
	# falls in via physics.
	var node := Node3D.new()
	node.name = "Cup"
	node.position = Vector3(cx, 0.004, cz)

	var seg     : int   = 48
	var rim_y   : float = base_h - CUP_GATHER_D
	var floor_y : float = rim_y - CUP_DEPTH

	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors  := PackedColorArray()
	var indices := PackedInt32Array()

	var radii := PackedFloat32Array()
	var gather_rings : int = 4
	for s in range(gather_rings):
		radii.append(lerpf(CUP_RADIUS, CUP_GATHER_R, float(s) / float(gather_rings)))
	var apron_rings : int = 4
	for s in range(apron_rings + 1):
		radii.append(lerpf(CUP_GATHER_R, CUP_COLLAR_R, float(s) / float(apron_rings)))

	var collar_start : int = verts.size()
	for r in radii:
		var y : float = base_h
		if r <= CUP_GATHER_R:
			var tr     : float = (r - CUP_RADIUS) / (CUP_GATHER_R - CUP_RADIUS)
			var smooth : float = tr * tr * (3.0 - 2.0 * tr)
			y = lerpf(rim_y, base_h, smooth)
		for i in range(seg + 1):
			var a : float = TAU * float(i) / float(seg)
			verts.append(Vector3(cos(a) * r, y, sin(a) * r))
			normals.append(Vector3.UP)
			colors.append(COL_GREEN)
	for s in range(radii.size() - 1):
		for i in range(seg):
			var a0 : int = collar_start + s * (seg + 1) + i
			var b0 : int = a0 + (seg + 1)
			indices.append_array(PackedInt32Array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1]))

	var wall_start : int = verts.size()
	for ring in range(2):
		var y : float = rim_y if ring == 0 else floor_y
		for i in range(seg + 1):
			var a : float = TAU * float(i) / float(seg)
			verts.append(Vector3(cos(a) * CUP_RADIUS, y, sin(a) * CUP_RADIUS))
			normals.append(Vector3(-cos(a), 0.0, -sin(a)))
			colors.append(COL_CUP)
	for i in range(seg):
		var t0 : int = wall_start + i
		var d0 : int = wall_start + (seg + 1) + i
		indices.append_array(PackedInt32Array([t0, d0, t0 + 1, t0 + 1, d0, d0 + 1]))

	var centre : int = verts.size()
	verts.append(Vector3(0.0, floor_y, 0.0))
	normals.append(Vector3.UP)
	colors.append(COL_CUP_FLOOR)
	var floor_ring : int = verts.size()
	for i in range(seg + 1):
		var a : float = TAU * float(i) / float(seg)
		verts.append(Vector3(cos(a) * CUP_RADIUS, floor_y, sin(a) * CUP_RADIUS))
		normals.append(Vector3.UP)
		colors.append(COL_CUP_FLOOR)
	for i in range(seg):
		indices.append_array(PackedInt32Array([centre, floor_ring + i, floor_ring + i + 1]))

	var arr := Array()
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR]  = colors
	arr[Mesh.ARRAY_INDEX]  = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	var mi  := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness         = 0.95
	mat.metallic          = 0.0
	mat.metallic_specular = 0.1
	mat.cull_mode         = BaseMaterial3D.CULL_DISABLED
	mi.material_override  = mat
	node.add_child(mi)

	var body := StaticBody3D.new()
	body.name = "CupBody"
	body.collision_layer = 1
	body.collision_mask  = 1
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce   = 0.0
	body.physics_material_override = pm
	var col   := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	shape.backface_collision = true
	col.shape = shape
	body.add_child(col)
	node.add_child(body)

	return node

func _make_flag(cup_pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = "Flag"

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

func _make_tee_box(tee: Dictionary) -> Node3D:
	var center : Vector2 = tee["center"]
	var dir    : Vector2 = tee["dir"]
	var pad_h  : float   = tee["pad_h"]
	var across : Vector2 = Vector2(-dir.y, dir.x)
	# Rotation about Y so the pad's local +Z runs down the line of play.
	var ang    : float   = atan2(dir.x, dir.y)

	var node := Node3D.new()
	node.name = "TeeBox"

	# Flat, slightly raised pad in a distinct mown colour.
	var pad     := MeshInstance3D.new()
	var pad_box := BoxMesh.new()
	pad_box.size = Vector3(TEE_HALF_W * 2.0, 0.08, TEE_HALF_LEN * 2.0)
	pad.mesh     = pad_box
	var pad_mat  := StandardMaterial3D.new()
	pad_mat.albedo_color = COL_TEE
	pad_mat.roughness    = 0.9
	pad.material_override = pad_mat
	pad.position    = Vector3(center.x, pad_h + 0.06, center.y)
	pad.rotation.y  = ang
	node.add_child(pad)

	# Two tee markers flanking the ball, on the pad just ahead of the teeing line.
	var fwd : Vector2 = center + dir * (TEE_HALF_LEN * 0.25)
	for s in [-1.0, 1.0]:
		var m_pos : Vector2 = fwd + across * (TEE_HALF_W * 0.7) * s
		var marker := MeshInstance3D.new()
		var m_box  := BoxMesh.new()
		m_box.size = Vector3(0.3, 0.3, 0.3)
		marker.mesh = m_box
		var m_mat := StandardMaterial3D.new()
		m_mat.albedo_color = COL_TEE_MARK
		marker.material_override = m_mat
		marker.position = Vector3(m_pos.x, pad_h + 0.2, m_pos.y)
		node.add_child(marker)

	# The tee peg the ball is teed up on (removed by hole_manager after the first stroke).
	var peg     := MeshInstance3D.new()
	peg.name = "TeePeg"
	var peg_cyl := CylinderMesh.new()
	peg_cyl.top_radius    = 0.025
	peg_cyl.bottom_radius = 0.035
	peg_cyl.height        = TEE_PEG_H
	peg.mesh = peg_cyl
	var peg_mat := StandardMaterial3D.new()
	peg_mat.albedo_color = COL_PEG
	peg.material_override = peg_mat
	peg.position = Vector3(center.x, pad_h + TEE_PEG_H * 0.5, center.y)
	node.add_child(peg)

	return node

# ── Vegetation node factories ─────────────────────────────────────────────────
# Placements (from _build_vegetation) are grouped by type and drawn with one MultiMesh
# each. Every base mesh is "ground-rooted" (local origin at the base, +Y up) so the wind
# shader's height-based bend mask works and the instance transform can sit straight on the
# ground. Built fresh per hole; cleared by hole_manager's course teardown.

func _build_vegetation_nodes(data: Dictionary, parent: Node3D) -> void:
	var veg : Array = data.get("vegetation", [])
	if veg.is_empty():
		return

	var groups : Dictionary = {}
	for item: Dictionary in veg:
		var t : String = item["type"]
		if not groups.has(t):
			groups[t] = []
		groups[t].append(item)

	var zl : float = float(data["pts_z"] - 1) * CELL
	for t: String in groups.keys():
		var items : Array = groups[t]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh             = _veg_mesh_for(t)
		mm.instance_count   = items.size()
		for i in range(items.size()):
			var it : Dictionary = items[i]
			var b : Basis = Basis(Vector3.UP, it["yaw"]).scaled(Vector3.ONE * float(it["scale"]))
			mm.set_instance_transform(i, Transform3D(b, it["pos"]))

		var mmi := MultiMeshInstance3D.new()
		mmi.name              = "Veg_" + t
		mmi.multimesh         = mm
		mmi.material_override  = _veg_material_for(t)
		# Trees cast shadows; low grass/scrub don't (mobile cost, negligible visual loss).
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if t == "tree" \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Span the whole course so the instance block is never wrongly frustum-culled.
		mmi.custom_aabb = AABB(Vector3(-TERRAIN_W, -12.0, -12.0), Vector3(TERRAIN_W * 2.0, 70.0, zl + 40.0))
		parent.add_child(mmi)

		# Trees are solid: the ball must bounce off them, not pass through. Grass and scrub
		# stay pass-through. One StaticBody3D carries a vertical trunk cylinder per tree.
		if t == "tree":
			parent.add_child(_make_tree_colliders(items))

func _make_tree_colliders(items: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "TreeColliders"
	# Default layer/mask = 1, the same layer the ball collides on (see hole_manager).
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce   = 0.35    # a lively ricochet off the trunk
	body.physics_material_override = pm
	for it: Dictionary in items:
		var sc  : float   = float(it["scale"])
		var p   : Vector3 = it["pos"]
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.42 * sc
		cyl.height = 3.0 * sc
		var col := CollisionShape3D.new()
		col.shape    = cyl
		col.position = Vector3(p.x, p.y + cyl.height * 0.5, p.z)
		body.add_child(col)
	return body

func _veg_mesh_for(t: String) -> ArrayMesh:
	match t:
		"tree":  return _make_tree_mesh()
		"scrub": return _make_scrub_mesh()
		_:       return _make_grass_mesh()

func _veg_material_for(t: String) -> Material:
	match t:
		"tree":
			var m := ShaderMaterial.new()
			m.shader = WIND_SHADER
			m.set_shader_parameter("wind_strength", 0.04)   # trees barely flex
			m.set_shader_parameter("wind_speed", 1.1)
			return m
		"scrub":
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			sm.roughness = 0.95
			return sm
		_:  # grass
			var g := ShaderMaterial.new()
			g.shader = WIND_SHADER
			g.set_shader_parameter("wind_strength", 0.14)
			g.set_shader_parameter("wind_speed", 1.8)
			return g

# Append a primitive mesh's surface (translated up by y_off, flat-coloured `col`) into the
# combined arrays of an ArrayMesh under construction.
func _append_prim(prim: Mesh, y_off: float, col: Color, verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var a  : Array = prim.surface_get_arrays(0)
	var pv : PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var pn : PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var pi : PackedInt32Array   = a[Mesh.ARRAY_INDEX]
	var base : int = verts.size()
	for k in range(pv.size()):
		verts.append(pv[k] + Vector3(0.0, y_off, 0.0))
		normals.append(pn[k])
		colors.append(col)
	for idx in pi:
		indices.append(base + idx)

func _arrays_to_mesh(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array) -> ArrayMesh:
	var arr := Array()
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR]  = colors
	arr[Mesh.ARRAY_INDEX]  = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

# A low-poly tree: a tapered trunk (brown) topped by a spherical canopy (green), merged
# into one mesh so a single MultiMesh covers a whole tree. Base sits at local y = 0.
func _make_tree_mesh() -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius      = 0.12
	trunk.bottom_radius   = 0.18
	trunk.height          = 1.6
	trunk.radial_segments = 6
	trunk.rings           = 1
	var canopy := SphereMesh.new()
	canopy.radius          = 1.0
	canopy.height          = 2.0
	canopy.radial_segments = 8
	canopy.rings           = 5

	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors  := PackedColorArray()
	var indices := PackedInt32Array()
	# Trunk centred at y=0 spans -0.8..0.8 -> lift 0.8 so its base is on the ground.
	_append_prim(trunk,  0.8, Color(0.42, 0.30, 0.18), verts, normals, colors, indices)
	# Canopy centre a touch above the trunk top (1.6), so it overlaps and reads as foliage.
	_append_prim(canopy, 2.3, Color(0.20, 0.52, 0.20), verts, normals, colors, indices)
	return _arrays_to_mesh(verts, normals, colors, indices)

# A grass tuft: three thin triangular blades fanned around the base, dark at the root and
# bright at the tip (the brightness also reads as the wind bend gradient). Base at y = 0.
func _make_grass_mesh() -> ArrayMesh:
	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors  := PackedColorArray()
	var indices := PackedInt32Array()
	var base_col := Color(0.20, 0.34, 0.12)
	var tip_col  := Color(0.56, 0.62, 0.30)
	var h  : float = 1.2
	var bw : float = 0.06   # half-width at the base
	var blades : int = 3
	for bnum in range(blades):
		var ang  : float   = PI * float(bnum) / float(blades)
		var dir  : Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		var perp : Vector3 = Vector3(-dir.z, 0.0, dir.x)
		var tip  : Vector3 = Vector3(0.0, h, 0.0) + dir * 0.28   # slight lean
		var bi   : int     = verts.size()
		verts.append(-perp * bw); normals.append(Vector3.UP); colors.append(base_col)
		verts.append( perp * bw); normals.append(Vector3.UP); colors.append(base_col)
		verts.append(tip);        normals.append(Vector3.UP); colors.append(tip_col)
		indices.append_array(PackedInt32Array([bi, bi + 1, bi + 2]))
	return _arrays_to_mesh(verts, normals, colors, indices)

# A low scrub bush: a squashed dome rooted at y = 0, muted blue-green.
func _make_scrub_mesh() -> ArrayMesh:
	var dome := SphereMesh.new()
	dome.radius          = 0.55
	dome.height          = 0.8
	dome.radial_segments = 8
	dome.rings           = 4
	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors  := PackedColorArray()
	var indices := PackedInt32Array()
	# Dome centred at y=0 spans -0.4..0.4 -> lift 0.4 so it sits on the ground.
	_append_prim(dome, 0.4, Color(0.30, 0.40, 0.22), verts, normals, colors, indices)
	return _arrays_to_mesh(verts, normals, colors, indices)
