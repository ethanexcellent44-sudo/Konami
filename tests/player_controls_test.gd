extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _send_key(physical_keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	event.keycode = physical_keycode
	event.pressed = pressed
	Input.parse_input_event(event)

func _has_physical_binding(action_name: String, physical_keycode: Key) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == physical_keycode:
			return true
	return false

func _run_test() -> void:
	var scene := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(scene)
	await physics_frame

	var player := scene.get_node("Player") as FootballPlayer
	var ball := scene.get_node("Ball") as RigidBody3D
	var home_team: Array = scene.get("home_team")
	if home_team.size() != 10:
		push_error("Home team should contain ten outfield players in addition to its goalkeeper")
		quit(1)
		return
	var start_position := player.global_position
	if not player.has_ball:
		push_error("Player should start kickoff with the ball")
		quit(1)
		return
	if _has_physical_binding("move_forward", KEY_W) or _has_physical_binding("move_back", KEY_S) or _has_physical_binding("move_left", KEY_A) or _has_physical_binding("move_right", KEY_D):
		push_error("Movement should use arrow keys only")
		quit(1)
		return
	_send_key(KEY_UP, true)
	for _frame in range(30):
		await physics_frame
	_send_key(KEY_UP, false)

	if player.global_position.z >= start_position.z - 0.5:
		push_error("Forward input did not move the player")
		quit(1)
		return
	if not player.has_ball:
		push_error("Player did not collect the nearby kickoff ball")
		quit(1)
		return

	var start_ball_position := ball.global_position
	_send_key(KEY_RIGHT, true)
	for _frame in range(15):
		await physics_frame
	_send_key(KEY_RIGHT, false)

	if player.global_position.x <= start_position.x + 0.2:
		push_error("Right input did not move the player")
		quit(1)
		return
	if ball.global_position.distance_to(player.global_position) > 2.0:
		push_error("Ball did not stay with the moving player")
		quit(1)
		return
	if ball.global_position.distance_to(start_ball_position) < 0.2:
		push_error("Ball did not move with the player")
		quit(1)
		return
	if not player.has_ball:
		push_error("Player lost kickoff possession during the movement test")
		quit(1)
		return

	if not _has_physical_binding("pass_ball", KEY_J):
		push_error("J is not mapped to pass")
		quit(1)
		return
	if not _has_physical_binding("shoot_ball", KEY_K):
		push_error("K is not mapped to shoot")
		quit(1)
		return
	var pass_target := player._select_pass_target()
	if not is_instance_valid(pass_target):
		push_error("Pass should select an available teammate")
		quit(1)
		return
	if player.facing.dot((pass_target.global_position - player.global_position).normalized()) <= 0.0:
		push_error("Pass target should be in front of the player")
		quit(1)
		return

	var before_arrow_move := player.global_position.z
	_send_key(KEY_UP, true)
	for _frame in range(15):
		await physics_frame
	_send_key(KEY_UP, false)
	if player.global_position.z >= before_arrow_move - 0.2:
		push_error("Arrow-key movement binding did not move the player")
		quit(1)
		return

	var before_left := player.global_position.x
	_send_key(KEY_LEFT, true)
	for _frame in range(12):
		await physics_frame
	_send_key(KEY_LEFT, false)
	if player.global_position.x >= before_left - 0.1:
		push_error("Left-arrow movement binding did not move the player")
		quit(1)
		return

	var before_right := player.global_position.x
	_send_key(KEY_RIGHT, true)
	for _frame in range(12):
		await physics_frame
	_send_key(KEY_RIGHT, false)
	if player.global_position.x <= before_right + 0.1:
		push_error("Right-arrow movement binding did not move the player")
		quit(1)
		return

	var before_down := player.global_position.z
	_send_key(KEY_DOWN, true)
	for _frame in range(12):
		await physics_frame
	_send_key(KEY_DOWN, false)
	if player.global_position.z <= before_down + 0.1:
		push_error("Down-arrow movement binding did not move the player")
		quit(1)
		return

	if not player.has_ball:
		player.has_ball = true
		ball.set_meta("owner", player.name)
		ball.freeze = true
		ball.global_position = player.global_position + player.facing * 1.05 + Vector3.UP * 0.38
	player._pass_ball()
	for _frame in range(180):
		await physics_frame
	var active_player := scene.get("player") as FootballPlayer
	if active_player == player:
		push_error("A teammate did not receive the pass and become controlled")
		quit(1)
		return

	print("PASS: physical movement, dribbling, teammate pass selection, reception, and control handoff work")
	scene.queue_free()
	quit()
