class_name ItemVisuals
extends RefCounted

# Shared rendering for clubs and balls so the clubhouse, the pro shop, and the box-opening
# overlay all draw items identically -- including procedurally generated items that carry their
# own per-item palette / pattern. Pure static helpers; build 3D thumbnails in a SubViewport and
# the runtime ball material.

const BALL_SHADER : Shader = preload("res://shaders/ball.gdshader")

const PATTERN_ID := {"solid": 0, "stripe": 1, "spots": 2, "two_tone": 3}

const RARITY_COLORS := {
	"common":    Color(0.78, 0.82, 0.78),
	"uncommon":  Color(0.42, 0.78, 0.45),
	"rare":      Color(0.36, 0.62, 0.95),
	"legendary": Color(0.86, 0.55, 0.95),
}


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS["common"])


# Palette for a club's 3D head/shaft. A generated club carries its own `colors` (arrays) +
# `pattern`; everything else falls back to ClubVisual's per-type default palette.
static func club_palette(club: Dictionary) -> Dictionary:
	if club.has("colors"):
		var c: Dictionary = club["colors"]
		return {
			"shaft": _to_color(c.get("shaft", [0.7, 0.7, 0.7])),
			"grip": _to_color(c.get("grip", [0.08, 0.08, 0.08])),
			"head": _to_color(c.get("head", [0.5, 0.5, 0.5])),
			"accent": _to_color(c.get("accent", [0.8, 0.8, 0.8])),
			"head_rough": float(c.get("head_rough", 0.4)),
			"head_metal": float(c.get("head_metal", 0.6)),
			"two_tone": club.get("pattern", "solid") == "two_tone",
		}
	var type: String = club.get("type", "driver")
	return ClubVisual.CLUB_PALETTES.get(type, ClubVisual.CLUB_PALETTES["driver"])


# Skin a ball MeshInstance3D from its data (colour, colour2, pattern). Used both in-course
# (ball.gd) and for thumbnails so what you see in the shop is what you putt with.
static func apply_ball_material(mesh: MeshInstance3D, ball: Dictionary) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = BALL_SHADER
	var col := _to_color(ball.get("color", [0.95, 0.95, 0.95]))
	var col2 := _to_color(ball.get("color2", [col.r * 0.3, col.g * 0.3, col.b * 0.3]))
	mat.set_shader_parameter("color", col)
	mat.set_shader_parameter("color2", col2)
	mat.set_shader_parameter("pattern", PATTERN_ID.get(ball.get("pattern", "solid"), 0))
	mesh.material_override = mat


# --- 3D thumbnails ----------------------------------------------------------

# A club head shown 3/4-on. The holder is mirrored on X so it reads right-handed (the raw
# geometry hangs the toe left); culling is disabled on the mirrored meshes so it still renders.
static func build_club_thumbnail(club: Dictionary) -> SubViewportContainer:
	var type: String = club.get("type", "driver")
	var holder := Node3D.new()
	holder.rotation = Vector3(deg_to_rad(-8.0), deg_to_rad(35.0), 0.0)
	holder.scale = Vector3(-1.0, 1.0, 1.0)
	var model := _club_model(club)
	model.position = Vector3(0.0, ClubVisual.SHAFT_LEN.get(type, 1.3) * 0.5, 0.0)
	holder.add_child(model)
	_disable_culling(model)
	return _make_thumb(holder, 3.2)


static func build_ball_thumbnail(ball: Dictionary) -> SubViewportContainer:
	var holder := Node3D.new()
	var ms := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 32
	sph.rings = 16
	ms.mesh = sph
	apply_ball_material(ms, ball)
	holder.add_child(ms)
	return _make_thumb(holder, 2.1)


# Static display club (shaft + grip + head) reusing the on-course geometry builders so the
# thumbnail matches the club you actually swing.
static func _club_model(club: Dictionary) -> Node3D:
	var type: String = club.get("type", "driver")
	var palette: Dictionary = club_palette(club)
	var shaft_len: float = ClubVisual.SHAFT_LEN.get(type, 1.3)
	var root := Node3D.new()

	var shaft := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius    = ClubVisual.SHAFT_RADIUS
	shaft_cyl.bottom_radius = ClubVisual.SHAFT_RADIUS
	shaft_cyl.height        = shaft_len
	shaft.mesh = shaft_cyl
	shaft.material_override = ClubVisual._mat(palette["shaft"], 0.3, 0.6)
	shaft.position = Vector3(0.0, -shaft_len * 0.5, 0.0)
	root.add_child(shaft)

	var grip := MeshInstance3D.new()
	var grip_cyl := CylinderMesh.new()
	grip_cyl.top_radius    = ClubVisual.GRIP_RADIUS
	grip_cyl.bottom_radius = ClubVisual.GRIP_RADIUS
	grip_cyl.height        = ClubVisual.GRIP_LEN
	grip.mesh = grip_cyl
	grip.material_override = ClubVisual._mat(palette["grip"], 0.9, 0.0)
	grip.position = Vector3(0.0, -0.13, 0.0)
	root.add_child(grip)

	var anchor := Node3D.new()
	anchor.position = Vector3(0.0, -shaft_len, 0.0)
	root.add_child(anchor)
	ClubVisual.build_head(type, anchor, palette)
	return root


# Shared inset SubViewport (transparent bg, lit, camera at cam_z) wrapping a 3D `content` node.
static func _make_thumb(content: Node3D, cam_z: float) -> SubViewportContainer:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE   # let clicks fall through to the host button
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.offset_left = 6.0
	svc.offset_top = 6.0
	svc.offset_right = -6.0
	svc.offset_bottom = -6.0

	var vp := SubViewport.new()
	vp.size = Vector2i(108, 108)
	vp.transparent_bg = true
	vp.own_world_3d = true   # isolate each thumbnail's 3D scene; otherwise all share the parent world and pile up
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	vp.add_child(content)

	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0.0, 0.0, cam_z)
	vp.add_child(cam)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.6)
	e.ambient_light_energy = 0.6
	env.environment = e
	vp.add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(-35.0), 0.0)
	key.light_energy = 1.3
	vp.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-10.0), deg_to_rad(120.0), 0.0)
	fill.light_energy = 0.4
	vp.add_child(fill)

	return svc


# Recursively disable backface culling so a mirror-scaled (flipped-winding) model renders.
static func _disable_culling(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.material_override is BaseMaterial3D:
			(mi.material_override as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	for child in node.get_children():
		_disable_culling(child)


static func _to_color(a) -> Color:
	if a is Color:
		return a
	if a is Array and a.size() >= 3:
		return Color(a[0], a[1], a[2])
	return Color(0.8, 0.8, 0.8)
