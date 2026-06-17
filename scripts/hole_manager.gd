extends Node

signal hole_complete(strokes: int, par: int, points_earned: int)

const ClubVisual = preload("res://scripts/club_visual.gd")

@onready var ball          : RigidBody3D = $"../Ball"
@onready var cup           : Area3D      = $"../Cup"
@onready var course        : Node3D      = $"../Course"
@onready var camera        : Camera3D    = $"../Camera"
@onready var aim_indicator : Control     = $"../HUD/AimIndicator"
@onready var input_handler : Node        = $"../InputHandler"
@onready var hole_gen      : Node        = $"../HoleGenerator"
@onready var lbl_strokes   : Label       = $"../HUD/StrokeLabel"
@onready var lbl_par       : Label       = $"../HUD/ParLabel"
@onready var lbl_hole      : Label       = $"../HUD/HoleLabel"
@onready var lbl_points    : Label       = $"../HUD/PointsLabel"
@onready var scorecard     : Control     = $"../HUD/ScoreCard"

var stroke_count     : int  = 0
var par              : int  = 4
var is_active        : bool = false
var _hole_data       : Dictionary = {}
var _penalty_active  : bool = false
var club             : Node3D

func _ready() -> void:
	_setup_environment()
	# The club lives on the persistent Hole root (NOT under Course, which is rebuilt every
	# hole) so it survives across holes.
	club = ClubVisual.new()
	club.name = "ClubVisual"
	get_parent().add_child(club)
	_connect_signals()
	_start_hole()

func _setup_environment() -> void:
	# A gradient procedural sky (replaces the old flat clear-colour background). The sun
	# disk is drawn automatically from the DirectionalLight3D created below, so the light
	# and the visible sun always agree. Set once -- the WorldEnvironment is not rebuilt
	# per hole.
	var sky_mat := ProceduralSkyMaterial.new()
	# A clear blue-to-pale gradient with a visible sun glow, distinct from the old flat
	# background. The sun disk is drawn from the DirectionalLight3D below.
	sky_mat.sky_top_color        = Color(0.18, 0.40, 0.78)   # deep zenith blue
	sky_mat.sky_horizon_color    = Color(0.80, 0.88, 0.94)   # bright pale horizon
	sky_mat.sky_curve            = 0.15
	sky_mat.ground_horizon_color = Color(0.72, 0.80, 0.84)
	sky_mat.ground_bottom_color  = Color(0.38, 0.44, 0.46)
	sky_mat.ground_curve         = 0.04
	sky_mat.sun_angle_max        = 30.0
	sky_mat.sun_curve            = 0.08   # tighter falloff -> a crisper, brighter sun disk
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env_node := WorldEnvironment.new()
	var env      := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky             = sky
	# Ambient stays an explicit COLOUR rather than AMBIENT_SOURCE_SKY: the Mobile renderer
	# has limited sky-based ambient/reflection support, and sky ambient there can collapse
	# to near-black, leaving the scene lit only by the sun (which made dark props like the
	# club head disappear). An explicit ambient colour is mobile-safe and matches the sky.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.75, 0.85, 1.0)
	env.ambient_light_energy = 0.55
	env_node.environment = env
	get_parent().add_child(env_node)

	# The procedural sky draws a sun DISK only where this light points, and only sized by
	# its angular distance (which defaults to 0 -- an invisible point). Give it a real disk
	# and a lower elevation so the sun actually sits in the playing camera's field of view
	# instead of high overhead where it's never framed.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees       = Vector3(-22.0, 35.0, 0.0)
	sun.light_energy           = 1.15
	sun.light_angular_distance = 3.0
	sun.sky_mode               = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	sun.shadow_enabled         = true
	get_parent().add_child(sun)

func _connect_signals() -> void:
	ball.ball_resting.connect(_on_ball_resting)
	ball.entered_hazard.connect(_on_hazard)
	cup.body_entered.connect(_on_cup_entered)
	input_handler.shot_taken.connect(_on_shot_taken)
	input_handler.aim_updated.connect(aim_indicator.show_aim)
	input_handler.aim_cancelled.connect(aim_indicator.clear_aim)
	input_handler.aim_changed.connect(club.set_aim)
	input_handler.aim_cancelled.connect(club.reset_address)
	scorecard.next_pressed.connect(_on_next_pressed)

func _start_hole() -> void:
	for child in course.get_children():
		child.queue_free()

	_hole_data   = hole_gen.generate_hole(GameState.get_hole_seed(), GameState.get_hole_biome())
	hole_gen.build_terrain(_hole_data, course)

	par          = _hole_data["par"]
	stroke_count = 0
	is_active    = true
	_penalty_active = false
	club.hide_club()

	ball.global_position     = _hole_data["tee_position"]
	ball.last_safe_position  = _hole_data["tee_position"]
	ball.shot_start_position = _hole_data["tee_position"]
	ball.linear_velocity    = Vector3.ZERO
	ball.angular_velocity   = Vector3.ZERO
	ball.scale              = Vector3.ONE
	ball.collision_layer    = 1
	ball.collision_mask     = 1
	ball.freeze             = true
	ball.in_sand            = false
	# Clear the resting flag left over from sinking the previous hole. Without this the
	# ball is still flagged as "resting" on the first frame of the new hole, and because
	# the cup's overlap list hasn't refreshed after the teleport it still lists the ball
	# from the prior sink -- which instantly re-triggers _on_cup_entered at 0 strokes.
	ball.is_resting         = false
	ball.setup_terrain(hole_gen, _hole_data)

	cup.global_position = _hole_data["cup_position"]
	# Size the trigger to the cup mouth so it spans the well from rim to floor.
	# Values track hole_generator.gd's CUP_RADIUS (0.6) and CUP_DEPTH (0.55).
	var cup_shape : CylinderShape3D = $"../Cup/CupShape".shape
	cup_shape.radius = 0.55
	cup_shape.height = 0.55

	# Water and sand are both carved terrain now, detected by ball position each frame
	# (water via hole_gen.water_at, sand via get_surface_type) -- no Area3D wiring needed.
	_update_hud()
	camera.setup(ball, _hole_data)
	input_handler.setup(ball, camera)

	await get_tree().create_timer(2.0).timeout
	camera.switch_to_aim()
	input_handler.can_shoot = true
	club.show_at(ball.global_position)

func _on_shot_taken(direction: Vector3, power: float) -> void:
	aim_indicator.clear_aim()
	club.play_swing()
	# A tee is only used for the opening shot -- pull the peg once the ball is struck.
	if stroke_count == 0:
		var peg : Node = course.get_node_or_null("TeeBox/TeePeg")
		if peg != null:
			peg.queue_free()
	stroke_count += 1
	_update_hud()
	var club_data := EquipmentManager.get_equipped_club()
	ball.apply_shot(direction, power, club_data.get("power", 35.0), club_data.get("backspin", 0.0))
	camera.start_following()

func _on_ball_resting() -> void:
	camera.on_ball_resting()
	if not _penalty_active and is_active:
		input_handler.can_shoot = true
		club.show_at(ball.global_position)

func _on_hazard() -> void:
	_trigger_penalty()

func _trigger_penalty(to_shot_start: bool = false) -> void:
	if _penalty_active or not is_active:
		return
	_penalty_active = true
	input_handler.can_shoot = false
	stroke_count += 1
	_update_hud()
	if to_shot_start:
		ball.reset_to_shot_start()
	else:
		ball.reset_to_safe()
	await get_tree().create_timer(0.7).timeout
	_penalty_active = false
	if is_active:
		input_handler.can_shoot = true

func _on_cup_entered(body: Node) -> void:
	if body != ball or not is_active:
		return
	if ball.linear_velocity.length() > 6.5:
		return
	is_active = false
	input_handler.can_shoot = false
	aim_indicator.clear_aim()
	await _sink_ball()

	var hole_num : int = GameState.current_hole
	var points   : int = SaveManager.record_hole_complete(stroke_count, par)
	GameState.record_hole(stroke_count, par)
	hole_complete.emit(stroke_count, par, points)

	var round_done : bool = GameState.is_round_complete()
	scorecard.show_hole_result(hole_num, stroke_count, par, points, round_done, GameState.get_score_vs_par(), GameState.get_total_strokes())

func _on_next_pressed() -> void:
	scorecard.visible = false
	if GameState.is_round_complete():
		GameState.new_round()
	_start_hole()

func _sink_ball() -> void:
	# The cup is real geometry now -- the ball has physically fallen between the
	# walls. Just kill any residual motion and settle it onto the floor centre,
	# then freeze. No collision tricks.
	ball.linear_velocity  = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO

	var target : Vector3 = Vector3(cup.global_position.x, cup.global_position.y - 0.18, cup.global_position.z)
	var tween  : Tween    = create_tween()
	tween.tween_property(ball, "global_position", target, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	ball.freeze = true

func _physics_process(_delta: float) -> void:
	if not is_active or _penalty_active:
		return

	var pos : Vector3 = ball.global_position

	# Water: replay from where the shot was struck (the wet shot already counted, +1
	# penalty here -> +2 total). Checked before the resting branch so a ball that settles
	# in a basin is still caught.
	if hole_gen.water_at(pos.x, pos.z, pos.y, _hole_data):
		_trigger_penalty(true)
		return

	if ball.is_resting:
		# If the ball rolled into the cup too fast to count and then settled without ever
		# leaving the zone, give it a second chance to sink.
		if cup.get_overlapping_bodies().has(ball):
			_on_cup_entered(ball)
		return

	var terrain_length : float = _hole_data.get("terrain_length", 300.0)
	var x_lim          : float = _hole_data.get("half_width", 55.0) + 5.0
	if pos.y < -6.0 or pos.x < -x_lim or pos.x > x_lim or pos.z < -10.0 or pos.z > terrain_length + 10.0:
		_trigger_penalty()

func _update_hud() -> void:
	lbl_strokes.text = "Strokes: %d" % stroke_count
	lbl_par.text     = "Par %d" % par
	lbl_hole.text    = "Hole %d / %d" % [GameState.current_hole, GameState.HOLES_PER_ROUND]
	lbl_points.text  = "%d pts" % SaveManager.data.get("points", 0)
