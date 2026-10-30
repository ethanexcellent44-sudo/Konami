extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _send_key(physical_keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	event.keycode = physical_keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run_test() -> void:
	var scene := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(scene)
	await physics_frame
	await physics_frame

	var player := scene.get_node("Player") as FootballPlayer
	var ball := scene.get_node("Ball") as RigidBody3D
	var home_gk := scene.get("home_goalkeeper") as FootballGoalkeeper
	var away_gk := scene.get("away_goalkeeper") as FootballGoalkeeper
	var hud := scene.get("hud") as MatchHud
	var camera := scene.get("follow_camera") as FollowCamera

	if not is_instance_valid(camera) or not is_instance_valid(hud.camera_view_button):
		push_error("Camera view control was not properly initialized")
		quit(1)
		return
	if not InputMap.has_action("standing_tackle") or not InputMap.has_action("keeper_distribute"):
		push_error("Standing tackle and keeper distribution actions are not configured")
		quit(1)
		return
	if hud.pause_modal.find_child("TrainingModeButton", true, false) == null or hud.pause_modal.find_child("TouchSizeSlider", true, false) == null:
		push_error("Pause menu is missing training or touch settings")
		quit(1)
		return
	var score_panel := hud.get_node_or_null("ScorePanel") as Panel
	var pause_panel := hud.pause_modal.find_child("PausePanel", true, false) as Panel
	if not is_instance_valid(score_panel) or not is_instance_valid(pause_panel) or not hud.interface_theme.has_stylebox("normal", "Button"):
		push_error("Polished HUD panels or shared button styling were not initialized")
		quit(1)
		return
	if player.get_node_or_null("LeftLeg/LimbMesh") == null or player.get_node_or_null("RightArm/LimbMesh") == null:
		push_error("Player limbs should use articulated hip and shoulder pivots")
		quit(1)
		return
	var touch_tackle_button: VirtualTouchControls.TouchButton
	for touch_button: VirtualTouchControls.TouchButton in hud.touch_controls.buttons:
		if touch_button.name == "btn_pass":
			touch_tackle_button = touch_button
	hud.touch_controls.set_possession_context(false)
	if not is_instance_valid(touch_tackle_button) or touch_tackle_button.action != "standing_tackle":
		push_error("Defensive touch button should invoke a standing tackle")
		quit(1)
		return
	hud.touch_controls.set_possession_context(true)
	var touch_controls := hud.touch_controls
	touch_controls._handle_touch(77, Vector2(150.0, 600.0), true)
	touch_controls._handle_drag(77, Vector2(150.0, 535.0))
	if touch_controls.joystick_vector.y > -0.9:
		push_error("Upward joystick drag should produce forward movement")
		quit(1)
		return
	touch_controls._handle_touch(77, Vector2(150.0, 535.0), false)
	if touch_controls.joystick_vector.length_squared() > 0.001:
		push_error("Releasing the joystick should stop movement")
		quit(1)
		return
	var sound_manager := scene.get("sound_manager") as SoundManager
	if not is_instance_valid(sound_manager.ethan_theme_stream) or sound_manager.ethan_theme_stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		push_error("Original Ethan launch theme was not generated as a loop")
		quit(1)
		return
	scene.call("_set_match_settings", 45.0, 0.8, 1, 2)
	if hud.half_duration != 45.0 or not is_equal_approx(scene.get("opponent_speed_scale"), 0.8):
		push_error("Match settings did not update half length and opponent speed")
		quit(1)
		return
	hud.touch_controls.set_control_scale(1.25)
	hud.touch_controls.set_control_layout(180.0, 50.0)
	if not is_equal_approx(hud.touch_controls.control_scale, 1.25) or not is_equal_approx(hud.touch_controls.joystick_base_pos.x, 180.0):
		push_error("Touch control size or position settings did not apply")
		quit(1)
		return
	hud.set_training_mode(true)
	hud.set_training_goals(2)
	if not hud.training_mode or not hud.training_label.visible or hud.training_label.text != "TRAINING GOALS: 2":
		push_error("Training mode goal counter did not update")
		quit(1)
		return
	hud.set_training_mode(false)
	if scene.get_node_or_null("Penalty Arc North0") == null or scene.get_node_or_null("Penalty Arc South27") == null:
		push_error("Penalty D-arcs are missing from the pitch")
		quit(1)
		return
	if scene.get_node_or_null("Center Spot") == null or scene.get_node_or_null("Center Spot").mesh is not CylinderMesh:
		push_error("Center spot should be a circular pitch marking")
		quit(1)
		return

	var expected_views := ["BROADCAST", "TACTICAL", "FOLLOW"]
	for expected_view in expected_views:
		hud.camera_view_button.pressed.emit()
		if camera.get_view_name() != expected_view or hud.camera_view_button.text != "CAM: " + expected_view:
			push_error("Camera view button did not cycle to %s" % expected_view)
			quit(1)
			return

	# 1. Verify Goalkeepers exist and are set up properly
	if not is_instance_valid(home_gk) or not is_instance_valid(away_gk):
		push_error("Goalkeepers were not properly instantiated")
		quit(1)
		return

	if home_gk.team != "home" or away_gk.team != "away":
		push_error("Goalkeeper teams not assigned correctly")
		quit(1)
		return

	if away_gk.global_position.z >= -20.0 or home_gk.global_position.z <= 20.0:
		push_error("Goalkeeper initial positions are outside their respective goal areas")
		quit(1)
		return

	# 2. Verify Goal Net Collisions exist
	var north_net := scene.get_node_or_null("North GoalCollision") as StaticBody3D
	var south_net := scene.get_node_or_null("South GoalCollision") as StaticBody3D
	if not is_instance_valid(north_net) or not is_instance_valid(south_net):
		push_error("Goal net collision bodies are missing")
		quit(1)
		return

	# 3. Test Shot Charging
	if not player.has_ball:
		push_error("Player should start with the ball for shot test")
		quit(1)
		return

	_send_key(KEY_K, true)
	for _f in range(3):
		await physics_frame

	if not player.is_charging_shot:
		push_error("Player did not start charging shot when K was pressed")
		quit(1)
		return

	if not hud.power_bar_panel.visible:
		push_error("HUD power bar did not appear when shot charging started")
		quit(1)
		return

	# Charge for several frames
	for _f in range(20):
		await physics_frame

	if player.shot_charge <= 0.15:
		push_error("Shot charge did not increase while holding K: charge=%f" % player.shot_charge)
		quit(1)
		return

	if not player.aim_arrow.visible:
		push_error("Aim arrow should be visible while charging shot")
		quit(1)
		return

	# 4. Test Directional Aiming
	_send_key(KEY_LEFT, true)
	for _f in range(12):
		await physics_frame
	_send_key(KEY_LEFT, false)

	if player.shot_aim_direction.x >= -0.05:
		push_error("Directional aim should steer left when holding left arrow key: x=%f" % player.shot_aim_direction.x)
		quit(1)
		return
	player.facing = Vector3(0.0, 0.0, -1.0)
	player.virtual_movement_direction = Vector2.RIGHT
	player._process_user_ball_actions(0.0)
	if player.shot_aim_direction.x <= 0.05:
		push_error("Virtual joystick should steer charged shots to the right: x=%f" % player.shot_aim_direction.x)
		quit(1)
		return
	player.virtual_movement_direction = Vector2.ZERO

	# Release K to fire shot
	_send_key(KEY_K, false)
	for _f in range(3):
		await physics_frame

	if player.is_charging_shot:
		push_error("Shot charge did not release after releasing K")
		quit(1)
		return

	if hud.power_bar_panel.visible:
		push_error("HUD power bar should hide after shot is released")
		quit(1)
		return

	if ball.linear_velocity.length() < 10.0:
		push_error("Ball was not fired with charged shot impulse: vel=%f" % ball.linear_velocity.length())
		quit(1)
		return

	# 5. Test Goal Net Containment: shoot directly into net from close range and verify ball stays in net
	ball.freeze = true
	ball.remove_meta("owner")
	ball.global_position = Vector3(0.0, 1.2, -23.0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.freeze = false
	ball.apply_central_impulse(Vector3(0.0, 0.0, -22.0))

	# Wait for ball to hit the back of the net
	for _f in range(60):
		await physics_frame

	# Net back is at z = -25.7 - 2.4 = -28.1. Ball should not pass z = -28.6
	if ball.global_position.z < -28.6:
		push_error("Ball penetrated through the back of the goal net: z=%f" % ball.global_position.z)
		quit(1)
		return

	var opponent := scene.get_node("Opponent") as FootballOpponent
	player.global_position = Vector3.ZERO
	player.facing = Vector3(0.0, 0.0, -1.0)
	player.has_ball = false
	player.standing_tackle_cooldown = 0.0
	opponent.global_position = Vector3(0.0, 0.0, -1.3)
	opponent.has_ball = true
	ball.set_meta("owner", "opponent")
	ball.freeze = true
	if not player._standing_tackle() or not player.has_ball or str(ball.get_meta("owner", "")) != player.name:
		push_error("Successful standing tackle did not transfer possession to the defender")
		quit(1)
		return

	var home_team: Array = scene.get("home_team")
	home_gk.distribution_targets = home_team
	home_gk.has_ball = true
	home_gk.facing = Vector3(0.0, 0.0, -1.0)
	home_gk.global_position = Vector3(0.0, 0.1, 24.0)
	ball.set_meta("owner", home_gk.name)
	ball.freeze = true
	home_gk._distribute_ball()
	if home_gk.has_ball or ball.freeze or ball.linear_velocity.z >= 0.0:
		push_error("Goalkeeper distribution did not release the ball toward a teammate")
		quit(1)
		return

	print("PASS: Goalkeepers, Goal Nets, Charged Shooting, Aiming, Standing Tackle, and Keeper Distribution")
	scene.queue_free()
	quit(0)
