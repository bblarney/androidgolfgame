extends Camera2D

enum State { OVERVIEW, FOLLOWING, RESTING }

const FOLLOW_LERP  := 7.0
const RESTING_LERP := 3.0
const ZOOM_OVERVIEW := 0.30
const ZOOM_PLAY     := 0.62
const ZOOM_SPEED    := 4.0

var _state   := State.OVERVIEW
var _ball    : RigidBody2D
var _target_zoom := ZOOM_OVERVIEW

func setup(ball: RigidBody2D, hole_data: Dictionary) -> void:
	_ball = ball
	_state = State.OVERVIEW
	_target_zoom = ZOOM_OVERVIEW
	zoom = Vector2(ZOOM_OVERVIEW, ZOOM_OVERVIEW)

	var tee: Vector2 = hole_data["tee_position"]
	var cup: Vector2 = hole_data["cup_position"]
	global_position = (tee + cup) * 0.5

func start_following() -> void:
	_state = State.FOLLOWING
	_target_zoom = ZOOM_PLAY

func on_ball_resting() -> void:
	_state = State.RESTING

func _physics_process(delta: float) -> void:
	if _ball == null:
		return

	# Smooth zoom
	zoom = zoom.lerp(Vector2(_target_zoom, _target_zoom), ZOOM_SPEED * delta)

	match _state:
		State.OVERVIEW:
			pass
		State.FOLLOWING:
			global_position = global_position.lerp(_ball.global_position, FOLLOW_LERP * delta)
		State.RESTING:
			global_position = global_position.lerp(_ball.global_position, RESTING_LERP * delta)
