extends Node

signal shot_taken(direction: Vector3, power: float)
signal aim_updated(power: float)
signal aim_cancelled

const MAX_DRAG         : float = 220.0
const MIN_DRAG         : float = 15.0
const BALL_TOUCH_PX    : float = 80.0
const CAM_ROTATE_SCALE : float = 0.008

var can_shoot  : bool = false

var _ball   : RigidBody3D
var _camera : Camera3D

var _mode          : int   = 0   # 0=idle, 1=rotate, 2=power
var _drag_start    : Vector2 = Vector2.ZERO
var _prev_touch    : Vector2 = Vector2.ZERO
var _is_dragging   : bool = false

func setup(ball: RigidBody3D, camera: Camera3D) -> void:
	_ball   = ball
	_camera = camera

func _input(event: InputEvent) -> void:
	if _ball == null or _camera == null:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_drag_start  = event.position
			_prev_touch  = event.position
			_is_dragging = true
			_mode = 2 if (can_shoot and _near_ball(event.position)) else 1
		else:
			if _is_dragging:
				if _mode == 2:
					_release(event.position)
				else:
					aim_cancelled.emit()
			_is_dragging = false
			_mode = 0

	elif event is InputEventScreenDrag and _is_dragging:
		match _mode:
			1:
				var dx : float = event.position.x - _prev_touch.x
				_camera.rotate_aim(dx * CAM_ROTATE_SCALE)
			2:
				_update_power(event.position)
		_prev_touch = event.position

func _update_power(screen_pos: Vector2) -> void:
	var drag : float = _drag_start.y - screen_pos.y   # drag UP = more power
	drag = clampf(drag, 0.0, MAX_DRAG)
	if drag > MIN_DRAG:
		aim_updated.emit(drag / MAX_DRAG)
	else:
		aim_cancelled.emit()

func _release(screen_pos: Vector2) -> void:
	var drag : float = _drag_start.y - screen_pos.y
	if drag < MIN_DRAG:
		aim_cancelled.emit()
		return

	var power       : float   = clampf(drag, 0.0, MAX_DRAG) / MAX_DRAG
	var flat_dir    : Vector3 = _camera.get_aim_direction()
	var launch_rad  : float   = deg_to_rad(44.0)
	var spread_deg  : float   = EquipmentManager.get_equipped_club().get("spread", 8.0)
	var spread_rad  : float   = deg_to_rad(randf_range(-spread_deg * 0.5, spread_deg * 0.5))

	flat_dir = flat_dir.rotated(Vector3.UP, spread_rad)
	var direction := Vector3(
		flat_dir.x * cos(launch_rad),
		sin(launch_rad),
		flat_dir.z * cos(launch_rad)
	).normalized()

	can_shoot = false
	shot_taken.emit(direction, power)

func _near_ball(screen_pos: Vector2) -> bool:
	var ball_screen : Vector2 = _camera.unproject_position(_ball.global_position)
	return screen_pos.distance_to(ball_screen) < BALL_TOUCH_PX
