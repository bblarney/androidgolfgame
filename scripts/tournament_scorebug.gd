extends Control
# Live tournament leaderboard tucked in a bottom corner during play: the current top 5 with
# their score-vs-par, the player's own row highlighted (and appended if outside the top 5 so
# you can always see where you stand). Drawn entirely with _draw() to match the project's
# asset-free UI convention (see scorebug.gd / aim_indicator.gd).

const UI = preload("res://scripts/ui_palette.gd")

const ROWS      : int   = 5
const ROW_H     : float = 30.0
const HEAD_H    : float = 28.0
const PAD       : float = 10.0
const RANK_W    : float = 36.0
const SCORE_W   : float = 52.0
const NAME_FS   : int   = 18
const HEAD_FS   : int   = 15

# Reuse the shared palette so this overlay tracks any future tweak to the HUD's colour identity
# (see ui_palette.gd). USER_COL is the broadcast gold at low alpha for the player's row tint.
const INK        : Color = UI.INK
const SUBINK     : Color = UI.SUBINK
static var USER_COL : Color = Color(UI.ACCENT, 0.22)
const DANGER_INK : Color = UI.DANGER

var _rows : Array = []   # cached standings entries to render

func refresh() -> void:
	var standings : Array = TournamentManager.get_standings()
	_rows = standings.slice(0, ROWS)
	# Always show the player: if they're outside the top 5, append their row beneath.
	var user_in_top : bool = false
	for r in _rows:
		if r["is_user"]:
			user_in_top = true
			break
	if not user_in_top:
		for r in standings:
			if r["is_user"]:
				_rows.append(r)
				break
	queue_redraw()

func _draw() -> void:
	if _rows.is_empty():
		return
	var w : float = size.x
	var h : float = HEAD_H + _rows.size() * ROW_H + PAD * 2.0
	draw_style_box(UI.card_style(0.0, 6), Rect2(0.0, 0.0, w, h))

	var font : Font = UI.FONT
	_text(font, Vector2(PAD, PAD + HEAD_FS), "%s LEADERBOARD" % TournamentManager.day_name().to_upper(), HEAD_FS, SUBINK)

	var y : float = PAD + HEAD_H
	for r in _rows:
		var row_top : float = y
		if r["is_user"]:
			draw_rect(Rect2(0.0, row_top, w, ROW_H), USER_COL, true)
		var ink : Color = DANGER_INK if r.get("in_danger", false) else INK
		var baseline : float = row_top + ROW_H * 0.5 + NAME_FS * 0.35
		_text(font, Vector2(PAD, baseline), str(r["rank"]), NAME_FS, ink)
		_text(font, Vector2(PAD + RANK_W, baseline), str(r["name"]), NAME_FS, ink)
		var score_txt : String = TournamentManager.format_score(int(r["score"]))
		var sw : Vector2 = font.get_string_size(score_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FS)
		_text(font, Vector2(w - PAD - sw.x, baseline), score_txt, NAME_FS, ink)
		y += ROW_H

# draw_string positions by the text baseline; callers pass the baseline point directly.
func _text(font: Font, pos: Vector2, txt: String, fs: int, col: Color) -> void:
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
