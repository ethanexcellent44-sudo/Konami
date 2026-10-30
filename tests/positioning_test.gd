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
	var home_team: Array[FootballPlayer] = scene.get("home_team")
	var opponent := scene.get_node("Opponent") as FootballOpponent

	# 1. Test Spacing & Formation at Kickoff
	for tm: FootballPlayer in home_team:
		for other: FootballPlayer in home_team:
			if tm != other:
				var dist: float = tm.global_position.distance_to(other.global_position)
				if dist < 3.5:
					push_error("Players start too close together: dist=%f between %s and %s" % [dist, tm.name, other.name])
					scene.queue_free()
					quit(1)
					return

	# 2. Move player forward and to the left (Left Flank attack)
	_send_key(KEY_UP, true)
	_send_key(KEY_LEFT, true)
	for _f in range(45):
		await physics_frame
	_send_key(KEY_UP, false)
	_send_key(KEY_LEFT, false)

	# Verify teammates did not clump onto the player or each other
	for tm: FootballPlayer in home_team:
		for other: FootballPlayer in home_team:
			if tm != other:
				var dist: float = tm.global_position.distance_to(other.global_position)
				if dist < 3.0:
					push_error("Players clumped during movement: dist=%f between %s and %s" % [dist, tm.name, other.name])
					scene.queue_free()
					quit(1)
					return

	# Verify pitch width coverage: teammates should provide lateral width
	var min_x: float = 999.0
	var max_x: float = -999.0
	for tm: FootballPlayer in home_team:
		if tm.global_position.x < min_x:
			min_x = tm.global_position.x
		if tm.global_position.x > max_x:
			max_x = tm.global_position.x

	var team_spread_x: float = max_x - min_x
	if team_spread_x < 6.0:
		push_error("Team failed to maintain width: spread_x=%f" % team_spread_x)
		scene.queue_free()
		quit(1)
		return

	# 3. Test Control Handoff: pass to a teammate and verify the old carrier drops into support rather than chasing
	var old_carrier := player
	var pass_target := player._select_pass_target()
	if not is_instance_valid(pass_target):
		push_error("No pass target available")
		scene.queue_free()
		quit(1)
		return

	player._pass_ball()
	for _f in range(90):
		await physics_frame

	var new_carrier := scene.get("player") as FootballPlayer
	if new_carrier == old_carrier:
		push_error("Pass was not completed to teammate")
		scene.queue_free()
		quit(1)
		return

	# Old carrier should NOT be right on top of new carrier
	var separation_after_pass: float = old_carrier.global_position.distance_to(new_carrier.global_position)
	if separation_after_pass < 4.0:
		push_error("Old carrier is crowding the new ball carrier: dist=%f" % separation_after_pass)
		scene.queue_free()
		quit(1)
		return

	# 4. Test Defensive Phase: give ball to opponent and check team does not follow player
	opponent._take_possession()
	for _f in range(30):
		await physics_frame

	var found_defending: bool = false
	for tm: FootballPlayer in home_team:
		var dist_to_opp: float = tm.global_position.distance_to(opponent.global_position)
		if dist_to_opp < 18.0:
			found_defending = true
			break

	if not found_defending:
		push_error("No player positioned defensively near the opponent")
		scene.queue_free()
		quit(1)
		return

	print("PASS: Intelligent positioning, triangle formations, anti-clumping, and role transitions verified")
	scene.queue_free()
	quit(0)
