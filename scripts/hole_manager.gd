extends Node

signal hole_complete(strokes: int, par: int, points_earned: int)

const ClubVisual = preload("res://scripts/club_visual.gd")
const UI = preload("res://scripts/ui_palette.gd")

@onready var ball          : RigidBody3D = $"../Ball"
@onready var cup           : Area3D      = $"../Cup"
@onready var course        : Node3D      = $"../Course"
@onready var camera        : Camera3D    = $"../Camera"
@onready var aim_indicator : Control     = $"../HUD/AimIndicator"
@onready var input_handler : Node        = $"../InputHandler"
@onready var hole_gen      : Node        = $"../HoleGenerator"
@onready var lbl_strokes   : Label         = $"../HUD/InfoCard/VBox/StrokeLabel"
@onready var lbl_holepar   : Label         = $"../HUD/TopStrip/HoleParLabel"
@onready var lbl_points    : Label         = $"../HUD/InfoCard/VBox/Line2/PointsLabel"
@onready var lbl_hazard    : Label         = $"../HUD/HazardBanner/HazardLabel"
@onready var lbl_lie       : Label         = $"../HUD/InfoCard/VBox/Line2/LieLabel"
@onready var info_card     : PanelContainer = $"../HUD/InfoCard"
@onready var hazard_banner : PanelContainer = $"../HUD/HazardBanner"
@onready var top_strip     : Control       = $"../HUD/TopStrip"
@onready var scorecard     : Control     = $"../HUD/ScoreCard"
@onready var tourney_bug    : Control     = $"../HUD/TournamentScorebug"
@onready var exit_button   : Button      = $"../HUD/ExitButton"
@onready var exit_dialog   : ConfirmationDialog = $"../HUD/ExitDialog"

var stroke_count     : int  = 0
# Last strokes value shown in the HUD, so _update_hud only plays the count-up pop on a real
# increment (not on the reset to 0 that opens each hole).
var _last_strokes_shown : int = 0
var par              : int  = 4
var is_active        : bool = false
var _hole_data       : Dictionary = {}
var _penalty_active  : bool = false
var club             : Node3D
# The shared Environment, kept so per-hole code can retune the haze for the current biome.
var _env             : Environment

func _ready() -> void:
	_setup_environment()
	# The club lives on the persistent Hole root (NOT under Course, which is rebuilt every
	# hole) so it survives across holes.
	club = ClubVisual.new()
	club.name = "ClubVisual"
	# Deferred for the same reason as the environment nodes below: the parent is mid
	# child-setup during _ready, so a direct add_child() is blocked.
	get_parent().add_child.call_deferred(club)
	_style_hud()
	_connect_signals()
	_start_hole()

# Apply the shared broadcast styling to the HUD chrome once. The translucent cards and pill
# button come from UiPalette so every overlay element reads as one cohesive layer.
func _style_hud() -> void:
	info_card.add_theme_stylebox_override("panel", UI.card_style(4.0))
	hazard_banner.add_theme_stylebox_override("panel", UI.card_style())
	UI.style_button(exit_button, false)

func _setup_environment() -> void:
	# A hand-written sky shader (res://shaders/sky.gdshader): vertical gradient + glowing
	# sun disk + drifting procedural clouds. ProceduralSkyMaterial -- the old approach --
	# has no clouds and renders as a near-flat blue-grey, which is what we're replacing.
	# Set once: the WorldEnvironment is not rebuilt per hole.
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	# The sun_direction uniform is set further down from the DirectionalLight3D so the
	# painted sun disk and the actual lighting direction always agree.
	var sky := Sky.new()
	sky.sky_material = sky_mat
	# Cheap radiance: ambient/reflections come from an explicit colour (below), not the
	# sky, so we don't need a high-res cubemap and can keep the animated sky affordable.
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode  = Sky.PROCESS_MODE_INCREMENTAL

	var env_node := WorldEnvironment.new()
	var env      := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky             = sky
	# Ambient stays an explicit COLOUR rather than AMBIENT_SOURCE_SKY: the Mobile renderer
	# has limited sky-based ambient/reflection support, and sky ambient there can collapse
	# to near-black, leaving the scene lit only by the sun (which made dark props like the
	# club head disappear). An explicit ambient colour is mobile-safe and matches the sky.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.62, 0.70, 0.84)
	# Ambient was 0.55 -- nearly half the sun's strength. That much flat fill washed out the
	# directional shading on the gently-rolling fairway/rough and softened cast shadows, so
	# sun-and-shadow only read where the relief is strong (the raised tee/green pads and their
	# lips). Dropping the fill lets the sun dominate, so shading and shadows appear across the
	# whole course; the sun energy below is raised to keep overall brightness up.
	env.ambient_light_energy = 0.25
	# Filmic tonemapping (with a hair under 1.0 exposure) rolls off the highlights instead of
	# letting bright turf/sand clip to flat blocks the way the default LINEAR tonemap does. This
	# is the main "realism" lever: it desaturates and softens the top end so nothing glows.
	env.tonemap_mode     = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white    = 1.0
	# Depth fog -- the keystone of the "not a floating island" illusion. The far end of the
	# hole, the surrounding apron and the perimeter treeline (both built in hole_generator)
	# all dissolve into this haze instead of cutting off against the void. Plain DEPTH fog,
	# NOT volumetric: volumetrics are costly and unsupported on the Mobile renderer.
	# fog_light_color matches the sky shader's sky_horizon_color so terrain blends into the
	# real horizon. begin/end keep the play area (camera orbits ~8 m from the ball) crisp
	# while everything past ~70 m softens and the far edge past ~220 m is fully hazed.
	env.fog_enabled            = true
	env.fog_mode               = Environment.FOG_MODE_DEPTH
	env.fog_light_color        = Color(0.66, 0.83, 0.95)
	env.fog_depth_begin        = 70.0
	env.fog_depth_end          = 220.0
	env.fog_sky_affect         = 0.3
	env.fog_aerial_perspective = 0.6
	_env = env   # retuned per hole by _apply_biome_atmosphere
	env_node.environment = env
	# _ready runs while our parent is still setting up its own children, so a direct
	# add_child() on it is blocked ("parent node is busy"). Defer until that pass ends.
	get_parent().add_child.call_deferred(env_node)

	# Sun elevation. A previous value of -22 deg put the sun only ~22 deg above the horizon;
	# the rolling heightmap (control-point relief + the per-cell ripple in _gen_heights) has
	# slopes in that same 8-20 deg band, so the lee side of every roll fell into self-shadow.
	# The whole rolling surface then read as dim, flat and shadow-speckled, while the only
	# *flattened* surfaces -- the tee pad and green pad -- stayed cleanly lit. Raising the sun
	# well above the terrain's slopes lets direct light reach the fairway/rough like the pads.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy     = 1.2
	sun.shadow_enabled   = true
	# Shadow range is deliberately SHORT. The camera always orbits ~8 m from the ball, so all
	# the shadows that matter (the ball, the club, nearby trees) sit close to it. Spreading
	# the atlas over the whole 300 m+ hole left only a few texels per metre near the camera,
	# so the ball's tiny (~0.2 m) shadow rendered smaller than a texel and disappeared -- only
	# the 3 m flagstick was tall enough to still show. Concentrating the same atlas over a
	# small radius gives the play area enough resolution to render small-object shadows.
	sun.directional_shadow_max_distance = 90.0
	# Tighter normal bias so the small ball/club shadows stay attached to the ground instead
	# of "peter-panning" off it. (The earlier large pancake_size override did the opposite --
	# it culled thin objects out of the shadow pass entirely -- so it's gone.)
	sun.shadow_normal_bias = 0.5
	# The shader paints the sun, so the light itself must NOT also add a sky disk.
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	get_parent().add_child.call_deferred(sun)

	# Point the shader's painted sun toward where the light comes FROM. A DirectionalLight
	# shines along its local -Z, so the sun sits in the opposite direction (+Z basis).
	# Derived from the Euler rotation rather than global_transform, which isn't valid until
	# the deferred add_child above has actually run.
	var sun_basis := Basis.from_euler(sun.rotation)
	sky_mat.set_shader_parameter("sun_direction", sun_basis.z)

# Retune the depth haze for the current biome. Alpine reads as thin, cold mountain air: a
# paler blue-white fog that begins closer and washes the distance out sooner than the default
# lowland haze, so the far peaks dissolve into a cold sky. Every other biome uses the default.
func _apply_biome_atmosphere(biome: String) -> void:
	if _env == null:
		return
	if biome == "alpine":
		_env.fog_light_color = Color(0.82, 0.88, 0.95)
		_env.fog_depth_begin = 55.0
		_env.fog_depth_end   = 190.0
	else:
		_env.fog_light_color = Color(0.66, 0.83, 0.95)
		_env.fog_depth_begin = 70.0
		_env.fog_depth_end   = 220.0

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
	exit_button.pressed.connect(func() -> void: exit_dialog.popup_centered())
	exit_dialog.confirmed.connect(_on_exit_confirmed)

func _on_exit_confirmed() -> void:
	# Save wherever the round stands so CONTINUE can pick it back up, then route home through the
	# loading screen. A tournament day is stashed in its own slot (so a later casual round can't
	# clobber it) and returns the player to the hub instead of the main menu.
	if GameState.game_mode == "tournament":
		TournamentManager.save_round_snapshot()
		SceneManager.goto(SceneManager.TOURNAMENT_HUB)
		return
	GameState.save_progress()
	SceneManager.goto(SceneManager.MAIN_MENU)

func _start_hole() -> void:
	for child in course.get_children():
		child.queue_free()

	_hole_data   = hole_gen.generate_hole(GameState.get_hole_seed(), GameState.get_hole_biome())
	_apply_biome_atmosphere(_hole_data.get("biome", "parkland"))
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
	# Values track hole_generator.gd's CUP_RADIUS (0.45) and CUP_DEPTH (0.55).
	var cup_shape : CylinderShape3D = $"../Cup/CupShape".shape
	cup_shape.radius = 0.41
	cup_shape.height = 0.55

	# Water and sand are both carved terrain now, detected by ball position each frame
	# (water via hole_gen.water_at, sand via get_surface_type) -- no Area3D wiring needed.
	_update_hud()
	_intro_hud()
	# The live field leaderboard only exists in tournament play; refresh it to the resumed/
	# carried standings as each hole opens.
	tourney_bug.visible = GameState.game_mode == "tournament"
	if tourney_bug.visible:
		tourney_bug.refresh()
	camera.setup(ball, _hole_data)
	input_handler.setup(ball, camera)

	await get_tree().create_timer(2.0).timeout
	camera.switch_to_aim()
	input_handler.can_shoot = true
	club.show_at(ball.global_position)
	_update_lie()

func _on_shot_taken(direction: Vector3, power: float) -> void:
	aim_indicator.clear_aim()
	club.play_swing()
	# Hide the tee peg the moment the ball is struck so it isn't left under the flying ball.
	# It is NOT freed: if this shot is penalised back to the tee, the ball re-tees and the
	# peg is shown again (see _refresh_tee_peg).
	var peg : Node3D = course.get_node_or_null("TeeBox/TeePeg")
	if peg != null:
		peg.visible = false
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
		_update_lie()

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
	_refresh_tee_peg()
	# Move the club to the ball's new (reset) spot. A frozen reset never emits ball_resting,
	# so without this the club stays stranded at the previous shot location and the next aim
	# (set_aim only re-orients, it doesn't reposition) shows it there instead of at the ball.
	club.show_at(ball.global_position)
	_update_lie()
	camera.switch_to_aim()
	await get_tree().create_timer(0.7).timeout
	_penalty_active = false
	if is_active:
		input_handler.can_shoot = true

func _trigger_water_penalty() -> void:
	if _penalty_active or not is_active:
		return
	_penalty_active = true
	input_handler.can_shoot = false
	stroke_count += 1
	_update_hud()
	# The ball has already settled in the basin (water is judged at rest now); hold the
	# penalty message on it where it lies, then replay from where the shot was struck.
	lbl_hazard.text = "WATER HAZARD   +1"
	hazard_banner.visible = true
	var tin := create_tween()
	tin.tween_property(hazard_banner, "modulate:a", 1.0, 0.25)
	await get_tree().create_timer(2.5).timeout
	# Fade out without blocking the replay below, so the ball re-tees on the same cadence as before.
	var tout := create_tween()
	tout.tween_property(hazard_banner, "modulate:a", 0.0, 0.3)
	tout.tween_callback(func() -> void: hazard_banner.visible = false)
	ball.reset_to_shot_start()
	_refresh_tee_peg()
	# See _trigger_penalty: reposition the club onto the replayed ball so it isn't left
	# rendering at the spot the wet shot was struck from.
	club.show_at(ball.global_position)
	_update_lie()
	camera.switch_to_aim()
	_penalty_active = false
	if is_active:
		input_handler.can_shoot = true

# Show the tee peg only while the ball is actually teed up (resting on the tee). Called after
# a penalty reset: if the stroke is replayed from the tee the ball re-tees and the peg
# reappears under it; from anywhere else the peg stays hidden so the ball sits on the turf.
func _refresh_tee_peg() -> void:
	var peg : Node3D = course.get_node_or_null("TeeBox/TeePeg")
	if peg != null:
		peg.visible = ball.global_position.distance_to(_hole_data["tee_position"]) < 0.5

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
	# Practice earns nothing (and records no stats); scored modes bank points + stats.
	var points   : int = SaveManager.record_hole_complete(stroke_count, par) if GameState.award_points else 0
	GameState.record_hole(stroke_count, par)
	hole_complete.emit(stroke_count, par, points)

	var tournament : bool = GameState.game_mode == "tournament"
	if tournament:
		# Simulate the field's score on this hole, then refresh the live leaderboard.
		TournamentManager.record_player_hole(par)
		tourney_bug.refresh()

	var round_done : bool = GameState.is_round_complete()
	if round_done:
		if tournament:
			# Fold the day into the running totals; the cut is applied later in the hub. Also
			# clear the casual in-progress flag so the main menu's CONTINUE doesn't offer this
			# finished day (the tournament keeps its own round slot for resuming mid-play).
			TournamentManager.finish_day()
			GameState.clear_round()
		else:
			# Record the round's stats (rounds_played / best_round_score) -- previously never
			# wired up -- then clear the in-progress flag so CONTINUE no longer offers it.
			SaveManager.record_round_complete(GameState.get_total_strokes(), GameState.get_total_par())
			GameState.clear_round()
	scorecard.show_hole_result(hole_num, stroke_count, par, points, round_done, GameState.get_score_vs_par(), GameState.get_total_strokes())

func _on_next_pressed() -> void:
	scorecard.visible = false
	# A finished 9/18 round returns to the menu; a finished tournament day returns to the hub
	# (which shows the leaderboard + cut). Practice (never "complete") and mid-round holes just
	# advance to the next hole.
	if GameState.is_round_complete():
		if GameState.game_mode == "tournament":
			SceneManager.goto(SceneManager.TOURNAMENT_HUB)
		else:
			SceneManager.goto(SceneManager.MAIN_MENU)
		return
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

	if ball.is_resting:
		# Water is judged only once the ball has settled: a shot that skips across the
		# hazard or bounces off the bank and comes to rest on dry land is legal and must
		# NOT be penalised. Only a ball that finally settles in the water counts -- replay
		# from where the shot was struck (the wet shot already counted, +1 here -> +2 total).
		if hole_gen.water_at(pos.x, pos.z, pos.y, _hole_data):
			_trigger_water_penalty()
			return
		# If the ball rolled into the cup too fast to count and then settled without ever
		# leaving the zone, give it a second chance to sink.
		if cup.get_overlapping_bodies().has(ball):
			_on_cup_entered(ball)
		return

	var terrain_length : float = _hole_data.get("terrain_length", 300.0)
	var x_lim          : float = _hole_data.get("half_width", 55.0) + 5.0
	# "Fell out of the world" must be judged RELATIVE to the local ground, not a fixed world
	# height: on a downhill hole the legitimate green/fairway can sit several metres below y=0,
	# and a fixed floor (was y < -6) reset every ball that landed there. Only a ball well below
	# the surface at its own xz has genuinely tunnelled into the void.
	var surf_h : float = hole_gen.height_at(pos.x, pos.z, _hole_data)
	if pos.y < surf_h - 5.0 or pos.x < -x_lim or pos.x > x_lim or pos.z < -10.0 or pos.z > terrain_length + 10.0:
		_trigger_penalty()

# Reports the surface the ball is sitting on so the player knows what they're hitting from.
# "Tee" is a special case: it isn't a distinct surface type (the tee pad classifies as
# fairway), so it's detected by proximity to the tee position while teed up.
func _update_lie() -> void:
	var pos     : Vector3 = ball.global_position
	var surface : String  = hole_gen.get_surface_type(pos.x, pos.z, _hole_data)
	var teed_up : bool    = pos.distance_to(_hole_data.get("tee_position", Vector3.ONE * 9999.0)) < 1.0

	# Tee is reported as fairway by the surface query, so flag it separately for the lie colour.
	var lie_key  : String = "tee" if teed_up else surface
	var lie_name : String = lie_key.capitalize() if UI.LIE_COLORS.has(lie_key) else "Rough"
	lbl_lie.text = lie_name
	lbl_lie.add_theme_color_override("font_color", UI.lie_color(lie_key))

func _update_hud() -> void:
	lbl_strokes.text = "STROKES  %d" % stroke_count
	if stroke_count > _last_strokes_shown:
		_pop_label(lbl_strokes)
	_last_strokes_shown = stroke_count
	if GameState.game_mode == "practice":
		lbl_holepar.text = "PRACTICE  ·  HOLE %d  ·  PAR %d" % [GameState.current_hole, par]
		lbl_points.text  = "Practice"
	elif GameState.game_mode == "tournament":
		# Tournaments earn no points; the points line carries the day name instead.
		lbl_holepar.text = "HOLE %d / %d  ·  PAR %d" % [GameState.current_hole, GameState.holes_per_round, par]
		lbl_points.text  = TournamentManager.day_name()
	else:
		lbl_holepar.text = "HOLE %d / %d  ·  PAR %d" % [GameState.current_hole, GameState.holes_per_round, par]
		lbl_points.text  = "%d pts" % SaveManager.data.get("points", 0)

# Soft fade-in of the HUD chrome as each hole opens, so it doesn't snap into place.
func _intro_hud() -> void:
	for n : CanvasItem in [top_strip, info_card]:
		n.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.05)
		tw.tween_property(n, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Quick scale-pop used when a value changes (e.g. stroke count ticks up) for a bit of life.
func _pop_label(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(1.18, 1.18)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
