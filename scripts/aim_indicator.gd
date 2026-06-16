extends Control

const BAR_W  : float = 38.0
const BAR_H  : float = 210.0
const BAR_X  : float = 32.0

var _power   : float = 0.0
var _showing : bool  = false

func show_aim(power: float) -> void:
	_power   = power
	_showing = true
	queue_redraw()

func clear_aim() -> void:
	_showing = false
	queue_redraw()

func _draw() -> void:
	if not _showing:
		return

	var sz  := get_size()
	var by  : float = (sz.y - BAR_H) * 0.5

	# Background
	draw_rect(Rect2(BAR_X, by, BAR_W, BAR_H), Color(0.08, 0.08, 0.08, 0.75), true)

	# Power fill — bottom-up
	if _power > 0.01:
		var fill  : float = BAR_H * _power
		var t     : float = _power
		var col   := Color(lerpf(0.1, 1.0, t), lerpf(0.9, 0.1, t), 0.08)
		draw_rect(Rect2(BAR_X, by + BAR_H - fill, BAR_W, fill), col, true)

	# Border
	draw_rect(Rect2(BAR_X, by, BAR_W, BAR_H), Color(0.85, 0.85, 0.85, 0.55), false, 2.0)

	# Label
	var font  := ThemeDB.fallback_font
	var pct   : int = int(_power * 100.0)
	draw_string(font, Vector2(BAR_X + BAR_W * 0.5 - 14.0, by - 12.0),
		"%d%%" % pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(font, Vector2(BAR_X - 4.0, by + BAR_H + 24.0),
		"PULL", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 1.0, 1.0, 0.7))
