extends Camera3D
class_name FollowCamera

var target: Node3D
var ball: Node3D
var follow_offset: Vector3 = Vector3(0.0, 7.5, 12.5)
var smoothing: float = 7.5
var view_mode: int = 0

const VIEW_NAMES := ["FOLLOW", "BROADCAST", "TACTICAL"]
const VIEW_OFFSETS := [
	Vector3(0.0, 8.5, 12.5),
	Vector3(16.0, 13.0, 1.5),
	Vector3(0.0, 28.0, 0.1)
]
const VIEW_FOVS := [62.0, 58.0, 70.0]

func set_view_mode(mode: int) -> void:
	view_mode = posmod(mode, VIEW_NAMES.size())
	fov = VIEW_FOVS[view_mode]

func get_view_name() -> String:
	return VIEW_NAMES[view_mode]

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var z_dist := target.global_position.z
	var penalty_factor := clampf((absf(z_dist) - 10.0) / 14.0, 0.0, 1.0)
	var follow_distance_offset := Vector3(0.0, penalty_factor * 1.5, -penalty_factor)
	var desired_focus := target.global_position
	if view_mode == 2 and is_instance_valid(ball):
		desired_focus = desired_focus.lerp(ball.global_position, 0.28)
	var desired: Vector3 = desired_focus + VIEW_OFFSETS[view_mode]
	if view_mode == 0:
		desired += follow_distance_offset
	global_position = global_position.lerp(desired, 1.0 - exp(-smoothing * delta))
	var look_target := desired_focus + Vector3(0.0, 1.0, 0.0)
	var up_direction := Vector3.FORWARD if view_mode == 2 else Vector3.UP
	look_at(look_target, up_direction)
