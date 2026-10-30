extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run_test() -> void:
	var scene := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(scene)
	await physics_frame
	await physics_frame

	var hud := scene.get("hud") as MatchHud
	var player := scene.get("player") as FootballPlayer
	var home_team: Array = scene.get("home_team")
	var away_team: Array = scene.get("away_team")
	var replay := scene.get_node_or_null("MatchReplay") as MatchReplay
	if not is_instance_valid(hud) or not is_instance_valid(player) or not is_instance_valid(replay):
		_fail("Tactical, HUD, or replay systems did not initialize")
		scene.queue_free()
		return
	if hud.tactical_preset_option.item_count != 3 or hud.remap_action_option.item_count < 10:
		_fail("Tactical presets or key remapping options are missing")
		scene.queue_free()
		return
	if scene.get("bench").size() != 5 or hud.substitute_player_option.item_count != 10 or hud.substitute_reserve_option.item_count != 5 or hud.weather_option.item_count != 3:
		_fail("Substitution slots or atmosphere options are missing")
		scene.queue_free()
		return

	for action_name in ["move_forward", "move_back", "move_left", "move_right", "pass_ball", "shoot_ball"]:
		var has_gamepad_binding := false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventJoypadMotion or event is InputEventJoypadButton:
				has_gamepad_binding = true
				break
		if not has_gamepad_binding:
			_fail("Controller binding is missing for %s" % action_name)
			scene.queue_free()
			return

	scene.call("_set_tactical_preset", 0)
	for teammate: FootballPlayer in home_team:
		if teammate.tactical_preset != 0:
			_fail("Tactical preset did not apply to every home player")
			scene.queue_free()
			return
	scene.call("_set_opponent_style", 2)
	if (away_team[0] as FootballOpponent).tactical_style != 2:
		_fail("Opponent tactics were not applied")
		scene.queue_free()
		return
	scene.call("_set_local_multiplayer", true)
	if not (away_team[0] as FootballOpponent).local_human_controlled:
		_fail("Second local player did not take control of the away striker")
		scene.queue_free()
		return
	var p2_has_key := false
	var p2_has_controller := false
	for event in InputMap.action_get_events("p2_shoot"):
		if event is InputEventKey and event.physical_keycode == KEY_O:
			p2_has_key = true
		elif event is InputEventJoypadButton and event.device == 1:
			p2_has_controller = true
	if not p2_has_key:
		_fail("Second local player keyboard controls were not registered")
		scene.queue_free()
		return
	if not p2_has_controller:
		_fail("Second player controller is not isolated to joypad device 2")
		scene.queue_free()
		return
	scene.call("_set_local_multiplayer", false)
	scene.call("_make_substitution", 2, 0)
	if (scene.get("home_team")[2] as FootballPlayer).name != "Reserve1" or (scene.get("bench")[0] as FootballPlayer).visible:
		_fail("Substitution did not exchange the active player with the reserve")
		scene.queue_free()
		return
	for reserve_index in range(1, 5):
		scene.call("_make_substitution", reserve_index + 2, reserve_index)
	if int(scene.get("substitutions_made")) != 5:
		_fail("Match did not allow five substitutions")
		scene.queue_free()
		return
	var sixth_substitute_name: String = (scene.get("home_team")[7] as FootballPlayer).name
	scene.call("_make_substitution", 7, 0)
	if (scene.get("home_team")[7] as FootballPlayer).name != sixth_substitute_name:
		_fail("Match allowed more than five substitutions")
		scene.queue_free()
		return

	var target := home_team[1] as FootballPlayer
	var ball := scene.get("ball") as RigidBody3D
	for index in range(away_team.size()):
		(away_team[index] as FootballOpponent).global_position = Vector3(0.0, 0.1, -15.0 + float(index))
	(scene.get("away_goalkeeper") as FootballGoalkeeper).global_position = Vector3(0.0, 0.1, -16.0)
	ball.global_position = Vector3(0.0, 0.5, -12.0)
	target.global_position = Vector3(0.0, 0.1, -14.0)
	if not scene.call("_is_offside_target", target):
		_fail("Offside check did not include the goalkeeper when selecting the second-last defender")
		scene.queue_free()
		return
	target.global_position = Vector3(0.0, 0.1, -10.0)
	if scene.call("_is_offside_target", target):
		_fail("An attacker behind the defensive line was incorrectly flagged offside")
		scene.queue_free()
		return
	target.global_position = Vector3(0.0, 0.1, -14.0)
	ball.global_position = Vector3(0.0, 0.5, -12.0)
	scene.set("last_kick_offside_exempt", true)
	scene.call("_on_through_ball_triggered", target)
	if scene.get("next_restart_type") == "indirect_free_kick":
		_fail("Throw-in, corner, and goal-kick restarts must be exempt from offside")
		scene.queue_free()
		return
	scene.set("last_ball_owner", "Player")
	ball.global_position = Vector3(16.0, 0.5, -27.0)
	if scene.call("_get_set_piece_type") != "goal_kick" or scene.call("_get_set_piece_team") != "away":
		_fail("Goal-line exit after the attacking touch did not award a goal kick")
		scene.queue_free()
		return
	scene.set("last_ball_owner", "Opponent")
	if scene.call("_get_set_piece_type") != "corner" or scene.call("_get_set_piece_team") != "home":
		_fail("Goal-line exit after a defending touch did not award a corner")
		scene.queue_free()
		return
	scene.set("next_restart_type", "free_kick")
	scene.call("_reset_play", Vector3(3.0, 0.45, -12.0), "home")
	if not scene.get("set_piece_mode") or not player.set_piece_aiming or not hud.set_piece_label.visible:
		_fail("Home free kick did not enter the interactive aiming phase")
		scene.queue_free()
		return
	if not (scene.get("set_piece_wall") as Array).all(func(wall: MeshInstance3D) -> bool: return wall.visible):
		_fail("Free kick defensive wall did not appear")
		scene.queue_free()
		return
	scene.call("_on_ball_kicked", 0.5)
	if scene.get("set_piece_mode") or player.set_piece_aiming or hud.set_piece_label.visible:
		_fail("Free kick did not leave aiming mode after the kick")
		scene.queue_free()
		return

	scene.call("_set_weather", 2)
	if not is_instance_valid(scene.get("rain_particles")) or not scene.get("rain_particles").emitting:
		_fail("Rain atmosphere did not start")
		scene.queue_free()
		return
	scene.call("_set_weather", 0)
	hud.set_accessibility(0.8, 1.2, true)
	if not is_equal_approx(Engine.time_scale, 0.8):
		_fail("Game speed accessibility setting did not apply")
		scene.queue_free()
		return
	hud.set_accessibility(1.0, 1.0, false)

	scene.call("_start_training_challenge", "passing")
	player.training_action.emit("passing")
	if scene.get("challenge_score") != 1 or not scene.get("challenge_active"):
		_fail("Passing challenge did not score a passing action")
		scene.queue_free()
		return
	scene.set("challenge_active", false)
	scene.set("challenge_type", "")

	await create_timer(0.8).timeout
	if replay.frames.is_empty() or replay.tracked_nodes.size() < 6:
		_fail("Replay recorder did not capture a complete match frame")
		scene.queue_free()
		return
	var player_transform := player.global_transform
	await replay.play_highlight()
	if player.global_transform.origin.distance_to(player_transform.origin) > 0.01:
		_fail("Highlight playback did not restore the live player position")
		scene.queue_free()
		return
	replay.handle_command("slow")
	if not replay.slow_motion:
		_fail("Replay slow-motion control did not toggle")
		scene.queue_free()
		return
	replay.handle_command("camera")
	if replay.replay_camera_mode != 1:
		_fail("Replay camera control did not cycle viewpoints")
		scene.queue_free()
		return
	replay.handle_command("slow")

	var test_save_path := "user://advanced_features_test_%d.cfg" % Time.get_ticks_usec()
	var test_profile := UserProfile.new()
	test_profile.save_path = test_save_path
	hud.profile_store = test_profile
	test_profile.start_tournament()
	var results := [Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(3, 1), Vector2i(1, 1), Vector2i(0, 2)]
	for index in range(results.size()):
		var result: Vector2i = results[index]
		hud.home_score = result.x
		hud.away_score = result.y
		hud.trigger_full_time()
		paused = false
		var report := hud.get_node("MatchEndModal/EndCard/EndStatsText") as Label
		if index == 0 and report.text.contains("PREVIOUS:"):
			_fail("The first match report incorrectly listed itself as a previous result")
			scene.queue_free()
			return
		if index == 1 and not report.text.contains("PREVIOUS: 2 - 0"):
			_fail("The match report did not include the prior result")
			scene.queue_free()
			return
	var loaded_profile := UserProfile.new()
	loaded_profile.save_path = test_save_path
	loaded_profile.load_profile()
	if loaded_profile.tournament_active or loaded_profile.tournament_matches_remaining != 0 or loaded_profile.tournament_points != 8:
		_fail("Six-match tournament standings did not persist")
		scene.queue_free()
		return
	if loaded_profile.match_history.size() != 6 or int(loaded_profile.match_history[0].get("home_score", 0)) != 0:
		_fail("Match history did not persist")
		scene.queue_free()
		return
	if loaded_profile.tournament_results.size() != 6 or loaded_profile.tournament_results[0].get("opponent", "") != "Harbor Athletic":
		_fail("League opponent fixture results did not persist")
		scene.queue_free()
		return
	test_profile.set_key_binding("shoot_ball", KEY_Q)
	loaded_profile.load_profile()
	var has_saved_key := false
	for event in InputMap.action_get_events("shoot_ball"):
		if event is InputEventKey and event.physical_keycode == KEY_Q:
			has_saved_key = true
			break
	if not has_saved_key:
		_fail("Custom keyboard binding did not persist")
		scene.queue_free()
		return
	test_profile.start_career()
	for _fixture in range(6):
		test_profile.record_career_result(1, 0)
	if test_profile.career_active or test_profile.career_points != 18 or test_profile.career_upgrade_points != 12:
		_fail("Career season table or upgrade rewards did not progress")
		scene.queue_free()
		return
	if not test_profile.purchase_upgrade("shot") or test_profile.player_shot_upgrade != 1:
		_fail("Career player development was not purchasable")
		scene.queue_free()
		return
	loaded_profile.load_profile()
	if loaded_profile.career_results.size() != 6 or loaded_profile.career_goal_difference != 6:
		_fail("Career fixture table did not persist")
		scene.queue_free()
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	test_profile.free()
	loaded_profile.free()

	var penalty_target := away_team[0] as FootballOpponent
	scene.set("reset_lock", 0.0)
	scene.call("_on_opponent_foul", Vector3(0.0, 0.1, -20.0))
	if hud.status_label.text != "FOUL! PENALTY KICK" or scene.get("reset_lock") <= 0.0:
		_fail("Opponent foul did not award a home penalty")
		scene.queue_free()
		return
	scene.call("_reset_play", Vector3(0.0, 0.45, -20.0), "home")
	if not scene.get("penalty_mode") or hud.set_piece_label.text.find("PENALTY") < 0:
		_fail("Penalty restart did not enter penalty aiming mode")
		scene.queue_free()
		return
	scene.set("reset_lock", 0.0)
	player.has_ball = false
	player.global_position = Vector3(0.0, 0.1, 18.8)
	player.facing = Vector3(0.0, 0.0, 1.0)
	penalty_target.global_position = Vector3(0.0, 0.1, 21.0)
	penalty_target.has_ball = true
	ball.set_meta("owner", penalty_target.name)
	ball.freeze = true
	if player._standing_tackle():
		_fail("A mistimed tackle unexpectedly won possession")
		scene.queue_free()
		return
	if hud.status_label.text != "FOUL! PENALTY KICK" or scene.get("reset_lock") <= 0.0:
		_fail("A foul in the penalty area did not award a penalty restart")
		scene.queue_free()
		return

	print("PASS: Tactics, local multiplayer, substitutions, training, weather, accessibility, offside/fouls/set pieces, replay, cup, career, and persistence")
	scene.queue_free()
	quit(0)
