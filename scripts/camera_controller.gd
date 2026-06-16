extends Camera3D

enum State { OVERVIEW, AIM, FOLLOWING, SETTLING }

const ORBIT_DIST  : float = 8.0
const ORBIT_H     : float = 4.5
const FOLLOW_LERP : float = 5.5
const SETTLE_LERP : float = 3.0
const ZOOM_LERP   : float = 3.0

var _state  : State = State.OVERVIEW
var _ball   : RigidBody3D
var _h_angle: float = 0.0
var _orbit_center := Vector3.ZERO

func setup(ball: RigidBody3D, hole_data: Dictionary) -> void:
	_ball  = ball
	_state = State.OVERVIEW
	_h_angle = 0.0

	var tee: Vector3 = hole_data["tee_position"]
	var cup: Vector3 = hole_data["cup_position"]
	var center := (tee + cup) * 0.5
	global_position = center + Vector3(0.0, 28.0, -25.0)
	look_at(center, Vector3.UP)

func switch_to_aim() -> void:
	_state = State.AIM
	_orbit_center = _ball.global_position
	_update_orbit()

func start_following() -> void:
	_state = State.FOLLOWING

func on_ball_resting() -> void:
	_state = State.SETTLING
	_orbit_center = _ball.global_position

func rotate_aim(delta_rad: float) -> void:
	_h_angle += delta_rad
	if _state == State.AIM:
		_update_orbit()

func get_aim_direction() -> Vector3:
	return Vector3(sin(_h_angle), 0.0, cos(_h_angle))

func _update_orbit() -> void:
	var offset := Vector3(
		sin(_h_angle) * -ORBIT_DIST,
		ORBIT_H,
		cos(_h_angle) * -ORBIT_DIST
	)
	global_position = _orbit_center + offset
	look_at(_orbit_center + Vector3(0.0, 0.5, 0.0), Vector3.UP)

func _physics_process(delta: float) -> void:
	if _ball == null:
		return
	match _state:
		State.FOLLOWING:
			var vel := _ball.linear_velocity
			var look_dir := vel.normalized() if vel.length() > 0.5 else get_aim_direction()
			var target := _ball.global_position \
				+ look_dir * (-ORBIT_DIST * 0.65) \
				+ Vector3(0.0, ORBIT_H * 0.85, 0.0)
			global_position = global_position.lerp(target, FOLLOW_LERP * delta)
			look_at(_ball.global_position + Vector3(0.0, 0.4, 0.0), Vector3.UP)
		State.SETTLING:
			_orbit_center = _orbit_center.lerp(_ball.global_position, SETTLE_LERP * delta)
			_update_orbit()
			if _orbit_center.distance_to(_ball.global_position) < 0.05:
				_state = State.AIM
