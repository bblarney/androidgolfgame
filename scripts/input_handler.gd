extends Node

signal shot_taken(direction: Vector3, power: float)
signal aim_updated(screen_origin: Vector2, screen_dir: Vector2, power: float)
# World-space aim for the 3D club visual: the flat direction the shot will fire and the
# charge level. Separate from aim_updated (which is screen-space, for the HUD arrow).
signal aim_changed(world_dir: Vector3, power: float)
signal aim_cancelled

const MAX_DRAG         : float = 220.0
const MIN_DRAG         : float = 15.0
const BALL_TOUCH_PX    : float = 80.0
const CAM_ROTATE_SCALE : float = 0.008

var can_shoot  : bool = false

var _ball   : RigidBody3D
var _camera : Camera3D

var _mode          : int   = 0   # 0=idle, 1=rotate, 2=aim
var _drag_start    : Vector2 = Vector2.ZERO
var _prev_touch    : Vector2 = Vector2.ZERO
var _is_dragging   : bool = false

func setup(ball: RigidBody3D, camera: Camera3D) -> void:
	_ball   = ball
	_camera = camera

func _input(event: InputEvent) -> void:
	if _ball == null or _camera == null:
		return

	var is_press_event   : bool = event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
	var is_motion_event  : bool = event is InputEventScreenDrag or event is InputEventMouseMotion

	if is_press_event:
		var pressed     : bool    = event.pressed
		var screen_pos  : Vector2 = event.position
		if pressed:
			_drag_start  = screen_pos
			_prev_touch  = screen_pos
			_is_dragging = true
			_mode = 2 if (can_shoot and _near_ball(screen_pos)) else 1
		else:
			if _is_dragging:
				if _mode == 2:
					_release(screen_pos)
				else:
					aim_cancelled.emit()
			_is_dragging = false
			_mode = 0

	elif is_motion_event and _is_dragging:
		var screen_pos : Vector2 = event.position
		match _mode:
			1:
				var dx : float = screen_pos.x - _prev_touch.x
				_camera.rotate_aim(dx * CAM_ROTATE_SCALE)
			2:
				_update_aim(screen_pos)
		_prev_touch = screen_pos

func _update_aim(screen_pos: Vector2) -> void:
	var drag : Vector2 = screen_pos - _drag_start
	if drag.length() < MIN_DRAG:
		aim_cancelled.emit()
		return

	var power       : float   = clampf(drag.length(), 0.0, MAX_DRAG) / MAX_DRAG
	var ball_screen : Vector2 = _camera.unproject_position(_ball.global_position)
	var screen_dir  : Vector2 = (-drag).normalized()
	aim_updated.emit(ball_screen, screen_dir, power)
	aim_changed.emit(_drag_to_world_direction(drag), power)

func _release(screen_pos: Vector2) -> void:
	var drag : Vector2 = screen_pos - _drag_start
	if drag.length() < MIN_DRAG:
		aim_cancelled.emit()
		return

	var power      : float     = clampf(drag.length(), 0.0, MAX_DRAG) / MAX_DRAG
	var flat_dir   : Vector3   = _drag_to_world_direction(drag)
	var club       : Dictionary = EquipmentManager.get_equipped_club()
	var launch_rad : float     = deg_to_rad(club.get("launch_angle", 30.0))
	var spread_deg : float     = club.get("spread", 8.0)
	var spread_rad : float     = deg_to_rad(randf_range(-spread_deg * 0.5, spread_deg * 0.5))

	flat_dir = flat_dir.rotated(Vector3.UP, spread_rad)
	var direction := Vector3(
		flat_dir.x * cos(launch_rad),
		sin(launch_rad),
		flat_dir.z * cos(launch_rad)
	).normalized()

	can_shoot = false
	shot_taken.emit(direction, power)

func _drag_to_world_direction(drag: Vector2) -> Vector3:
	# Pull the ball back like a slingshot: the shot fires opposite the drag,
	# mapped through the camera's flattened right/forward so it matches what
	# the player sees on screen regardless of camera angle.
	var basis     : Basis   = _camera.global_transform.basis
	var cam_right : Vector3 = Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	var cam_fwd   : Vector3 = Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	var world_dir : Vector3 = cam_right * -drag.x + cam_fwd * drag.y
	if world_dir.length() < 0.001:
		return cam_fwd
	return world_dir.normalized()

func _near_ball(screen_pos: Vector2) -> bool:
	var ball_screen : Vector2 = _camera.unproject_position(_ball.global_position)
	return screen_pos.distance_to(ball_screen) < BALL_TOUCH_PX
