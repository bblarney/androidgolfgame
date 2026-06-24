extends Control

# Basic front-end menu. One scene with stacked panels toggled by visibility:
#   MainPanel  - CONTINUE / PLAY / CLUBHOUSE / PRO SHOP / SETTINGS / EXIT
#   PlayPanel  - PRACTICE / 9 HOLES / 18 HOLES / TOURNAMENT(disabled) / BACK
#   Placeholder- reused for CLUBHOUSE / PRO SHOP / SETTINGS (title + BACK)
# All exits (EXIT here, leaving a round in-game) are gated by an "Are you sure?" dialog.

@onready var main_panel        : Control           = $MainPanel
@onready var play_panel        : Control           = $PlayPanel
@onready var placeholder       : Control           = $Placeholder
@onready var placeholder_title : Label             = $Placeholder/VBox/Title
@onready var continue_button   : Button            = $MainPanel/VBox/ContinueButton
@onready var exit_dialog       : ConfirmationDialog = $ExitDialog

func _ready() -> void:
	# CONTINUE only makes sense when a saved round is mid-flight.
	continue_button.disabled = not GameState.has_resumable_round()
	_show_only(main_panel)

	# Main panel
	continue_button.pressed.connect(_on_continue)
	$MainPanel/VBox/PlayButton.pressed.connect(func() -> void: _show_only(play_panel))
	$MainPanel/VBox/ClubhouseButton.pressed.connect(func() -> void: SceneManager.goto(SceneManager.CLUBHOUSE))
	$MainPanel/VBox/ProShopButton.pressed.connect(func() -> void: SceneManager.goto(SceneManager.PRO_SHOP))
	$MainPanel/VBox/SettingsButton.pressed.connect(func() -> void: _open_placeholder("SETTINGS"))
	$MainPanel/VBox/ExitButton.pressed.connect(func() -> void: exit_dialog.popup_centered())

	# Play panel
	$PlayPanel/VBox/PracticeButton.pressed.connect(func() -> void: _start("practice"))
	$PlayPanel/VBox/NineButton.pressed.connect(func() -> void: _start("9"))
	$PlayPanel/VBox/EighteenButton.pressed.connect(func() -> void: _start("18"))
	$PlayPanel/VBox/BackButton.pressed.connect(func() -> void: _show_only(main_panel))

	# Placeholder panel
	$Placeholder/VBox/BackButton.pressed.connect(func() -> void: _show_only(main_panel))

	exit_dialog.confirmed.connect(func() -> void: get_tree().quit())

func _show_only(panel: Control) -> void:
	main_panel.visible  = panel == main_panel
	play_panel.visible  = panel == play_panel
	placeholder.visible = panel == placeholder

func _open_placeholder(title: String) -> void:
	placeholder_title.text = title
	_show_only(placeholder)

func _start(mode: String) -> void:
	GameState.start_round(mode)
	SceneManager.goto(SceneManager.HOLE)

func _on_continue() -> void:
	GameState.resume_round()
	SceneManager.goto(SceneManager.HOLE)
