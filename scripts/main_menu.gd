extends Control

# Basic front-end menu. One scene with stacked panels toggled by visibility:
#   MainPanel  - CONTINUE / PLAY NOW / TOURNAMENT / CLUBHOUSE / PRO SHOP / HOW TO PLAY / SETTINGS / EXIT
#   PlayPanel  - PRACTICE / 9 HOLES / 18 HOLES / BACK
#   Placeholder- reused for CLUBHOUSE / PRO SHOP / SETTINGS (title + BACK)
# All exits (EXIT here, leaving a round in-game) are gated by an "Are you sure?" dialog.

const UI = preload("res://scripts/ui_palette.gd")

@onready var main_panel        : Control           = $MainPanel
@onready var play_panel        : Control           = $PlayPanel
@onready var placeholder       : Control           = $Placeholder
@onready var placeholder_title : Label             = $Placeholder/VBox/Title
@onready var continue_button   : Button            = $MainPanel/VBox/ContinueButton
@onready var exit_dialog       : ConfirmationDialog = $ExitDialog

# Settings panel is built in code (the scene only ships the old "Coming soon" placeholder); it
# carries the three volume sliders wired to AudioManager.
var settings_panel : Control

func _ready() -> void:
	AudioManager.play_music("menu")
	# CONTINUE only makes sense when a saved round is mid-flight.
	continue_button.disabled = not GameState.has_resumable_round()
	_show_only(main_panel)

	# Main panel
	continue_button.pressed.connect(_on_continue)
	$MainPanel/VBox/PlayButton.pressed.connect(func() -> void: _show_only(play_panel))
	$MainPanel/VBox/TournamentButton.pressed.connect(func() -> void: SceneManager.goto(SceneManager.TOURNAMENT_HUB))
	$MainPanel/VBox/ClubhouseButton.pressed.connect(func() -> void: SceneManager.goto(SceneManager.CLUBHOUSE))
	$MainPanel/VBox/ProShopButton.pressed.connect(func() -> void: SceneManager.goto(SceneManager.PRO_SHOP))
	$MainPanel/VBox/HowToPlayButton.pressed.connect(func() -> void: SceneManager.goto(SceneManager.TUTORIAL))
	$MainPanel/VBox/SettingsButton.pressed.connect(func() -> void: _show_only(settings_panel))
	$MainPanel/VBox/ExitButton.pressed.connect(func() -> void: exit_dialog.popup_centered())

	# Play panel
	$PlayPanel/VBox/PracticeButton.pressed.connect(func() -> void: _start("practice"))
	$PlayPanel/VBox/NineButton.pressed.connect(func() -> void: _start("9"))
	$PlayPanel/VBox/EighteenButton.pressed.connect(func() -> void: _start("18"))
	$PlayPanel/VBox/BackButton.pressed.connect(func() -> void: _show_only(main_panel))

	# Placeholder panel
	$Placeholder/VBox/BackButton.pressed.connect(func() -> void: _show_only(main_panel))

	exit_dialog.confirmed.connect(func() -> void: get_tree().quit())

	_build_settings()
	_style_buttons()

# Give every menu button the shared broadcast pill look (translucent normally, gold when pressed)
# in place of Godot's grey default.
func _style_buttons() -> void:
	for path in ["MainPanel/VBox", "PlayPanel/VBox", "Placeholder/VBox"]:
		for child in get_node(path).get_children():
			if child is Button:
				UI.style_button(child, false)

func _show_only(panel: Control) -> void:
	main_panel.visible  = panel == main_panel
	play_panel.visible  = panel == play_panel
	placeholder.visible = panel == placeholder
	if settings_panel != null:
		settings_panel.visible = panel == settings_panel

# Build the settings screen: a centred card of MASTER / MUSIC / SFX sliders (initialised from the
# save) plus BACK, styled with the shared UiPalette so it matches the rest of the front-end.
func _build_settings() -> void:
	settings_panel = CenterContainer.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel.visible = false
	add_child(settings_panel)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.solid_card_style(UI.EDGE, 14, 28.0))
	settings_panel.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.custom_minimum_size = Vector2(520, 0)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UI.INK)
	title.add_theme_font_override("font", UI.FONT)
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	_add_volume_row(vbox, "MASTER", "master_volume", AudioManager.set_master_volume)
	_add_volume_row(vbox, "MUSIC",  "music_volume",  AudioManager.set_music_volume)
	_add_volume_row(vbox, "SFX",    "sfx_volume",    AudioManager.set_sfx_volume)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(400, 56)
	back.pressed.connect(func() -> void: _show_only(main_panel))
	vbox.add_child(back)
	UI.style_button(back, false)

func _add_volume_row(parent: Control, label_text: String, save_key: String, on_change: Callable) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", UI.SUBINK)
	lbl.add_theme_font_override("font", UI.FONT)
	lbl.add_theme_font_size_override("font_size", 24)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = SaveManager.get_volume(save_key)
	slider.custom_minimum_size = Vector2(460, 28)
	slider.value_changed.connect(func(v: float) -> void: on_change.call(v))
	row.add_child(slider)
	parent.add_child(row)

func _open_placeholder(title: String) -> void:
	placeholder_title.text = title
	_show_only(placeholder)

func _start(mode: String) -> void:
	GameState.start_round(mode)
	SceneManager.goto(SceneManager.HOLE)

func _on_continue() -> void:
	GameState.resume_round()
	SceneManager.goto(SceneManager.HOLE)
