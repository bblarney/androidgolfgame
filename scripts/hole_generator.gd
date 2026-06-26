extends Node

# ── Course dimensions ─────────────────────────────────────────────────────────
const CELL        : float = 2.0
const TERRAIN_W   : float = 110.0   # widened from 80 so doglegs have lateral room
const OVERRUN     : float = 35.0    # run-off behind the green

# ── Surrounding landscape (the "not a floating island" layers) ────────────────
# A rolling ground apron extends this far past the playfield in every direction, replacing
# the void with continuous land that the depth fog (hole_manager) fades into. Its inner edge
# is stitched to the terrain border at full resolution (see _apron_height); only the outward
# rings are coarse, so it stays cheap for mobile. BG_DENSITY is the single knob to thin the
# surrounding forest on weaker devices (1.0 = full, lower = fewer trees).
const APRON_MARGIN : float = 280.0
const APRON_DROP   : float = 1.5    # how far below the avg edge the distant far-field settles
const BG_DENSITY   : float = 1.0
# Over a water boundary the apron rises from the (submerged) seam to a bank just above the
# waterline across this distance. Water surfaces spill the same distance past the playfield
# edge so the flat plane reaches the rising apron and the emerging bank forms the shoreline,
# rather than the plane ending in a hard straight cut at the boundary.
const APRON_BANK_W : float = 5.0
# The over-water apron climbs out of the water STEEPLY over this short distance to a crest that
# stands APRON_BANK_LIP above the waterline -- a defined bank with a crisp edge that mirrors the
# carved near shore, instead of a long shallow slope the flat water plane appears to float over.
const APRON_BANK_RISE : float = 1.8
const APRON_BANK_LIP  : float = 0.4
# Decorative apron/perimeter trees must root at least this far above the local waterline, so
# the treeline sits back on dry ground instead of on the shore bank under the water plane.
const TREE_SHORE_CLEAR : float = 1.0

# ── Surface colours ───────────────────────────────────────────────────────────
# Turf tones are deliberately muted/desaturated -- real mown grass is a soft olive-green,
# not the neon it reads at full saturation. Green/fairway are only slightly lighter and
# finer than the rough, so the course looks lit rather than glowing.
const COL_ROUGH    : Color = Color(0.08, 0.15, 0.06)
const COL_FAIR     : Color = Color(0.15, 0.28, 0.11)
const COL_GREEN    : Color = Color(0.14, 0.32, 0.13)
const COL_FRINGE   : Color = Color(0.13, 0.25, 0.11)   # collar around the green
const COL_SAND     : Color = Color(0.78, 0.71, 0.52)   # warm, pale sand; the shader adds grain
const COL_WATER    : Color = Color(0.16, 0.38, 0.58, 0.80)
const COL_WATERBED : Color = Color(0.10, 0.24, 0.30)   # lakebed under the translucent plane
const COL_FLAG     : Color = Color(0.82, 0.20, 0.18)
# Biome-specific rough tints (parkland keeps the default lush COL_ROUGH).
const COL_ROUGH_LINKS  : Color = Color(0.25, 0.29, 0.16)   # pale, dry seaside turf
const COL_ROUGH_FESCUE : Color = Color(0.32, 0.32, 0.18)   # golden tall-grass rough
const COL_ROUGH_ALPINE : Color = Color(0.14, 0.20, 0.14)   # cool grey-green high-country turf
const COL_ROUGH_AUTUMN : Color = Color(0.30, 0.22, 0.10)   # warm golden-brown heather floor

# ── Cup well (unchanged machinery: a self-contained collar + walls + floor object
#    dropped into the flat green pad). See _make_cup_well for the full rationale. ──
const CUP_RADIUS    : float = 0.45   # ~25% smaller mouth -- harder to hole out
const CUP_DEPTH     : float = 0.55
const CUP_GATHER_R  : float = 1.2
const CUP_GATHER_D  : float = 0.10
const CUP_COLLAR_R  : float = 4.2
const COL_CUP       : Color = Color(0.90, 0.88, 0.82)
const COL_CUP_FLOOR : Color = Color(0.80, 0.78, 0.72)

# ── Green pad shaping ─────────────────────────────────────────────────────────
const GREEN_RAISE   : float = 0.5    # pad sits this far above the surrounding turf (the lip)
const GREEN_LIP_END : float = 1.28   # normalized ellipse dist where the bank finishes blending out
# Greens are no longer dead-flat: a gentle tilt/tier is laid over the pad so approach shots must
# account for the slope and putts have to be read. The relief is capped well below the grade that
# would stop the ball resting, and is faded to zero around the pin (see _green_relief) so the cup
# well/collar still seat on level ground exactly as before.
const GREEN_RELIEF_MAX : float = 0.55   # max world-unit deviation of the pad surface from pad_h

# ── Bunker shaping ────────────────────────────────────────────────────────────
# Bunkers are oval depressions (same ellipse metric as the green) with a defined edge:
# sand sits a step (LIP_DROP) below the surrounding turf, then a thin raised grass lip
# rings the rim (taller on the face toward the green). One analytic shape drives the
# carve, the classification and the lip so the coloured "sand" cells and the carved hole
# are always the exact same footprint -- the no-clip discipline used for water.
const BUNKER_LIP_END  : float = 1.18   # normalized ellipse dist where the grass lip blends out
const BUNKER_LIP_DROP : float = 0.22   # sand rim sits this far below the surrounding turf
const BUNKER_TILT_MAX : float = 0.35   # max floor slope (rise/run) when draping over grade

# ── Tee box ───────────────────────────────────────────────────────────────────
const TEE_RAISE    : float = 0.3     # tee pad sits this far above the surrounding turf
const TEE_HALF_LEN : float = 5.5     # pad half-extent along the line of play
const TEE_HALF_W   : float = 3.2     # pad half-extent across the line of play
# The flat turf extends this far past the pad so it also covers the collar skirt (which is
# +1.0 larger). Without it the collar's outer ring sat over terrain that was already blending
# UP through the lip, so rolling ground poked through the pad's front/side edges.
const TEE_FLAT_MARGIN : float = 1.4
const TEE_LIP      : float = 1.6     # blend band from pad down to natural turf
const TEE_PEG_H    : float = 0.35    # height the tee peg lifts the ball above the pad
const COL_TEE      : Color = Color(0.20, 0.36, 0.16)   # neat mown tee, lighter than the fairway
const COL_TEE_MARK : Color = Color(0.92, 0.92, 0.95)   # white tee markers
const COL_PEG      : Color = Color(0.86, 0.74, 0.52)   # wooden tee peg
# Kept in sync with ball.gd BALL_RADIUS so the ball rests exactly on the peg top.
const BALL_R       : float = 0.117

const WIND_SHADER    : Shader = preload("res://shaders/wind.gdshader")
const FLAG_SHADER    : Shader = preload("res://shaders/flag.gdshader")
const TERRAIN_SHADER : Shader = preload("res://shaders/terrain.gdshader")

var rng := RandomNumberGenerator.new()

# ── Public API ────────────────────────────────────────────────────────────────

func generate_hole(hole_seed: int, biome: String = "parkland") -> Dictionary:
	rng.seed = hole_seed

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
	var sand : Array = _build_sand(heights, pts_x, pts_z, spine, fairway_half, green, water_bodies, bp["template"])

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
	# Surrounding land first, so the playfield terrain draws over its inner overlap.
	parent.add_child(_make_apron(data))

	var terrain_mesh : ArrayMesh = _build_mesh(data)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = terrain_mesh
	# Procedural detail shader: keeps the per-surface vertex colour as the base, but mottles
	# the brightness and perturbs the normal with world-space noise so the turf/sand reads as
	# textured rather than a flat slab. (cull_disabled lives in the shader's render_mode.)
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
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
	# NOTE: par is the FIRST randf() off the seeded stream -- GameState.get_par_for_hole
	# reproduces exactly this roll/thresholds to show par for unreached holes. Keep them in sync.
	var par_roll : float = rng.randf()
	var par      : int
	var length   : float
	# Lengths run long: top-tier gear roughly doubles carry, so holes are scaled up (more on
	# par 4/5, where the extra shots bite) to keep greens-in-regulation -- and birdies -- earned.
	# Par is unchanged, so the longer holes raise the birdie bar directly.
	if par_roll < 0.30:
		par    = 3
		length = rng.randf_range(130.0, 190.0)
	elif par_roll < 0.75:
		par    = 4
		length = rng.randf_range(250.0, 360.0)
	else:
		par    = 5
		length = rng.randf_range(410.0, 540.0)

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
	elif er < 0.40:
		# Uphills are now the more common slope: the rise shortens roll-out and makes the hole
		# play longer than its yardage, stacking distance pressure on top of the longer holes.
		# Amplitude is moderate (well short of the cliff drop) and spread over the whole length.
		theme  = "uphill"
		elev_a = rng.randf_range(4.0, 8.0)
	elif er < 0.60:
		theme  = "downhill"
		elev_a = rng.randf_range(3.0, 5.5)
	# else: rolling

	# Water feature. Bodies are large now and present on the large majority of holes, with
	# fairway-edge ponds/lakes (side_pond) the most common look.
	var water : String = "none"
	var wr : float = rng.randf()
	if theme == "cliff":
		# A cliff hole reads best clean, but a lake below is a common and dramatic pairing.
		water = "side_pond" if wr < 0.55 else "none"
	else:
		if wr < 0.55:
			water = "side_pond"
		elif wr < 0.78:
			water = "river"
		elif wr < 0.90 and par >= 4:
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
			# Sharper bends: the corner sits a touch later and the green swings further to the
			# outside, so the post-corner leg is short and steep (~55-70 deg). cx hugs the inside
			# so the safe approach is the long way round; _place_dogleg_guard plants sand on the
			# inside corner so cutting the angle is punished rather than rewarded.
			var cf    : float = rng.randf_range(0.54, 0.66)
			var cx    : float = -dir * rng.randf_range(5.0, 11.0)   # landing favours the outside of the bend
			var swing : float = rng.randf_range(26.0, 40.0)
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
	var flat_l : float   = TEE_HALF_LEN + TEE_FLAT_MARGIN
	var flat_w : float   = TEE_HALF_W   + TEE_FLAT_MARGIN

	# Stand the pad above the HIGHEST natural turf under its (collar-covering) footprint, not
	# just the centre sample. On rippled/rolling ground the centre can be a low spot, leaving
	# the surrounding terrain poking up through the flat pad -- the "clipping" at the edges.
	var peak : float = -INF
	for zi in range(pts_z):
		for xi in range(pts_x):
			var x : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
			var z : float = float(zi) * CELL
			var d : Vector2 = Vector2(x - center.x, z - center.y)
			if absf(d.dot(dir)) <= flat_l and absf(d.dot(across)) <= flat_w:
				peak = maxf(peak, heights[zi * pts_x + xi])
	if peak == -INF:
		peak = _sample_height(heights, pts_x, pts_z, center.x, center.y)
	var pad_h : float = peak + TEE_RAISE

	for zi in range(pts_z):
		for xi in range(pts_x):
			var x : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
			var z : float = float(zi) * CELL
			var d : Vector2 = Vector2(x - center.x, z - center.y)
			# Distance outside the flat rectangle (0 when under the pad/collar).
			var ol : float = maxf(absf(d.dot(dir))    - flat_l, 0.0)
			var op : float = maxf(absf(d.dot(across)) - flat_w, 0.0)
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

	var pad_h  : float      = _sample_height(heights, pts_x, pts_z, center.x, center.y) + GREEN_RAISE
	var relief : Dictionary = _roll_green_relief()

	for zi in range(pts_z):
		for xi in range(pts_x):
			var x  : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
			var z  : float = float(zi) * CELL
			# Green-local coords (ellipse axis-aligned): lx across, lz along the line of play.
			var dx : float = x - center.x
			var dz : float = z - center.y
			var lx : float =  dx * cos(rot) + dz * sin(rot)
			var lz : float = -dx * sin(rot) + dz * cos(rot)
			var nd : float = sqrt((lx / rx) * (lx / rx) + (lz / rz) * (lz / rz))
			if nd <= 1.0:
				heights[zi * pts_x + xi] = pad_h + _green_relief(lx, lz, rx, rz, relief)
			elif nd <= GREEN_LIP_END:
				# Short bank from the raised pad down to the natural turf -> a defined lip. Blend
				# from the relief'd pad edge (not flat pad_h) so the lip meets the sloped surface.
				var t      : float = (nd - 1.0) / (GREEN_LIP_END - 1.0)
				var edge_h : float = pad_h + _green_relief(lx, lz, rx, rz, relief)
				heights[zi * pts_x + xi] = lerpf(edge_h, heights[zi * pts_x + xi], t * t * (3.0 - 2.0 * t))

	return { "center": center, "rx": rx, "rz": rz, "rot": rot, "pad_h": pad_h }

# Roll the green's surface character: usually a single gentle plane (tilt), sometimes a two-shelf
# tier with a smooth step. Amplitudes are deliberately small so the resulting grade stays well
# under what would keep the ball from resting (see _green_relief for the cap and the pin shelf).
func _roll_green_relief() -> Dictionary:
	if rng.randf() < 0.34:
		return {
			"form"  : "tier",
			"edge"  : rng.randf_range(-0.25, 0.25),   # where the step sits along depth (u = lz/rz)
			"band"  : rng.randf_range(0.35, 0.50),    # half-width of the smooth transition, in u
			"step"  : rng.randf_range(0.18, 0.28),    # half the height difference between shelves
			"cross" : rng.randf_range(-0.20, 0.20),   # slight side-fall on top of the tier
		}
	return {
		"form" : "tilt",
		"ax"   : rng.randf_range(-0.40, 0.40),        # fall across the green, at the edge
		"az"   : rng.randf_range(-0.40, 0.40),        # fall front-to-back, at the edge
	}

# Height offset (world units) of the green surface above/below pad_h at green-local coords lx,lz.
# Faded to zero within CUP_COLLAR_R of the pin so the cup well and collar sit level, and clamped
# to GREEN_RELIEF_MAX so the slope never gets steep enough to stop the ball resting.
func _green_relief(lx: float, lz: float, rx: float, rz: float, relief: Dictionary) -> float:
	var h : float
	if relief["form"] == "tier":
		var u : float = lz / rz                                   # -1..1 along depth
		var s : float = smoothstep(relief["edge"] - relief["band"], relief["edge"] + relief["band"], u)
		h = lerpf(-relief["step"], relief["step"], s) + relief["cross"] * (lx / rx)
	else:  # "tilt": a single gentle plane
		h = relief["ax"] * (lx / rx) + relief["az"] * (lz / rz)
	var d     : float = sqrt(lx * lx + lz * lz)
	var shelf : float = smoothstep(CUP_COLLAR_R, CUP_COLLAR_R + 2.5, d)
	return clampf(h, -GREEN_RELIEF_MAX, GREEN_RELIEF_MAX) * shelf

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
		# Spill past the scene edge onto the rising apron bank (which occludes the plane where
		# land emerges) so the river meets its banks continuously instead of cutting off square.
		bl.x = clampf(bl.x, -(hw + APRON_BANK_W), hw + APRON_BANK_W); bl.y = clampf(bl.y, -APRON_BANK_W, zmax + APRON_BANK_W)
		br.x = clampf(br.x, -(hw + APRON_BANK_W), hw + APRON_BANK_W); br.y = clampf(br.y, -APRON_BANK_W, zmax + APRON_BANK_W)
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
	# Extend the quilt this many cells past the playfield so the lake spills onto the rising
	# apron bank behind/beside the green; the emerging bank occludes the plane to form the
	# shoreline. Membership is geometric (_in_island_body), so off-grid cells classify fine.
	var ext : int = int(ceil(APRON_BANK_W / CELL))
	for zi in range(-ext, pts_z - 1 + ext):
		for xi in range(-ext, pts_x - 1 + ext):
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
		# Spill past the playfield edge onto the rising apron bank (which occludes the plane
		# where land emerges above the waterline) so the shore reads continuous, not cut off.
		wo.x = clampf(wo.x, -(hw + APRON_BANK_W), hw + APRON_BANK_W)
		wo.y = clampf(wo.y, -APRON_BANK_W, float(body["spine_len"]) + OVERRUN + APRON_BANK_W)
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

func _build_sand(heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, fairway_half: float, green: Dictionary, water: Array, template: String) -> Array:
	var out     : Array = []
	var z_max   : float = float(pts_z - 1) * CELL
	# Roll the two characters independently and mix them on the hole, but guarantee at
	# least two bunkers overall. Fairway count runs higher now so the longer holes have real
	# trouble in the landing zones rather than a single token trap.
	var n_fair  : int = rng.randi_range(2, 4)
	var n_green : int = rng.randi_range(1, 3)
	# Greenside first so the fairway overlap test sees them too.
	_place_greenside_bunkers(out, heights, pts_x, pts_z, spine, green, water, z_max, n_green)
	# Guard the inside of a dogleg before the random fairway traps, so the corner always wins
	# its spot -- a sharp dogleg only matters if cutting the corner risks sand.
	_place_dogleg_guard(out, heights, pts_x, pts_z, spine, template, fairway_half, green, water, z_max)
	_place_fairway_bunkers(out, heights, pts_x, pts_z, spine, fairway_half, green, water, z_max, n_fair)
	return out

# Plant 1-2 traps on the INSIDE of a dogleg's bend -- the cuttable corner a long hitter would
# try to fly. dir is the side the hole turns toward; the corner control point sits on the far
# side, so offsetting from the bend toward `dir` lands the sand squarely on the shortcut line.
# Reuses the same bunker machinery as the fairway traps; runs before them so it owns its spot.
func _place_dogleg_guard(out: Array, heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, template: String, fairway_half: float, green: Dictionary, water: Array, z_max: float) -> void:
	if template != "dogleg_left" and template != "dogleg_right":
		return
	var dir    : float   = -1.0 if template == "dogleg_left" else 1.0
	var inside : Vector2 = Vector2(dir, 0.0)   # the hole turns toward +x*dir; the cut is on that side
	var n      : int = rng.randi_range(1, 2)
	var placed : int = 0
	var attempts : int = 0
	while placed < n and attempts < 40:
		attempts += 1
		var frac   : float   = rng.randf_range(0.55, 0.68)
		var c      : Vector2 = _spine_sample(spine, frac)
		var brx    : float   = rng.randf_range(5.0, 8.0)
		var brz    : float   = brx * rng.randf_range(0.55, 0.75)
		var off    : float   = fairway_half + rng.randf_range(2.0, 7.0)
		var center : Vector2 = c + inside * off
		if not _bunker_spot_ok(center, brx, brz, green, water, out, z_max):
			continue
		var tng  : Vector2 = _spine_tangent(spine, frac)
		var body : Dictionary = _make_bunker_body("fairway", center, brx, brz, atan2(tng.y, tng.x),
			rng.randf_range(0.6, 1.0), 0.5, -inside, rng.randf_range(0.2, 0.32), heights, pts_x, pts_z)
		_carve_bunker(heights, pts_x, pts_z, body, green)
		out.append(body)
		placed += 1

# Greenside bunkers: small, deep, steep-faced. They ring the SIDES and REAR of the green
# (and the front corners) but never the front-centre, so the approach to the pin always
# stays open. Their floors drape along the green's grade and a taller lip faces the green.
func _place_greenside_bunkers(out: Array, heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, green: Dictionary, water: Array, z_max: float, count: int) -> void:
	if count <= 0:
		return
	var gc        : Vector2 = green["center"]
	var pd        : Vector2 = _spine_tangent(spine, 1.0)        # forward, toward the cup
	var front_ang : float   = atan2(-pd.y, -pd.x)               # the open approach direction
	var placed_ang : Array[float] = []
	var attempts  : int = 0
	while placed_ang.size() < count and attempts < 60:
		attempts += 1
		var ang : float = rng.randf_range(0.0, TAU)
		# Keep the front-centre approach clear, and never crowd two bunkers together.
		if absf(_ang_diff(ang, front_ang)) < deg_to_rad(35.0):
			continue
		var crowded : bool = false
		for a in placed_ang:
			if absf(_ang_diff(ang, a)) < deg_to_rad(50.0):
				crowded = true
				break
		if crowded:
			continue
		var dir_w  : Vector2 = Vector2(cos(ang), sin(ang))
		var r_edge : float   = _green_radius_in_dir(green, dir_w)
		# Long tangential axis (brx) and a flatter radial one (brz) so the trap is drawn out
		# around the green's arc -- it wraps the side rather than sitting as a round bowl.
		var brx    : float   = rng.randf_range(4.0, 6.5)
		var brz    : float   = brx * rng.randf_range(0.45, 0.6)
		var center : Vector2 = gc + dir_w * (r_edge + rng.randf_range(2.0, 4.0) + brz)
		if not _bunker_spot_ok(center, brx, brz, green, water, out, z_max):
			continue
		# Long axis tangential to the green (rot + 90 deg); the lip faces back at the green.
		var body : Dictionary = _make_bunker_body("greenside", center, brx, brz, ang + PI * 0.5,
			rng.randf_range(1.1, 1.8), 0.62, -dir_w, rng.randf_range(0.28, 0.45), heights, pts_x, pts_z)
		_carve_bunker(heights, pts_x, pts_z, body, green)
		out.append(body)
		placed_ang.append(ang)

# Fairway bunkers: wide, shallow, gentle. Usually set into one side of the corridor;
# occasionally a centre-line carry bunker.
func _place_fairway_bunkers(out: Array, heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, fairway_half: float, green: Dictionary, water: Array, z_max: float, count: int) -> void:
	var placed   : int = 0
	var attempts : int = 0
	while placed < count and attempts < 60:
		attempts += 1
		# Bias toward two decision zones rather than scattering uniformly: the drive landing
		# zone and the lay-up/approach zone short of the green -- where a strong shot actually
		# comes down -- so the traps catch good distance instead of sitting out of play.
		var t   : float   = rng.randf_range(0.32, 0.48) if rng.randf() < 0.5 else rng.randf_range(0.62, 0.78)
		var c   : Vector2 = _spine_sample(spine, t)
		var tng : Vector2 = _spine_tangent(spine, t)
		var nrm : Vector2 = Vector2(-tng.y, tng.x)
		var brx : float   = rng.randf_range(5.0, 9.0)
		var brz : float   = brx * rng.randf_range(0.5, 0.7)
		var off : float
		var lip_dir : Vector2
		var rot : float
		if rng.randf() < 0.18:
			# Centre-line carry bunker: long axis ACROSS the corridor (a wide carry).
			off     = rng.randf_range(-fairway_half * 0.3, fairway_half * 0.3)
			lip_dir = -tng                  # face back toward the tee
			rot     = atan2(nrm.y, nrm.x)
		else:
			# Edge bunker: long axis ALONG the fairway, so it runs alongside the corridor the
			# way the side water does, hard against the fairway edge.
			var side : float = 1.0 if rng.randf() > 0.5 else -1.0
			off      = fairway_half * rng.randf_range(0.6, 1.1) * side
			lip_dir  = -nrm * signf(off)    # face in toward the centre of the fairway
			rot      = atan2(tng.y, tng.x)
		var center : Vector2 = c + nrm * off
		if not _bunker_spot_ok(center, brx, brz, green, water, out, z_max):
			continue
		var body : Dictionary = _make_bunker_body("fairway", center, brx, brz, rot,
			rng.randf_range(0.5, 0.9), 0.5, lip_dir, rng.randf_range(0.15, 0.28), heights, pts_x, pts_z)
		_carve_bunker(heights, pts_x, pts_z, body, green)
		out.append(body)
		placed += 1

# Pack a bunker's analytic shape. base_y is the turf height at the centre; tilt is the
# local terrain gradient (clamped) so the carved floor drapes along the existing grade --
# near a raised green that grade is the pad's lip bank, so the trap slopes with the green.
func _make_bunker_body(kind: String, center: Vector2, rx: float, rz: float, rot: float, depth: float, floor_frac: float, lip_dir: Vector2, lip_h: float, heights: PackedFloat32Array, pts_x: int, pts_z: int) -> Dictionary:
	var base_y : float = _sample_height(heights, pts_x, pts_z, center.x, center.y)
	var probe  : float = maxf(rx, rz) * 0.7
	var gx : float = (_sample_height(heights, pts_x, pts_z, center.x + probe, center.y)
		- _sample_height(heights, pts_x, pts_z, center.x - probe, center.y)) / (2.0 * probe)
	var gz : float = (_sample_height(heights, pts_x, pts_z, center.x, center.y + probe)
		- _sample_height(heights, pts_x, pts_z, center.x, center.y - probe)) / (2.0 * probe)
	var tilt : Vector2 = Vector2(clampf(gx, -BUNKER_TILT_MAX, BUNKER_TILT_MAX), clampf(gz, -BUNKER_TILT_MAX, BUNKER_TILT_MAX))
	return {
		"kind": kind, "center": center, "rx": rx, "rz": rz, "rot": rot,
		"depth": depth, "floor_frac": floor_frac,
		"lip_dir": lip_dir.normalized() if lip_dir.length() > 0.001 else Vector2.ZERO,
		"lip_h": lip_h, "base_y": base_y, "tilt": tilt,
	}

# Is this spot clear of the green pad, water and other bunkers, and inside the playfield?
func _bunker_spot_ok(center: Vector2, rx: float, rz: float, green: Dictionary, water: Array, out: Array, z_max: float) -> bool:
	var mr : float = maxf(rx, rz)
	if absf(center.x) > TERRAIN_W * 0.5 - mr * 0.5 or center.y < mr * 0.5 or center.y > z_max - mr * 0.5:
		return false
	# Off the green pad (plus a small buffer so the lip never notches the pad).
	if _green_norm_dist(center.x, center.y, green["center"], green["rx"] + 1.0, green["rz"] + 1.0, green["rot"]) <= 1.0:
		return false
	# Clear of water -- otherwise the trap carves the dry shoreline the water plane rests on.
	if _water_within(center, mr + 2.0, water):
		return false
	for b: Dictionary in out:
		if center.distance_to(b["center"]) < mr + maxf(b["rx"], b["rz"]) + 1.0:
			return false
	return true

# Smallest signed angular difference a-b, wrapped to [-PI, PI].
func _ang_diff(a: float, b: float) -> float:
	return atan2(sin(a - b), cos(a - b))

# The green ellipse's radius (world units) in a given unit world direction.
func _green_radius_in_dir(green: Dictionary, dir_w: Vector2) -> float:
	var rot : float = green["rot"]
	var ux  : float =  dir_w.x * cos(rot) + dir_w.y * sin(rot)
	var uz  : float = -dir_w.x * sin(rot) + dir_w.y * cos(rot)
	var rx  : float = green["rx"]
	var rz  : float = green["rz"]
	return 1.0 / sqrt((ux / rx) * (ux / rx) + (uz / rz) * (uz / rz))

func _carve_bunker(heights: PackedFloat32Array, pts_x: int, pts_z: int, body: Dictionary, green: Dictionary) -> void:
	# Oval depression with a defined edge. Within the ellipse: a draped (tilted) sand floor,
	# then a steep wall up to a rim that sits LIP_DROP below the surrounding turf. Just
	# outside it: a thin raised grass lip, taller on the face toward `lip_dir`. min() keeps
	# the floor/wall from ever raising land; the lip is the one deliberate max() band.
	var center : Vector2 = body["center"]
	var rx     : float   = body["rx"]
	var rz     : float   = body["rz"]
	var rot    : float   = body["rot"]
	var depth  : float   = body["depth"]
	var ff     : float   = body["floor_frac"]
	var lip_dir: Vector2 = body["lip_dir"]
	var lip_h  : float   = body["lip_h"]
	var base_y : float   = body["base_y"]
	var tilt   : Vector2 = body["tilt"]
	var mr     : float   = maxf(rx, rz) * BUNKER_LIP_END
	var r0 : int = maxi(int(round((center.x + TERRAIN_W * 0.5 - mr) / CELL)), 0)
	var r1 : int = mini(int(round((center.x + TERRAIN_W * 0.5 + mr) / CELL)), pts_x - 1)
	var z0 : int = maxi(int(round((center.y - mr) / CELL)), 0)
	var z1 : int = mini(int(round((center.y + mr) / CELL)), pts_z - 1)
	for zi in range(z0, z1 + 1):
		for xi in range(r0, r1 + 1):
			var x : float = (-TERRAIN_W * 0.5) + float(xi) * CELL
			var z : float = float(zi) * CELL
			var nd : float = _green_norm_dist(x, z, center, rx, rz, rot)
			if nd > BUNKER_LIP_END:
				continue
			# Never touch the green pad OR its collar -- a raised bunker lip poking into the
			# fringe band is what made the collar read jagged. Keeping clear out to
			# GREEN_LIP_END leaves the green's edge the smooth ellipse the green carve drew.
			if _green_norm_dist(x, z, green["center"], green["rx"], green["rz"], green["rot"]) <= GREEN_LIP_END:
				continue
			var off2  : Vector2 = Vector2(x - center.x, z - center.y)
			var ref_y : float   = base_y + tilt.x * off2.x + tilt.y * off2.y   # local turf
			var idx   : int     = zi * pts_x + xi
			if nd <= ff:
				heights[idx] = minf(heights[idx], ref_y - depth)
			elif nd <= 1.0:
				var rim_y   : float = ref_y - BUNKER_LIP_DROP
				var floor_y : float = ref_y - depth
				var t : float = (nd - ff) / (1.0 - ff)
				t = t * t * (3.0 - 2.0 * t)
				heights[idx] = minf(heights[idx], lerpf(floor_y, rim_y, t))
			else:
				# Grass lip: raised above the local turf, tall on the face toward the green,
				# fading out by BUNKER_LIP_END so it blends cleanly with no vertical gap.
				var face : float = 1.0
				if lip_dir != Vector2.ZERO and off2.length() > 0.001:
					face = clampf(off2.normalized().dot(lip_dir), 0.0, 1.0)
				var fade  : float = 1.0 - smoothstep(1.0, BUNKER_LIP_END, nd)
				var raise : float = lip_h * (0.35 + 0.65 * face) * fade
				heights[idx] = maxf(heights[idx], ref_y + raise)

func _in_sand(x: float, z: float, sand: Array) -> bool:
	for s: Dictionary in sand:
		if _green_norm_dist(x, z, s["center"], s["rx"], s["rz"], s["rot"]) <= 1.0:
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
			# Tree-lined: a dense gallery of mixed broadleaves (with the odd slim/pine) hugging
			# both fairway edges, plus a light carpet of short grass.
			_veg_line_trees(out, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, 0.55, Vector2(2.0, 26.0), 1.0, 1.7, ["tree", "tree", "tree", "tree", "tree_slim", "tree_slim", "pine"])
			_veg_scatter(out, "grass", 220, 0.4, 0.8, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, z_max)
		"links":
			# Open seaside links: almost no trees, low gorse-like scrub and wispy short grass.
			_veg_line_trees(out, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, 0.04, Vector2(4.0, 16.0), 0.9, 1.4, ["tree", "tree", "tree_slim"])
			_veg_scatter(out, "scrub", 90,  0.7, 1.3, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, z_max)
			_veg_scatter(out, "grass", 280, 0.3, 0.6, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, z_max)
		"fescue":
			# Tall fescue: the rough is a sea of grass. Tufts are half-height now but twice as
			# dense, so the sea reads thicker without any single blade towering over the ball.
			_veg_scatter(out, "grass", 4400, 0.7, 1.3, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, z_max)
			_veg_line_trees(out, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, 0.12, Vector2(3.0, 14.0), 1.0, 1.6, ["tree", "tree", "tree_slim"])
		"alpine":
			# High-country conifer forest: dense pine lines (the odd broadleaf) over a cool,
			# grey-green floor with only sparse grass.
			_veg_line_trees(out, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, 0.5, Vector2(2.0, 28.0), 1.0, 1.8, ["pine", "pine", "pine", "pine", "tree"])
			_veg_scatter(out, "grass", 160, 0.3, 0.6, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, z_max)
		"autumn":
			# Warm deciduous woodland: a dense gallery of round canopies in fall colours
			# (orange/red/gold) with the occasional evergreen, over a moderate grass carpet.
			_veg_line_trees(out, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, 0.55, Vector2(2.0, 26.0), 1.0, 1.7, ["tree_autumn_orange", "tree_autumn_orange", "tree_autumn_red", "tree_autumn_gold", "tree_autumn_gold", "pine"])
			_veg_scatter(out, "grass", 200, 0.4, 0.8, heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, z_max)

	# ── Surrounding landscape (every biome) ──────────────────────────────────
	# Three background layers that make the hole read as part of a larger course:
	#   * a treeline "wall" just outside the playfield edge (hides the mesh seam),
	#   * sparse trees scattered across the apron beyond it (fading into fog),
	#   * a light fill of trees through the in-bounds outer rough (so it isn't barren).
	# The first two are `decorative` (no colliders, off-playfield); the rough fill is in
	# bounds, so it keeps the normal trunk colliders. Palette + counts come from _bg_profile.
	var bg     : Dictionary = _bg_profile(bp["biome"])
	var palette : Array     = bg["palette"]
	var edge_h : float      = _edge_avg_h(heights, pts_x, pts_z)
	var base_h : float      = edge_h - APRON_DROP
	_veg_perimeter_trees(out, heights, pts_x, pts_z, z_max, edge_h, water, palette, int(bg["rows"]), bg["smin"], bg["smax"], minf(float(bg["perim_density"]) * BG_DENSITY, 1.0))
	_veg_apron_scatter(out, heights, pts_x, pts_z, z_max, base_h, water, palette, int(round(float(bg["scatter"]) * BG_DENSITY)), bg["smin"], bg["smax"])
	if int(bg["rough_trees"]) > 0:
		_veg_scatter_palette(out, palette, int(round(float(bg["rough_trees"]) * BG_DENSITY)), bg["smin"], bg["smax"], heights, pts_x, pts_z, spine, fairway_half, green, water, sand, tee, z_max)
	return out

# Per-biome background landscape recipe: tree palette, perimeter row count + per-station
# probability, apron-scatter count, in-bounds rough-fill count, and a scale range. Open
# biomes (links, fescue) deliberately keep a thin perimeter and rely more on the apron + fog.
func _bg_profile(biome: String) -> Dictionary:
	match biome:
		"links":
			return {"palette": ["tree", "tree_slim"], "rows": 1, "perim_density": 0.18, "scatter": 24, "rough_trees": 0, "smin": 0.9, "smax": 1.4}
		"fescue":
			return {"palette": ["tree", "tree_slim", "pine"], "rows": 1, "perim_density": 0.35, "scatter": 36, "rough_trees": 20, "smin": 1.0, "smax": 1.6}
		"alpine":
			return {"palette": ["pine", "pine", "pine", "tree"], "rows": 3, "perim_density": 0.85, "scatter": 110, "rough_trees": 90, "smin": 1.0, "smax": 1.9}
		"autumn":
			return {"palette": ["tree_autumn_orange", "tree_autumn_red", "tree_autumn_gold", "pine"], "rows": 3, "perim_density": 0.8, "scatter": 100, "rough_trees": 90, "smin": 1.0, "smax": 1.8}
		_:  # parkland
			return {"palette": ["tree", "tree", "tree_slim", "pine"], "rows": 3, "perim_density": 0.8, "scatter": 100, "rough_trees": 90, "smin": 1.0, "smax": 1.8}

# Is (x, z) a valid spot for vegetation: rough turf, clear of the tee pad.
func _veg_ok(x: float, z: float, spine: PackedVector2Array, fairway_half: float, green: Dictionary, water: Array, sand: Array, tee: Dictionary) -> bool:
	if _classify(x, z, spine, fairway_half, green, water, sand) != "rough":
		return false
	if Vector2(x, z).distance_to(tee["center"]) < 8.0:
		return false
	# Keep the wedge BEHIND the tee clear: the tee-shot camera stands ~16 m back and looks
	# down the line of play, so any tree behind the teeing line crowds (or blocks) that view.
	var d   : Vector2 = Vector2(x, z) - tee["center"]
	var dir : Vector2 = tee.get("dir", Vector2(0.0, 1.0))
	var behind : float = -d.dot(dir)
	if behind > 0.0 and behind < 34.0 and absf(d.dot(Vector2(-dir.y, dir.x))) < fairway_half + 16.0:
		return false
	return true

# Walk down the spine and line both fairway edges with trees (probability `density` per
# side per station). `band` is the offset range beyond the fairway edge. More stations and
# a small per-hit cluster (1-3 trees at staggered depths) build deeper, denser tree lines --
# roughly triple the old single-row count. `palette` is a weighted list of tree types (a
# type's repetition count is its weight); one is picked per tree so designs intermix.
func _veg_line_trees(out: Array, heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, fairway_half: float, green: Dictionary, water: Array, sand: Array, tee: Dictionary, density: float, band: Vector2, smin: float, smax: float, palette: Array) -> void:
	var stations : int = 110
	for k in range(stations + 1):
		var frac : float   = float(k) / float(stations)
		var c    : Vector2 = _spine_sample(spine, frac)
		var tng  : Vector2 = _spine_tangent(spine, frac)
		var nrm  : Vector2 = Vector2(-tng.y, tng.x)
		for side in [-1.0, 1.0]:
			if rng.randf() > density:
				continue
			var cluster : int = rng.randi_range(1, 3)
			for _n in range(cluster):
				var off : float   = fairway_half + rng.randf_range(band.x, band.y)
				var p   : Vector2 = c + nrm * side * off
				if not _veg_ok(p.x, p.y, spine, fairway_half, green, water, sand, tee):
					continue
				var y : float = _sample_height(heights, pts_x, pts_z, p.x, p.y)
				var ttype : String = palette[rng.randi_range(0, palette.size() - 1)]
				out.append({"type": ttype, "pos": Vector3(p.x, y, p.y), "yaw": rng.randf() * TAU, "scale": rng.randf_range(smin, smax)})

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

# As _veg_scatter, but each prop's type is drawn from a weighted `palette` (so a mixed tree
# fill intermixes types). In-bounds rough only -- these get the normal trunk colliders.
func _veg_scatter_palette(out: Array, palette: Array, count: int, smin: float, smax: float, heights: PackedFloat32Array, pts_x: int, pts_z: int, spine: PackedVector2Array, fairway_half: float, green: Dictionary, water: Array, sand: Array, tee: Dictionary, z_max: float) -> void:
	var hw       : float = TERRAIN_W * 0.5 - 2.0
	var placed   : int   = 0
	var attempts : int   = 0
	var max_att  : int   = count * 5
	while placed < count and attempts < max_att:
		attempts += 1
		var x : float = rng.randf_range(-hw, hw)
		var z : float = rng.randf_range(0.0, z_max)
		if not _veg_ok(x, z, spine, fairway_half, green, water, sand, tee):
			continue
		var y : float = _sample_height(heights, pts_x, pts_z, x, z)
		var ttype : String = palette[rng.randi_range(0, palette.size() - 1)]
		out.append({"type": ttype, "pos": Vector3(x, y, z), "yaw": rng.randf() * TAU, "scale": rng.randf_range(smin, smax)})
		placed += 1

# Treeline "wall" just outside the playfield boundary: walk the rectangle (both long edges +
# the tee/back ends) and, per station per row, drop a tree a few metres outside the edge. The
# trunks root at the playfield lip height (where the apron meets the course) so they line the
# boundary cleanly. Marked `decorative` -- off-playfield, no colliders.
func _veg_perimeter_trees(out: Array, heights: PackedFloat32Array, pts_x: int, pts_z: int, z_max: float, edge_h: float, water: Array, palette: Array, rows: int, smin: float, smax: float, density: float) -> void:
	var hw     : float = TERRAIN_W * 0.5
	var base_h : float = edge_h - APRON_DROP   # far-field apron level the roll settles toward
	var step   : float = 5.0
	var nz     : int   = int(z_max / step)
	var nx     : int   = int((hw * 2.0) / step)
	# Long edges (x = +/-hw), trees pushed outward (+/-x).
	for side in [-1.0, 1.0]:
		for i in range(nz + 1):
			_perim_place(out, heights, pts_x, pts_z, base_h, z_max, water, Vector2(side * hw, float(i) * step), Vector2(side, 0.0), rows, palette, smin, smax, density)
	# Tee end (z = 0, outward -z) and back end (z = z_max, outward +z). On the tee end we
	# leave a central gap so the treeline wall never sits behind the tee in the camera's view.
	for endz in [0.0, z_max]:
		var ndir : float = -1.0 if endz == 0.0 else 1.0
		for i in range(nx + 1):
			var bx : float = -hw + float(i) * step
			if endz == 0.0 and absf(bx) < 30.0:
				continue
			_perim_place(out, heights, pts_x, pts_z, base_h, z_max, water, Vector2(bx, endz), Vector2(0.0, ndir), rows, palette, smin, smax, density)

func _perim_place(out: Array, heights: PackedFloat32Array, pts_x: int, pts_z: int, base_h: float, z_max: float, water: Array, boundary: Vector2, outdir: Vector2, rows: int, palette: Array, smin: float, smax: float, density: float) -> void:
	for r in range(rows):
		if rng.randf() > density:
			continue
		var off    : float   = 3.0 + float(r) * 6.0 + rng.randf_range(-1.5, 1.5)
		var jitter : Vector2 = Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
		var p      : Vector2 = boundary + outdir * off + jitter
		# Root on the apron surface just outside the boundary so trunks sit on the ground.
		var y      : float   = _apron_height(heights, pts_x, pts_z, p.x, p.y, base_h, z_max, water)
		# Skip the shore bank / water: those trees would stand under the apron-spilling water
		# plane. Leaving the immediate shore clear keeps the treeline back on dry land.
		var wy     : float   = _apron_water_y(p.x, p.y, z_max, water)
		if wy > -INF and y < wy + TREE_SHORE_CLEAR:
			continue
		var ttype  : String  = palette[rng.randi_range(0, palette.size() - 1)]
		out.append({"type": ttype, "pos": Vector3(p.x, y, p.y), "yaw": rng.randf() * TAU, "scale": rng.randf_range(smin, smax), "decorative": true})

# Sparse trees scattered across the apron ring (beyond the perimeter wall, out toward the
# fog). Rooted on the apron surface via _apron_height. `decorative` -- no colliders.
func _veg_apron_scatter(out: Array, heights: PackedFloat32Array, pts_x: int, pts_z: int, z_max: float, base_h: float, water: Array, palette: Array, count: int, smin: float, smax: float) -> void:
	var hw       : float = TERRAIN_W * 0.5
	var inner    : float = hw + 8.0            # leave the boundary band to the perimeter pass
	var reach    : float = APRON_MARGIN * 0.7  # stop short of the fog wall
	var placed   : int   = 0
	var attempts : int   = 0
	var max_att  : int   = count * 4
	while placed < count and attempts < max_att:
		attempts += 1
		var x : float = rng.randf_range(-hw - reach, hw + reach)
		var z : float = rng.randf_range(-reach, z_max + reach)
		# Skip points inside (or hugging) the playfield -- those belong to other passes.
		if absf(x) < inner and z > -8.0 and z < z_max + 8.0:
			continue
		# Keep the corridor behind the tee (low z, near centre) clear for the tee-shot camera.
		if z < 8.0 and absf(x) < 32.0:
			continue
		var y : float = _apron_height(heights, pts_x, pts_z, x, z, base_h, z_max, water)
		# Don't scatter onto the shore bank / water (would sit under the water plane).
		var wy : float = _apron_water_y(x, z, z_max, water)
		if wy > -INF and y < wy + TREE_SHORE_CLEAR:
			continue
		var ttype : String = palette[rng.randi_range(0, palette.size() - 1)]
		out.append({"type": ttype, "pos": Vector3(x, y, z), "yaw": rng.randf() * TAU, "scale": rng.randf_range(smin, smax), "decorative": true})
		placed += 1

# ── Surrounding apron ─────────────────────────────────────────────────────────
# Average height of the four playfield border rows/cols. The apron meets the course near
# this elevation so the seam between them stays subtle (and is further hidden by the
# perimeter treeline + fog).
func _edge_avg_h(heights: PackedFloat32Array, pts_x: int, pts_z: int) -> float:
	var s : float = 0.0
	var n : int   = 0
	for xi in range(pts_x):
		s += heights[xi]                            # z = 0 border
		s += heights[(pts_z - 1) * pts_x + xi]      # z = max border
		n += 2
	for zi in range(pts_z):
		s += heights[zi * pts_x]                    # x = -hw border
		s += heights[zi * pts_x + (pts_x - 1)]      # x = +hw border
		n += 2
	return s / float(n) if n > 0 else 0.0

# Apron surface height at a world point, and the single source of truth shared by the apron
# mesh and the background tree placement.
#   * At the seam (d = 0) it returns the EXACT terrain border height (_sample_height clamps to
#     the grid, so any outside point maps to its nearest border vertex). The apron mesh samples
#     the seam at terrain (CELL) resolution, so its inner edge coincides with the terrain's
#     rolling border vertices and there is no gap -- whatever the hole's elevation change.
#   * Where the nearest border point is under water, the seam still matches the (low) pond bed
#     so it stays watertight there, but a few metres out the apron rises to a BANK just above
#     the waterline, so the pond reads as enclosed by a far shore instead of the apron jutting
#     out of the bed (which also left the water plane edge looking like a floating wall).
#   * Beyond the bank it eases toward a gently rolling far-field level so distant land undulates.
func _apron_height(heights: PackedFloat32Array, pts_x: int, pts_z: int, x: float, z: float, base_h: float, z_max: float, water: Array) -> float:
	var hw       : float = TERRAIN_W * 0.5
	var dx       : float = maxf(absf(x) - hw, 0.0)
	var dz       : float = maxf(maxf(-z, z - z_max), 0.0)
	var d        : float = sqrt(dx * dx + dz * dz)
	var border_h : float = _sample_height(heights, pts_x, pts_z, x, z)
	if d <= 0.001:
		return border_h   # exact seam -> watertight with the terrain border
	var roll  : float = sin(x * 0.018) * cos(z * 0.015) + sin(x * 0.041 + z * 0.033) * 0.5
	var far_h : float = base_h + roll * 4.0
	# Where the nearest in-bounds point is submerged, build a DEFINED bank that mirrors the
	# carved near shore: a short, STEEP climb out of the water to a crest just above the
	# waterline (a real water's edge), then a gentle ease to the far field. The crest is held
	# across the water plane's reach so the plane always meets solid bank -- a crisp edge --
	# rather than fading out over a long shallow slope that reads as the water floating.
	var crest : float = -INF
	for b: Dictionary in water:
		if _in_body(clampf(x, -hw, hw), clampf(z, 0.0, z_max), b):
			crest = maxf(crest, float(b["water_y"]) + APRON_BANK_LIP)
	if crest > -INF:
		crest = maxf(crest, border_h)
		if d <= APRON_BANK_RISE:
			var tb : float = d / APRON_BANK_RISE
			return lerpf(border_h, crest, tb * tb * (3.0 - 2.0 * tb))
		var te : float = clampf((d - APRON_BANK_RISE) / (APRON_MARGIN - APRON_BANK_RISE), 0.0, 1.0)
		var he : float = lerpf(crest, far_h, te * te * (3.0 - 2.0 * te))
		return maxf(he, crest) if d <= APRON_BANK_W else he
	# Dry border: hold the seam height across the near apron, then ease to the rolling far field.
	if d <= APRON_BANK_W:
		return border_h
	var t : float = clampf((d - APRON_BANK_W) / (APRON_MARGIN - APRON_BANK_W), 0.0, 1.0)
	return lerpf(border_h, far_h, t * t * (3.0 - 2.0 * t))

# The waterline at an apron point if its nearest in-bounds point is submerged (the same test
# _apron_height uses to raise the shore bank), else -INF. Lets the decorative tree passes keep
# the treeline back from the water rather than planting it on the bank under the water plane.
func _apron_water_y(x: float, z: float, z_max: float, water: Array) -> float:
	var hw : float = TERRAIN_W * 0.5
	var cx : float = clampf(x, -hw, hw)
	var cz : float = clampf(z, 0.0, z_max)
	var best : float = -INF
	for b: Dictionary in water:
		if _in_body(cx, cz, b):
			best = maxf(best, float(b["water_y"]))
	return best

# A rolling ground plane that surrounds the playfield (never covers its interior). Visual only
# -- no collider (the ball is reset out of bounds long before it could reach here). Coloured
# with the biome rough tone and drawn with the terrain shader so its detail matches the course;
# its far reaches dissolve into the depth fog set in hole_manager. Lives under `course`.
func _make_apron(data: Dictionary) -> MeshInstance3D:
	var pts_x   : int                = data["pts_x"]
	var pts_z   : int                = data["pts_z"]
	var heights : PackedFloat32Array = data["heights"]
	var water   : Array              = data.get("water_bodies", [])
	var z_max   : float              = float(pts_z - 1) * CELL
	var hw      : float              = TERRAIN_W * 0.5
	var base_h  : float              = _edge_avg_h(heights, pts_x, pts_z) - APRON_DROP

	var col : Color = _rough_color(data.get("biome", "parkland"))
	col.a = 1.0   # terrain shader's "turf" bucket

	# A single continuous "picture-frame" ring around the playfield, instead of four separate
	# edge strips. The inner loop is sampled at terrain (CELL) resolution along the whole border,
	# so it lands on the same rolling border vertices the terrain mesh ends on -- watertight. The
	# loop then steps outward over coarse rings to the fog horizon. Because it is ONE grid with a
	# shared topology (no independent strips meeting at the corners), there are no T-junctions, so
	# the mismatched-vertex cracks that used to show the void along the distant seams are gone.
	# Corner points get a diagonal outward normal so the rings fan out and fill the corners.
	var loop := PackedVector2Array()
	var onrm := PackedVector2Array()
	const DIAG : float = 0.70710678
	# Walk the border as a closed loop: front edge (+x), right edge (+z), back edge (-x), left
	# edge (-z). Each corner is emitted once with the averaged (diagonal) outward normal.
	loop.append(Vector2(-hw, 0.0));    onrm.append(Vector2(-DIAG, -DIAG))
	var x : float = -hw + CELL
	while x < hw - 0.001:
		loop.append(Vector2(x, 0.0));  onrm.append(Vector2(0.0, -1.0)); x += CELL
	loop.append(Vector2(hw, 0.0));     onrm.append(Vector2(DIAG, -DIAG))
	var z : float = CELL
	while z < z_max - 0.001:
		loop.append(Vector2(hw, z));   onrm.append(Vector2(1.0, 0.0)); z += CELL
	loop.append(Vector2(hw, z_max));   onrm.append(Vector2(DIAG, DIAG))
	x = hw - CELL
	while x > -hw + 0.001:
		loop.append(Vector2(x, z_max)); onrm.append(Vector2(0.0, 1.0)); x -= CELL
	loop.append(Vector2(-hw, z_max));  onrm.append(Vector2(-DIAG, DIAG))
	z = z_max - CELL
	while z > 0.001:
		loop.append(Vector2(-hw, z));  onrm.append(Vector2(-1.0, 0.0)); z -= CELL

	# Outward rings. The close ring at APRON_BANK_RISE gives the steep over-water bank real
	# geometry (without it the bank flattens into the long gradual slope to the far field).
	var rdist : Array = [0.0, APRON_BANK_RISE, APRON_BANK_W, 30.0, 90.0, APRON_MARGIN]
	var nr    : int   = rdist.size()
	var ns    : int   = loop.size()

	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors  := PackedColorArray()
	var indices := PackedInt32Array()
	for j in range(ns):
		for k in range(nr):
			var p : Vector2 = loop[j] + onrm[j] * float(rdist[k])
			var y : float = _apron_height(heights, pts_x, pts_z, p.x, p.y, base_h, z_max, water)
			verts.append(Vector3(p.x, y, p.y))
			colors.append(col)
			normals.append(Vector3.UP)   # replaced below once neighbours exist
	# Per-vertex normals from neighbours. The loop wraps (j is modular); rings clamp.
	for j in range(ns):
		var jp : int = (j + 1) % ns
		var jm : int = (j - 1 + ns) % ns
		for k in range(nr):
			var a : Vector3 = verts[jp * nr + k] - verts[jm * nr + k]
			var c : Vector3 = verts[j * nr + mini(k + 1, nr - 1)] - verts[j * nr + maxi(k - 1, 0)]
			var n : Vector3 = c.cross(a)
			if n.y < 0.0:
				n = -n
			normals[j * nr + k] = n.normalized() if n.length() > 1e-6 else Vector3.UP
	# Triangulate between consecutive rings around the closed loop (jn wraps to seal the frame).
	for j in range(ns):
		var jn : int = (j + 1) % ns
		for k in range(nr - 1):
			var tl : int = j * nr + k
			var tr : int = jn * nr + k
			var bl : int = tl + 1
			var br : int = tr + 1
			indices.append_array(PackedInt32Array([tl, tr, bl, tr, br, bl]))

	var mi := MeshInstance3D.new()
	mi.name = "Apron"
	mi.mesh = _arrays_to_mesh(verts, normals, colors, indices)
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mi.material_override = mat
	# It's large and distant; casting shadows would be costly and pointless.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

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
			var col  : Color  = rough_col if kind == "rough" else _color_for(kind)
			# Vertex-colour alpha is the terrain shader's surface flag: 0.0 = putting green
			# (smooth, manicured), 0.5 = sand (the shader's grain/ripple branch), 1.0 = turf
			# (the broad mottle). Kept as discrete sentinels the fragment shader buckets.
			if kind == "green":
				col.a = 0.0
			elif kind == "sand":
				col.a = 0.5
			else:
				col.a = 1.0
			colors.append(col)

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
			# Wind the triangles so their front faces point UP (Godot treats clockwise-from-front
			# as the front face). The earlier order put the front faces underneath, so with the
			# material's CULL_DISABLED the camera saw back faces whose shading normal is flipped
			# to -Y -- the whole terrain then took only ambient light and looked dim/flat while
			# the separately-built pads (tee, cup collar) stayed correctly lit and conspicuously
			# bright. This winding lights the surface the player actually sees.
			indices.append_array(PackedInt32Array([tl, tr, bl, tr, br, bl]))

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
		"alpine": return COL_ROUGH_ALPINE
		"autumn": return COL_ROUGH_AUTUMN
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
	# Match the terrain detail shader's surface response (roughness 0.9, default specular) so
	# the green collar reads as the same shade as the masked-flat green it sits in.
	mat.roughness         = 0.9
	mat.metallic          = 0.0
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

	# Pole drops all the way to the cup floor: cup_pos sits CUP_DEPTH*0.5 above the floor,
	# so a base offset of -CUP_DEPTH*0.5 plants the pole on the floor with no floating gap.
	var pole_h   : float = 3.8
	var pole     := MeshInstance3D.new()
	var pole_cyl := CylinderMesh.new()
	pole_cyl.top_radius    = 0.05
	pole_cyl.bottom_radius = 0.05
	pole_cyl.height        = pole_h
	pole.mesh     = pole_cyl
	var pole_mat  := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.85, 0.85, 0.85)
	pole.material_override = pole_mat
	pole.position = cup_pos + Vector3(0.0, -CUP_DEPTH * 0.5 + pole_h * 0.5, 0.0)
	node.add_child(pole)

	# Larger, fluttering flag. A subdivided plane (so it can ripple) anchored at the pole:
	# its local +X runs out to the free edge, +Y is the cloth height. Rotated upright so the
	# plane stands vertical, then shifted so the attached edge meets the pole near the top.
	var flag_w   : float = 1.5
	var flag_h   : float = 0.9
	var flag     := MeshInstance3D.new()
	var flag_plane := PlaneMesh.new()
	flag_plane.size           = Vector2(flag_w, flag_h)
	flag_plane.subdivide_width = 10
	flag_plane.subdivide_depth = 2
	# PlaneMesh lies in XZ centred on origin; lift its local origin to the attached corner so
	# X in [0, flag_w] is distance from the pole (the shader's flutter mask).
	flag_plane.center_offset = Vector3(flag_w * 0.5, 0.0, flag_h * 0.5)
	flag.mesh = flag_plane
	var flag_mat := ShaderMaterial.new()
	flag_mat.shader = FLAG_SHADER
	flag_mat.set_shader_parameter("flag_color", Color(COL_FLAG.r, COL_FLAG.g, COL_FLAG.b))
	flag.material_override = flag_mat
	# Stand the plane upright (XZ -> XY) so width runs along world X and height along world Y.
	flag.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	# Attached edge against the pole, top of the cloth just below the pole top.
	var pole_top : float = cup_pos.y - CUP_DEPTH * 0.5 + pole_h
	flag.position = Vector3(cup_pos.x + 0.05, pole_top - flag_h - 0.12, cup_pos.z)
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

	# Mown collar skirt: a slightly larger, lower pad in the darker fringe tone that frames
	# the tee (mirrors the collar around the green) and gives the pad a defined edge.
	var collar     := MeshInstance3D.new()
	var collar_box := BoxMesh.new()
	collar_box.size = Vector3((TEE_HALF_W + 1.0) * 2.0, 0.10, (TEE_HALF_LEN + 1.0) * 2.0)
	collar.mesh = collar_box
	var collar_mat := StandardMaterial3D.new()
	collar_mat.albedo_color = COL_FRINGE
	collar_mat.roughness    = 0.95
	collar.material_override = collar_mat
	collar.position   = Vector3(center.x, pad_h + 0.03, center.y)
	collar.rotation.y = ang
	node.add_child(collar)

	# Flat, neatly mown tee pad in a distinct lighter green, standing proud of the collar.
	var pad     := MeshInstance3D.new()
	var pad_box := BoxMesh.new()
	pad_box.size = Vector3(TEE_HALF_W * 2.0, 0.10, TEE_HALF_LEN * 2.0)
	pad.mesh     = pad_box
	var pad_mat  := StandardMaterial3D.new()
	pad_mat.albedo_color = COL_TEE
	pad_mat.roughness    = 0.9
	pad.material_override = pad_mat
	pad.position    = Vector3(center.x, pad_h + 0.07, center.y)
	pad.rotation.y  = ang
	node.add_child(pad)

	var pad_top : float = pad_h + 0.12   # mown surface the markers and sign stand on

	# Two ball-on-post tee markers flanking the ball, just ahead of the teeing line.
	var fwd : Vector2 = center + dir * (TEE_HALF_LEN * 0.25)
	for s in [-1.0, 1.0]:
		var m_pos : Vector2 = fwd + across * (TEE_HALF_W * 0.7) * s
		node.add_child(_make_tee_marker(Vector3(m_pos.x, pad_top, m_pos.y)))

	# A low wooden tee sign at the back corner of the pad -- a small, realistic detail.
	var sign_pos : Vector2 = center - dir * (TEE_HALF_LEN * 0.8) + across * (TEE_HALF_W * 0.85)
	node.add_child(_make_tee_sign(Vector3(sign_pos.x, pad_top, sign_pos.y), ang))

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

# A classic "ball on a post" tee marker: a short tapered post capped with a sphere, in the
# white marker colour. `pos` is the mown surface the post stands on.
func _make_tee_marker(pos: Vector3) -> Node3D:
	var m := Node3D.new()
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COL_TEE_MARK
	mat.roughness    = 0.55

	var post     := MeshInstance3D.new()
	var post_cyl := CylinderMesh.new()
	post_cyl.top_radius    = 0.11
	post_cyl.bottom_radius = 0.14
	post_cyl.height        = 0.22
	post.mesh = post_cyl
	post.material_override = mat
	post.position = Vector3(0.0, 0.11, 0.0)
	m.add_child(post)

	var cap     := MeshInstance3D.new()
	var cap_sph := SphereMesh.new()
	cap_sph.radius = 0.16
	cap_sph.height = 0.32
	cap.mesh = cap_sph
	cap.material_override = mat
	cap.position = Vector3(0.0, 0.30, 0.0)
	m.add_child(cap)
	return m

# A small wooden tee sign: a tapered post topped with an angled plaque board. `ang` aligns
# it with the line of play; `pos` is the mown surface it stands on.
func _make_tee_sign(pos: Vector3, ang: float) -> Node3D:
	var s := Node3D.new()
	s.position   = pos
	s.rotation.y = ang

	var wood := StandardMaterial3D.new()
	wood.albedo_color = COL_PEG     # weathered wood, shared with the tee peg
	wood.roughness    = 0.95

	var post     := MeshInstance3D.new()
	var post_cyl := CylinderMesh.new()
	post_cyl.top_radius    = 0.05
	post_cyl.bottom_radius = 0.06
	post_cyl.height        = 0.95
	post.mesh = post_cyl
	post.material_override = wood
	post.position = Vector3(0.0, 0.47, 0.0)
	s.add_child(post)

	var board     := MeshInstance3D.new()
	var board_box := BoxMesh.new()
	board_box.size = Vector3(0.72, 0.34, 0.05)
	board.mesh = board_box
	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.16, 0.12, 0.08)   # dark stained board face
	board_mat.roughness    = 0.9
	board.material_override = board_mat
	board.position   = Vector3(0.0, 0.92, 0.0)
	board.rotation.x = deg_to_rad(18.0)
	s.add_child(board)
	return s

# ── Vegetation node factories ─────────────────────────────────────────────────
# Placements (from _build_vegetation) are grouped by type and drawn with one MultiMesh
# each. Every base mesh is "ground-rooted" (local origin at the base, +Y up) so the wind
# shader's height-based bend mask works and the instance transform can sit straight on the
# ground. Built fresh per hole; cleared by hole_manager's course teardown.

func _build_vegetation_nodes(data: Dictionary, parent: Node3D) -> void:
	var veg : Array = data.get("vegetation", [])
	if veg.is_empty():
		return

	# Group by type AND the decorative flag: a tree type can have both in-bounds (collidable)
	# and off-playfield decorative instances, and they need separate MultiMeshes so only the
	# in-bounds ones get trunk colliders.
	var groups : Dictionary = {}
	for item: Dictionary in veg:
		var t    : String = item["type"]
		var deco : bool   = item.get("decorative", false)
		var key  : String = t + ("#bg" if deco else "")
		if not groups.has(key):
			groups[key] = {"type": t, "decorative": deco, "items": []}
		groups[key]["items"].append(item)

	var zl  : float = float(data["pts_z"] - 1) * CELL
	# Reach far enough to enclose the apron + perimeter trees so the block is never wrongly
	# frustum-culled when the camera looks out toward the horizon.
	var rad : float = TERRAIN_W * 0.5 + APRON_MARGIN
	for key: String in groups.keys():
		var t     : String = groups[key]["type"]
		var deco  : bool   = groups[key]["decorative"]
		var items : Array  = groups[key]["items"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh             = _veg_mesh_for(t)
		mm.instance_count   = items.size()
		for i in range(items.size()):
			var it : Dictionary = items[i]
			var b : Basis = Basis(Vector3.UP, it["yaw"]).scaled(Vector3.ONE * float(it["scale"]))
			mm.set_instance_transform(i, Transform3D(b, it["pos"]))

		var mmi := MultiMeshInstance3D.new()
		mmi.name              = "Veg_" + key
		mmi.multimesh         = mm
		mmi.material_override  = _veg_material_for(t)
		# Trees cast shadows; low grass/scrub don't (mobile cost, negligible visual loss).
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _is_tree(t) \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-rad, -20.0, -APRON_MARGIN), Vector3(rad * 2.0, 90.0, zl + APRON_MARGIN * 2.0))
		parent.add_child(mmi)

		# Trees are solid: the ball must bounce off them, not pass through. Grass/scrub stay
		# pass-through, and decorative trees are off-playfield (the ball is reset out of bounds
		# before reaching them), so only in-bounds trees get a trunk collider.
		if _is_tree(t) and not deco:
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
		var tt  : String  = it["type"]
		# Pines and slim trees have notably thinner trunks than the round broadleaf.
		var rad_f : float = 0.28 if (tt == "pine" or tt == "tree_slim") else 0.42
		var cyl := CylinderShape3D.new()
		cyl.radius = rad_f * sc
		cyl.height = 3.0 * sc
		var col := CollisionShape3D.new()
		col.shape    = cyl
		col.position = Vector3(p.x, p.y + cyl.height * 0.5, p.z)
		body.add_child(col)
	return body

# True for every solid, wind-swept tree variant (round, pine, slim, autumn hues). Drives
# mesh choice, the wind material, shadow casting and trunk colliders alike.
func _is_tree(t: String) -> bool:
	return t == "tree" or t == "pine" or t == "tree_slim" or t.begins_with("tree_autumn")

func _veg_mesh_for(t: String) -> ArrayMesh:
	match t:
		"tree":               return _make_tree_mesh()
		"pine":               return _make_pine_mesh()
		"tree_slim":          return _make_slim_tree_mesh()
		"tree_autumn_orange": return _make_tree_mesh_tinted(Color(0.78, 0.42, 0.12))
		"tree_autumn_red":    return _make_tree_mesh_tinted(Color(0.66, 0.20, 0.12))
		"tree_autumn_gold":   return _make_tree_mesh_tinted(Color(0.80, 0.62, 0.16))
		"scrub":              return _make_scrub_mesh()
		_:                    return _make_grass_mesh()

func _veg_material_for(t: String) -> Material:
	if _is_tree(t):
		var m := ShaderMaterial.new()
		m.shader = WIND_SHADER
		m.set_shader_parameter("wind_strength", 0.04)   # trees barely flex
		m.set_shader_parameter("wind_speed", 1.1)
		return m
	match t:
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

# A low-poly tree: a tapered trunk (brown) topped by a spherical canopy, merged into one
# mesh so a single MultiMesh covers a whole tree. Base sits at local y = 0. The canopy
# colour is a parameter so the autumn biome can reuse the shape in warm fall hues.
func _make_tree_mesh() -> ArrayMesh:
	return _make_tree_mesh_tinted(Color(0.18, 0.36, 0.17))

func _make_tree_mesh_tinted(canopy_col: Color) -> ArrayMesh:
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
	_append_prim(canopy, 2.3, canopy_col, verts, normals, colors, indices)
	return _arrays_to_mesh(verts, normals, colors, indices)

# A small upward cone (CylinderMesh with a zero-radius top), used to layer a conifer.
func _cone(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius      = 0.0
	c.bottom_radius   = radius
	c.height          = height
	c.radial_segments = 8
	c.rings           = 1
	return c

# A conifer/pine: a short trunk topped by three overlapping cones, tall and narrow with a
# dark blue-green needle colour. Base at local y = 0.
func _make_pine_mesh() -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius      = 0.08
	trunk.bottom_radius   = 0.13
	trunk.height          = 1.2
	trunk.radial_segments = 6
	trunk.rings           = 1
	var needle := Color(0.12, 0.30, 0.18)

	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors  := PackedColorArray()
	var indices := PackedInt32Array()
	_append_prim(trunk, 0.6, Color(0.34, 0.24, 0.15), verts, normals, colors, indices)
	# Three stacked cones (centre = base + height*0.5), each narrower and higher.
	_append_prim(_cone(1.10, 1.8), 1.9,  needle, verts, normals, colors, indices)
	_append_prim(_cone(0.85, 1.5), 2.75, needle, verts, normals, colors, indices)
	_append_prim(_cone(0.55, 1.3), 3.55, needle, verts, normals, colors, indices)
	return _arrays_to_mesh(verts, normals, colors, indices)

# A slim broadleaf (birch/poplar): a tall thin pale trunk with a narrow, tall canopy.
# Base at local y = 0.
func _make_slim_tree_mesh() -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius      = 0.07
	trunk.bottom_radius   = 0.10
	trunk.height          = 2.4
	trunk.radial_segments = 6
	trunk.rings           = 1
	var canopy := SphereMesh.new()
	canopy.radius          = 0.7
	canopy.height          = 2.8
	canopy.radial_segments = 8
	canopy.rings           = 5

	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors  := PackedColorArray()
	var indices := PackedInt32Array()
	_append_prim(trunk,  1.2, Color(0.78, 0.78, 0.74), verts, normals, colors, indices)
	_append_prim(canopy, 3.0, Color(0.22, 0.40, 0.20), verts, normals, colors, indices)
	return _arrays_to_mesh(verts, normals, colors, indices)

# A grass tuft: three thin triangular blades fanned around the base, dark at the root and
# bright at the tip (the brightness also reads as the wind bend gradient). Base at y = 0.
func _make_grass_mesh() -> ArrayMesh:
	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors  := PackedColorArray()
	var indices := PackedInt32Array()
	var base_col := Color(0.19, 0.28, 0.13)
	var tip_col  := Color(0.44, 0.48, 0.27)
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
	_append_prim(dome, 0.4, Color(0.27, 0.34, 0.21), verts, normals, colors, indices)
	return _arrays_to_mesh(verts, normals, colors, indices)
