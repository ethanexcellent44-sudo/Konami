extends CharacterBody3D
class_name FootballOpponent

signal ball_kicked(power_ratio: float)
signal slide_started()
signal foul_committed(position: Vector3)

@export var move_speed: float = 5.4
@export var acceleration: float = 15.0
@export var steal_distance: float = 1.35
@export var shooting_distance: float = 9.0
@export var role: String = "striker" # "striker", "midfielder", "defender"

var ball: RigidBody3D
var player: FootballPlayer
var teammates: Array = []
var home_players: Array = []
var has_ball: bool = false
var facing: Vector3 = Vector3(0, 0, 1)
var kick_cooldown: float = 0.0
var pass_cooldown: float = 0.0
var gait_phase: float = 0.0
var local_human_controlled: bool = false
var tactical_style: int = 1
var foul_reported: bool = false

var is_sliding: bool = false
var slide_timer: float = 0.0
var slide_cooldown: float = 0.0
var slide_direction: Vector3 = Vector3.ZERO

var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D

const ATTACKING_GOAL := Vector3(0.0, 0.0, 25.7)

func _process(delta: float) -> void:
	if left_leg == null:
		left_leg = get_node_or_null("LeftLeg") as Node3D
		right_leg = get_node_or_null("RightLeg") as Node3D
		left_arm = get_node_or_null("LeftArm") as Node3D
		right_arm = get_node_or_null("RightArm") as Node3D

	if is_sliding:
		rotation.x = move_toward(rotation.x, -0.38, delta * 8.0)
		if is_instance_valid(right_leg):
			right_leg.rotation.x = move_toward(right_leg.rotation.x, 1.1, delta * 12.0)
		if is_instance_valid(left_leg):
			left_leg.rotation.x = move_toward(left_leg.rotation.x, -0.55, delta * 12.0)
		return

	rotation.x = move_toward(rotation.x, 0.0, delta * 6.0)
	var movement_speed := Vector2(velocity.x, velocity.z).length()
	var movement_blend := clampf(movement_speed / move_speed, 0.0, 1.0)
	if movement_blend > 0.02:
		gait_phase += movement_speed * 1.4 * delta
	var leg_swing := sin(gait_phase) * 0.48 * movement_blend
	var arm_swing := -leg_swing * 0.55
	if is_instance_valid(left_leg):
		left_leg.rotation.x = move_toward(left_leg.rotation.x, leg_swing, delta * 7.0)
	if is_instance_valid(right_leg):
		right_leg.rotation.x = move_toward(right_leg.rotation.x, -leg_swing, delta * 7.0)
	if is_instance_valid(left_arm):
		left_arm.rotation.x = move_toward(left_arm.rotation.x, arm_swing, delta * 7.0)
	if is_instance_valid(right_arm):
		right_arm.rotation.x = move_toward(right_arm.rotation.x, -arm_swing, delta * 7.0)

func _physics_process(delta: float) -> void:
	kick_cooldown = maxf(0.0, kick_cooldown - delta)
	pass_cooldown = maxf(0.0, pass_cooldown - delta)
	slide_cooldown = maxf(0.0, slide_cooldown - delta)

	if is_sliding:
		slide_timer -= delta
		velocity.x = slide_direction.x * 9.5
		velocity.z = slide_direction.z * 9.5
		move_and_slide()
		_check_slide_contact()
		if slide_timer <= 0.0:
			is_sliding = false
			rotation.x = 0.0
		return

	if not is_instance_valid(ball):
		return
	if local_human_controlled:
		_process_local_player(delta)
		return

	var ball_owner: String = str(ball.get_meta("owner", ""))
	var to_ball := ball.global_position - global_position
	to_ball.y = 0.0
	var direction := Vector3.ZERO

	if has_ball:
		direction = (ATTACKING_GOAL - global_position).normalized()
		direction.y = 0.0
		if _should_shoot():
			_shoot()
		elif pass_cooldown <= 0.0 and _should_pass():
			_maybe_pass_forward()
	elif ball_owner == name or (name == "Opponent" and ball_owner == "opponent"):
		# In sync with possession
		has_ball = true
	elif _is_away_teammate_owner(ball_owner):
		# Teammate has ball: provide tactical support
		direction = _get_tactical_support_direction()
	elif _is_home_player_owner(ball_owner):
		# Home team has ball: press or zonal mark
		var dist_to_ball := to_ball.length()
		var should_press: bool = _is_closest_to_ball() or (tactical_style == 0 and role != "defender") or (tactical_style == 2 and role == "defender" and to_ball.length() < 4.0)
		if should_press:
			if dist_to_ball > 0.01:
				direction = to_ball.normalized()
			if dist_to_ball <= steal_distance:
				_take_possession()
			elif dist_to_ball < 2.2 and slide_cooldown <= 0.0 and randf() < 0.02:
				_slide_tackle()
		else:
			direction = _get_defensive_cover_direction()
	else:
		# Loose ball
		var dist_to_ball := to_ball.length()
		if _is_closest_to_ball() or dist_to_ball < 8.0:
			if dist_to_ball > 0.01:
				direction = to_ball.normalized()
			if dist_to_ball <= steal_distance and ball.linear_velocity.length() < 7.0:
				_take_possession()
		else:
			direction = _get_tactical_support_direction()

	var movement_speed := Vector2(velocity.x, velocity.z).length()
	var movement_blend := clampf(movement_speed / move_speed, 0.0, 1.0)
	if direction.length_squared() > 0.001:
		facing = direction.normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), 8.0 * delta)
		rotation.z = move_toward(rotation.z, -direction.x * 0.1 * movement_blend, delta * 6.0)
	else:
		rotation.z = move_toward(rotation.z, 0.0, delta * 6.0)

	var effective_speed := move_speed
	if has_ball:
		effective_speed *= 0.85
	velocity.x = move_toward(velocity.x, direction.x * effective_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * effective_speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	if has_ball and is_instance_valid(ball):
		var touch_offset := sin(gait_phase) * 0.08 * movement_blend
		ball.global_position = global_position + facing * (1.0 + touch_offset) + Vector3.UP * 0.36
		if movement_speed > 0.1:
			var spin_axis := facing.cross(Vector3.UP).normalized()
			ball.rotate(spin_axis, -(movement_speed / 0.34) * delta)

func _process_local_player(delta: float) -> void:
	var input_direction := Input.get_vector("p2_move_left", "p2_move_right", "p2_move_forward", "p2_move_back")
	if input_direction.length_squared() > 0.01:
		facing = Vector3(input_direction.x, 0.0, input_direction.y).normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), 8.0 * delta)
	var speed := move_speed
	if Input.is_action_pressed("p2_sprint"):
		speed *= 1.4
	velocity.x = move_toward(velocity.x, input_direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, input_direction.y * speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	var ball_owner: String = str(ball.get_meta("owner", ""))
	if has_ball or ball_owner == name or (name == "Opponent" and ball_owner == "opponent"):
		has_ball = true
		if Input.is_action_just_pressed("p2_pass"):
			_maybe_pass_forward()
		elif Input.is_action_just_pressed("p2_shoot"):
			_shoot()
		elif Input.is_action_just_pressed("p2_tackle"):
			_slide_tackle()
	elif ball_owner.is_empty() and global_position.distance_to(ball.global_position) < steal_distance:
		_take_possession()
	elif _is_home_player_owner(ball_owner) and global_position.distance_to(ball.global_position) < steal_distance:
		_take_possession()
	if has_ball:
		ball.global_position = global_position + facing * 1.0 + Vector3.UP * 0.36

func _is_away_teammate_owner(ball_owner: String) -> bool:
	if ball_owner.is_empty():
		return false
	if ball_owner == "opponent" or ball_owner == "Opponent":
		return name != "Opponent"
	for tm in teammates:
		if is_instance_valid(tm) and tm.name == ball_owner:
			return true
	return false

func _is_home_player_owner(ball_owner: String) -> bool:
	if ball_owner.is_empty():
		return false
	if ball_owner == "Player" or ball_owner.begins_with("Teammate"):
		return true
	return false

func _is_closest_to_ball() -> bool:
	if not is_instance_valid(ball):
		return false
	var my_dist := global_position.distance_to(ball.global_position)
	for tm in teammates:
		if is_instance_valid(tm) and tm != self:
			if tm.global_position.distance_to(ball.global_position) < my_dist:
				return false
	return true

func _get_tactical_support_direction() -> Vector3:
	var target := global_position
	if role == "striker":
		target = Vector3(clampf(ball.global_position.x * 0.7, -6.0, 6.0), 0.1, maxf(ball.global_position.z + 5.5, 8.0))
	elif role == "midfielder":
		target = Vector3(clampf(-ball.global_position.x * 0.5, -8.0, 8.0), 0.1, clampf(ball.global_position.z + 1.0, -4.0, 12.0))
	else: # Defender
		target = Vector3(clampf(ball.global_position.x * 0.3, -5.0, 5.0), 0.1, clampf(ball.global_position.z - 7.0, -18.0, -6.0))

	var diff := target - global_position
	diff.y = 0.0
	if diff.length() > 1.2:
		return diff.normalized()
	return Vector3.ZERO

func _get_defensive_cover_direction() -> Vector3:
	var target := global_position
	if role == "defender":
		# Shield away goal corridor
		target = Vector3(clampf(ball.global_position.x * 0.5, -5.0, 5.0), 0.1, clampf(ball.global_position.z - 8.0, -21.0, -12.0))
	elif role == "midfielder":
		target = Vector3(clampf(ball.global_position.x * 0.6, -7.0, 7.0), 0.1, clampf(ball.global_position.z - 4.0, -14.0, 2.0))
	else:
		target = Vector3(ball.global_position.x, 0.1, clampf(ball.global_position.z - 2.0, -8.0, 10.0))

	var diff := target - global_position
	diff.y = 0.0
	if diff.length() > 1.0:
		return diff.normalized()
	return Vector3.ZERO

func _maybe_pass_forward() -> void:
	var best_target := _find_best_pass_target()
	if is_instance_valid(best_target):
		_pass_to_teammate(best_target)

func _find_best_pass_target() -> FootballOpponent:
	var best_target: FootballOpponent = null
	var best_score := -INF
	for tm in teammates:
		if is_instance_valid(tm) and tm != self:
			var to_tm: Vector3 = tm.global_position - global_position
			to_tm.y = 0.0
			var forward_lead: float = to_tm.z
			var dist: float = to_tm.length()
			if dist <= 3.0 or dist >= 20.0 or forward_lead <= 0.5:
				continue

			var score := forward_lead * 1.5 - absf(dist - 9.0) * 0.25
			var receiver_space := _nearest_home_player_distance(tm.global_position)
			score += minf(receiver_space, 6.0) * 0.4
			score -= _pass_lane_pressure(global_position, tm.global_position) * 3.0
			if score > best_score:
				best_score = score
				best_target = tm

	return best_target if best_score > 2.0 else null

func _should_shoot() -> bool:
	if kick_cooldown > 0.0:
		return false

	var goal_distance := Vector2(
		ATTACKING_GOAL.x - ball.global_position.x,
		ATTACKING_GOAL.z - ball.global_position.z
	).length()
	var range_bonus := 2.0 if role == "striker" else 0.0
	if role == "defender":
		range_bonus = -2.0
	var shooting_range := shooting_distance + range_bonus
	if tactical_style == 0:
		shooting_range += 2.0
	elif tactical_style == 2:
		shooting_range -= 2.0
	if goal_distance > shooting_range:
		return false

	return _nearest_home_player_distance(ball.global_position) > 1.6 or goal_distance < 5.0

func _should_pass() -> bool:
	if not is_instance_valid(_find_best_pass_target()):
		return false

	var pressure_distance := _nearest_home_player_distance(global_position)
	if tactical_style == 0:
		return pressure_distance < 5.5
	if tactical_style == 2:
		return role != "striker" and pressure_distance < 9.0
	if role == "defender":
		return true
	if role == "midfielder":
		return pressure_distance < 7.0
	return pressure_distance < 3.8

func _nearest_home_player_distance(point: Vector3) -> float:
	var nearest_distance := INF
	for home_player in home_players:
		if is_instance_valid(home_player):
			nearest_distance = minf(nearest_distance, point.distance_to(home_player.global_position))
	return nearest_distance

func _pass_lane_pressure(start: Vector3, finish: Vector3) -> float:
	var pass_vector := finish - start
	pass_vector.y = 0.0
	if pass_vector.length_squared() <= 0.001:
		return 0.0

	var nearest_clearance := INF
	for home_player in home_players:
		if not is_instance_valid(home_player):
			continue
		var to_defender: Vector3 = home_player.global_position - start
		to_defender.y = 0.0
		var along_pass := clampf(to_defender.dot(pass_vector) / pass_vector.length_squared(), 0.0, 1.0)
		var closest_point := start + pass_vector * along_pass
		nearest_clearance = minf(nearest_clearance, home_player.global_position.distance_to(closest_point))

	return maxf(0.0, 2.0 - nearest_clearance)

func _pass_to_teammate(target_opp: FootballOpponent) -> void:
	has_ball = false
	pass_cooldown = 2.5
	kick_cooldown = 1.0
	ball.freeze = false
	ball.remove_meta("owner")

	var lead_target := target_opp.global_position + target_opp.velocity * 0.25 + Vector3(0, 0, 0.8)
	var pass_dir := (lead_target - ball.global_position).normalized()
	pass_dir.y = 0.0
	ball.global_position = global_position + facing * 1.1 + Vector3.UP * 0.38
	var pass_speed := clampf(9.0 + global_position.distance_to(target_opp.global_position) * 0.35, 10.0, 16.0)
	ball.linear_velocity = pass_dir * pass_speed + Vector3.UP * 1.1
	var spin_axis := pass_dir.cross(Vector3.UP).normalized()
	ball.angular_velocity = spin_axis * 12.0
	ball_kicked.emit(0.4)

func _slide_tackle() -> void:
	is_sliding = true
	slide_timer = 0.38
	slide_cooldown = 2.0
	slide_direction = facing.normalized()
	foul_reported = false
	slide_started.emit()

func _check_slide_contact() -> void:
	if not is_instance_valid(ball):
		return
	if not foul_reported:
		for home_player: FootballPlayer in home_players:
			if is_instance_valid(home_player) and global_position.distance_to(home_player.global_position) < 1.05:
				foul_reported = true
				foul_committed.emit(home_player.global_position)
				break
	if global_position.distance_to(ball.global_position) < 1.6:
		var ball_owner: String = str(ball.get_meta("owner", ""))
		if _is_home_player_owner(ball_owner):
			ball.remove_meta("owner")
			ball.freeze = false
			ball.linear_velocity = slide_direction * 7.5 + Vector3.UP * 1.2

func _take_possession() -> void:
	has_ball = true
	if is_instance_valid(player):
		player.has_ball = false
	for p in home_players:
		if is_instance_valid(p):
			p.has_ball = false
	var meta_owner := "opponent" if name == "Opponent" else str(name)
	ball.set_meta("owner", meta_owner)
	ball.freeze = true

func _shoot() -> void:
	has_ball = false
	kick_cooldown = 2.2
	pass_cooldown = 1.5
	ball.freeze = false
	ball.remove_meta("owner")
	var target := Vector3(randf_range(-2.2, 2.2), 1.2, 26.5)
	var shot_direction := (target - ball.global_position).normalized()
	ball.global_position = global_position + facing * 1.35 + Vector3.UP * 0.42
	ball.linear_velocity = Vector3.ZERO
	var spin_axis := shot_direction.cross(Vector3.UP).normalized()
	ball.angular_velocity = spin_axis * 16.0
	ball.apply_central_impulse(shot_direction * 18.0 + Vector3.UP * 3.5)
	ball_kicked.emit(0.7)
