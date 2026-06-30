extends Control

# How To Play: a click-through slide deck reached from the main menu. Walks a new player
# through game modes, on-course controls/scoring, the clubhouse, and the pro shop. UI is
# built entirely in code (the .tscn only holds the bg), mirroring clubhouse.gd / pro_shop.gd.
# Slides are pure data (SLIDES); _show_slide rebuilds the body for the current index.

const UI = preload("res://scripts/ui_palette.gd")

const TEXT     := UI.INK
const SUBTEXT  := UI.SUBINK
const PANEL_BG := UI.PANEL_SOLID
const HILITE   := UI.ACCENT
const ACCENT   := UI.METER

# Each slide: title, a one-line intro, and a list of points. A point is either
#   {"head": "...", "body": "..."}  -> bold label + description (feature lists)
#   {"body": "..."}                 -> plain bullet
const SLIDES := [
	{
		"title": "WELCOME TO GREENSIDE",
		"intro": "A quick-swing golf game on endless, procedurally-built holes.",
		"points": [
			{"body": "Every hole is generated fresh, across five scenery biomes\nfrom parkland to alpine."},
			{"body": "Play holes, score well, and earn points."},
			{"body": "Spend points in the Pro Shop on new clubs and balls, then\nequip them in the Clubhouse."},
			{"body": "Tap NEXT to take the tour, or SKIP to jump straight in."},
		],
	},
	{
		"title": "GAME MODES",
		"intro": "Pick a mode from PLAY on the main menu.",
		"points": [
			{"head": "Practice", "body": "Endless holes to warm up. No points awarded — just swing freely."},
			{"head": "9 Holes", "body": "A full scored round. Earn points on every hole."},
			{"head": "18 Holes", "body": "The long round, with a front-nine / back-nine scorecard."},
			{"head": "Tournament", "body": "Coming soon."},
			{"body": "Leave a scored round mid-way and CONTINUE on the menu picks\nit right back up."},
		],
	},
	{
		"title": "ON THE COURSE",
		"intro": "Everything is one finger: look around, then sling the ball.",
		"points": [
			{"head": "Look around", "body": "Drag anywhere away from the ball to rotate the camera and read the hole."},
			{"head": "Aim & power", "body": "Touch near the ball and drag BACK like a slingshot. The shot fires opposite your drag; pull farther for more power."},
			{"head": "Release", "body": "Let go to swing. A short drag cancels the shot."},
			{"head": "Pick a club", "body": "Use the club buttons (Driver / Iron / Wedge / Putter) to switch. Each swings to whatever you've slotted in the Clubhouse."},
		],
	},
	{
		"title": "SCORING & POINTS",
		"intro": "Beat par to bank the biggest rewards.",
		"points": [
			{"body": "Each hole has a par. Your strokes vs par set the result:\nbirdie, par, bogey, and so on."},
			{"head": "Hole-in-one", "body": "+500 points"},
			{"head": "Eagle or better", "body": "+300 points"},
			{"head": "Birdie", "body": "+150 points"},
			{"head": "Par", "body": "+75 points"},
			{"head": "Bogey / worse", "body": "+25 and down — every hole still pays something."},
		],
	},
	{
		"title": "THE CLUBHOUSE",
		"intro": "Your bag: view and swap the gear you own.",
		"points": [
			{"head": "Five slots", "body": "Driver, Iron, Wedge, Putter, and Ball — one equipped in each."},
			{"head": "Swap gear", "body": "Open a slot to see every item you own in that category, then tap one to equip it. The gold frame marks what's equipped."},
			{"head": "Read the stats", "body": "Bars compare items head-to-head — Power, Accuracy, Spin, Loft for clubs; Distance, Roll, Backspin and more for balls."},
			{"body": "Whatever you equip here is what you swing on the course."},
		],
	},
	{
		"title": "THE PRO SHOP",
		"intro": "Spend your points on new gear.",
		"points": [
			{"head": "Daily offerings", "body": "Three procedurally-generated clubs and balls, each with its own rarity and price. Buying one rerolls that slot."},
			{"head": "Rarity", "body": "Rarer gear has stronger stats — and costs more."},
			{"head": "Mystery Box", "body": "A flat-price gamble with better odds at rare and legendary gear. Watch the reel spin, then add the prize to your bag."},
			{"body": "New gear lands in your inventory — head to the Clubhouse to\nequip it."},
		],
	},
	{
		"title": "YOU'RE READY",
		"intro": "That's everything. Time to tee off.",
		"points": [
			{"body": "Start with a Practice round to get a feel for the slingshot swing."},
			{"body": "Then play 9 or 18 holes to start banking points."},
			{"body": "Cash points in the Pro Shop, equip your finds in the Clubhouse,\nand chase that hole-in-one."},
			{"body": "Good luck out there!"},
		],
	},
]

var index : int = 0

var title_label  : Label
var step_label   : Label
var body_box     : VBoxContainer
var dots_box     : HBoxContainer
var back_button  : Button
var next_button  : Button


func _ready() -> void:
	AudioManager.play_music("menu")
	_build_ui()
	_show_slide()


func _build_ui() -> void:
	title_label = Label.new()
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_top = 56.0
	title_label.offset_bottom = 132.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 60)
	title_label.add_theme_color_override("font_color", TEXT)
	add_child(title_label)

	step_label = Label.new()
	step_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	step_label.offset_left = 40.0
	step_label.offset_right = 200.0
	step_label.offset_top = 64.0
	step_label.offset_bottom = 100.0
	step_label.add_theme_font_size_override("font_size", 24)
	step_label.add_theme_color_override("font_color", SUBTEXT)
	add_child(step_label)

	var skip := Button.new()
	skip.text = "SKIP"
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -180.0
	skip.offset_right = -40.0
	skip.offset_top = 56.0
	skip.offset_bottom = 108.0
	skip.add_theme_font_size_override("font_size", 24)
	UI.style_button(skip, false)
	skip.pressed.connect(_exit)
	add_child(skip)

	# Centered content card holding the current slide's body.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 150.0
	center.offset_bottom = -150.0
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980.0, 0.0)
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.set_corner_radius_all(14)
	box.set_border_width_all(2)
	box.border_color = UI.EDGE
	box.content_margin_left = 48.0
	box.content_margin_right = 48.0
	box.content_margin_top = 40.0
	box.content_margin_bottom = 40.0
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)

	body_box = VBoxContainer.new()
	body_box.add_theme_constant_override("separation", 20)
	panel.add_child(body_box)

	# Bottom navigation row: BACK | progress dots | NEXT.
	var nav := HBoxContainer.new()
	nav.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nav.offset_left = 80.0
	nav.offset_right = -80.0
	nav.offset_top = -116.0
	nav.offset_bottom = -52.0
	nav.add_theme_constant_override("separation", 24)
	add_child(nav)

	back_button = Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(220.0, 60.0)
	back_button.add_theme_font_size_override("font_size", 26)
	UI.style_button(back_button, false)
	back_button.pressed.connect(_prev)
	nav.add_child(back_button)

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(left_spacer)

	dots_box = HBoxContainer.new()
	dots_box.add_theme_constant_override("separation", 14)
	dots_box.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_child(dots_box)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(right_spacer)

	next_button = Button.new()
	next_button.custom_minimum_size = Vector2(220.0, 60.0)
	next_button.add_theme_font_size_override("font_size", 26)
	UI.style_button(next_button, true)
	next_button.pressed.connect(_next)
	nav.add_child(next_button)


func _show_slide() -> void:
	var slide : Dictionary = SLIDES[index]

	title_label.text = slide["title"]
	step_label.text = "%d / %d" % [index + 1, SLIDES.size()]

	for child in body_box.get_children():
		child.queue_free()

	var intro := Label.new()
	intro.text = slide["intro"]
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 30)
	intro.add_theme_color_override("font_color", HILITE)
	body_box.add_child(intro)

	for point: Dictionary in slide["points"]:
		body_box.add_child(_make_point(point))

	_rebuild_dots()

	# First slide has nothing to go back to; let BACK leave the tour entirely.
	back_button.text = "BACK" if index > 0 else "MENU"
	next_button.text = "NEXT" if index < SLIDES.size() - 1 else "LET'S GO"


func _make_point(point: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var bullet := Label.new()
	bullet.text = "•"
	bullet.add_theme_font_size_override("font_size", 24)
	bullet.add_theme_color_override("font_color", ACCENT)
	bullet.custom_minimum_size = Vector2(20.0, 0.0)
	row.add_child(bullet)

	if point.has("head"):
		# Feature line: "Head — body" with the head emphasised.
		var line := RichTextLabel.new()
		line.bbcode_enabled = true
		line.fit_content = true
		line.scroll_active = false
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_font_size_override("normal_font_size", 24)
		line.add_theme_font_size_override("bold_font_size", 24)
		line.add_theme_color_override("default_color", SUBTEXT)
		line.text = "[color=#%s][b]%s[/b][/color]   %s" % [TEXT.to_html(false), point["head"], point["body"]]
		row.add_child(line)
	else:
		var line := Label.new()
		line.text = point["body"]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_font_size_override("font_size", 24)
		line.add_theme_color_override("font_color", SUBTEXT)
		row.add_child(line)

	return row


func _rebuild_dots() -> void:
	for child in dots_box.get_children():
		child.queue_free()
	for i in range(SLIDES.size()):
		# The current slide's dot is a filled gold pill; the rest are dim dots. Drawn as
		# styled panels rather than glyphs so they never fall back to tofu.
		var is_cur : bool = i == index
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(28.0 if is_cur else 14.0, 14.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = HILITE if is_cur else Color(0.3, 0.42, 0.34)
		sb.set_corner_radius_all(7)
		dot.add_theme_stylebox_override("panel", sb)
		dots_box.add_child(dot)


func _next() -> void:
	if index < SLIDES.size() - 1:
		index += 1
		_show_slide()
	else:
		_exit()


func _prev() -> void:
	if index > 0:
		index -= 1
		_show_slide()
	else:
		_exit()


func _exit() -> void:
	SceneManager.goto(SceneManager.MAIN_MENU)
