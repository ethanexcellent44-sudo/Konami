extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var scene := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(scene)
	await physics_frame

	var player := scene.get_node("Player") as FootballPlayer
	var ball := scene.get_node("Ball") as RigidBody3D
	player.set_physics_process(false)
	player.has_ball = true
	player.gait_phase = 0.0
	ball.set_meta("owner", player.name)
	ball.freeze = true

	player.velocity = Vector3.ZERO
	player._update_ball_control()
	var walking_touch_distance := Vector2(
		ball.global_position.x - player.global_position.x,
		ball.global_position.z - player.global_position.z
	).length()

	player.velocity = Vector3(0.0, 0.0, -player.sprint_speed)
	player._update_ball_control()
	var sprint_touch_distance := Vector2(
		ball.global_position.x - player.global_position.x,
		ball.global_position.z - player.global_position.z
	).length()

	if sprint_touch_distance <= walking_touch_distance:
		push_error("Fast dribbling should push the ball farther ahead than a walking touch")
		scene.queue_free()
		quit(1)
		return
	if sprint_touch_distance > 2.0:
		push_error("Dribbling touch let the ball get too far from the player")
		scene.queue_free()
		quit(1)
		return

	var opponent := scene.get_node("Opponent") as FootballOpponent
	var away_team: Array = scene.get("away_team")
	opponent.home_players = []
	opponent.kick_cooldown = 0.0
	opponent.global_position = Vector3.ZERO
	ball.global_position = Vector3(0.0, 0.0, 8.0)
	if opponent._should_shoot():
		push_error("Opponent should not shoot from outside its shooting range")
		scene.queue_free()
		quit(1)
		return

	ball.global_position = Vector3(0.0, 0.0, 18.0)
	if not opponent._should_shoot():
		push_error("Opponent should shoot when close to goal with no nearby pressure")
		scene.queue_free()
		quit(1)
		return

	opponent.global_position = Vector3.ZERO
	away_team[1].global_position = Vector3(0.0, 0.0, 10.0)
	away_team[2].global_position = Vector3(8.0, 0.0, 8.0)
	player.global_position = Vector3(0.0, 0.0, 5.0)
	opponent.home_players = [player]
	if opponent._find_best_pass_target() != away_team[2]:
		push_error("Opponent should prefer an open pass lane over a marked forward teammate")
		scene.queue_free()
		quit(1)
		return

	print("PASS: Speed-sensitive dribbling, shot range, and open-lane pass selection")
	scene.queue_free()
	quit(0)
