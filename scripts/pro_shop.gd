extends Control

# Pro shop. Four options across the top: three procedurally-generated items (each rerolls only
# when bought, persisted between visits) plus a mystery box -- a flat-price gamble that plays a
# CS-style cycling reveal and skews toward rarer items. Currency is the player's earned points
# (SaveManager.spend_points). UI is built in code, mirroring clubhouse.gd / loading_screen.gd.

const UI = preload("res://scripts/ui_palette.gd")

const TEXT     := UI.INK
const SUBTEXT  := UI.SUBINK
const PANEL_BG := UI.PANEL_SOLID
const HILITE   := UI.ACCENT
const BAR_FILL := UI.METER
const DIM      := Color(0.05, 0.09, 0.07, 1.0)   # opaque: fully hides the picker behind the box overlay

const BALL_CHANCE := 0.35   # share of offerings / box results that are balls vs clubs

# Compact stat bars shown on each card (3 each to keep cards small).
const CLUB_BARS := [
	{"label": "Power",    "field": "power",  "min": 0.0, "max": 90.0, "inv": false},
	{"label": "Accuracy", "field": "spread", "min": 0.0, "max": 14.0, "inv": true},
	{"label": "Spin",     "field": "spin",   "min": 0.0, "max": 1.0,  "inv": false},
]
const BALL_BARS := [
	{"label": "Distance", "field": "distance_modifier", "min": 0.75, "max": 1.70, "inv": false, "def": 1.0},
	{"label": "Roll",     "field": "roll_resistance",   "min": 1.40, "max": 3.60, "inv": true,  "def": 2.8},
	{"label": "Backspin", "field": "backspin_mod",      "min": 0.60, "max": 1.80, "inv": false, "def": 1.0},
]
const MIN_BAR := 8.0

# Box reel layout.
const STRIP_COUNT  := 28
const WINNER_INDEX := 23
const CARD_W       := 150.0
const CARD_SEP     := 12.0
const REEL_TIME    := 4.5

var offerings : Array = []      # [{kind, item, price}, x3]
var cards_hbox : HBoxContainer
var points_label : Label
var box_overlay : Control


func _ready() -> void:
	randomize()
	_load_offerings()
	_build_ui()
	_rebuild_all()


# --- Offerings state --------------------------------------------------------

func _load_offerings() -> void:
	offerings = SaveManager.data.get("shop", {}).get("offerings", [])
	var changed := false
	while offerings.size() < 3:
		offerings.append(_make_offering())
		changed = true
	if offerings.size() > 3:
		offerings.resize(3)
		changed = true
	if changed:
		_save_offerings()

func _make_offering() -> Dictionary:
	var rarity : String = ItemGenerator.roll_rarity(ItemGenerator.STANDARD_WEIGHTS)
	var is_ball : bool = randf() < BALL_CHANCE
	var item : Dictionary = ItemGenerator.generate_ball(rarity) if is_ball else ItemGenerator.generate_club(rarity)
	return {"kind": "ball" if is_ball else "club", "item": item, "price": ItemGenerator.price_for(rarity)}

func _save_offerings() -> void:
	SaveManager.data["shop"]["offerings"] = offerings
	SaveManager.save()


# --- UI shell ---------------------------------------------------------------

func _build_ui() -> void:
	var title := Label.new()
	title.text = "PRO SHOP"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 40.0
	title.offset_bottom = 120.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", TEXT)
	add_child(title)

	points_label = Label.new()
	points_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	points_label.offset_left = -360.0
	points_label.offset_right = -40.0
	points_label.offset_top = 56.0
	points_label.offset_bottom = 96.0
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	points_label.add_theme_font_size_override("font_size", 30)
	points_label.add_theme_color_override("font_color", HILITE)
	add_child(points_label)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 28)
	center.add_child(vbox)

	cards_hbox = HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 18)
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(cards_hbox)

	var back := Button.new()
	back.text = "BACK TO MAIN MENU"
	back.custom_minimum_size = Vector2(560.0, 60.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 26)
	UI.style_button(back, false)
	back.pressed.connect(func() -> void: SceneManager.goto(SceneManager.MAIN_MENU))
	vbox.add_child(back)

	_refresh_points()

func _refresh_points() -> void:
	points_label.text = "%s pts" % _fmt(_points())

func _points() -> int:
	return int(SaveManager.data.get("points", 0))

func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


# --- Cards ------------------------------------------------------------------

func _rebuild_all() -> void:
	for child in cards_hbox.get_children():
		cards_hbox.remove_child(child)
		child.queue_free()
	for i in range(3):
		cards_hbox.add_child(_build_offer_card(i))
	cards_hbox.add_child(_build_box_card())

func _card_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(270.0, 470.0)
	panel.add_theme_stylebox_override("panel", UI.solid_card_style(UI.EDGE, 10, 16.0))
	return panel

func _build_offer_card(index: int) -> Control:
	var off : Dictionary = offerings[index]
	var item : Dictionary = off["item"]
	var is_ball : bool = off["kind"] == "ball"
	var rarity : String = item.get("rarity", "common")
	var rc : Color = ItemVisuals.rarity_color(rarity)

	var panel := _card_panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	v.add_child(_thumb_holder(is_ball, item))

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "—")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", rc)
	v.add_child(name_lbl)

	var rar_lbl := Label.new()
	rar_lbl.text = rarity.to_upper()
	rar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rar_lbl.add_theme_font_size_override("font_size", 15)
	rar_lbl.add_theme_color_override("font_color", rc)
	v.add_child(rar_lbl)

	v.add_child(_stat_rows(item, is_ball))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var buy := Button.new()
	var price : int = int(off["price"])
	var afford : bool = _points() >= price
	buy.text = "BUY  %s" % _fmt(price)
	buy.custom_minimum_size = Vector2(0.0, 52.0)
	buy.add_theme_font_size_override("font_size", 22)
	buy.disabled = not afford
	UI.style_button(buy, afford)
	if afford:
		buy.pressed.connect(_buy_offer.bind(index))
	v.add_child(buy)

	return panel

func _build_box_card() -> Control:
	var panel := _card_panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var art_holder := Control.new()
	art_holder.custom_minimum_size = Vector2(130.0, 130.0)
	art_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var qmark := Label.new()
	qmark.text = "?"
	qmark.set_anchors_preset(Control.PRESET_FULL_RECT)
	qmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qmark.add_theme_font_size_override("font_size", 96)
	qmark.add_theme_color_override("font_color", HILITE)
	art_holder.add_child(qmark)
	v.add_child(art_holder)

	var name_lbl := Label.new()
	name_lbl.text = "MYSTERY BOX"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", TEXT)
	v.add_child(name_lbl)

	var sub := Label.new()
	sub.text = "Better odds at\nrare & legendary gear"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", SUBTEXT)
	v.add_child(sub)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var open := Button.new()
	var price : int = ItemGenerator.BOX_PRICE
	var afford : bool = _points() >= price
	open.text = "OPEN  %s" % _fmt(price)
	open.custom_minimum_size = Vector2(0.0, 52.0)
	open.add_theme_font_size_override("font_size", 22)
	open.disabled = not afford
	UI.style_button(open, afford)
	if afford:
		open.pressed.connect(_open_box)
	v.add_child(open)

	return panel

func _thumb_holder(is_ball: bool, item: Dictionary) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(130.0, 130.0)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var svc : SubViewportContainer = ItemVisuals.build_ball_thumbnail(item) if is_ball else ItemVisuals.build_club_thumbnail(item)
	holder.add_child(svc)
	return holder

func _stat_rows(item: Dictionary, is_ball: bool) -> Control:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	var bars : Array = BALL_BARS if is_ball else CLUB_BARS
	for m: Dictionary in bars:
		var v : float = item.get(m["field"], m.get("def", 0.0))
		var pct : float = clampf((v - m["min"]) / (m["max"] - m["min"]), 0.0, 1.0)
		if m["inv"]:
			pct = 1.0 - pct
		rows.add_child(_make_bar(m["label"], maxf(pct * 100.0, MIN_BAR)))
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


# --- Purchase ---------------------------------------------------------------

func _buy_offer(index: int) -> void:
	var off : Dictionary = offerings[index]
	var price : int = int(off["price"])
	if not SaveManager.spend_points(price):
		return
	var item : Dictionary = off["item"]
	EquipmentManager.register_generated_item(item)
	EquipmentManager.add_to_inventory(item.get("id", ""))
	# Reroll only this slot; the others stay put.
	offerings[index] = _make_offering()
	_save_offerings()
	_refresh_points()
	_rebuild_all()


# --- Mystery box ------------------------------------------------------------

func _open_box() -> void:
	if not SaveManager.spend_points(ItemGenerator.BOX_PRICE):
		return
	_refresh_points()
	# The winner is decided up front; the reel is pure show.
	var rarity : String = ItemGenerator.roll_rarity(ItemGenerator.BOX_WEIGHTS)
	var is_ball : bool = randf() < BALL_CHANCE
	var winner : Dictionary = ItemGenerator.generate_ball(rarity) if is_ball else ItemGenerator.generate_club(rarity)
	var winner_kind : String = "ball" if is_ball else "club"
	_rebuild_all()   # box price spent -> refresh affordability behind the overlay
	_play_reel(winner, winner_kind)

func _decoy() -> Dictionary:
	var rarity : String = ItemGenerator.roll_rarity(ItemGenerator.BOX_WEIGHTS)
	var is_ball : bool = randf() < BALL_CHANCE
	var item : Dictionary = ItemGenerator.generate_ball(rarity) if is_ball else ItemGenerator.generate_club(rarity)
	return {"kind": "ball" if is_ball else "club", "item": item}

func _play_reel(winner: Dictionary, winner_kind: String) -> void:
	box_overlay = Control.new()
	box_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	box_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(box_overlay)

	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	box_overlay.add_child(dim)

	var heading := Label.new()
	heading.text = "OPENING..."
	heading.set_anchors_preset(Control.PRESET_TOP_WIDE)
	heading.offset_top = 220.0
	heading.offset_bottom = 280.0
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 40)
	heading.add_theme_color_override("font_color", TEXT)
	box_overlay.add_child(heading)

	# Clip window centred on screen; the reel scrolls left within it.
	var window_w := CARD_W * 5.0
	var window_h := CARD_W + 30.0
	var window := Control.new()
	window.clip_contents = true
	window.anchor_left = 0.5
	window.anchor_right = 0.5
	window.anchor_top = 0.5
	window.anchor_bottom = 0.5
	window.offset_left = -window_w * 0.5
	window.offset_right = window_w * 0.5
	window.offset_top = -window_h * 0.5
	window.offset_bottom = window_h * 0.5
	box_overlay.add_child(window)

	# Centre marker.
	var marker := ColorRect.new()
	marker.color = HILITE
	marker.size = Vector2(3.0, CARD_W + 30.0)
	marker.position = Vector2(window_w * 0.5 - 1.5, 0.0)
	window.add_child(marker)

	# Build the reel of cards.
	var reel := Control.new()
	window.add_child(reel)
	for i in range(STRIP_COUNT):
		var entry : Dictionary = winner_kind_entry(winner, winner_kind) if i == WINNER_INDEX else _decoy()
		var card := _reel_card(entry)
		card.position = Vector2(i * (CARD_W + CARD_SEP), 15.0)
		reel.add_child(card)

	# Land the winner under the marker (with a small random in-card offset for life).
	var winner_centre := WINNER_INDEX * (CARD_W + CARD_SEP) + CARD_W * 0.5
	var jitter := randf_range(-CARD_W * 0.28, CARD_W * 0.28)
	var target_x := window_w * 0.5 - winner_centre + jitter
	reel.position = Vector2(window_w * 0.5 + CARD_W * 0.5, 0.0)

	var tw := create_tween()
	tw.tween_property(reel, "position:x", target_x, REEL_TIME).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_reveal.bind(winner, winner_kind, heading, window))

func winner_kind_entry(winner: Dictionary, kind: String) -> Dictionary:
	return {"kind": kind, "item": winner}

func _reel_card(entry: Dictionary) -> Control:
	var item : Dictionary = entry["item"]
	var rc : Color = ItemVisuals.rarity_color(item.get("rarity", "common"))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_W, CARD_W)
	panel.size = Vector2(CARD_W, CARD_W)
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.set_corner_radius_all(8)
	box.set_border_width_all(3)
	box.border_color = rc
	panel.add_theme_stylebox_override("panel", box)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(CARD_W - 16.0, CARD_W - 16.0)
	var svc : SubViewportContainer = ItemVisuals.build_ball_thumbnail(item) if entry["kind"] == "ball" else ItemVisuals.build_club_thumbnail(item)
	holder.add_child(svc)
	panel.add_child(holder)
	return panel

func _reveal(winner: Dictionary, winner_kind: String, heading: Label, window: Control) -> void:
	# Clear the reel (and its centre marker child) so only the won item remains on screen.
	window.queue_free()

	# Commit the prize now so it's kept even if the overlay is dismissed.
	EquipmentManager.register_generated_item(winner)
	EquipmentManager.add_to_inventory(winner.get("id", ""))

	var rarity : String = winner.get("rarity", "common")
	var rc : Color = ItemVisuals.rarity_color(rarity)
	heading.text = "%s %s" % [rarity.capitalize(), winner.get("name", "—")]
	heading.add_theme_color_override("font_color", rc)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 60.0
	box_overlay.add_child(center)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(200.0, 200.0)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var svc : SubViewportContainer = ItemVisuals.build_ball_thumbnail(winner) if winner_kind == "ball" else ItemVisuals.build_club_thumbnail(winner)
	holder.add_child(svc)
	v.add_child(holder)

	var add := Button.new()
	add.text = "ADD TO BAG"
	add.custom_minimum_size = Vector2(320.0, 60.0)
	add.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add.add_theme_font_size_override("font_size", 26)
	UI.style_button(add, true)
	add.pressed.connect(_close_box)
	v.add_child(add)

func _close_box() -> void:
	if box_overlay != null:
		box_overlay.queue_free()
		box_overlay = null
	_refresh_points()
	_rebuild_all()
