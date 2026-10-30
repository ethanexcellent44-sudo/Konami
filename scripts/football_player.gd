extends CharacterBody3D
class_name FootballPlayer

signal shot_charge_changed(charge: float, is_charging: bool)
signal stamina_changed(current: float, max_val: float)
signal ball_kicked(power_ratio: float)
signal slide_started()
signal slide_hit()
signal standing_tackle_won()
signal foul_committed(position: Vector3)
signal training_action(action_name: String)
signal through_ball_triggered(target: FootballPlayer)

@export var walk_speed: float = 5.8
@export var sprint_speed: float = 8.7
@export var acceleration: float = 14.0
@export var turn_speed: float = 8.0

var ball: RigidBody3D
var has_ball: bool = false
var facing: Vector3 = Vector3(0, 0, -1)
var is_user_controlled: bool = true
var tactical_preset: int = 1
var set_piece_aiming: bool = false
var formation_offset: Vector3 = Vector3.ZERO
var teammates: Array[FootballPlayer] = []
var all_opponents: Array = []
var pass_target: FootballPlayer
var gait_phase: float = 0.0

var virtual_movement_direction: Vector2 = Vector2.ZERO

var is_sliding: bool = false
var slide_timer: float = 0.0
var slide_cooldown: float = 0.0
var slide_duration: float = 0.42
var slide_speed: float = 11.0
var slide_direction: Vector3 = Vector3.ZERO
var standing_tackle_cooldown: float = 0.0

var stamina: float = 100.0
var max_stamina: float = 100.0

var is_charging_shot: bool = false
var shot_charge: float = 0.0
var shot_charge_speed: float = 1.4
var min_shot_power: float = 15.0
var max_shot_power: float = 28.0
var shot_aim_direction: Vector3 = Vector3(0, 0, -1)

var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var aim_arrow: Node3D
var aim_arrow_shaft: MeshInstance3D
var pass_marker: MeshInstance3D
var player_cursor: MeshInstance3D

func _ready() -> void:
	_cache_nodes()
	_build_aim_arrow()
	_build_pass_marker()
	_build_player_cursor()

func _build_player_cursor() -> void:
	player_cursor = MeshInstance3D.new()
	player_cursor.name = "PlayerCursor"
	var prism := PrismMesh.new()
	prism.size = Vector3(0.36, 0.36, 0.12)
	player_cursor.mesh = prism
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.88, 0.15)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	player_cursor.material_override = mat
	player_cursor.rotation.x = PI
	player_cursor.position = Vector3(0.0, 2.45, 0.0)
	player_cursor.visible = is_user_controlled
	add_child(player_cursor)

func _cache_nodes() -> void:
	left_leg = get_node_or_null("LeftLeg") as Node3D
	right_leg = get_node_or_null("RightLeg") as Node3D
	left_arm = get_node_or_null("LeftArm") as Node3D
	right_arm = get_node_or_null("RightArm") as Node3D

func _build_aim_arrow() -> void:
	aim_arrow = Node3D.new()
	aim_arrow.name = "AimArrow"
	aim_arrow.visible = false
	aim_arrow.top_level = true
	add_child(aim_arrow)

	aim_arrow_shaft = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.03, 1.4)
	aim_arrow_shaft.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_arrow_shaft.material_override = mat
	aim_arrow_shaft.position = Vector3(0.0, 0.03, -0.7)
	aim_arrow.add_child(aim_arrow_shaft)

	var head := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.48, 0.48, 0.03)
	head.mesh = prism
	head.material_override = mat
	head.rotation.x = -PI * 0.5
	head.position = Vector3(0.0, 0.03, -1.4)
	aim_arrow.add_child(head)

func _build_pass_marker() -> void:
	pass_marker = MeshInstance3D.new()
	pass_marker.name = "PassTargetMarker"
	var prism := PrismMesh.new()
	prism.size = Vector3(0.32, 0.32, 0.12)
	pass_marker.mesh = prism
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.85, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pass_marker.material_override = mat
	pass_marker.rotation.x = PI
	pass_marker.position = Vector3(0.0, 2.35, 0.0)
	pass_marker.visible = false
	add_child(pass_marker)

func set_pass_highlight(active: bool) -> void:
	if is_instance_valid(pass_marker):
		pass_marker.visible = active

func _process(delta: float) -> void:
	if left_leg == null:
		_cache_nodes()
	var movement_speed := Vector2(velocity.x, velocity.z).length()
	var movement_blend := clampf(movement_speed / sprint_speed, 0.0, 1.0)
	if movement_blend > 0.02:
		gait_phase += movement_speed * 1.4 * delta
	var leg_swing := sin(gait_phase) * 0.48 * movement_blend
	var arm_swing := -leg_swing * 0.55

	if is_sliding:
		rotation.x = move_toward(rotation.x, -0.42, delta * 8.0)
		if is_instance_valid(right_leg):
			right_leg.rotation.x = move_toward(right_leg.rotation.x, 1.15, delta * 12.0)
		if is_instance_valid(left_leg):
			left_leg.rotation.x = move_toward(left_leg.rotation.x, -0.6, delta * 12.0)
		if is_instance_valid(left_arm):
			left_arm.rotation.x = move_toward(left_arm.rotation.x, 0.45, delta * 9.0)
		if is_instance_valid(right_arm):
			right_arm.rotation.x = move_toward(right_arm.rotation.x, -0.75, delta * 9.0)
	elif is_charging_shot:
		if is_instance_valid(right_leg):
			right_leg.rotation.x = move_toward(right_leg.rotation.x, -0.65 - shot_charge * 0.55, delta * 9.0)
		if is_instance_valid(left_leg):
			left_leg.rotation.x = move_toward(left_leg.rotation.x, 0.35, delta * 7.0)
		if is_instance_valid(left_arm):
			left_arm.rotation.x = move_toward(left_arm.rotation.x, -0.5, delta * 7.0)
		if is_instance_valid(right_arm):
			right_arm.rotation.x = move_toward(right_arm.rotation.x, 0.5, delta * 7.0)
		rotation.x = move_toward(rotation.x, 0.12, delta * 6.0)
	else:
		rotation.x = move_toward(rotation.x, 0.0, delta * 6.0)
		if is_instance_valid(left_leg):
			left_leg.rotation.x = move_toward(left_leg.rotation.x, leg_swing, delta * 7.0)
		if is_instance_valid(right_leg):
			right_leg.rotation.x = move_toward(right_leg.rotation.x, -leg_swing, delta * 7.0)
		if is_instance_valid(left_arm):
			left_arm.rotation.x = move_toward(left_arm.rotation.x, arm_swing, delta * 7.0)
		if is_instance_valid(right_arm):
			right_arm.rotation.x = move_toward(right_arm.rotation.x, -arm_swing, delta * 7.0)

	if is_instance_valid(pass_marker) and pass_marker.visible:
		pass_marker.rotation.y += delta * 3.5

	if is_instance_valid(player_cursor):
		player_cursor.visible = is_user_controlled
		if is_user_controlled:
			player_cursor.rotation.y += delta * 2.5
			player_cursor.position.y = 2.45 + sin(Time.get_ticks_msec() * 0.005) * 0.06

func _physics_process(delta: float) -> void:
	slide_cooldown = maxf(0.0, slide_cooldown - delta)
	standing_tackle_cooldown = maxf(0.0, standing_tackle_cooldown - delta)

	if is_sliding:
		slide_timer -= delta
		velocity.x = slide_direction.x * slide_speed
		velocity.z = slide_direction.z * slide_speed
		move_and_slide()
		_check_slide_collisions()
		if slide_timer <= 0.0:
			is_sliding = false
			rotation.x = 0.0
		return

	var direction := _get_movement_direction()
	var movement_speed := Vector2(velocity.x, velocity.z).length()
	var movement_blend := clampf(movement_speed / sprint_speed, 0.0, 1.0)
	var is_sprinting: bool = is_user_controlled and Input.is_action_pressed("sprint") and stamina > 5.0 and direction.length_squared() > 0.001

	if direction.length_squared() > 0.001 and not is_charging_shot:
		var desired_facing := direction.normalized()
		var turn_factor := lerpf(1.0, 0.62, movement_blend)
		if is_sprinting:
			turn_factor *= 0.82
		if has_ball:
			turn_factor *= 0.88
		var effective_turn_speed := turn_speed * turn_factor
		facing = facing.slerp(desired_facing, minf(1.0, effective_turn_speed * delta)).normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), effective_turn_speed * delta)
		var bank_angle := -direction.x * 0.12 * movement_blend
		rotation.z = move_toward(rotation.z, bank_angle, delta * 6.0)
	else:
		rotation.z = move_toward(rotation.z, 0.0, delta * 6.0)

	var speed := walk_speed

	if is_user_controlled:
		speed = sprint_speed if is_sprinting else walk_speed
		if is_sprinting:
			stamina = maxf(0.0, stamina - 22.0 * delta)
		else:
			stamina = minf(max_stamina, stamina + 18.0 * delta)
		stamina_changed.emit(stamina, max_stamina)
	else:
		# AI teammate positioning speed control: jog when close, run when far
		var tactical_target := _calculate_tactical_target()
		var dist_to_tactical := global_position.distance_to(tactical_target)
		if dist_to_tactical > 7.0:
			speed = sprint_speed * 0.92
		elif dist_to_tactical > 3.0:
			speed = walk_speed * 1.05
		else:
			speed = walk_speed * 0.85

	if has_ball:
		speed *= 0.82
	if is_charging_shot:
		speed *= 0.55

	var control_acceleration := acceleration
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if direction.length_squared() > 0.001 and horizontal_velocity.dot(direction) < 0.0:
		control_acceleration *= 3.8
	velocity.x = move_toward(velocity.x, direction.x * speed, control_acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, control_acceleration * delta)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	_update_ball_control()

	if is_user_controlled and has_ball:
		_process_user_ball_actions(delta)
		var best_target := _select_pass_target()
		for teammate in teammates:
			if is_instance_valid(teammate) and teammate != self:
				teammate.set_pass_highlight(teammate == best_target)
	else:
		if is_user_controlled and not has_ball:
			if Input.is_action_just_pressed("standing_tackle"):
				_standing_tackle()
			if Input.is_action_just_pressed("slide_tackle") and not is_sliding and slide_cooldown <= 0.0:
				_slide_tackle()
		if is_charging_shot:
			_cancel_shot()
		for teammate in teammates:
			if is_instance_valid(teammate) and teammate != self:
				teammate.set_pass_highlight(false)

func _process_user_ball_actions(delta: float) -> void:
	if Input.is_action_just_pressed("pass_ball"):
		if is_charging_shot:
			_cancel_shot()
		_pass_ball()
		return

	if Input.is_action_just_pressed("through_ball"):
		if is_charging_shot:
			_cancel_shot()
		_through_ball()
		return

	if Input.is_action_just_pressed("shoot_ball"):
		is_charging_shot = true
		shot_charge = 0.08
		shot_aim_direction = facing
		shot_charge_changed.emit(shot_charge, true)

	if is_charging_shot:
		if Input.is_action_pressed("shoot_ball"):
			shot_charge = minf(1.0, shot_charge + shot_charge_speed * delta)
			shot_charge_changed.emit(shot_charge, true)
			var input_vec := virtual_movement_direction
			if input_vec.length_squared() <= 0.01:
				input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			if input_vec.length_squared() > 0.01:
				var steer_dir := Vector3(input_vec.x, 0.0, input_vec.y).normalized()
				shot_aim_direction = (facing * 0.65 + steer_dir * 0.45).normalized()
			else:
				shot_aim_direction = facing
			_update_aim_arrow()

		if Input.is_action_just_released("shoot_ball") or shot_charge >= 1.0:
			_execute_charged_shot()

func _update_aim_arrow() -> void:
	if not is_instance_valid(aim_arrow):
		return
	aim_arrow.visible = true
	aim_arrow.global_position = global_position + Vector3.UP * 0.05
	aim_arrow.rotation.y = atan2(-shot_aim_direction.x, -shot_aim_direction.z)
	var scale_len := 0.75 + shot_charge * 1.5
	aim_arrow.scale = Vector3(1.0, 1.0, scale_len)
	var mat: StandardMaterial3D = aim_arrow_shaft.material_override
	if is_instance_valid(mat):
		if shot_charge < 0.5:
			mat.albedo_color = Color(0.2, 0.9, 0.3).lerp(Color(0.95, 0.85, 0.15), shot_charge * 2.0)
		else:
			mat.albedo_color = Color(0.95, 0.85, 0.15).lerp(Color(0.95, 0.2, 0.1), (shot_charge - 0.5) * 2.0)

func _execute_charged_shot() -> void:
	training_action.emit("shooting")
	var power: float = lerpf(min_shot_power, max_shot_power, shot_charge)
	var lift: float = 0.08
	if shot_charge < 0.4:
		lift = lerpf(0.08, 0.15, shot_charge / 0.4)
	elif shot_charge < 0.8:
		lift = lerpf(0.15, 0.25, (shot_charge - 0.4) / 0.4)
	else:
		lift = lerpf(0.25, 0.33, (shot_charge - 0.8) / 0.2)

	var kick_dir: Vector3 = shot_aim_direction if shot_aim_direction.length_squared() > 0.01 else facing
	_kick_ball(power, lift, kick_dir)
	_cancel_shot()

func _cancel_shot() -> void:
	is_charging_shot = false
	shot_charge = 0.0
	shot_charge_changed.emit(0.0, false)
	if is_instance_valid(aim_arrow):
		aim_arrow.visible = false

func _calculate_tactical_target() -> Vector3:
	var carrier := _get_controlled_teammate()
	if not is_instance_valid(carrier):
		return global_position

	var ball_owner: String = ""
	if is_instance_valid(ball):
		ball_owner = str(ball.get_meta("owner", ""))

	# 1. DEFENSIVE PHASE: Opponent has the ball
	if (ball_owner == "opponent" or ball_owner.begins_with("Opponent")) and is_instance_valid(ball):
		var min_opp_dist := global_position.distance_to(ball.global_position)
		var closest_to_opp := self
		for tm in teammates:
			if is_instance_valid(tm) and not tm.is_user_controlled:
				var d := tm.global_position.distance_to(ball.global_position)
				if d < min_opp_dist:
					min_opp_dist = d
					closest_to_opp = tm

		if closest_to_opp == self or (tactical_preset == 0 and min_opp_dist < 18.0):
			# Press the opponent directly
			var to_ball_vec := ball.global_position - global_position
			to_ball_vec.y = 0.0
			return ball.global_position + to_ball_vec.normalized() * 0.6
		else:
			# Drop back and cover the central corridor between opponent and our goal
			var cover_x := clampf(ball.global_position.x * 0.4, -5.0, 5.0)
			var cover_z := clampf(ball.global_position.z + 7.5, 4.0, 18.0)
			if tactical_preset == 2:
				cover_z += 3.0
			return Vector3(cover_x, 0.1, cover_z)

	# 2. LOOSE BALL PHASE
	if ball_owner == "" and is_instance_valid(ball):
		var dist_to_ball := global_position.distance_to(ball.global_position)
		var closest_tm := self
		var min_d := dist_to_ball
		for tm in teammates:
			if is_instance_valid(tm):
				var d := tm.global_position.distance_to(ball.global_position)
				if d < min_d:
					min_d = d
					closest_tm = tm
		if closest_tm == self and dist_to_ball < 14.0:
			return ball.global_position

	# Preserve each player's formation lane while the side shifts toward the ball.
	var target_x := formation_offset.x + clampf(ball.global_position.x * 0.28, -4.5, 4.5)
	var target_z := formation_offset.z + clampf((carrier.global_position.z - formation_offset.z) * 0.3, -6.0, 6.0)
	var width_scale := 1.2 if tactical_preset == 0 else (0.75 if tactical_preset == 2 else 1.0)
	target_x *= width_scale
	if tactical_preset == 0:
		target_z -= 2.0
	elif tactical_preset == 2:
		target_z += 2.5
	target_x = clampf(target_x, -15.0, 15.0)
	target_z = clampf(target_z, -24.0, 24.0)

	return Vector3(target_x, 0.1, target_z)

func _get_movement_direction() -> Vector3:
	if set_piece_aiming:
		return Vector3.ZERO
	if is_user_controlled:
		var input_direction := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if virtual_movement_direction.length_squared() > 0.01:
			input_direction = virtual_movement_direction
		return Vector3(input_direction.x, 0.0, input_direction.y)

	if not is_instance_valid(ball):
		return Vector3.ZERO

	var target_pos := _calculate_tactical_target()
	var to_target := target_pos - global_position
	to_target.y = 0.0

	var move_dir := Vector3.ZERO
	if to_target.length() > 1.2:
		move_dir = to_target.normalized()

	# Anti-clumping repulsion: maintain personal space (minimum 4.2m)
	var separation := Vector3.ZERO
	for tm in teammates:
		if is_instance_valid(tm) and tm != self:
			var diff := global_position - tm.global_position
			diff.y = 0.0
			var dist := diff.length()
			if dist < 4.2 and dist > 0.01:
				separation += diff.normalized() * ((4.2 - dist) / 4.2) * 2.2

	# Extra spacing from ball carrier: never crowd the ball carrier (minimum 5.0m)
	if is_instance_valid(ball):
		var owner_name := str(ball.get_meta("owner", ""))
		if owner_name != "" and owner_name != name:
			var diff_carrier := global_position - ball.global_position
			diff_carrier.y = 0.0
			var dist_carrier := diff_carrier.length()
			if dist_carrier < 5.0 and dist_carrier > 0.01:
				separation += diff_carrier.normalized() * ((5.0 - dist_carrier) / 5.0) * 2.8

	var final_dir := move_dir + separation
	final_dir.y = 0.0
	if final_dir.length_squared() > 0.01:
		return final_dir.normalized()

	return Vector3.ZERO

func _get_controlled_teammate() -> FootballPlayer:
	if is_user_controlled:
		return self
	for teammate in teammates:
		if is_instance_valid(teammate) and teammate.is_user_controlled:
			return teammate
	return null

func _select_pass_target() -> FootballPlayer:
	var best_score := -INF
	var best_target: FootballPlayer
	for teammate in teammates:
		if not is_instance_valid(teammate) or teammate == self:
			continue
		var offset := teammate.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance < 2.0 or distance > 24.0:
			continue
		var forward_score := facing.dot(offset.normalized())
		var score := forward_score * 12.0 - distance * 0.25
		if score > best_score:
			best_score = score
			best_target = teammate
	return best_target

func _pass_ball() -> void:
	training_action.emit("passing")
	pass_target = _select_pass_target()
	var target_position := global_position + facing * 12.0
	if is_instance_valid(pass_target):
		target_position = pass_target.global_position + pass_target.velocity * 0.35
	var pass_direction := target_position - ball.global_position
	pass_direction.y = 0.0
	if pass_direction.length_squared() < 0.01:
		pass_direction = facing
	pass_direction = pass_direction.normalized()
	has_ball = false
	ball.freeze = false
	ball.remove_meta("owner")
	ball.global_position = global_position + facing * 1.0 + Vector3.UP * 0.38
	ball.linear_velocity = pass_direction * 12.0 + Vector3.UP * 1.6
	var spin_axis := pass_direction.cross(Vector3.UP).normalized()
	ball.angular_velocity = spin_axis * 12.0
	ball_kicked.emit(0.4)

func _through_ball() -> void:
	training_action.emit("passing")
	pass_target = _select_pass_target()
	var lead_distance := 6.0
	var target_position := global_position + facing * 14.0
	if is_instance_valid(pass_target):
		var target_vel := pass_target.velocity
		if target_vel.length() < 0.5:
			# Lead into attacking space towards north goal
			target_position = pass_target.global_position + Vector3(0.0, 0.0, -lead_distance)
		else:
			target_position = pass_target.global_position + target_vel.normalized() * lead_distance
	target_position.x = clampf(target_position.x, -14.5, 14.5)
	target_position.z = clampf(target_position.z, -24.0, 24.0)

	var pass_direction := target_position - ball.global_position
	pass_direction.y = 0.0
	if pass_direction.length_squared() < 0.01:
		pass_direction = facing
	pass_direction = pass_direction.normalized()

	has_ball = false
	ball.freeze = false
	ball.remove_meta("owner")
	ball.global_position = global_position + facing * 1.0 + Vector3.UP * 0.38
	ball.linear_velocity = pass_direction * 15.0 + Vector3.UP * 1.2
	var spin_axis := pass_direction.cross(Vector3.UP).normalized()
	ball.angular_velocity = spin_axis * 14.0
	ball_kicked.emit(0.55)
	if is_instance_valid(pass_target):
		through_ball_triggered.emit(pass_target)

func _slide_tackle() -> void:
	if has_ball or is_sliding or slide_cooldown > 0.0:
		return
	is_sliding = true
	slide_timer = slide_duration
	slide_cooldown = 1.3
	slide_direction = facing.normalized()
	slide_started.emit()

func _standing_tackle() -> bool:
	if has_ball or standing_tackle_cooldown > 0.0:
		return false
	standing_tackle_cooldown = 0.85
	var target_opponent: FootballOpponent
	var best_distance := 1.8
	for opposing_player: FootballOpponent in all_opponents:
		if not is_instance_valid(opposing_player) or not opposing_player.has_ball:
			continue
		var offset: Vector3 = opposing_player.global_position - global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance >= best_distance or distance < 0.01:
			continue
		if facing.normalized().dot(offset.normalized()) < 0.2:
			continue
		best_distance = distance
		target_opponent = opposing_player
	if not is_instance_valid(target_opponent):
		for opposing_player: FootballOpponent in all_opponents:
			if is_instance_valid(opposing_player) and opposing_player.has_ball and global_position.distance_to(opposing_player.global_position) < 2.6:
				foul_committed.emit(opposing_player.global_position)
				break
		return false
	target_opponent.has_ball = false
	has_ball = true
	ball.set_meta("owner", name)
	ball.freeze = true
	ball.global_position = global_position + facing * 0.95 + Vector3.UP * 0.38
	ball.linear_velocity = Vector3.ZERO
	standing_tackle_won.emit()
	training_action.emit("defending")
	return true

func _check_slide_collisions() -> void:
	if not is_instance_valid(ball):
		return
	var d_ball := global_position.distance_to(ball.global_position)
	if d_ball < 1.8:
		var ball_owner := str(ball.get_meta("owner", ""))
		if ball_owner != name and not ball_owner.is_empty():
			ball.remove_meta("owner")
			ball.freeze = false
			ball.linear_velocity = slide_direction * 9.0 + Vector3.UP * 1.3
			var spin_axis := slide_direction.cross(Vector3.UP).normalized()
			ball.angular_velocity = spin_axis * 16.0
			slide_hit.emit()
			training_action.emit("defending")
		elif ball_owner.is_empty() and d_ball < 1.4:
			ball.linear_velocity = slide_direction * 7.5 + Vector3.UP * 1.0
			slide_hit.emit()
			training_action.emit("defending")

	for opp in all_opponents:
		if is_instance_valid(opp):
			var d_opp: float = global_position.distance_to(opp.global_position)
			if d_opp < 1.6 and opp.has_ball:
				opp.has_ball = false
				ball.remove_meta("owner")
				ball.freeze = false
				ball.linear_velocity = slide_direction * 8.5 + Vector3.UP * 1.2
				slide_hit.emit()

func _update_ball_control() -> void:
	if not is_instance_valid(ball):
		return
	var owner: String = str(ball.get_meta("owner", ""))
	if not owner.is_empty() and owner != name:
		has_ball = false
		return
	var distance := global_position.distance_to(ball.global_position)
	var catch_speed := 12.5 if not is_user_controlled else 4.5
	if not has_ball and distance < 1.55 and ball.linear_velocity.length() < catch_speed:
		has_ball = true
		ball.set_meta("owner", name)
		ball.freeze = true
	if has_ball:
		var movement_speed := Vector2(velocity.x, velocity.z).length()
		var movement_blend := clampf(movement_speed / sprint_speed, 0.0, 1.0)
		var touch_distance := lerpf(0.92, 1.4, movement_blend)
		touch_distance += sin(gait_phase) * 0.08 * movement_blend
		var dribble_target := global_position + facing * touch_distance + Vector3.UP * 0.36
		var touch_response := lerpf(18.0, 10.0, movement_blend)
		ball.global_position = ball.global_position.lerp(dribble_target, 1.0 - exp(-touch_response * get_physics_process_delta_time()))
		if movement_speed > 0.1:
			var spin_axis := facing.cross(Vector3.UP).normalized()
			ball.rotate(spin_axis, -(movement_speed / 0.34) * get_physics_process_delta_time())
		if distance > 3.0:
			has_ball = false
			ball.remove_meta("owner")
			ball.freeze = false

func _kick_ball(power: float = 19.0, lift: float = 0.14, kick_direction: Vector3 = Vector3.ZERO) -> void:
	has_ball = false
	ball.freeze = false
	ball.remove_meta("owner")
	var dir := kick_direction if kick_direction.length_squared() > 0.01 else facing
	dir = dir.normalized()
	ball.global_position = global_position + dir * 1.4 + Vector3.UP * 0.45
	ball.linear_velocity = Vector3.ZERO
	var spin_axis := dir.cross(Vector3.UP).normalized()
	ball.angular_velocity = spin_axis * (power * 1.6)
	ball.apply_central_impulse(dir * power + Vector3.UP * power * lift)
	var ratio := clampf((power - min_shot_power) / (max_shot_power - min_shot_power), 0.0, 1.0)
	ball_kicked.emit(ratio)
