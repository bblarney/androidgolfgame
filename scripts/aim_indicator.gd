extends Control

const MIN_LEN  : float = 50.0
const MAX_LEN  : float = 240.0
const HEAD_LEN : float = 26.0
const HEAD_W   : float = 16.0

var _origin  : Vector2 = Vector2.ZERO
var _dir     : Vector2 = Vector2.RIGHT
var _power   : float   = 0.0
var _showing : bool    = false

func show_aim(origin: Vector2, dir: Vector2, power: float) -> void:
	_origin  = origin
	_dir     = dir
	_power   = power
	_showing = true
	queue_redraw()

func clear_aim() -> void:
	_showing = false
	queue_redraw()

func _draw() -> void:
	if not _showing:
		return

	var length : float = lerpf(MIN_LEN, MAX_LEN, _power)
	var tip    : Vector2 = _origin + _dir * length
	var col    : Color = Color(lerpf(0.1, 1.0, _power), lerpf(0.9, 0.1, _power), 0.08, 0.9)

	draw_line(_origin, tip, col, 8.0, true)

	var perp : Vector2 = Vector2(-_dir.y, _dir.x)
	var base : Vector2 = tip - _dir * HEAD_LEN
	var p1   : Vector2 = base + perp * HEAD_W
	var p2   : Vector2 = base - perp * HEAD_W
	draw_polygon(PackedVector2Array([tip, p1, p2]), PackedColorArray([col, col, col]))

	var font : Font = ThemeDB.fallback_font
	var pct  : int  = int(_power * 100.0)
	draw_string(font, tip + _dir * 18.0, "%d%%" % pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
