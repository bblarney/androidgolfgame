extends RigidBody2D

signal ball_resting
signal entered_hazard

@onready var ground_ray: RayCast2D = $GroundRay

const BALL_RADIUS := 18.0
const RESTING_SPEED := 28.0
const RESTING_CONFIRM_TIME := 0.4
const SAFE_POS_INTERVAL := 0.5

var is_grounded := false
var is_resting := false
var last_safe_position := Vector2.ZERO

var distance_modifier := 1.0
var air_resistance := 0.08
var roll_resistance := 1.2

var _resting_timer := 0.0
var _safe_pos_timer := 0.0
var _in_flight := false

func _ready() -> void:
	last_safe_position = global_position
	var ball_data := EquipmentManager.get_equipped_ball()
	distance_modifier = ball_data.get("distance_modifier", 1.0)
	air_resistance = ball_data.get("air_resistance", 0.08)
	roll_resistance = ball_data.get("roll_resistance", 1.2)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, BALL_RADIUS, Color.WHITE)
	draw_arc(Vector2.ZERO, BALL_RADIUS, 0.0, TAU, 32, Color(0.75, 0.75, 0.75), 2.5)

func _physics_process(delta: float) -> void:
	is_grounded = ground_ray.is_colliding()
	linear_damp = roll_resistance if is_grounded else air_resistance
	_update_safe_position(delta)
	_check_resting(delta)

func _update_safe_position(delta: float) -> void:
	if is_grounded and not _in_flight:
		_safe_pos_timer += delta
		if _safe_pos_timer >= SAFE_POS_INTERVAL:
			last_safe_position = global_position
			_safe_pos_timer = 0.0

func _check_resting(delta: float) -> void:
	if linear_velocity.length() < RESTING_SPEED and is_grounded:
		_resting_timer += delta
		if _resting_timer >= RESTING_CONFIRM_TIME and not is_resting:
			is_resting = true
			_in_flight = false
			ball_resting.emit()
	else:
		_resting_timer = 0.0
		if is_resting:
			is_resting = false

func apply_shot(direction: Vector2, power: float, club_power: float) -> void:
	is_resting = false
	_in_flight = true
	_resting_timer = 0.0
	_safe_pos_timer = 0.0
	apply_central_impulse(direction * power * club_power * distance_modifier)

func reset_to_safe() -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	global_position = last_safe_position
	is_resting = false
	_in_flight = false
	_resting_timer = 0.0
