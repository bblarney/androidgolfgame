extends Node

signal shot_taken(direction: Vector2, power: float)
signal aim_updated(ball_pos: Vector2, direction: Vector2, power: float)
signal aim_cancelled

const MAX_DRAG := 210.0
const MIN_DRAG := 14.0
const BALL_TOUCH_RADIUS := 60.0

var can_shoot := false
var _is_dragging := false
var _drag_start := Vector2.ZERO
var _ball: RigidBody2D
var _camera: Camera2D

func setup(ball: RigidBody2D, camera: Camera2D) -> void:
	_ball = ball
	_camera = camera

func _input(event: InputEvent) -> void:
	if not can_shoot or _ball == null:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_near_ball(event.position):
				_drag_start = event.position
				_is_dragging = true
		else:
			if _is_dragging:
				_release(event.position)
				_is_dragging = false
				aim_cancelled.emit()

	elif event is InputEventScreenDrag and _is_dragging:
		_update_drag(event.position)

func _update_drag(screen_pos: Vector2) -> void:
	var drag_vec := _drag_start - screen_pos
	var raw_len := drag_vec.length()
	if raw_len < MIN_DRAG:
		return
	var power := clamp(raw_len, 0.0, MAX_DRAG) / MAX_DRAG
	var direction := drag_vec.normalized()
	aim_updated.emit(_ball.global_position, direction, power)

func _release(screen_pos: Vector2) -> void:
	var drag_vec := _drag_start - screen_pos
	if drag_vec.length() < MIN_DRAG:
		aim_cancelled.emit()
		return

	var power := clamp(drag_vec.length(), 0.0, MAX_DRAG) / MAX_DRAG
	var direction := drag_vec.normalized()

	var spread_deg: float = EquipmentManager.get_equipped_club().get("spread", 8.0)
	direction = direction.rotated(deg_to_rad(randf_range(-spread_deg * 0.5, spread_deg * 0.5)))

	can_shoot = false
	shot_taken.emit(direction, power)

func _is_near_ball(screen_pos: Vector2) -> bool:
	var world_pos := _screen_to_world(screen_pos)
	return world_pos.distance_to(_ball.global_position) < BALL_TOUCH_RADIUS

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos
