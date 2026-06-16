extends Node2D

const DOT_COUNT: int = 14
const DOT_RADIUS_MIN: float = 4.0
const DOT_RADIUS_MAX: float = 8.0

var _ball_pos: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.ZERO
var _power: float = 0.0

func show_aim(ball_pos: Vector2, direction: Vector2, power: float) -> void:
	_ball_pos = ball_pos
	_direction = direction
	_power = power
	visible = true
	queue_redraw()

func clear_aim() -> void:
	visible = false

func _draw() -> void:
	if _power < 0.05:
		return

	var max_length: float = _power * 380.0
	var step: float = max_length / float(DOT_COUNT)

	for i in range(DOT_COUNT):
		var t: float = float(i) / float(DOT_COUNT)
		var pos: Vector2 = _ball_pos + _direction * (float(i) * step + step * 0.5)
		var alpha: float = 1.0 - t * 0.6
		var radius: float = lerp(DOT_RADIUS_MIN, DOT_RADIUS_MAX, 1.0 - t)
		draw_circle(pos, radius, Color(1.0, 0.92, 0.1, alpha))

	var arc_radius: float = 30.0 + _power * 20.0
	draw_arc(_ball_pos, arc_radius, 0.0, TAU, 32, Color(1.0, 0.5, 0.1, 0.55), 3.0)
