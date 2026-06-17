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

	var tee : Vector3 = hole_data["tee_position"]
	var cup : Vector3 = hole_data.get("cup_pos_surface", hole_data["cup_position"])
	# Look down the line of play. On a dogleg the spine midpoint sits over the
	# fairway bend, which frames the hole far better than the straight tee->cup line.
	var mid : Vector3
	var spine : PackedVector2Array = hole_data.get("spine", PackedVector2Array())
	if spine.size() >= 2:
		var s : Vector2 = spine[spine.size() / 2]
		mid = Vector3(s.x, (tee.y + cup.y) * 0.5, s.y)
	else:
		mid = (tee + cup) * 0.5
	# Stand 16 units behind the tee, elevated, looking down the full fairway
	global_position = Vector3(tee.x, 22.0, tee.z - 16.0)
	look_at(mid + Vector3(0.0, 2.0, 0.0), Vector3.UP)

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
			var vel     := _ball.linear_velocity
			# Flatten to XZ so the camera height stays stable throughout the arc --
			# using the full 3D velocity makes the camera pitch steeply up on launch
			# and swing down during descent as the Y component dominates.
			var flat_vel := Vector3(vel.x, 0.0, vel.z)
			var look_dir := flat_vel.normalized() if flat_vel.length() > 1.5 else get_aim_direction()
			var target   := _ball.global_position \
				+ look_dir * (-ORBIT_DIST * 0.65) \
				+ Vector3(0.0, ORBIT_H * 0.85, 0.0)
			global_position = global_position.lerp(target, FOLLOW_LERP * delta)
			look_at(_ball.global_position + Vector3(0.0, 0.4, 0.0), Vector3.UP)
		State.SETTLING:
			_orbit_center = _orbit_center.lerp(_ball.global_position, SETTLE_LERP * delta)
			_update_orbit()
			if _orbit_center.distance_to(_ball.global_position) < 0.05:
				_state = State.AIM
