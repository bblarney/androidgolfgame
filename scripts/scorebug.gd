extends Control
# TV-style golf scorebug: a HOLE / PAR / SCORE grid with one column per hole. The stroke
# number in the SCORE row is wrapped in a shape encoding score-vs-par, the way a broadcast
# overlay or printed scorecard does it:
#   >= +2 double bogey+  double square (blue)
#    = +1 bogey          single square (blue)
#    =  0 par            plain number  (neutral)
#    = -1 birdie         single circle (red)
#   <= -2 eagle+         double circle (red)
# Unreached holes show their par with a blank SCORE cell. Drawn entirely with _draw() to
# match the project's asset-free UI convention (see aim_indicator.gd).

const UI = preload("res://scripts/ui_palette.gd")

const BLANK := -1

# Layout (tuned so an 18-hole back nine -- 9 cols + IN + TOT -- fits the ScoreCard panel).
const LABEL_W : float = 64.0    # left gutter holding the row labels
const CELL_W  : float = 56.0    # per-column width
const ROW_H   : float = 42.0    # height of each of the three rows
const GAP     : float = 0.0     # front/back blocks abut so the 18-hole grid reads continuous

const NUM_FS    : int = 22
const LABEL_FS  : int = 15

# Monochrome: every number and shape is drawn in plain white; the score-vs-par meaning is
# carried entirely by the shape (square/circle, single/double), not by colour.
const INK       : Color = Color(1.0, 1.0, 1.0)
const LABEL_COL : Color = Color(0.70, 0.74, 0.62)
const LINE_COL  : Color = Color(1.0, 1.0, 1.0, 0.14)
const HEADER_COL: Color = Color(1.0, 1.0, 1.0, 0.06)
const HILITE_COL: Color = Color(1.0, 0.85, 0.25, 0.16)

var _numbers : Array = []
var _pars    : Array = []
var _scores  : Array = []   # BLANK for unreached holes
var _current : int   = 0    # hole number to highlight (0 = none)

func set_round(numbers: Array, pars: Array, scores: Array, current: int) -> void:
	_numbers = numbers
	_pars    = pars
	_scores  = scores
	_current = current
	queue_redraw()

func _draw() -> void:
	if _numbers.is_empty():
		return
	if _numbers.size() <= 9:
		var totals : Array = [_make_total("OUT", 0, _numbers.size())]
		var y0 : float = (size.y - ROW_H * 3.0) * 0.5
		_draw_block(0, _numbers.size(), y0, totals)
	else:
		# Front nine over back nine, stacked like a real scorecard. Each block carries its own
		# nine's subtotal (OUT/IN) plus a running TOT (round total through that hole) so both
		# blocks are the same 11 columns wide and line up edge-to-edge.
		var front : Array = [_make_total("OUT", 0, 9), _make_total("TOT", 0, 9)]
		var back  : Array = [_make_total("IN", 9, 18), _make_total("TOT", 0, 18)]
		var total_h : float = ROW_H * 6.0 + GAP
		var y0 : float = (size.y - total_h) * 0.5
		_draw_block(0, 9, y0, front)
		_draw_block(9, 18, y0 + ROW_H * 3.0 + GAP, back)

# Summed par (always known) and strokes (played holes only) for a totals column.
func _make_total(label: String, i_start: int, i_end: int) -> Dictionary:
	var par_sum   : int = 0
	var score_sum : int = 0
	var played    : int = 0
	for i in range(i_start, min(i_end, _pars.size())):
		par_sum += _pars[i]
		if _scores[i] != BLANK:
			score_sum += _scores[i]
			played += 1
	return {"label": label, "par": par_sum, "score": score_sum, "played": played}

func _draw_block(i_start: int, i_end: int, y_top: float, totals: Array) -> void:
	var n      : int   = i_end - i_start
	var cols   : int   = n + totals.size()
	var grid_w : float = LABEL_W + cols * CELL_W
	var x0     : float = (size.x - grid_w) * 0.5

	var y_hole  : float = y_top + ROW_H * 0.5
	var y_par   : float = y_top + ROW_H * 1.5
	var y_score : float = y_top + ROW_H * 2.5

	# Header band behind the HOLE row + horizontal row separators.
	draw_rect(Rect2(x0, y_top, grid_w, ROW_H), HEADER_COL, true)
	for r in range(4):
		var ly : float = y_top + r * ROW_H
		draw_line(Vector2(x0, ly), Vector2(x0 + grid_w, ly), LINE_COL, 1.0)
	# Vertical rule after the label gutter and before the totals block.
	draw_line(Vector2(x0 + LABEL_W, y_top), Vector2(x0 + LABEL_W, y_top + ROW_H * 3.0), LINE_COL, 1.0)
	if totals.size() > 0:
		var tx : float = x0 + LABEL_W + n * CELL_W
		draw_line(Vector2(tx, y_top), Vector2(tx, y_top + ROW_H * 3.0), LINE_COL, 1.0)

	# Row labels in the gutter.
	var lx : float = x0 + LABEL_W * 0.5
	_text(Vector2(lx, y_hole), "HOLE", LABEL_FS, LABEL_COL)
	_text(Vector2(lx, y_par), "PAR", LABEL_FS, LABEL_COL)
	_text(Vector2(lx, y_score), "SCORE", LABEL_FS, LABEL_COL)

	# Hole columns.
	for k in range(n):
		var i  : int   = i_start + k
		var cx : float = x0 + LABEL_W + k * CELL_W + CELL_W * 0.5
		if _numbers[i] == _current:
			draw_rect(Rect2(cx - CELL_W * 0.5, y_top, CELL_W, ROW_H * 3.0), HILITE_COL, true)
		_text(Vector2(cx, y_hole), str(_numbers[i]), NUM_FS, INK)
		_text(Vector2(cx, y_par), str(_pars[i]), NUM_FS, INK)
		if _scores[i] != BLANK:
			var diff : int = _scores[i] - _pars[i]
			_text(Vector2(cx, y_score), str(_scores[i]), NUM_FS, INK)
			_draw_score_shape(Vector2(cx, y_score), diff, INK)

	# Totals columns.
	for t in range(totals.size()):
		var info : Dictionary = totals[t]
		var cx   : float = x0 + LABEL_W + (n + t) * CELL_W + CELL_W * 0.5
		_text(Vector2(cx, y_hole), info["label"], LABEL_FS, LABEL_COL)
		_text(Vector2(cx, y_par), str(info["par"]), NUM_FS, INK)
		if info["played"] > 0:
			_text(Vector2(cx, y_score), str(info["score"]), NUM_FS, INK)

# Stroked (unfilled) shape centred on the stroke number.
func _draw_score_shape(center: Vector2, diff: int, col: Color) -> void:
	var width : float = 2.0
	var outer : float = 16.0
	var inner : float = 11.0
	if diff >= 2:
		_square(center, outer, col, width)
		_square(center, inner, col, width)
	elif diff == 1:
		_square(center, outer, col, width)
	elif diff == -1:
		draw_arc(center, outer, 0.0, TAU, 48, col, width, true)
	elif diff <= -2:
		draw_arc(center, outer, 0.0, TAU, 48, col, width, true)
		draw_arc(center, inner, 0.0, TAU, 48, col, width, true)
	# diff == 0 (par): plain number, no shape.

func _square(center: Vector2, half: float, col: Color, width: float) -> void:
	draw_rect(Rect2(center - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), col, false, width)

# draw_string positions by the text baseline, so centre it manually on the cell point.
func _text(center: Vector2, txt: String, fs: int, col: Color) -> void:
	var font : Font = UI.FONT
	var dim  : Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos  : Vector2 = Vector2(center.x - dim.x * 0.5, center.y + fs * 0.35)
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
