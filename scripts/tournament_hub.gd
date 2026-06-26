extends Control

# Tournament hub: the front door for the 4-day tournament. One scene, several views toggled by
# TournamentManager state and rebuilt in code (the .tscn only holds bg + heading), mirroring the
# clubhouse pattern:
#   start       - no tournament yet: START NEW TOURNAMENT
#   menu        - active tournament: CONTINUE / PLAY NEXT ROUND / LEADERBOARD / WITHDRAW
#   results     - a day just finished: leaderboard + cut line, CONTINUE applies the cut
#   leaderboard - current standings (in-danger golfers flagged while a round is live)
#   missed_cut  - the player fell on the cut: shown once, then back to start
#   complete    - Championship Sunday done: champion + final board
# All tournament logic lives in TournamentManager; this only renders and routes.

const UI = preload("res://scripts/ui_palette.gd")

const TEXT      := UI.INK
const SUBTEXT   := UI.SUBINK
const HILITE    := UI.ACCENT
const DANGER    := UI.DANGER
const CUT_COL   := Color(0.85, 0.40, 0.35)
const MYTHIC    := Color(1.0, 0.62, 0.20)
const PANEL_BG  := UI.PANEL_SOLID
const BAR_FILL  := UI.METER

const ROW_W     := 460.0

# Compact stat bars for the prize card, mirroring the pro shop's three-bar summary.
const CLUB_BARS := [
	{"label": "Power",    "field": "power",  "min": 0.0, "max": 90.0, "inv": false, "def": 0.0},
	{"label": "Accuracy", "field": "spread", "min": 0.0, "max": 14.0, "inv": true,  "def": 0.0},
	{"label": "Spin",     "field": "spin",   "min": 0.0, "max": 1.0,  "inv": false, "def": 0.0},
]
const BALL_BARS := [
	{"label": "Distance", "field": "distance_modifier", "min": 0.75, "max": 1.70, "inv": false, "def": 1.0},
	{"label": "Roll",     "field": "roll_resistance",   "min": 1.40, "max": 3.60, "inv": true,  "def": 2.8},
	{"label": "Backspin", "field": "backspin_mod",      "min": 0.60, "max": 1.80, "inv": false, "def": 1.0},
]

var content : Control          # current view root; cleared and rebuilt on each render
var confirm : ConfirmationDialog

func _ready() -> void:
	confirm = ConfirmationDialog.new()
	confirm.title = "Withdraw"
	confirm.dialog_text = "Withdraw from the tournament? All progress is lost."
	confirm.ok_button_text = "Withdraw"
	confirm.confirmed.connect(_on_withdraw_confirmed)
	add_child(confirm)
	_render()

func _render() -> void:
	_reset_content()
	if TournamentManager.has_pending_results():
		_build_results()
	elif TournamentManager.missed_cut():
		_build_missed_cut()
	elif TournamentManager.is_complete():
		_build_complete()
	elif TournamentManager.has_active_tournament():
		_build_menu()
	else:
		_build_start()

func _reset_content() -> void:
	if content != null:
		content.queue_free()
	content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(content)

# --- Button / action handlers ----------------------------------------------

func _on_start_new() -> void:
	TournamentManager.start_new_tournament()
	_render()

func _on_resume_day() -> void:
	TournamentManager.resume_day()
	SceneManager.goto(SceneManager.HOLE)

func _on_play_next() -> void:
	TournamentManager.begin_day()
	SceneManager.goto(SceneManager.HOLE)

func _on_apply_cut() -> void:
	TournamentManager.apply_cut_and_advance()
	_render()

func _on_withdraw_confirmed() -> void:
	TournamentManager.withdraw()
	_render()

func _on_complete_new() -> void:
	TournamentManager.withdraw()
	_render()

func _to_main_menu() -> void:
	SceneManager.goto(SceneManager.MAIN_MENU)

# --- Shared building blocks -------------------------------------------------

func _menu_box() -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)
	return vbox

func _label(parent: Node, txt: String, fs: int, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

func _button(parent: Node, txt: String, on_press: Callable, enabled: bool = true) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(ROW_W, 64.0)
	btn.add_theme_font_size_override("font_size", 26)
	btn.disabled = not enabled
	UI.style_button(btn, false)
	if enabled:
		btn.pressed.connect(on_press)
	parent.add_child(btn)
	return btn

func _spacer(parent: Node, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0.0, h)
	parent.add_child(s)

# --- Prize card (shop-style) ------------------------------------------------

# A pro-shop-style card for the Mythic prize: 3D thumbnail, name, MYTHIC label and three stat
# bars. Reuses ItemVisuals so the prize renders exactly like the same item would in the shop.
func _prize_card(prize: Dictionary) -> Control:
	var item: Dictionary = prize.get("item", {})
	var is_ball: bool = prize.get("kind", "club") == "ball"

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300.0, 0.0)
	panel.add_theme_stylebox_override("panel", UI.solid_card_style(MYTHIC, 10, 16.0))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(130.0, 130.0)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var svc: SubViewportContainer = ItemVisuals.build_ball_thumbnail(item) if is_ball else ItemVisuals.build_club_thumbnail(item)
	holder.add_child(svc)
	v.add_child(holder)

	var name_lbl := _label(v, str(item.get("name", "—")), 22, MYTHIC)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(v, "MYTHIC", 15, MYTHIC)
	v.add_child(_stat_rows(item, is_ball))
	return panel

func _stat_rows(item: Dictionary, is_ball: bool) -> Control:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	var bars: Array = BALL_BARS if is_ball else CLUB_BARS
	for m: Dictionary in bars:
		var val: float = item.get(m["field"], m.get("def", 0.0))
		var pct: float = clampf((val - m["min"]) / (m["max"] - m["min"]), 0.0, 1.0)
		if m["inv"]:
			pct = 1.0 - pct
		rows.add_child(_make_bar(m["label"], maxf(pct * 100.0, 8.0)))
	return rows

func _make_bar(label_text: String, value: float) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", SUBTEXT)
	row.add_child(lbl)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 14.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = BAR_FILL
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return row

# --- Views ------------------------------------------------------------------

func _build_start() -> void:
	var vbox := _menu_box()
	_label(vbox, "Four days. One hundred players.\nSurvive each cut to Championship Sunday.", 24, SUBTEXT)
	_spacer(vbox, 12.0)
	_button(vbox, "START NEW TOURNAMENT", _on_start_new)
	_button(vbox, "BACK TO MAIN MENU", _to_main_menu)

func _build_menu() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(center)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 70)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(hbox)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(vbox)

	var day := TournamentManager.current_day()
	_label(vbox, "Day %d of %d — %s" % [day, TournamentManager.TOTAL_DAYS, TournamentManager.day_name()], 30, HILITE)
	_label(vbox, "Field: %d players" % _field_size(), 22, SUBTEXT)
	_spacer(vbox, 8.0)

	if TournamentManager.round_in_progress():
		_button(vbox, "CONTINUE", _on_resume_day)
	else:
		_button(vbox, "PLAY ROUND %d (%s)" % [day, TournamentManager.day_name()], _on_play_next)

	_button(vbox, "LEADERBOARD", _build_leaderboard_view)
	_button(vbox, "WITHDRAW", func() -> void: confirm.popup_centered())
	_button(vbox, "BACK TO MAIN MENU", _to_main_menu)

	# The Mythic staked on these four days, shown shop-style so the player knows the stakes.
	var prize := TournamentManager.get_prize()
	if not prize.is_empty():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 10)
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(col)
		_label(col, "PLAYING FOR", 24, MYTHIC)
		col.add_child(_prize_card(prize))
		_label(col, "Win it all to keep it.\nFall out and it's gone.", 16, SUBTEXT)

func _build_results() -> void:
	var has_cut := TournamentManager.has_cut_ahead()
	var sub := "%d players miss the cut" % TournamentManager.projected_cut_count() if has_cut else "Final standings"
	_build_board_layout("%s Complete" % TournamentManager.day_name(), sub, has_cut, _on_apply_cut, "CONTINUE")

func _build_leaderboard_view() -> void:
	_reset_content()
	var sub := "Day %d — %s" % [TournamentManager.current_day(), TournamentManager.day_name()]
	_build_board_layout("LEADERBOARD", sub, TournamentManager.has_cut_ahead(), _render, "BACK")

func _build_missed_cut() -> void:
	TournamentManager.acknowledge_missed_cut()   # one-shot: next hub visit shows the start view
	var vbox := _menu_box()
	_label(vbox, "MISSED THE CUT", 48, DANGER)
	_label(vbox, "Your tournament ends here. Better luck next time.", 24, SUBTEXT)
	_spacer(vbox, 12.0)
	_button(vbox, "START NEW TOURNAMENT", _on_start_new)
	_button(vbox, "BACK TO MAIN MENU", _to_main_menu)

func _build_complete() -> void:
	var champ := TournamentManager.champion_name()
	var won := champ == TournamentManager.USER_NAME
	if not won:
		_build_board_layout("CHAMPION: %s" % champ, "Championship Sunday — Final", false, _on_complete_new, "NEW TOURNAMENT")
		return

	# Champion: celebrate, and present the Mythic they just claimed.
	var vbox := _menu_box()
	_label(vbox, "CHAMPION: YOU!", 48, HILITE)
	var prize := TournamentManager.get_prize()
	if not prize.is_empty():
		_label(vbox, "The Mythic is yours — added to your bag.", 22, MYTHIC)
		var holder := CenterContainer.new()
		holder.add_child(_prize_card(prize))
		vbox.add_child(holder)
	_spacer(vbox, 8.0)
	_button(vbox, "VIEW FINAL LEADERBOARD", _build_leaderboard_view)
	_button(vbox, "NEW TOURNAMENT", _on_complete_new)
	_button(vbox, "BACK TO MAIN MENU", _to_main_menu)

# --- Leaderboard layout (results / leaderboard / complete share this) -------

# A heading + subheading, a scrollable full-field standings list, and one action button.
func _build_board_layout(header: String, sub: String, show_cut: bool, action: Callable, action_text: String) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_top = 150.0
	vbox.offset_bottom = -30.0
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(vbox)

	_label(vbox, header, 40, HILITE)
	_label(vbox, sub, 22, SUBTEXT)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(ROW_W + 40.0, 540.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var standings := TournamentManager.get_standings()
	var cut_line_drawn := false
	var user_row : Control = null
	for i in range(standings.size()):
		# A dashed cut line drops in just above the first player who falls, so the line and the
		# "N players miss the cut" count agree even when ties at the line all advance.
		if show_cut and not cut_line_drawn and standings[i].get("in_danger", false) and i > 0:
			_add_cut_line(list)
			cut_line_drawn = true
		var row := _make_row(standings[i])
		list.add_child(row)
		if standings[i]["is_user"]:
			user_row = row

	var btn_box := CenterContainer.new()
	vbox.add_child(btn_box)
	_button(btn_box, action_text, action)

	# Keep the player's row in view when the field is long.
	if user_row != null:
		await get_tree().process_frame
		if is_instance_valid(scroll) and is_instance_valid(user_row):
			scroll.ensure_control_visible(user_row)

func _make_row(entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ROW_W, 0.0)
	var is_user : bool = entry["is_user"]
	var in_danger : bool = entry.get("in_danger", false)
	var style := StyleBoxFlat.new()
	if is_user:
		style.bg_color = Color(HILITE.r, HILITE.g, HILITE.b, 0.22)
	elif in_danger:
		style.bg_color = Color(0.55, 0.18, 0.15, 0.20)
	else:
		style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var ink : Color = HILITE if is_user else (DANGER if in_danger else TEXT)
	var rank := _row_label("%d" % entry["rank"], 22, ink, HORIZONTAL_ALIGNMENT_LEFT)
	rank.custom_minimum_size = Vector2(52.0, 0.0)
	row.add_child(rank)

	var name_lbl := _row_label(str(entry["name"]), 22, ink, HORIZONTAL_ALIGNMENT_LEFT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var score := _row_label(TournamentManager.format_score(int(entry["score"])), 22, ink, HORIZONTAL_ALIGNMENT_RIGHT)
	score.custom_minimum_size = Vector2(70.0, 0.0)
	row.add_child(score)
	return panel

func _row_label(txt: String, fs: int, col: Color, align: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	return l

func _add_cut_line(list: VBoxContainer) -> void:
	var lbl := Label.new()
	lbl.text = "— — — CUT LINE — — —"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", CUT_COL)
	list.add_child(lbl)

func _field_size() -> int:
	return TournamentManager.state.get("opponents", []).size() + 1
