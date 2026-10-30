extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var pitch_scene: PackedScene = load("res://scenes/pitch_2d.tscn")
	if pitch_scene == null:
		_fail("2D pitch scene failed to load")
		return
	var pitch: Node2D = pitch_scene.instantiate() as Node2D
	root.add_child(pitch)
	await physics_frame
	await physics_frame
	var home: Node = pitch.get_node_or_null("HomeTeamAI")
	var away: Node = pitch.get_node_or_null("AwayTeamAI")
	if home == null or away == null:
		_fail("Pitch did not create both AI teams")
		pitch.queue_free()
		return
	var home_players: Array = home.get("players")
	var away_players: Array = away.get("players")
	if home_players.size() != 11 or away_players.size() != 11:
		_fail("Each formation must contain exactly eleven players")
		pitch.queue_free()
		return
	if str(home.get("formation")) != "4-3-3" or str(away.get("formation")) != "4-4-2":
		_fail("Team formations did not load correctly")
		pitch.queue_free()
		return

	home.set("formation", "4-4-2")
	home.call("rebuild_formation")
	await process_frame
	if (home.get("players") as Array).size() != 11:
		_fail("Changing formation did not preserve the eleven-player squad")
		pitch.queue_free()
		return
	if str(home.get("formation")) != "4-4-2":
		_fail("The team did not retain the selected 4-4-2 formation")
		pitch.queue_free()
		return

	var ball: RigidBody2D = pitch.get_node_or_null("FootballBall2D") as RigidBody2D
	var home_ai_players: Array = home.get("players")
	var away_ai_players: Array = away.get("players")
	var human_player: Node2D = pitch.get_node("Player2D") as Node2D
	var nearest_defender: Node2D = away_ai_players[5] as Node2D
	ball.global_position = Vector2(640.0, 360.0)
	for away_player: Node2D in away_ai_players:
		away_player.global_position = Vector2(1050.0, 600.0)
	nearest_defender.global_position = Vector2(710.0, 360.0)
	human_player.global_position = Vector2(520.0, 400.0)
	home_ai_players[2].global_position = Vector2(620.0, 360.0)
	home_ai_players[3].global_position = Vector2(720.0, 270.0)
	home_ai_players[4].global_position = Vector2(640.0, 250.0)
	home_ai_players[2].set_ai_target(Vector2(620.0, 360.0))
	home_ai_players[3].set_ai_target(Vector2(720.0, 270.0))
	home_ai_players[4].set_ai_target(Vector2(640.0, 250.0))
	home.set("_kick_cooldown", 0.0)
	away.call("_update_team_ai")
	home.call("_update_team_ai")
	if int(away.get("pressing_player_index")) != 5:
		_fail("Opponent press did not select the closest defender")
		pitch.queue_free()
		return
	if str(home.get("last_decision")) != "pass":
		_fail("AI with possession did not select a forward passing option")
		pitch.queue_free()
		return
	if int(home.get("last_pass_receiver")) < 0:
		_fail("AI pass decision did not choose a receiver")
		pitch.queue_free()
		return
	print("PASS: 4-3-3/4-4-2 squads, formation switching, pressing, and forward passing")
	pitch.queue_free()
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
