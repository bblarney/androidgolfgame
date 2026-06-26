extends Control

const UI = preload("res://scripts/ui_palette.gd")

const MIN_LEN  : float = 60.0
const MAX_LEN  : float = 250.0
const HEAD_LEN : float = 24.0
const HEAD_W   : float = 15.0
const LINE_W   : float = 7.0

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
	# Power-driven colour: calm green at low power through to a hot red at full pull.
	var col : Color = Color(0.45, 0.90, 0.35).lerp(Color(1.0, 0.30, 0.20), _power)

	# A soft dark underlay first so the arrow stays legible over bright fairway or sky.
	draw_line(_origin, tip, UI.SHADOW, LINE_W + 4.0, true)
	draw_line(_origin, tip, col, LINE_W, true)

	var perp : Vector2 = Vector2(-_dir.y, _dir.x)
	var base : Vector2 = tip - _dir * HEAD_LEN
	var p1   : Vector2 = base + perp * HEAD_W
	var p2   : Vector2 = base - perp * HEAD_W
	draw_polygon(PackedVector2Array([tip, p1, p2]), PackedColorArray([col, col, col]))

	# A nub at the pull-back point so the origin of the shot reads clearly.
	draw_circle(_origin, 5.0, col)

	# Power readout in a small translucent pill near the tip; flips to the other side of the
	# tip when aiming leftward so it never runs off-screen.
	var txt : String   = "%d%%" % int(round(_power * 100.0))
	var fs  : int      = 22
	var dim : Vector2  = UI.FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pad : Vector2  = Vector2(10.0, 6.0)
	var anchor : Vector2 = tip + _dir * 14.0
	var box : Rect2 = Rect2(anchor - Vector2(0.0, dim.y * 0.5 + pad.y), dim + pad * 2.0)
	if _dir.x < 0.0:
		box.position.x = anchor.x - box.size.x
	var pill := StyleBoxFlat.new()
	pill.bg_color = UI.PANEL
	pill.set_corner_radius_all(6)
	draw_style_box(pill, box)
	draw_string(UI.FONT, box.position + Vector2(pad.x, pad.y + fs * 0.82), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.INK)
