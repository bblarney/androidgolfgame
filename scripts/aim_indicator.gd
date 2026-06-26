extends Control

const UI = preload("res://scripts/ui_palette.gd")

const MIN_LEN  : float = 56.0
const MAX_LEN  : float = 250.0
const HEAD_LEN : float = 30.0   # long head → acute, sharp point
const HEAD_HW  : float = 13.0   # barb half-width (head wider than shaft)
const BASE_HW  : float = 5.5    # shaft half-width at the origin
const SHAFT_HW : float = 3.5    # shaft half-width at the neck (subtle taper → waist)

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
	var perp   : Vector2 = Vector2(-_dir.y, _dir.x)
	var neck   : Vector2 = tip - _dir * HEAD_LEN
	var col    : Color   = _power_color(_power)

	# One filled "dart": a shaft that tapers to a slim waist then flares into a sharp swept
	# head. A single polygon keeps the silhouette crisp with no overlapping-primitive seams.
	var pts := PackedVector2Array([
		_origin + perp * BASE_HW,   # base, left
		neck    + perp * SHAFT_HW,  # waist, left
		neck    + perp * HEAD_HW,   # barb, left
		tip,                        # point
		neck    - perp * HEAD_HW,   # barb, right
		neck    - perp * SHAFT_HW,  # waist, right
		_origin - perp * BASE_HW,   # base, right
	])
	draw_colored_polygon(pts, col)
	# Antialiased outline in the same colour smooths the edges (no dark border underlay).
	draw_polyline(pts + PackedVector2Array([pts[0]]), col, 1.5, true)

	# Power readout: a plain floating number just past the tip, no panel.
	var txt : String = "%d%%" % int(round(_power * 100.0))
	draw_string(UI.FONT, tip + _dir * 18.0, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.INK)

# Power-driven colour: green (weak) → yellow (mid) → red (full pull).
func _power_color(p: float) -> Color:
	var green  := Color(0.30, 0.85, 0.30)
	var yellow := Color(0.98, 0.83, 0.15)
	var red    := Color(0.95, 0.25, 0.20)
	return green.lerp(yellow, p * 2.0) if p < 0.5 else yellow.lerp(red, (p - 0.5) * 2.0)
