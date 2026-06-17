extends Control

signal next_pressed

@onready var lbl_hole    : Label  = $Panel/VBox/HoleLabel
@onready var lbl_strokes : Label  = $Panel/VBox/StrokesLabel
@onready var lbl_par     : Label  = $Panel/VBox/ParLabel
@onready var lbl_result  : Label  = $Panel/VBox/ResultLabel
@onready var lbl_points  : Label  = $Panel/VBox/PointsLabel
@onready var next_button : Button = $Panel/VBox/NextButton

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
	lbl_points.text  = "+%d pts" % points

	if round_done:
		var sign_str : String = "+" if total_vs_par >= 0 else ""
		lbl_result.text  = "Round Complete!  Total: %d (%s%d)" % [total_strokes, sign_str, total_vs_par]
		next_button.text = "New Round"
	else:
		lbl_result.text  = ""
		next_button.text = "Next Hole"

	visible = true
