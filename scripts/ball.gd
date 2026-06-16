extends RigidBody3D

signal ball_resting
signal entered_hazard

@onready var ground_ray: RayCast3D = $GroundRay

const BALL_RADIUS      : float = 0.35
const RESTING_SPEED    : float = 0.35
const RESTING_TIME     : float = 0.45
const SAFE_POS_INTERVAL: float = 0.5

var is_grounded  := false
var is_resting   := false
var last_safe_position := Vector3.ZERO

var distance_modifier : float = 1.0
var air_resistance    : float = 0.05
var roll_resistance   : float = 2.8

var _resting_timer : float = 0.0
var _safe_timer    : float = 0.0
var _in_flight     : bool  = false

func _ready() -> void:
	last_safe_position = global_position
	var bd := EquipmentManager.get_equipped_ball()
	distance_modifier = bd.get("distance_modifier", 1.0)
	air_resistance    = bd.get("air_resistance",    0.05)
	roll_resistance   = bd.get("roll_resistance",   2.8)

func _physics_process(delta: float) -> void:
	is_grounded  = ground_ray.is_colliding()
	linear_damp  = roll_resistance if is_grounded else air_resistance
	_update_safe(delta)
	_check_resting(delta)

func _update_safe(delta: float) -> void:
	if is_grounded and not _in_flight:
		_safe_timer += delta
		if _safe_timer >= SAFE_POS_INTERVAL:
			last_safe_position = global_position
			_safe_timer = 0.0

func _check_resting(delta: float) -> void:
	if linear_velocity.length() < RESTING_SPEED and is_grounded:
		_resting_timer += delta
		if _resting_timer >= RESTING_TIME and not is_resting:
			is_resting = true
			_in_flight = false
			ball_resting.emit()
	else:
		_resting_timer = 0.0
		if is_resting:
			is_resting = false

func apply_shot(direction: Vector3, power: float, club_power: float) -> void:
	is_resting    = false
	_in_flight    = true
	_resting_timer = 0.0
	_safe_timer   = 0.0
	apply_central_impulse(direction * power * club_power * distance_modifier)

func reset_to_safe() -> void:
	linear_velocity  = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position  = last_safe_position
	is_resting  = false
	_in_flight  = false
	_resting_timer = 0.0
