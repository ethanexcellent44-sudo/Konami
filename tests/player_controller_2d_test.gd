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
	var player: CharacterBody2D = pitch.get_node_or_null("Player2D") as CharacterBody2D
	if player == null:
		_fail("2D pitch is missing its player controller")
		pitch.queue_free()
		return
	var controls: Control = player.get_node_or_null("PlayerControlsLayer/VirtualTouchControls") as Control
	if controls == null:
		_fail("Virtual touch controls were not created")
		pitch.queue_free()
		return
	var player_origin: Vector2 = player.global_position
	Input.action_press("move_right")
	for frame_index in range(8):
		await physics_frame
	Input.action_release("move_right")
	if player.global_position.x <= player_origin.x:
		_fail("Keyboard movement did not move the 2D player")
		pitch.queue_free()
		return

	var stamina_before: float = float(player.get("stamina"))
	Input.action_press("sprint")
	Input.action_press("move_forward")
	for frame_index in range(12):
		await physics_frame
	Input.action_release("sprint")
	Input.action_release("move_forward")
	if float(player.get("stamina")) >= stamina_before:
		_fail("Sprint did not consume stamina")
		pitch.queue_free()
		return

	var shot_emitted: Array[bool] = [false]
	player.connect("shot_released", func(_direction: Vector2, _power: float) -> void: shot_emitted[0] = true)
	Input.action_press("shoot_ball")
	for frame_index in range(100):
		await physics_frame
	Input.action_release("shoot_ball")
	await physics_frame
	if not shot_emitted[0]:
		_fail("Charged shot did not emit its release signal")
		pitch.queue_free()
		return
	var virtual_controls: Node = controls
	var touch_buttons: Array = virtual_controls.get("buttons")
	var has_pass: bool = false
	var has_through: bool = false
	var has_sprint: bool = false
	var has_shoot: bool = false
	for touch_button: Variant in touch_buttons:
		has_pass = has_pass or touch_button.action == "pass_ball"
		has_through = has_through or touch_button.action == "through_ball"
		has_sprint = has_sprint or touch_button.action == "sprint"
		has_shoot = has_shoot or touch_button.action == "shoot_ball"
	if not has_pass or not has_through or not has_sprint or not has_shoot:
		_fail("Required mobile action buttons are missing")
		pitch.queue_free()
		return
	print("PASS: 2D player movement, sprint stamina, charged shot, and touch actions")
	pitch.queue_free()
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
