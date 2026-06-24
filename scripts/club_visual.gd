class_name ClubVisual
extends Node3D
# Golf club that takes the shot. Dragging back swings it into a backswing scaled by power;
# releasing plays a downswing through impact into a follow-through.
#
# Four visually distinct heads -- driver / iron / wedge / putter -- are built from the
# equipped club's `type` (see data/clubs.json, surfaced by EquipmentManager). The geometry
# is split into a shared SWING RIG (_build_rig) plus a per-type HEAD builder, and every head
# is skinned from a per-type entry in CLUB_PALETTES. Future unlockable variants only need to
# supply a different palette (and, for putters, an alternate head shape) -- the rig and the
# swing logic never change.
#
# Swing geometry: the root's `rotation.y` aims the whole club down the shot line, then an
# intermediate `_plane` node ROLLS the swing plane about that line by SWING_PLANE_TILT. A
# roll about the target line is the key: it inclines the swing plane (so the backswing rises
# up and around to the side, like a real golf swing) WITHOUT turning the clubface off the
# target -- a roll leaves the face normal pointing straight down the line, so impact stays
# square. The pivot then lifts the club via its local X to sweep through this tilted plane.
#
# The swing logic only ever touches `_pivot.rotation.x` and the root's `rotation.y`; the head
# hangs off a level, counter-rolled `head_anchor` so its face normal stays on the line. LOFT
# is applied as a tilt about the head's local X (the heel-toe axis): that leans the face back
# (up) without adding any sideways component to the normal, so the strike stays square.

const HAND_H         : float = 1.2                   # pivot ("hands") height above the ball
const ADDRESS_ANGLE  : float = deg_to_rad(-12.0)     # slight forward lean at address
const BACKSWING_MAX  : float = deg_to_rad(125.0)     # top of backswing at full power
const FOLLOW_THROUGH : float = deg_to_rad(-120.0)    # finish, club up in front
# How far the swing plane is inclined off vertical (rolled about the target line). ~50deg
# reads as a natural golf plane: the club rises up and around to the side on the way back.
# Flip the sign to swing to the opposite side (i.e. left- vs right-handed).
const SWING_PLANE_TILT : float = deg_to_rad(-50.0)

const SHAFT_RADIUS : float = 0.026
const GRIP_RADIUS  : float = 0.045
const GRIP_LEN     : float = 0.26

# Shaft length (grip-to-head) per club type. Driver is longest, wedge & putter shortest --
# the order real clubs run in. The hands stay at HAND_H, so a shorter shaft simply hangs the
# head higher; proportions read correctly without needing precise ground contact.
const SHAFT_LEN : Dictionary = {
	"driver": 1.32,
	"iron":   1.30,
	"wedge":  1.15,
	"putter": 1.22,
}

# Per-type skin. `head_rough`/`head_metal` set the finish; `accent` is used for the face
# plate (driver) and sight line (putter). Default look is classic-realistic: chrome irons,
# a dark painted driver crown, brushed steel wedge, matte putter, black grips throughout.
# A future unlock is just a new palette entry of the same shape.
const CLUB_PALETTES : Dictionary = {
	"driver": {
		"shaft": Color(0.16, 0.16, 0.18), "grip": Color(0.08, 0.08, 0.08),
		"head": Color(0.10, 0.11, 0.15),  "accent": Color(0.72, 0.75, 0.82),
		"head_rough": 0.25, "head_metal": 0.5,
	},
	"iron": {
		"shaft": Color(0.82, 0.84, 0.88), "grip": Color(0.08, 0.08, 0.08),
		"head": Color(0.78, 0.80, 0.85),  "accent": Color(0.55, 0.57, 0.62),
		"head_rough": 0.18, "head_metal": 0.85,
	},
	"wedge": {
		"shaft": Color(0.80, 0.82, 0.86), "grip": Color(0.08, 0.08, 0.08),
		"head": Color(0.62, 0.64, 0.68),  "accent": Color(0.45, 0.47, 0.50),
		"head_rough": 0.55, "head_metal": 0.7,
	},
	"putter": {
		"shaft": Color(0.30, 0.31, 0.34), "grip": Color(0.08, 0.08, 0.08),
		"head": Color(0.13, 0.14, 0.16),  "accent": Color(0.95, 0.95, 0.98),
		"head_rough": 0.6, "head_metal": 0.4,
	},
}

var _plane        : Node3D
var _pivot        : Node3D
var _current_type : String = ""
var _current_id   : String = ""
var _swinging     : bool = false
var _swing_tween  : Tween

func _ready() -> void:
	_ensure_built()
	visible = false
	# Re-skin the moment the player picks a different club, rather than waiting for the next
	# aim/shot to drive a rebuild (which left a noticeable lag after clicking).
	EquipmentManager.club_changed.connect(_on_club_changed)

func _on_club_changed(_id: String) -> void:
	_ensure_built()

# Build (or rebuild) the club geometry for the currently equipped club type. Idempotent: a
# no-op when the right type is already built. Callers invoke it at each entry point so the
# club is valid no matter when the manager first drives it (it's created at runtime, so
# _ready may not have fired yet) and so it re-skins when the player switches clubs.
func _ensure_built() -> void:
	var club : Dictionary = EquipmentManager.get_equipped_club()
	var t : String = club.get("type", "driver")
	if not CLUB_PALETTES.has(t):
		t = "driver"
	# Rebuild whenever the equipped club id changes, not just its type: two generated clubs of
	# the same type carry different palettes/patterns and must re-skin.
	var id : String = club.get("id", "")
	if id == _current_id and _pivot != null:
		return
	# Never swap geometry out from under a live swing -- a club change mid-swing waits for the
	# next show_at (which re-runs this) to take effect.
	if _swinging and _pivot != null:
		return
	if _plane != null:
		# Detach immediately (not just queue_free, which keeps it rendered until frame end) so
		# the old club can't show alongside the new one for a frame.
		remove_child(_plane)
		_plane.queue_free()
		_plane = null
		_pivot = null
	_build(t)
	_current_type = t
	_current_id = id

func _build(type: String) -> void:
	var palette : Dictionary = ItemVisuals.club_palette(EquipmentManager.get_equipped_club())
	var shaft_len : float = SHAFT_LEN[type]
	var head_anchor := _build_rig(shaft_len, palette)
	build_head(type, head_anchor, palette)

# Dispatch to the per-type head builder. Shared by the on-course club and the clubhouse / shop
# thumbnails (via ItemVisuals) so both render identical geometry from the same palette.
static func build_head(type: String, anchor: Node3D, palette: Dictionary) -> void:
	match type:
		"driver": _build_driver_head(anchor, palette)
		"iron":   _build_blade_head(anchor, palette, Vector3(0.26, 0.12, 0.035), deg_to_rad(22.0))
		"wedge":  _build_blade_head(anchor, palette, Vector3(0.25, 0.14, 0.040), deg_to_rad(52.0))
		"putter": _build_putter_head(anchor, palette)
		_:        _build_driver_head(anchor, palette)

# Shared swing rig: _plane (rolls the plane about the target line) -> _pivot (the "hands",
# the only node the swing tweens) -> shaft + grip, plus a level, counter-rolled head_anchor
# at the shaft tip. Returns the head_anchor for the per-type head builder to hang a head off.
func _build_rig(shaft_len: float, palette: Dictionary) -> Node3D:
	# Swing-plane node: rolls the plane about the target line so the backswing rises out to
	# the side instead of straight back. It sits at the origin (on the line), so the roll
	# pivots the hands out to the side -- a natural address -- and keeps the face square.
	_plane = Node3D.new()
	_plane.rotation.z = SWING_PLANE_TILT
	add_child(_plane)

	# Pivot at the hands; the shaft and head hang straight down the -Y axis from it, so a
	# rotation about the pivot's local X sweeps the club through the (now inclined) plane.
	_pivot = Node3D.new()
	_pivot.position = Vector3(0.0, HAND_H, 0.0)
	_pivot.rotation.x = ADDRESS_ANGLE
	_plane.add_child(_pivot)

	var shaft     := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius    = SHAFT_RADIUS
	shaft_cyl.bottom_radius = SHAFT_RADIUS
	shaft_cyl.height        = shaft_len
	shaft.mesh = shaft_cyl
	shaft.material_override = _mat(palette["shaft"], 0.3, 0.6)
	shaft.position = Vector3(0.0, -shaft_len * 0.5, 0.0)
	_pivot.add_child(shaft)

	var grip     := MeshInstance3D.new()
	var grip_cyl := CylinderMesh.new()
	grip_cyl.top_radius    = GRIP_RADIUS
	grip_cyl.bottom_radius = GRIP_RADIUS
	grip_cyl.height        = GRIP_LEN
	grip.mesh = grip_cyl
	grip.material_override = _mat(palette["grip"], 0.9, 0.0)
	grip.position = Vector3(0.0, -0.13, 0.0)
	_pivot.add_child(grip)

	# Head anchor: sits at the shaft tip and carries the counter-roll against the plane tilt,
	# so the head's frame is level (a natural lie) and its face normal stays on the target
	# line (roll about Z preserves it) -- impact stays square. Heads hang off this anchor by
	# their HEEL (heel at the anchor origin, top toward the shaft tip), the way a shaft joins
	# a real club, instead of being skewered through the middle.
	var head_anchor := Node3D.new()
	head_anchor.position  = Vector3(0.0, -shaft_len, 0.0)
	head_anchor.rotation.z = -SWING_PLANE_TILT
	_pivot.add_child(head_anchor)
	return head_anchor

# Driver: large rounded "wood" head -- a deep, bulbous body (scaled sphere, rounded crown,
# deep front-to-back) at a low loft.
static func _build_driver_head(anchor: Node3D, palette: Dictionary) -> void:
	# Deep, shallow, wide proportions of a real driver "wood". Centred on the anchor so the
	# crown rises above the shaft tip (the shaft enters the head, no gap) while the sole drops
	# only ~half the height below it -- which keeps the head clear of the terrain despite this
	# being the longest club. (Tuned against the swing-rig transform; see the sole-height calc.)
	var size := Vector3(0.38, 0.22, 0.42)   # heel-toe, height, front-to-back
	var loft : float = deg_to_rad(11.0)

	# Tilt the whole head back by the loft about the heel-toe (X) axis.
	var lofted := Node3D.new()
	lofted.rotation.x = loft
	anchor.add_child(lofted)

	var body     := MeshInstance3D.new()
	var body_sph := SphereMesh.new()
	body_sph.radius = 0.5
	body_sph.height = 1.0
	body.mesh   = body_sph
	body.scale  = size
	# Heel toward the anchor origin (-X toward the toe), centred vertically on the shaft tip,
	# sitting just behind the ball (small -Z so the leading edge ends up roughly on the line).
	body.position = Vector3(-0.12, 0.0, -0.05)
	body.material_override = _head_mat(palette["head"], palette["head_rough"], palette["head_metal"])
	lofted.add_child(body)

	# Two-tone finish: a contrasting accent stripe across the crown.
	if palette.get("two_tone", false):
		var band := MeshInstance3D.new()
		var bbox := BoxMesh.new()
		bbox.size = Vector3(size.x * 1.02, 0.03, size.z * 0.5)
		band.mesh = bbox
		band.position = body.position + Vector3(0.0, size.y * 0.36, 0.0)
		band.material_override = _head_mat(palette["accent"], 0.3, 0.5)
		lofted.add_child(band)

# Iron / wedge: a thin metal blade, lofted. The blade strikes with its +Z face; a short
# hosel cylinder bridges the shaft tip into the heel. Wedge passes a thinner/taller blade
# and a steeper loft so it reads as the more-angled, shorter club.
static func _build_blade_head(anchor: Node3D, palette: Dictionary, size: Vector3, loft: float) -> void:
	var lofted := Node3D.new()
	lofted.rotation.x = loft
	anchor.add_child(lofted)

	var blade     := MeshInstance3D.new()
	var blade_box := BoxMesh.new()
	blade_box.size = size
	blade.mesh = blade_box
	# Heel at the anchor origin (toe toward -X), top toward the shaft tip, face nudged +Z so
	# it sits just behind the ball -- matches the original head alignment.
	blade.position = Vector3(-size.x * 0.5, -size.y * 0.5, 0.06)
	blade.material_override = _head_mat(palette["head"], palette["head_rough"], palette["head_metal"])
	lofted.add_child(blade)

	# Two-tone finish: a contrasting sole stripe along the bottom of the blade.
	if palette.get("two_tone", false):
		var stripe := MeshInstance3D.new()
		var sbox := BoxMesh.new()
		sbox.size = Vector3(size.x, size.y * 0.25, size.z + 0.012)
		stripe.mesh = sbox
		stripe.position = blade.position + Vector3(0.0, -size.y * 0.36, 0.0)
		stripe.material_override = _head_mat(palette["accent"], 0.3, 0.4)
		lofted.add_child(stripe)

	# Short hosel: continues the shaft line a little way into the heel. Built outside the
	# lofted frame (on the anchor) so it stays in line with the shaft.
	var hosel     := MeshInstance3D.new()
	var hosel_cyl := CylinderMesh.new()
	hosel_cyl.top_radius    = SHAFT_RADIUS
	hosel_cyl.bottom_radius = SHAFT_RADIUS * 1.2
	hosel_cyl.height        = 0.08
	hosel.mesh = hosel_cyl
	hosel.position = Vector3(0.0, -0.035, 0.04)
	hosel.material_override = _head_mat(palette["head"], palette["head_rough"], palette["head_metal"])
	anchor.add_child(hosel)

# Putter: a larger, blockier mallet head -- wide heel-to-toe, low, and deep front-to-back,
# with a flat vertical face (no loft) and a bright sight-line strip along the top.
static func _build_putter_head(anchor: Node3D, palette: Dictionary) -> void:
	var size := Vector3(0.32, 0.075, 0.13)   # heel-toe, height, front-to-back

	var head     := MeshInstance3D.new()
	var head_box := BoxMesh.new()
	head_box.size = size
	head.mesh = head_box
	head.position = Vector3(-size.x * 0.5, -size.y * 0.5, 0.06)
	head.material_override = _head_mat(palette["head"], palette["head_rough"], palette["head_metal"])
	anchor.add_child(head)

	# Sight line: a thin bright strip running front-to-back (Z) along the centre of the crown
	# to aim the putt -- the instantly-readable putter cue.
	var sight     := MeshInstance3D.new()
	var sight_box := BoxMesh.new()
	sight_box.size = Vector3(0.012, 0.004, size.z * 0.8)
	sight.mesh = sight_box
	sight.position = head.position + Vector3(0.0, size.y * 0.5, 0.0)
	sight.material_override = _head_mat(palette["accent"], 0.4, 0.0)
	anchor.add_child(sight)

static func _mat(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness    = rough
	m.metallic     = metal
	return m

# Head material: like _mat but faintly self-lit (matched to its own colour) so the head reads
# clearly even in shadow against the dark turf.
static func _head_mat(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := _mat(col, rough, metal)
	m.emission_enabled = true
	m.emission = col.lightened(0.3)
	m.emission_energy_multiplier = 0.35
	return m

# Place the club at the ball and reset to address.
func show_at(ball_pos: Vector3) -> void:
	_ensure_built()
	# Kill any swing still in flight: a penalty can reposition the club mid-swing, and a live
	# tween would otherwise keep driving the pivot (and fire its hide_club callback) afterward.
	_kill_swing()
	# show_at can be driven from a physics-step signal (ball_resting). On a frame where
	# this node isn't yet reporting as in-tree, writing global_position throws -- guard it
	# so the club just keeps its prior transform for that frame instead of erroring.
	if is_inside_tree():
		global_position = ball_pos
	_swinging = false
	_pivot.rotation.x = ADDRESS_ANGLE
	visible = true

# Live aim while dragging: orient down the shot line and lift into a power-scaled backswing.
func set_aim(world_dir: Vector3, power: float) -> void:
	_ensure_built()
	if _swinging:
		return
	visible = true
	if world_dir.length() > 0.001:
		rotation.y = atan2(world_dir.x, world_dir.z)
	_pivot.rotation.x = lerpf(ADDRESS_ANGLE, BACKSWING_MAX, clampf(power, 0.0, 1.0))

# Drag was cancelled before release -- settle back to address.
func reset_address() -> void:
	_ensure_built()
	if _swinging:
		return
	_pivot.rotation.x = ADDRESS_ANGLE

# Release: downswing through impact into a follow-through, then hide.
func play_swing() -> void:
	_ensure_built()
	if not visible:
		return
	_swinging = true
	_kill_swing()
	_swing_tween = create_tween()
	_swing_tween.tween_property(_pivot, "rotation:x", ADDRESS_ANGLE, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_swing_tween.tween_property(_pivot, "rotation:x", FOLLOW_THROUGH, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_callback(hide_club)

func _kill_swing() -> void:
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	_swing_tween = null

func hide_club() -> void:
	_kill_swing()
	visible = false
	_swinging = false
