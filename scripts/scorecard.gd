extends Control

const UI = preload("res://scripts/ui_palette.gd")

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
	_style()

# Broadcast styling for the post-hole modal: a rounded translucent panel with a gold accent
# edge, cohesive ink colours, and a gold primary action button.
func _style() -> void:
	$Panel.add_theme_stylebox_override("panel", UI.card_style(5.0, 12))
	lbl_hole.add_theme_color_override("font_color", UI.ACCENT)
	lbl_points.add_theme_color_override("font_color", UI.ACCENT)
	lbl_result.add_theme_color_override("font_color", UI.SUBINK)
	for l : Label in [lbl_strokes, lbl_par]:
		l.add_theme_color_override("font_color", UI.INK)
	UI.style_button(next_button, true)

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
		if GameState.game_mode == "tournament":
			# A tournament day ends on the leaderboard (cut + standings) rather than the menu.
			lbl_result.text  = "%s Complete!  Today: %d (%s%d)" % [TournamentManager.day_name(), total_strokes, sign_str, total_vs_par]
			next_button.text = "Leaderboard"
		else:
			lbl_result.text  = "Round Complete!  Total: %d (%s%d)" % [total_strokes, sign_str, total_vs_par]
			next_button.text = "Main Menu"
	else:
		lbl_result.text  = ""
		next_button.text = "Next Hole"

	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
