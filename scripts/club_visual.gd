extends Node3D
# Placeholder golf club that takes the shot. Dragging back swings it into a backswing
# scaled by power; releasing plays a downswing through impact into a follow-through.
#
# Deliberately modular: the geometry lives entirely in _build_placeholder(), and the
# swing logic only ever touches `_pivot.rotation.x` and the root's `rotation.y`. To ship
# real per-club models later, swap _build_placeholder() for a loaded mesh whose grip sits
# at the pivot and whose head hangs down the -Y axis -- nothing else needs to change.

const HAND_H         : float = 1.2                   # pivot ("hands") height above the ball
const SHAFT_LEN      : float = 1.35                  # grip-to-head length
const ADDRESS_ANGLE  : float = deg_to_rad(-12.0)     # slight forward lean at address
const BACKSWING_MAX  : float = deg_to_rad(125.0)     # top of backswing at full power
const FOLLOW_THROUGH : float = deg_to_rad(-120.0)    # finish, club up in front

const COL_SHAFT : Color = Color(0.90, 0.92, 0.96)
const COL_HEAD  : Color = Color(0.22, 0.24, 0.30)
const COL_GRIP  : Color = Color(0.08, 0.08, 0.08)

var _pivot   : Node3D
var _swinging : bool = false

func _ready() -> void:
	_build_placeholder()
	visible = false

func _build_placeholder() -> void:
	# Idempotent: callers build lazily so the club is valid no matter when the manager
	# first drives it (it's created at runtime, so _ready may not have fired yet).
	if _pivot != null:
		return
	# Pivot at the hands; the shaft and head hang straight down the -Y axis from it, so a
	# rotation about the pivot's local X sweeps the club through the swing plane.
	_pivot = Node3D.new()
	_pivot.position = Vector3(0.0, HAND_H, 0.0)
	_pivot.rotation.x = ADDRESS_ANGLE
	add_child(_pivot)

	var shaft     := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius    = 0.03
	shaft_cyl.bottom_radius = 0.03
	shaft_cyl.height        = SHAFT_LEN
	shaft.mesh = shaft_cyl
	shaft.material_override = _mat(COL_SHAFT, 0.3, 0.6)
	shaft.position = Vector3(0.0, -SHAFT_LEN * 0.5, 0.0)
	_pivot.add_child(shaft)

	var grip     := MeshInstance3D.new()
	var grip_cyl := CylinderMesh.new()
	grip_cyl.top_radius    = 0.045
	grip_cyl.bottom_radius = 0.045
	grip_cyl.height        = 0.26
	grip.mesh = grip_cyl
	grip.material_override = _mat(COL_GRIP, 0.9, 0.0)
	grip.position = Vector3(0.0, -0.13, 0.0)
	_pivot.add_child(grip)

	var head     := MeshInstance3D.new()
	var head_box := BoxMesh.new()
	head_box.size = Vector3(0.2, 0.13, 0.34)
	head.mesh = head_box
	# Faintly self-lit so the head reads clearly even in shadow against the dark turf.
	var head_mat := _mat(COL_HEAD, 0.3, 0.5)
	head_mat.emission_enabled = true
	head_mat.emission = Color(0.45, 0.50, 0.62)
	head_mat.emission_energy_multiplier = 0.5
	head.material_override = head_mat
	# At the bottom of the shaft, nudged forward (+Z) so it sits behind the ball ready to strike.
	head.position = Vector3(0.0, -SHAFT_LEN, 0.1)
	_pivot.add_child(head)

func _mat(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness    = rough
	m.metallic     = metal
	return m

# Place the club at the ball and reset to address.
func show_at(ball_pos: Vector3) -> void:
	_build_placeholder()
	global_position = ball_pos
	_swinging = false
	_pivot.rotation.x = ADDRESS_ANGLE
	visible = true

# Live aim while dragging: orient down the shot line and lift into a power-scaled backswing.
func set_aim(world_dir: Vector3, power: float) -> void:
	_build_placeholder()
	if _swinging:
		return
	visible = true
	if world_dir.length() > 0.001:
		rotation.y = atan2(world_dir.x, world_dir.z)
	_pivot.rotation.x = lerpf(ADDRESS_ANGLE, BACKSWING_MAX, clampf(power, 0.0, 1.0))

# Drag was cancelled before release -- settle back to address.
func reset_address() -> void:
	_build_placeholder()
	if _swinging:
		return
	_pivot.rotation.x = ADDRESS_ANGLE

# Release: downswing through impact into a follow-through, then hide.
func play_swing() -> void:
	_build_placeholder()
	if not visible:
		return
	_swinging = true
	var t : Tween = create_tween()
	t.tween_property(_pivot, "rotation:x", ADDRESS_ANGLE, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(_pivot, "rotation:x", FOLLOW_THROUGH, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(hide_club)

func hide_club() -> void:
	visible = false
	_swinging = false
