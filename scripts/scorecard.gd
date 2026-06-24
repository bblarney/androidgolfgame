extends Control

signal next_pressed

@onready var lbl_hole    : Label   = $Panel/VBox/HoleLabel
@onready var lbl_strokes : Label   = $Panel/VBox/StrokesLabel
@onready var lbl_par     : Label   = $Panel/VBox/ParLabel
@onready var lbl_result  : Label   = $Panel/VBox/ResultLabel
@onready var lbl_points  : Label   = $Panel/VBox/PointsLabel
@onready var next_button : Button  = $Panel/VBox/NextButton
@onready var scorebug    : Control = $Panel/VBox/Scorebug

func _ready() -> void:
	next_button.pressed.connect(func() -> void: next_pressed.emit())

func show_hole_result(hole_num: int, strokes: int, par: int, points: int, round_done: bool, total_vs_par: int, total_strokes: int) -> void:
	var diff : int = strokes - par
	var diff_text : String
	if diff == 0:
		diff_text = "Par"
	elif diff < 0:
		diff_text = "%d Under" % -diff
	else:
		diff_text = "%d Over" % diff

	lbl_hole.text    = "Hole %d Complete" % hole_num
	lbl_strokes.text = "Strokes: %d" % strokes
	lbl_par.text     = "Par %d  (%s)" % [par, diff_text]
	# Practice awards no points (always 0); hide the line rather than show a misleading "+0".
	lbl_points.visible = points > 0
	lbl_points.text    = "+%d pts" % points

	# 9- and 18-hole rounds get the full TV scorebug grid; practice (endless, no fixed
	# layout) keeps the simple per-hole strokes/par text.
	var scored_round : bool = GameState.holes_per_round != GameState.INFINITE
	scorebug.visible    = scored_round
	lbl_strokes.visible = not scored_round
	lbl_par.visible     = not scored_round
	if scored_round:
		var numbers : Array[int] = []
		var pars    : Array[int] = []
		var scores  : Array[int] = []
		for n in range(1, GameState.holes_per_round + 1):
			numbers.append(n)
			if n <= GameState.hole_pars.size():
				pars.append(GameState.hole_pars[n - 1])
				scores.append(GameState.hole_scores[n - 1])
			else:
				pars.append(GameState.get_par_for_hole(n))
				scores.append(-1)   # unreached hole: par shown, score cell blank
		scorebug.set_round(numbers, pars, scores, hole_num)

	if round_done:
		var sign_str : String = "+" if total_vs_par >= 0 else ""
		lbl_result.text  = "Round Complete!  Total: %d (%s%d)" % [total_strokes, sign_str, total_vs_par]
		next_button.text = "Main Menu"
	else:
		lbl_result.text  = ""
		next_button.text = "Next Hole"

	visible = true
