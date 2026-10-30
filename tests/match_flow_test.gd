extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run_test() -> void:
	var scene := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(scene)
	await process_frame
	await physics_frame

	var hud := scene.get("hud") as MatchHud
	var team: Array = scene.get("home_team")
	var opponents: Array = scene.get("away_team")
	var ball := scene.get("ball") as RigidBody3D
	var current_player := scene.get("player") as FootballPlayer
	var opponent := scene.get("opponent") as FootballOpponent

	if team.size() != 10 or opponents.size() != 10:
		_fail("Match should start with ten outfield players plus a goalkeeper per team")
		scene.queue_free()
		return
	if scene.get("bench").size() != 5:
		_fail("Match should provide five substitution slots")
		scene.queue_free()
		return

	opponent._take_possession()
	var nearest_defender: FootballPlayer
	var nearest_distance := INF
	for teammate: FootballPlayer in team:
		if teammate == current_player:
			continue
		var distance := teammate.global_position.distance_squared_to(ball.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_defender = teammate
	scene.call("_switch_to_closest_defender")
	current_player = scene.get("player") as FootballPlayer
	if current_player != nearest_defender or not current_player.is_user_controlled:
		_fail("Defender switch did not select the closest available teammate")
		scene.queue_free()
		return
	for away_player: FootballOpponent in opponents:
		if away_player.player != current_player:
			_fail("Opponent AI was not updated after the controlled defender changed")
			scene.queue_free()
			return

	hud.home_score = 2
	hud.away_score = 1
	hud.home_shots = 4
	hud.home_possession_time = 20.0
	hud.trigger_half_time()
	if hud.running or hud.match_period != 2 or not hud.match_end_modal.visible or not paused:
		_fail("Half-time did not stop play and show the period modal")
		scene.queue_free()
		return

	scene.call("_start_second_half")
	if not hud.running or hud.match_period != 3 or hud.elapsed != hud.half_duration or paused:
		_fail("Starting the second half did not resume the match clock")
		scene.queue_free()
		return
	if hud.match_end_modal.visible:
		_fail("The period modal remained open after the second-half kickoff")
		scene.queue_free()
		return

	scene.call("_restart_match")
	if hud.home_score != 0 or hud.away_score != 0 or hud.home_shots != 0:
		_fail("Restarting the match did not clear the score and match statistics")
		scene.queue_free()
		return
	if hud.match_period != 1 or hud.elapsed != 0.0 or not hud.running or paused:
		_fail("Restarting the match did not restore the first-half clock")
		scene.queue_free()
		return
	for away_player: FootballOpponent in opponents:
		if away_player.has_ball or away_player.velocity.length_squared() > 0.0:
			_fail("Restarting the match left an away player in stale possession or motion")
			scene.queue_free()
			return

	print("PASS: Defender switching, half-time flow, and clean match restart")
	scene.queue_free()
	quit(0)
