extends Control
# A little HUD arrow that points the way the wind is blowing, sitting next to the WIND speed in the
# top strip. Replaces the old WITH / INTO / L>R / R>L text (Oswald has no arrow glyphs, so we draw
# our own). Heading is relative to the player view: the overview camera stands behind the tee
# looking down +Z, so on screen up = downfield (+Z, away from the tee) and -- because that view is
# turned 180 deg about Y -- world +X falls on the LEFT. The arrow points the way the ball is
# actually blown, and tints green -> gold -> coral with rising speed so a glance reads both
# direction and how hard it's blowing.
const UI = preload("res://scripts/ui_palette.gd")

# Screen-space angle the arrow points (radians, 0 = right, measured CW because screen Y is down).
# NAN means "calm" -- nothing is drawn.
var _angle : float = NAN
var _strength : float = 0.0   # 0..1, drives the colour ramp

# A wind speed at/above this (mph) reads as full-strength coral on the ramp.
const FULL_STRENGTH_MPH : float = 28.0

# Set from hole_manager with the hole's world wind vector. Empty/zero wind hides the arrow.
func set_wind(w: Vector3) -> void:
	var mph : float = Vector2(w.x, w.z).length()
	if mph <= 0.0:
		_angle = NAN
	else:
		# Screen-up = +Z (downfield) and screen-right = -X (the view is turned 180 deg about Y),
		# so the screen-space drift is (-w.x, -w.z) in (right, down) coords.
		_angle = atan2(-w.z, -w.x)
		_strength = clampf(mph / FULL_STRENGTH_MPH, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	if is_nan(_angle):
		return
	var c : Vector2 = size * 0.5
	var s : float = minf(size.x, size.y) * 0.46   # arrow half-length
	var col : Color = UI.METER.lerp(UI.ACCENT, _strength) if _strength < 0.5 \
		else UI.ACCENT.lerp(UI.DANGER, (_strength - 0.5) * 2.0)
	# Classic arrow outline, modelled pointing right then rotated into the wind heading.
	var pts : PackedVector2Array = [
		Vector2(s, 0.0),
		Vector2(0.15 * s, 0.55 * s),
		Vector2(0.15 * s, 0.24 * s),
		Vector2(-s, 0.24 * s),
		Vector2(-s, -0.24 * s),
		Vector2(0.15 * s, -0.24 * s),
		Vector2(0.15 * s, -0.55 * s),
	]
	var rot := Transform2D(_angle, c)
	var world : PackedVector2Array = rot * pts
	draw_colored_polygon(world, col)
