extends Control

# Career Stats: a read-only summary of lifetime play, reached from the main menu. Every figure
# comes straight from SaveManager's persisted "stats" block (plus the points balance), so this
# screen only formats and displays -- it never mutates the save. UI is built in code (the .tscn
# holds just the bg), mirroring tutorial.gd / clubhouse.gd and styled via ui_palette.gd.

const UI = preload("res://scripts/ui_palette.gd")

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.solid_card_style(UI.EDGE, 14, 32.0))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	vbox.custom_minimum_size = Vector2(620, 0)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "CAREER STATS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UI.INK)
	title.add_theme_font_override("font", UI.FONT)
	title.add_theme_font_size_override("font_size", 52)
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(grid)

	var stats : Dictionary = SaveManager.data.get("stats", {}) if SaveManager.data.get("stats", null) is Dictionary else {}
	var holes : int = int(stats.get("holes_completed", 0))
	var avg : String = ("%.2f" % (float(int(stats.get("total_strokes", 0))) / float(holes))) if holes > 0 else "—"

	_row(grid, "Rounds Played",       str(int(stats.get("rounds_played", 0))))
	_row(grid, "Holes Played",        str(holes))
	_row(grid, "Avg Strokes / Hole",  avg)
	_row(grid, "Best Round",          _vs_par(int(stats.get("best_round_score", 9999)), 9999))
	_row(grid, "Best Hole",           _vs_par(int(stats.get("best_hole_vs_par", 99)), 99))
	_row(grid, "Holes in One",        str(int(stats.get("hole_in_ones", 0))))
	_row(grid, "Eagles",              str(int(stats.get("eagles", 0))))
	_row(grid, "Birdies",             str(int(stats.get("birdies", 0))))
	_row(grid, "Bogeys",              str(int(stats.get("bogeys", 0))))
	_row(grid, "Points Banked",       _fmt(int(SaveManager.data.get("points", 0))))
	_row(grid, "Lifetime Points",     _fmt(int(SaveManager.data.get("lifetime_points", 0))))

	var back := Button.new()
	back.text = "BACK TO MAIN MENU"
	back.custom_minimum_size = Vector2(440, 56)
	back.pressed.connect(func() -> void: SceneManager.goto(SceneManager.MAIN_MENU))
	vbox.add_child(back)
	UI.style_button(back, false)

func _row(grid: GridContainer, label_text: String, value_text: String) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", UI.SUBINK)
	lbl.add_theme_font_override("font", UI.FONT)
	lbl.add_theme_font_size_override("font_size", 26)
	grid.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.add_theme_color_override("font_color", UI.INK)
	val.add_theme_font_override("font", UI.FONT)
	val.add_theme_font_size_override("font_size", 26)
	grid.add_child(val)

# Formats a score-vs-par as "Even" / "-2" / "+3", or a dash when the no-data sentinel is set
# (best_round_score starts at 9999, best_hole_vs_par at 99 -- see SaveManager._default_save).
func _vs_par(value: int, sentinel: int) -> String:
	if value == sentinel:
		return "—"
	if value == 0:
		return "Even"
	return ("+%d" % value) if value > 0 else str(value)

# Thousands separator for big point totals (same idea as pro_shop.gd's _fmt).
func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
