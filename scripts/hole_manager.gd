extends Node

signal hole_complete(strokes: int, par: int, points_earned: int)

@onready var ball         : RigidBody2D = $"../Ball"
@onready var cup          : Area2D      = $"../Cup"
@onready var course       : Node2D      = $"../Course"
@onready var camera       : Camera2D   = $"../Camera"
@onready var aim_indicator: Node2D     = $"../AimIndicator"
@onready var input_handler: Node       = $"../InputHandler"
@onready var hole_gen     : Node       = $"../HoleGenerator"
@onready var lbl_strokes  : Label      = $"../HUD/StrokeLabel"
@onready var lbl_par      : Label      = $"../HUD/ParLabel"
@onready var lbl_hole     : Label      = $"../HUD/HoleLabel"
@onready var lbl_points   : Label      = $"../HUD/PointsLabel"

var stroke_count   := 0
var par            := 4
var is_active      := false
var _hole_data     : Dictionary = {}
var _penalty_active := false

func _ready() -> void:
	_connect_signals()
	_start_hole()

func _connect_signals() -> void:
	ball.ball_resting.connect(_on_ball_resting)
	ball.entered_hazard.connect(_on_hazard)
	cup.body_entered.connect(_on_cup_entered)
	input_handler.shot_taken.connect(_on_shot_taken)
	input_handler.aim_updated.connect(aim_indicator.show_aim)
	input_handler.aim_cancelled.connect(aim_indicator.hide)

func _start_hole() -> void:
	# Clear previous terrain
	for child in course.get_children():
		child.queue_free()

	_hole_data = hole_gen.generate_hole(GameState.get_hole_seed())
	hole_gen.build_terrain(_hole_data, course)

	par = _hole_data["par"]
	stroke_count = 0
	is_active = true
	_penalty_active = false

	ball.global_position = _hole_data["tee_position"]
	ball.last_safe_position = _hole_data["tee_position"]
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0

	cup.global_position = _hole_data["cup_position"]

	# Wire up water hazard signals after terrain is built
	await get_tree().process_frame
	for node in course.find_children("*", "Area2D", true, false):
		if node.get_meta("hazard_type", "") == "water":
			if not node.body_entered.is_connected(_on_hazard_area):
				node.body_entered.connect(_on_hazard_area)

	_update_hud()
	camera.setup(ball, _hole_data)
	input_handler.setup(ball, camera)

	# Brief overview before enabling input
	await get_tree().create_timer(1.6).timeout
	input_handler.can_shoot = true

func _on_shot_taken(direction: Vector2, power: float) -> void:
	aim_indicator.hide()
	stroke_count += 1
	_update_hud()
	var club := EquipmentManager.get_equipped_club()
	ball.apply_shot(direction, power, club.get("power", 1500.0))
	camera.start_following()

func _on_ball_resting() -> void:
	camera.on_ball_resting()
	if not _penalty_active and is_active:
		input_handler.can_shoot = true

func _on_hazard() -> void:
	_trigger_penalty()

func _on_hazard_area(body: Node) -> void:
	if body == ball:
		_trigger_penalty()

func _trigger_penalty() -> void:
	if _penalty_active or not is_active:
		return
	_penalty_active = true
	input_handler.can_shoot = false
	stroke_count += 1
	_update_hud()
	ball.reset_to_safe()
	await get_tree().create_timer(0.6).timeout
	_penalty_active = false
	if is_active:
		input_handler.can_shoot = true

func _on_cup_entered(body: Node) -> void:
	if body != ball or not is_active:
		return
	if ball.linear_velocity.length() > 85.0:
		return
	is_active = false
	input_handler.can_shoot = false
	aim_indicator.hide()

	var points := SaveManager.record_hole_complete(stroke_count, par)
	GameState.record_hole(stroke_count, par)

	hole_complete.emit(stroke_count, par, points)

func _physics_process(_delta: float) -> void:
	if not is_active or ball.is_resting or _penalty_active:
		return
	var pos := ball.global_position
	var length: float = _hole_data.get("length", 5000.0)
	if pos.y > 1350.0 or pos.x < -250.0 or pos.x > length + 250.0:
		_trigger_penalty()

func _update_hud() -> void:
	lbl_strokes.text = "Strokes: %d" % stroke_count
	lbl_par.text     = "Par %d" % par
	lbl_hole.text    = "Hole %d / %d" % [GameState.current_hole, GameState.HOLES_PER_ROUND]
	lbl_points.text  = "%d pts" % SaveManager.data.get("points", 0)
