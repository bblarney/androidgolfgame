extends Node2D

const DOT_COUNT := 14
const DOT_SPACING := 22.0
const DOT_RADIUS_MIN := 4.0
const DOT_RADIUS_MAX := 8.0

var _ball_pos := Vector2.ZERO
var _direction := Vector2.ZERO
var _power := 0.0
var _visible := false

func show_aim(ball_pos: Vector2, direction: Vector2, power: float) -> void:
	_ball_pos = ball_pos
	_direction = direction
	_power = power
	_visible = true
	queue_redraw()

func hide() -> void:
	_visible = false
	queue_redraw()

func _draw() -> void:
	if not _visible or _power < 0.05:
		return

	var max_length := _power * 380.0
	var step := max_length / DOT_COUNT

	for i in range(DOT_COUNT):
		var t := float(i) / DOT_COUNT
		var pos := _ball_pos + _direction * (i * step + step * 0.5)
		var alpha := 1.0 - t * 0.6
		var radius := lerp(DOT_RADIUS_MIN, DOT_RADIUS_MAX, 1.0 - t)
		draw_circle(pos, radius, Color(1.0, 0.92, 0.1, alpha))

	# Power arc behind ball (pull indicator)
	var arc_radius := 30.0 + _power * 20.0
	var arc_color := Color(1.0, 0.5, 0.1, 0.55)
	draw_arc(_ball_pos, arc_radius, 0.0, TAU, 32, arc_color, 3.0)
