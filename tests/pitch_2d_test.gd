extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var pitch_scene: PackedScene = load("res://scenes/pitch_2d.tscn")
	if pitch_scene == null:
		_fail("2D pitch scene failed to load")
		return
	var pitch := pitch_scene.instantiate() as Node2D
	if pitch == null:
		_fail("2D pitch scene root is not a FootballPitch2D")
		return
	if absf(pitch.field_origin.x - 60.0) > 0.001 or absf(pitch.field_origin.y - 60.0) > 0.001:
		_fail("Pitch field origin must align to the reference kit at (60, 60)")
		pitch.queue_free()
		return
	if absf(pitch.field_size.x - 1050.0) > 0.001 or absf(pitch.field_size.y - 680.0) > 0.001:
		_fail("Pitch field must use the corrected 1050x680 playing rectangle from the reference kit")
		pitch.queue_free()
		return
	if absf(pitch.goal_width - 73.2) > 0.001:
		_fail("Goal width must match the 73.2 px reference dimension")
		pitch.queue_free()
		return
	root.add_child(pitch)
	await physics_frame
	var ball := pitch.get_node_or_null("FootballBall2D") as RigidBody2D
	if ball == null:
		_fail("2D pitch scene is missing its rigid-body ball")
		pitch.queue_free()
		return
	if pitch.get_node_or_null("LeftTouchline") != null or pitch.get_node_or_null("TopGoalLeftPost") == null:
		_fail("Touchlines must be open for throw-ins while goal-post collisions remain")
		pitch.queue_free()
		return
	var initial_velocity: Vector2 = ball.linear_velocity
	ball.call("kick", Vector2.RIGHT, 0.5)
	await physics_frame
	if ball.linear_velocity.x <= initial_velocity.x:
		_fail("Ball kick did not apply a forward physics impulse")
		pitch.queue_free()
		return
	print("PASS: 2D pitch scene, goal posts, boundaries, ball physics, and kick impulse")
	pitch.queue_free()
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
