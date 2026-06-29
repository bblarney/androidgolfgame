extends Control

# Clubhouse: view & swap the player's equipped clubs and ball.
#   Overview  - five category cards (Driver/Iron/Wedge/Putter/Ball) showing the equipped item.
#   Submenu   - a 4x4 grid of every owned item in that category (empty slots = black boxes) plus
#               stat "loading bars" for the equipped item. Clicking an owned item equips it.
# UI is built in code (the .tscn only holds the bg + heading), mirroring club_selector.gd /
# loading_screen.gd. Equip/loadout/save all go through EquipmentManager.

const UI = preload("res://scripts/ui_palette.gd")

const TEXT       := UI.INK
const SUBTEXT    := UI.SUBINK
const SLOT_BG    := UI.PANEL_SOLID
const SLOT_EMPTY := Color(0.0, 0.0, 0.0)
const HILITE     := UI.ACCENT
const BAR_FILL   := UI.METER

const GRID_SLOTS := 16
const GRID_COLS  := 4

# category -> { "title": display, "is_ball": bool }
const CATEGORIES := [
	{"id": "driver", "title": "DRIVER",  "is_ball": false},
	{"id": "iron",   "title": "IRON",    "is_ball": false},
	{"id": "wedge",  "title": "WEDGE",   "is_ball": false},
	{"id": "putter", "title": "PUTTER",  "is_ball": false},
	{"id": "ball",   "title": "BALL",    "is_ball": true},
]

# Friendly meter -> { field, min, max, inverted }. Each bar maps the raw field onto a fixed
# absolute scale shared by every club (NOT a per-type range), so the bars compare clubs against
# each other and read true to character: drivers high power, wedges high spin/loft, putters high
# accuracy, etc. `inverted` means lower raw value = fuller bar (less spread = more accuracy).
# Every bar is also floored at MIN_BAR so no stat ever shows completely empty.
const MIN_BAR := 8.0

const CLUB_METRICS := [
	{"label": "Power",    "field": "power",        "min": 0.0, "max": 90.0, "inverted": false},
	{"label": "Accuracy", "field": "spread",       "min": 0.0, "max": 14.0, "inverted": true},
	{"label": "Spin",     "field": "spin",         "min": 0.0, "max": 1.0,  "inverted": false},
	{"label": "Loft",     "field": "launch_angle", "min": 0.0, "max": 50.0, "inverted": false},
]
const BALL_METRICS := [
	{"label": "Distance",     "field": "distance_modifier", "min": 0.75, "max": 1.70, "inverted": false},
	{"label": "Air control",  "field": "air_resistance",    "min": 0.01, "max": 0.12, "inverted": true},
	{"label": "Roll control", "field": "roll_resistance",   "min": 1.40, "max": 3.60, "inverted": false},
	{"label": "Backspin",     "field": "backspin_mod",      "min": 0.60, "max": 1.80, "inverted": false, "default": 1.0},
]

var overview : Control
var submenu  : Control

var card_buttons : Dictionary = {}   # category id -> Button (overview)
var submenu_title : Label
var slot_buttons : Array[Button] = []
var stats_box : VBoxContainer

var current_category : Dictionary = {}
var current_items    : Array = []     # item dicts currently shown in the grid

# Slot styleboxes are identical for any (empty, equipped, rarity) combination, so build each once
# and share it across slots/refreshes instead of allocating a fresh StyleBoxFlat per slot.
var _slot_style_cache : Dictionary = {}


func _ready() -> void:
	AudioManager.play_music("menu")
	_build_overview()
	_build_submenu()
	_show_overview()


# --- Overview ---------------------------------------------------------------

func _build_overview() -> void:
	overview = Control.new()
	overview.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overview)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overview.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	for cat: Dictionary in CATEGORIES:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(560.0, 72.0)
		btn.add_theme_font_size_override("font_size", 26)
		UI.style_button(btn, false)
		btn.pressed.connect(_open_category.bind(cat))
		vbox.add_child(btn)
		card_buttons[cat["id"]] = btn

	var back := Button.new()
	back.custom_minimum_size = Vector2(560.0, 64.0)
	back.add_theme_font_size_override("font_size", 26)
	back.text = "BACK TO MAIN MENU"
	UI.style_button(back, false)
	back.pressed.connect(func() -> void: SceneManager.goto(SceneManager.MAIN_MENU))
	vbox.add_child(back)


func _refresh_overview() -> void:
	for cat: Dictionary in CATEGORIES:
		var item := _equipped_item(cat)
		var item_name : String = item.get("name", "—")
		var btn : Button = card_buttons[cat["id"]]
		btn.text = "%s:   %s" % [cat["title"], item_name]
		var rc : Color = ItemVisuals.rarity_color(item.get("rarity", "common")) if not item.is_empty() else TEXT
		btn.add_theme_color_override("font_color", rc)
		btn.add_theme_color_override("font_hover_color", rc)
		btn.add_theme_color_override("font_pressed_color", rc)
		btn.add_theme_color_override("font_focus_color", rc)


func _show_overview() -> void:
	_refresh_overview()
	overview.visible = true
	submenu.visible = false


# --- Submenu ----------------------------------------------------------------

func _build_submenu() -> void:
	submenu = Control.new()
	submenu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(submenu)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	submenu.add_child(center)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	center.add_child(root)

	submenu_title = Label.new()
	submenu_title.add_theme_font_size_override("font_size", 40)
	submenu_title.add_theme_color_override("font_color", TEXT)
	submenu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(submenu_title)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 36)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(body)

	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)

	for i in range(GRID_SLOTS):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120.0, 120.0)
		btn.add_theme_font_size_override("font_size", 16)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.clip_text = true
		btn.pressed.connect(_on_slot_pressed.bind(i))
		grid.add_child(btn)
		slot_buttons.append(btn)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320.0, 0.0)
	panel.add_theme_stylebox_override("panel", UI.solid_card_style(UI.EDGE, 10, 8.0))
	body.add_child(panel)

	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 12)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.add_child(stats_box)
	panel.add_child(margin)

	var back := Button.new()
	back.custom_minimum_size = Vector2(220.0, 56.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 24)
	back.text = "BACK"
	UI.style_button(back, false)
	back.pressed.connect(_show_overview)
	root.add_child(back)


func _open_category(cat: Dictionary) -> void:
	current_category = cat
	submenu_title.text = "%sS" % cat["title"]
	_refresh_grid()
	overview.visible = false
	submenu.visible = true


func _refresh_grid() -> void:
	var cat := current_category
	if cat["is_ball"]:
		current_items = EquipmentManager.get_owned_balls()
	else:
		current_items = EquipmentManager.get_owned_clubs_by_type(cat["id"])

	var equipped_id : String = _equipped_item(cat).get("id", "")
	var is_ball : bool = cat["is_ball"]

	for i in range(GRID_SLOTS):
		var btn := slot_buttons[i]
		_clear_slot_thumb(btn)
		if i < current_items.size():
			var item : Dictionary = current_items[i]
			var is_eq : bool = item.get("id", "") == equipped_id
			btn.disabled = false
			btn.text = ""
			_style_slot(btn, false, is_eq, ItemVisuals.rarity_color(item.get("rarity", "common")))
			# Live 3D render in every slot: a club head, or a coloured ball.
			if is_ball:
				btn.add_child(ItemVisuals.build_ball_thumbnail(item))
			else:
				btn.add_child(ItemVisuals.build_club_thumbnail(item))
		else:
			btn.disabled = true
			btn.text = ""
			_style_slot(btn, true, false)

	# Show the equipped item's stats.
	_refresh_stats(_equipped_item(cat))


func _on_slot_pressed(index: int) -> void:
	if index >= current_items.size():
		return
	var item : Dictionary = current_items[index]
	var id : String = item.get("id", "")
	if current_category["is_ball"]:
		EquipmentManager.equip_ball(id)
	else:
		EquipmentManager.set_loadout_club(current_category["id"], id)
	_refresh_grid()


# --- Stat bars --------------------------------------------------------------

func _refresh_stats(item: Dictionary) -> void:
	for child in stats_box.get_children():
		child.queue_free()

	var has_item : bool = not item.is_empty()
	var rarity : String = item.get("rarity", "common")
	var rc : Color = ItemVisuals.rarity_color(rarity)

	var name_label := Label.new()
	name_label.text = item.get("name", "—")
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", rc if has_item else TEXT)
	stats_box.add_child(name_label)

	if has_item:
		var rar_label := Label.new()
		rar_label.text = rarity.to_upper()
		rar_label.add_theme_font_size_override("font_size", 14)
		rar_label.add_theme_color_override("font_color", rc)
		stats_box.add_child(rar_label)

	var is_ball : bool = current_category["is_ball"]
	var metrics : Array = BALL_METRICS if is_ball else CLUB_METRICS

	for m: Dictionary in metrics:
		var v : float = item.get(m["field"], m.get("default", 0.0))
		var pct : float = clampf((v - m["min"]) / (m["max"] - m["min"]), 0.0, 1.0)
		if m["inverted"]:
			pct = 1.0 - pct
		stats_box.add_child(_make_bar(m["label"], maxf(pct * 100.0, MIN_BAR)))


func _make_bar(label_text: String, value: float) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", SUBTEXT)
	row.add_child(lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(280.0, 18.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = BAR_FILL
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return row


# --- Club thumbnails (live 3D render in each slot) --------------------------

func _clear_slot_thumb(btn: Button) -> void:
	for child in btn.get_children():
		if child is SubViewportContainer:
			btn.remove_child(child)
			child.queue_free()

# --- Helpers ----------------------------------------------------------------

func _equipped_item(cat: Dictionary) -> Dictionary:
	if cat["is_ball"]:
		return EquipmentManager.get_equipped_ball()
	var id := EquipmentManager.get_loadout_club(cat["id"])
	return EquipmentManager.get_all_clubs().get(id, {})


func _style_slot(btn: Button, empty: bool, equipped: bool, rarity_col: Color = SUBTEXT) -> void:
	var key := "%s_%s_%s" % [empty, equipped, rarity_col.to_html()]
	var box : StyleBoxFlat = _slot_style_cache.get(key)
	if box == null:
		box = StyleBoxFlat.new()
		box.bg_color = SLOT_EMPTY if empty else SLOT_BG
		box.set_corner_radius_all(6)
		if equipped:
			# Equipped item keeps the gold highlight so it stays unmistakable at a glance.
			box.border_color = HILITE
			box.set_border_width_all(4)
		elif not empty:
			# Owned items are framed in their rarity colour.
			box.border_color = rarity_col
			box.set_border_width_all(3)
		_slot_style_cache[key] = box
	btn.add_theme_stylebox_override("normal", box)
	btn.add_theme_stylebox_override("hover", box)
	btn.add_theme_stylebox_override("pressed", box)
	btn.add_theme_stylebox_override("disabled", box)
	btn.add_theme_color_override("font_color", TEXT if equipped else SUBTEXT)
