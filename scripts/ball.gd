extends RigidBody3D

signal ball_resting
signal entered_hazard
# Fired when the ball reflects off the turf on landing. `strength` is the into-surface impact
# speed (m/s); `surface` is the lie it struck. Carries no audio knowledge itself -- hole_manager
# turns it into a bounce SFX -- so ball.gd stays presentation-agnostic.
signal ball_bounced(strength: float, surface: String)

@onready var ground_ray: RayCast3D = $GroundRay
@onready var ball_mesh : MeshInstance3D = $BallMesh

const BALL_RADIUS      : float = 0.117
const RESTING_SPEED    : float = 0.35
# Derived from v = Ï‰Â·r (rolling without slipping) so this stays correct if BALL_RADIUS
# ever changes again -- a fixed constant here previously broke when the ball shrank.
const RESTING_ANGULAR  : float = (RESTING_SPEED / BALL_RADIUS) * 1.2
const RESTING_TIME     : float = 0.45
const SAFE_POS_INTERVAL: float = 0.5

# Shot-end watchdog. The ball is force-settled only when it has been BARELY moving for a
# while (creeping/jittering with nowhere to go) -- a genuine long roll is never cut off.
# HARD_CAP is a generous absolute backstop so a shot always terminates eventually.
const STUCK_SPEED      : float = 0.9
const STUCK_TIME       : float = 2.5
const HARD_CAP         : float = 30.0

# roll_resistance from balls.json is calibrated around this baseline (the starter
# ball's value) -- it scales the surface damp below rather than replacing it, so
# rarer low-resistance balls still roll noticeably farther on every surface.
const BASE_ROLL_RESISTANCE : float = 2.8

# Per-surface response. `bounce` is the normal-velocity restitution applied on landing
# (a controlled reflection about the smooth terrain normal -- see _physics_process);
# `linear`/`angular` are the rolling-friction damps once the ball is on the ground.
# Firmness governs both: fairway is firm so it bounces and runs, the green is receptive
# so it bounces low and checks, rough grabs and deadens, sand plugs almost completely.
const SURFACE : Dictionary = {
	"green":   {"bounce": 0.30, "linear": 0.22, "angular": 0.40},
	"fairway": {"bounce": 0.52, "linear": 0.55, "angular": 1.0},
	"rough":   {"bounce": 0.20, "linear": 1.8,  "angular": 3.0},
	"sand":    {"bounce": 0.04, "linear": 9.0,  "angular": 14.0},
}

# "Bounce depends on height of flight": a ball that flew high comes down fast, and turf
# absorbs proportionally more of a hard impact, so high shots sit while low skipping
# shots keep their bounce. Normal restitution is scaled down by impact speed and clamped
# so even a screamer keeps some life.
const REST_SPEED_FALLOFF : float = 0.012   # restitution lost per m/s of impact speed
const REST_MIN_SCALE     : float = 0.5

# A landing only counts as a bounce when the ball is moving into the surface faster than
# this; below it the ball is treated as rolling (no reflection) so it settles cleanly.
const BOUNCE_ARM_SPEED   : float = 0.8

# Fraction of tangential (sideways/forward) speed kept through a bounce -- the rest is
# scrubbed off as friction on contact.
const TANGENTIAL_KEEP    : float = 0.72

# How close (vertically) the ball centre must be to the smooth surface to count as in
# contact, and how near the cup we hand the ball back to the engine so it can fall in.
const CONTACT_EPS        : float = 0.06
const CUP_SKIP_R         : float = 1.6

var is_grounded  := false
var is_resting   := false
var in_sand      : bool    = false
var in_rough     : bool    = false
var last_safe_position := Vector3.ZERO
# Where the current shot was struck from -- a ball that finds water is replayed
# from here (stroke + distance), not from the rolling last_safe_position.
var shot_start_position := Vector3.ZERO

var distance_modifier : float = 1.0
var air_resistance    : float = 0.05
var roll_resistance   : float = 2.8
# Backspin shaping from the equipped ball: `mod` multiplies the club's backspin, `add` is a
# flat amount applied on any club so a "spinner" ball bites even off a driver (which has none).
var backspin_mod      : float = 1.0
var backspin_add      : float = 0.0

var _resting_timer : float = 0.0
var _safe_timer    : float = 0.0
var _flight_timer  : float = 0.0
var _stuck_timer   : float = 0.0
var _in_flight     : bool  = false
var _was_contact   : bool  = false
var _prev_vn       : float = 0.0   # normal-velocity last frame (catches engine pre-empting a bounce)
var _hole_gen      : Node
var _hole_data     : Dictionary = {}

func _ready() -> void:
	last_safe_position = global_position
	# The engine never bounces the ball: restitution is owned analytically in
	# _physics_process (reflected about the smooth terrain normal), so the faceted
	# collision mesh can no longer kick the ball off sideways/backwards.
	if physics_material_override == null:
		physics_material_override = PhysicsMaterial.new()
		physics_material_override.friction = 0.8
	else:
		physics_material_override = physics_material_override.duplicate()
	physics_material_override.bounce = 0.0
	var bd := EquipmentManager.get_equipped_ball()
	distance_modifier = bd.get("distance_modifier", 1.0)
	air_resistance    = bd.get("air_resistance",    0.05)
	roll_resistance   = bd.get("roll_resistance",   2.8)
	backspin_mod      = bd.get("backspin_mod",      1.0)
	backspin_add      = bd.get("backspin_add",      0.0)
	# The ball mesh ships with a fixed material in the scene; skin it from the equipped ball's
	# colour/pattern so the player actually sees the ball they bought.
	if ball_mesh != null:
		ItemVisuals.apply_ball_material(ball_mesh, bd)

func setup_terrain(hole_gen: Node, hole_data: Dictionary) -> void:
	_hole_gen  = hole_gen
	_hole_data = hole_data

func _physics_process(delta: float) -> void:
	if freeze:
		return

	var pos     : Vector3    = global_position
	var surface : String     = _surface_at(pos)
	in_sand  = (surface == "sand")
	in_rough = (surface == "rough")
	var resp    : Dictionary = SURFACE.get(surface, SURFACE["fairway"])

	var has_terrain : bool = _hole_gen != null and not _hole_data.is_empty()
	var near_cup    : bool = false
	if has_terrain:
		var cx : float = _hole_data.get("cup_x_off", 0.0)
		var cz : float = _hole_data.get("cup_z_w", 0.0)
		near_cup = Vector2(pos.x - cx, pos.z - cz).length() < CUP_SKIP_R

	var contact : bool    = false
	var n       : Vector3 = Vector3.UP
	if has_terrain:
		var h : float = _hole_gen.height_at(pos.x, pos.z, _hole_data)
		n = _hole_gen.surface_normal_at(pos.x, pos.z, _hole_data)
		contact = (pos.y - BALL_RADIUS) <= (h + CONTACT_EPS)
		var vn : float = linear_velocity.dot(n)

		# Landing: reflect the velocity about the SMOOTH normal so the bounce always goes
		# up-and-forward, never off a triangle edge. min() with last frame's normal speed
		# catches the case where the engine's contact already scrubbed the descent. Skipped
		# right at the cup so the ball can drop into the well (engine handles that contact).
		if contact and not _was_contact and not near_cup:
			var impact_vn : float = minf(vn, _prev_vn)
			if impact_vn < -BOUNCE_ARM_SPEED:
				var into : float = -impact_vn
				var rest : float = resp["bounce"] * clampf(1.0 - into * REST_SPEED_FALLOFF, REST_MIN_SCALE, 1.0)
				var tang : Vector3 = linear_velocity - n * vn
				linear_velocity = tang * TANGENTIAL_KEEP + n * (into * rest)
				# A ball pitching into sand plugs rather than skipping.
				if in_sand:
					linear_velocity *= 0.12
				# Lift clear of the surface so the engine doesn't re-resolve the contact.
				var gp : Vector3 = global_position
				gp.y = h + BALL_RADIUS + CONTACT_EPS
				global_position = gp
				ball_bounced.emit(into, surface)

		# Safety net against tunnelling. The faceted collider can let a fast ball punch
		# straight THROUGH the terrain -- most easily over the cup, where the terrain mesh is
		# cut away and the analytic bounce above is deliberately skipped, so a hard-arriving
		# ball passes the thin cup-well floor and drops into the void under the green (then
		# trips the out-of-bounds reset). If the ball is ever found below where it belongs,
		# snap it back up and kill the downward velocity so it can never sink out of the world.
		var min_y : float
		if near_cup:
			# Let the ball settle into the cup well, but never below its floor. cup_base_h is
			# the green surface at the cup; the well is ~0.65 m deep, so clamp just above that
			# floor -- low enough to read as holed (inside the cup trigger), high enough that a
			# hard-arriving ball can never punch on through into the void under the green.
			min_y = _hole_data.get("cup_base_h", h) - 0.6
		else:
			min_y = h + BALL_RADIUS
		if global_position.y < min_y:
			var gpc : Vector3 = global_position
			gpc.y = min_y
			global_position = gpc
			if linear_velocity.y < 0.0:
				linear_velocity.y = 0.0

	is_grounded  = contact
	_was_contact = contact
	_prev_vn     = linear_velocity.dot(n)

	# Rolling friction once grounded; light air drag while in flight.
	if is_grounded:
		var roll_scale : float = roll_resistance / BASE_ROLL_RESISTANCE
		linear_damp  = resp["linear"]  * roll_scale
		angular_damp = resp["angular"] * roll_scale
	else:
		linear_damp  = air_resistance
		angular_damp = air_resistance

	_update_safe(delta)
	_check_resting(delta)

func _surface_at(pos: Vector3) -> String:
	if _hole_gen == null:
		return "fairway"
	return _hole_gen.get_surface_type(pos.x, pos.z, _hole_data)

func _update_safe(delta: float) -> void:
	if is_grounded and not _in_flight:
		_safe_timer += delta
		if _safe_timer >= SAFE_POS_INTERVAL:
			last_safe_position = global_position
			_safe_timer = 0.0

func _check_resting(delta: float) -> void:
	# Resting is judged purely on velocity, not ground contact -- a flickering contact
	# test on bumpy terrain would otherwise reset this timer forever and the ball would
	# sit there making micro-movements without ever settling.
	var slow_enough : bool = linear_velocity.length() < RESTING_SPEED \
		and angular_velocity.length() < RESTING_ANGULAR
	if slow_enough:
		_resting_timer += delta
		if _resting_timer >= RESTING_TIME and not is_resting:
			_settle()
	else:
		_resting_timer = 0.0
		if is_resting:
			is_resting = false

	if _in_flight and not is_resting:
		# Watchdog: force a settle only once the ball has been barely moving for a while
		# (stuck/jittering) -- a fast or long roll never trips this.
		if linear_velocity.length() < STUCK_SPEED:
			_stuck_timer += delta
			if _stuck_timer >= STUCK_TIME:
				_settle()
		else:
			_stuck_timer = 0.0
		# Absolute backstop so a shot always ends eventually.
		_flight_timer += delta
		if _flight_timer >= HARD_CAP:
			_settle()
	else:
		_stuck_timer  = 0.0
		_flight_timer = 0.0

func _settle() -> void:
	is_resting       = true
	_in_flight        = false
	linear_velocity  = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	ball_resting.emit()

func apply_shot(direction: Vector3, power: float, club_power: float, backspin: float = 0.0) -> void:
	shot_start_position = global_position
	freeze        = false
	is_resting    = false
	_in_flight    = true
	_was_contact  = false
	_prev_vn      = 0.0
	_resting_timer = 0.0
	_safe_timer   = 0.0
	_stuck_timer  = 0.0
	_flight_timer = 0.0
	# A buried lie in a bunker robs the shot of distance: only ~70% of the ball speed
	# carries, and the sand smothers any spin, so there's no wedge bite to escape with.
	# Rough is less severe than sand but still grabby: the grass between clubface and ball
	# steals ~15% of the carry and kills the clean contact a wedge needs to put bite on it.
	var lie_factor : float = 1.0
	if in_sand:
		lie_factor = 0.7
	elif in_rough:
		lie_factor = 0.85
	apply_central_impulse(direction * power * club_power * distance_modifier * lie_factor)

	# The equipped ball reshapes the club's backspin: a spinner ball multiplies it and adds a
	# flat floor (so it bites off any club), a roller ball damps it. Sand/rough still kill spin.
	var eff_backspin : float = backspin * backspin_mod + backspin_add
	if eff_backspin > 0.001 and not in_sand and not in_rough:
		# Spin opposite the natural forward-roll axis so when the ball lands,
		# ground friction fights its forward motion instead of feeding it --
		# the "bite and stop" feel of a real wedge shot.
		var flat_dir : Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
		var spin_axis: Vector3 = flat_dir.cross(Vector3.UP).normalized()
		angular_velocity = spin_axis * eff_backspin * power

func reset_to_safe() -> void:
	_reset_to(last_safe_position)

func reset_to_shot_start() -> void:
	_reset_to(shot_start_position)

func _reset_to(pos: Vector3) -> void:
	# Unfreeze before teleporting: a ball that settled in the water is frozen (STATIC),
	# and assigning global_position to a frozen static body won't relocate the physics
	# body -- it would stay in the hazard. Re-frozen at the end once moved.
	freeze = false
	linear_velocity  = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position  = pos
	is_resting  = false
	in_sand     = false
	in_rough    = false
	_in_flight  = false
	_was_contact = false
	_prev_vn    = 0.0
	_resting_timer = 0.0
	_stuck_timer   = 0.0
	_flight_timer  = 0.0
	freeze = true
