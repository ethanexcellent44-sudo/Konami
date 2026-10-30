extends Node
class_name MatchReplay

signal replay_state_changed(active: bool)
var tracked_nodes: Array[Node3D] = []
var frames: Array = []
var sample_timer: float = 0.0
var replaying: bool = false
var slow_motion: bool = false
var skip_requested: bool = false
var replay_camera_mode: int = 0
const SAMPLE_INTERVAL := 0.12
const MAX_FRAMES := 30

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if replaying or tracked_nodes.is_empty():
		return
	sample_timer += delta
	if sample_timer < SAMPLE_INTERVAL:
		return
	sample_timer = 0.0
	var frame: Array[Dictionary] = []
	for tracked_node in tracked_nodes:
		if not is_instance_valid(tracked_node):
			frame.append({})
			continue
		var sample := {"transform": tracked_node.global_transform}
		if tracked_node is CharacterBody3D:
			sample["velocity"] = (tracked_node as CharacterBody3D).velocity
		elif tracked_node is RigidBody3D:
			var rigid_body := tracked_node as RigidBody3D
			sample["linear_velocity"] = rigid_body.linear_velocity
			sample["angular_velocity"] = rigid_body.angular_velocity
		frame.append(sample)
	frames.append(frame)
	if frames.size() > MAX_FRAMES:
		frames.pop_front()

func play_highlight() -> void:
	if replaying or frames.size() < 5:
		return
	replaying = true
	skip_requested = false
	replay_camera_mode = 0
	replay_state_changed.emit(true)
	var saved_state: Array[Dictionary] = []
	for tracked_node in tracked_nodes:
		if not is_instance_valid(tracked_node):
			saved_state.append({})
			continue
		var state := {"transform": tracked_node.global_transform}
		if tracked_node is CharacterBody3D:
			state["velocity"] = (tracked_node as CharacterBody3D).velocity
		elif tracked_node is RigidBody3D:
			var rigid_body := tracked_node as RigidBody3D
			state["linear_velocity"] = rigid_body.linear_velocity
			state["angular_velocity"] = rigid_body.angular_velocity
			state["freeze"] = rigid_body.freeze
			rigid_body.freeze = true
		saved_state.append(state)
	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	for frame: Array in frames:
		if skip_requested:
			break
		_apply_frame(frame)
		_apply_replay_camera()
		await tree.create_timer(0.12 if slow_motion else 0.04, true).timeout
	for index in range(tracked_nodes.size()):
		var tracked_node := tracked_nodes[index]
		var state: Dictionary = saved_state[index]
		if not is_instance_valid(tracked_node) or state.is_empty():
			continue
		tracked_node.global_transform = state["transform"]
		if tracked_node is CharacterBody3D:
			(tracked_node as CharacterBody3D).velocity = state.get("velocity", Vector3.ZERO)
		elif tracked_node is RigidBody3D:
			var rigid_body := tracked_node as RigidBody3D
			rigid_body.linear_velocity = state.get("linear_velocity", Vector3.ZERO)
			rigid_body.angular_velocity = state.get("angular_velocity", Vector3.ZERO)
			rigid_body.freeze = state.get("freeze", false)
	tree.paused = was_paused
	replaying = false
	slow_motion = false
	replay_state_changed.emit(false)

func _apply_frame(frame: Array) -> void:
	for index in range(mini(frame.size(), tracked_nodes.size())):
		var tracked_node := tracked_nodes[index]
		var sample: Dictionary = frame[index]
		if not is_instance_valid(tracked_node) or sample.is_empty():
			continue
		tracked_node.global_transform = sample["transform"]

func handle_command(command: String) -> void:
	match command:
		"slow":
			slow_motion = not slow_motion
		"camera":
			replay_camera_mode = posmod(replay_camera_mode + 1, 3)
		"skip":
			skip_requested = true

func _apply_replay_camera() -> void:
	if tracked_nodes.size() <= 3:
		return
	var replay_camera := tracked_nodes[3] as Camera3D
	if not is_instance_valid(replay_camera):
		return
	var focus_node := tracked_nodes[0]
	if replay_camera_mode == 2 and tracked_nodes.size() > 2:
		focus_node = tracked_nodes[2]
	if not is_instance_valid(focus_node):
		return
	var offsets := [Vector3(0.0, 8.5, 12.5), Vector3(16.0, 13.0, 1.5), Vector3(0.0, 28.0, 0.1)]
	var focus := focus_node.global_position
	replay_camera.global_position = focus + offsets[replay_camera_mode]
	replay_camera.look_at(focus + Vector3.UP, Vector3.UP)
