extends CharacterBody3D
class_name FootballGoalkeeper

signal shot_saved(team: String)

@export var team: String = "away"
@export var goal_z: float = -25.7
@export var facing_z: float = 1.0
@export var patrol_range: float = 3.0
@export var move_speed: float = 5.2
@export var dive_speed: float = 9.2
@export var save_distance: float = 1.65

var ball: RigidBody3D
var home_position: Vector3 = Vector3.ZERO
var facing: Vector3 = Vector3(0, 0, 1)
var is_diving: bool = false
var dive_direction: Vector3 = Vector3.ZERO
var dive_timer: float = 0.0
var dive_duration: float = 0.6
var recover_timer: float = 0.0
var has_ball: bool = false
var hold_ball_timer: float = 0.0
var kick_cooldown: float = 0.0
var gait_phase: float = 0.0
var distribution_targets: Array = []
var distribution_requested: bool = false

var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var torso: Node3D

func _ready() -> void:
	home_position = global_position
	facing = Vector3(0.0, 0.0, facing_z).normalized()
	rotation.y = atan2(-facing.x, -facing.z)
	_cache_nodes()

func _cache_nodes() -> void:
	left_leg = get_node_or_null("LeftLeg") as Node3D
	right_leg = get_node_or_null("RightLeg") as Node3D
	left_arm = get_node_or_null("LeftArm") as Node3D
	right_arm = get_node_or_null("RightArm") as Node3D
	torso = get_node_or_null("Torso") as Node3D

func _process(delta: float) -> void:
	if left_leg == null:
		_cache_nodes()

	if is_diving:
		var dive_angle: float = -dive_direction.x * 0.85 * facing_z
		rotation.z = move_toward(rotation.z, dive_angle, delta * 9.0)
		if is_instance_valid(left_arm) and is_instance_valid(right_arm):
			var reach_x: float = dive_direction.x * 0.9 * facing_z
			left_arm.rotation.z = reach_x - 0.3
			right_arm.rotation.z = reach_x + 0.3
			left_arm.rotation.x = -0.6
			right_arm.rotation.x = -0.6
		return

	rotation.z = move_toward(rotation.z, 0.0, delta * 6.0)

	var movement_speed := Vector2(velocity.x, velocity.z).length()
	var movement_blend := clampf(movement_speed / move_speed, 0.0, 1.0)
	if movement_blend > 0.02:
		gait_phase += movement_speed * 1.6 * delta
	var leg_swing := sin(gait_phase) * 0.42 * movement_blend
	var arm_swing := -leg_swing * 0.5

	if is_instance_valid(left_leg):
		left_leg.rotation.x = move_toward(left_leg.rotation.x, leg_swing, delta * 7.0)
	if is_instance_valid(right_leg):
		right_leg.rotation.x = move_toward(right_leg.rotation.x, -leg_swing, delta * 7.0)
	if is_instance_valid(left_arm):
		left_arm.rotation.x = move_toward(left_arm.rotation.x, arm_swing, delta * 7.0)
		left_arm.rotation.z = -0.25
	if is_instance_valid(right_arm):
		right_arm.rotation.x = move_toward(right_arm.rotation.x, -arm_swing, delta * 7.0)
		right_arm.rotation.z = 0.25

func _physics_process(delta: float) -> void:
	kick_cooldown = maxf(0.0, kick_cooldown - delta)

	if not is_instance_valid(ball):
		return

	if has_ball:
		_process_held_ball(delta)
		return

	if recover_timer > 0.0:
		recover_timer = maxf(0.0, recover_timer - delta)
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		move_and_slide()
		return

	if is_diving:
		_process_dive(delta)
		return

	_process_patrol_and_threat(delta)

func _process_held_ball(delta: float) -> void:
	ball.global_position = global_position + facing * 0.8 + Vector3.UP * 0.95
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	if distribution_requested:
		distribution_requested = false
		_distribute_ball()
		return
	hold_ball_timer -= delta
	if hold_ball_timer <= 0.0:
		_clear_ball()

func request_distribution() -> void:
	if has_ball:
		distribution_requested = true

func _distribute_ball() -> void:
	var target: Node3D
	var best_score := -INF
	for teammate: CharacterBody3D in distribution_targets:
		if not is_instance_valid(teammate):
			continue
		var offset: Vector3 = teammate.global_position - global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance < 3.0 or distance > 24.0:
			continue
		var forward_score := facing.dot(offset.normalized())
		var score := forward_score * 10.0 - distance * 0.12
		if score > best_score:
			best_score = score
			target = teammate
	has_ball = false
	ball.freeze = false
	ball.remove_meta("owner")
	var target_position := global_position + facing * 10.0
	if is_instance_valid(target):
		target_position = target.global_position + target.velocity * 0.25
	var direction := target_position - global_position
	direction.y = 0.0
	direction = direction.normalized()
	ball.global_position = global_position + direction * 1.0 + Vector3.UP * 0.55
	ball.linear_velocity = direction * 12.0 + Vector3.UP * 2.4
	ball.angular_velocity = direction.cross(Vector3.UP) * 8.0
	kick_cooldown = 1.0
	recover_timer = 0.35

func _clear_ball() -> void:
	has_ball = false
	ball.freeze = false
	ball.remove_meta("owner")
	ball.global_position = global_position + facing * 1.2 + Vector3.UP * 0.6
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	var clear_dir := facing + Vector3(randf_range(-0.25, 0.25), 0.0, 0.0)
	clear_dir = clear_dir.normalized()
	ball.apply_central_impulse(clear_dir * 18.5 + Vector3.UP * 4.2)
	kick_cooldown = 2.0
	recover_timer = 0.5

func _process_dive(delta: float) -> void:
	dive_timer -= delta
	velocity = dive_direction * dive_speed

	var to_ball := ball.global_position - global_position
	if to_ball.length() < save_distance:
		_perform_save()
		return

	if dive_timer <= 0.0:
		is_diving = false
		recover_timer = 0.5
		velocity = Vector3.ZERO

	move_and_slide()

func _process_patrol_and_threat(delta: float) -> void:
	var to_goal_z := (goal_z - ball.global_position.z)
	var moving_towards_goal: bool = false
	if goal_z < 0.0:
		moving_towards_goal = ball.linear_velocity.z < -4.5 and ball.global_position.z < -3.0
	else:
		moving_towards_goal = ball.linear_velocity.z > 4.5 and ball.global_position.z > 3.0

	var dist_z := absf(to_goal_z)
	var threat_detected: bool = false

	if moving_towards_goal and dist_z < 22.0:
		var speed_z := absf(ball.linear_velocity.z)
		var time_to_goal := dist_z / maxf(1.0, speed_z)
		var predicted_x := ball.global_position.x + ball.linear_velocity.x * time_to_goal
		if absf(predicted_x) < 3.7 and time_to_goal < 1.3:
			threat_detected = true
			var x_diff := predicted_x - global_position.x
			if absf(x_diff) > 0.75:
				_trigger_dive(signf(x_diff), time_to_goal)
				return

	var target_x: float = clampf(ball.global_position.x * 0.65, -patrol_range, patrol_range)
	var target_pos := Vector3(target_x, 0.1, home_position.z)

	var dist_to_ball := global_position.distance_to(ball.global_position)
	var ball_owner: String = str(ball.get_meta("owner", ""))
	var penalty_box_z: bool = (goal_z < 0.0 and ball.global_position.z < -18.0) or (goal_z > 0.0 and ball.global_position.z > 18.0)

	if ball_owner == "" and penalty_box_z and dist_to_ball < 4.2 and absf(ball.global_position.x) < 5.0:
		target_pos = ball.global_position
		if dist_to_ball < 1.4:
			_catch_ball()
			return

	if dist_to_ball < save_distance and absf(ball.linear_velocity.z) > 3.0:
		_perform_save()
		return

	var move_vec := target_pos - global_position
	move_vec.y = 0.0

	if move_vec.length() > 0.15:
		velocity.x = move_toward(velocity.x, move_vec.normalized().x * move_speed, 20.0 * delta)
		velocity.z = move_toward(velocity.z, move_vec.normalized().z * move_speed, 20.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)

	move_and_slide()

func _trigger_dive(dir_x: float, time_to_goal: float) -> void:
	is_diving = true
	dive_direction = Vector3(dir_x, 0.0, 0.0)
	dive_timer = minf(time_to_goal + 0.25, dive_duration)

func _perform_save() -> void:
	shot_saved.emit(team)
	if ball.linear_velocity.length() < 16.0 and randf() < 0.45:
		_catch_ball()
	else:
		_parry_ball()

func _catch_ball() -> void:
	has_ball = true
	hold_ball_timer = 0.85
	is_diving = false
	recover_timer = 0.0
	velocity = Vector3.ZERO
	ball.freeze = true
	ball.set_meta("owner", name)
	shot_saved.emit(team)

func _parry_ball() -> void:
	is_diving = false
	recover_timer = 0.6
	velocity = Vector3.ZERO
	var deflect_dir := (ball.global_position - global_position).normalized()
	deflect_dir.z = facing_z * 0.7
	deflect_dir.y = 0.35
	deflect_dir = deflect_dir.normalized()
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.apply_central_impulse(deflect_dir * 12.0)
	kick_cooldown = 1.0

func reset_position() -> void:
	is_diving = false
	has_ball = false
	dive_timer = 0.0
	recover_timer = 0.0
	hold_ball_timer = 0.0
	distribution_requested = false
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	rotation.y = atan2(-facing.x, -facing.z)
	global_position = home_position
