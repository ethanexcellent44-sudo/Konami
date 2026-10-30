extends CharacterBody2D
class_name FootballPlayer2D

signal pass_requested(direction: Vector2)
signal through_ball_requested(direction: Vector2)
signal shot_released(direction: Vector2, power: float)
signal tackle_attempted(position: Vector2)
signal stamina_changed(current: float, maximum: float)

@export var walk_speed: float = 230.0
@export var sprint_speed: float = 340.0
@export var acceleration: float = 1150.0
@export var friction: float = 1450.0
@export var maximum_stamina: float = 100.0
@export var stamina_drain_per_second: float = 34.0
@export var stamina_recovery_per_second: float = 22.0
@export var shot_charge_seconds: float = 1.25
@export var ball_control_radius: float = 54.0
@export var pass_power: float = 0.58
@export var through_power: float = 0.78
@export var tackle_cooldown_seconds: float = 0.8
@export var ball_path: NodePath = NodePath("../FootballBall2D")
@export var is_human_controlled: bool = true
@export var team_color: Color = Color("#22e07a")
@export_range(1, 99, 1) var squad_number: int = 10
@export var attack_direction: Vector2 = Vector2.UP

const VIRTUAL_CONTROLS_SCRIPT: GDScript = preload("res://scripts/virtual_touch_controls.gd")
const TEAM_GREEN: Color = Color("#22e07a")
const NAVY: Color = Color("#0b1530")
const GOLD: Color = Color("#f0a500")

var ball: FootballBall2D
var joystick_direction: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.UP
var stamina: float = 100.0
var shot_charge: float = 0.0
var is_charging_shot: bool = false
var tackle_cooldown: float = 0.0
var stamina_bar: ProgressBar
var shot_bar: ProgressBar
var ai_target_position: Vector2
var ai_sprinting: bool = false

func _ready() -> void:
	stamina = maximum_stamina
	ai_target_position = global_position
	ball = get_node_or_null(ball_path) as FootballBall2D
	_build_visual()
	if is_human_controlled:
		_build_hud()
		stamina_changed.emit(stamina, maximum_stamina)

func set_ai_target(target_position: Vector2, sprinting: bool = false) -> void:
	ai_target_position = target_position
	ai_sprinting = sprinting

func ai_kick(direction: Vector2, power: float) -> void:
	if not is_instance_valid(ball):
		return
	facing_direction = direction.normalized()
	ball.kick(facing_direction, power)

func _physics_process(delta: float) -> void:
	var movement: Vector2
	var sprinting: bool
	if is_human_controlled:
		var keyboard_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		movement = joystick_direction if not joystick_direction.is_zero_approx() else keyboard_direction
		sprinting = Input.is_action_pressed("sprint") and stamina > 0.0 and not movement.is_zero_approx()
	else:
		var to_target: Vector2 = ai_target_position - global_position
		movement = to_target.normalized() if to_target.length() > 8.0 else Vector2.ZERO
		sprinting = ai_sprinting and stamina > 0.0 and not movement.is_zero_approx()
	var target_speed: float = sprint_speed if sprinting else walk_speed
	var target_velocity: Vector2 = movement * target_speed
	var rate: float = acceleration if not movement.is_zero_approx() else friction
	velocity = velocity.move_toward(target_velocity, rate * delta)
	move_and_slide()

	if not movement.is_zero_approx():
		facing_direction = movement.normalized()
	if sprinting:
		stamina = maxf(0.0, stamina - stamina_drain_per_second * delta)
	else:
		stamina = minf(maximum_stamina, stamina + stamina_recovery_per_second * delta)
	if is_human_controlled:
		stamina_changed.emit(stamina, maximum_stamina)
		stamina_bar.value = stamina
	if is_human_controlled:
		if tackle_cooldown > 0.0:
			tackle_cooldown = maxf(0.0, tackle_cooldown - delta)
		_handle_actions(delta)
	_update_ball_reference()

func _handle_actions(delta: float) -> void:
	if Input.is_action_just_pressed("pass_ball"):
		pass_requested.emit(_attack_facing_direction())
		_kick_ball(_attack_facing_direction(), pass_power)
	if Input.is_action_just_pressed("through_ball"):
		through_ball_requested.emit(_attack_facing_direction())
		_kick_ball(_attack_facing_direction(), through_power)
	if Input.is_action_just_pressed("shoot_ball"):
		is_charging_shot = true
		shot_charge = 0.0
	if is_charging_shot and Input.is_action_pressed("shoot_ball"):
		shot_charge = minf(1.0, shot_charge + delta / maxf(shot_charge_seconds, 0.1))
		shot_bar.value = shot_charge * 100.0
	if is_charging_shot and (Input.is_action_just_released("shoot_ball") or shot_charge >= 1.0):
		var released_power: float = maxf(0.25, shot_charge)
		shot_released.emit(_attack_facing_direction(), released_power)
		_kick_ball(_attack_facing_direction(), released_power)
		is_charging_shot = false
		shot_charge = 0.0
		shot_bar.value = 0.0
	if Input.is_action_just_pressed("standing_tackle") or Input.is_action_just_pressed("slide_tackle"):
		_attempt_tackle()

func _kick_ball(direction: Vector2, power: float) -> void:
	if not is_instance_valid(ball) or global_position.distance_to(ball.global_position) > ball_control_radius:
		return
	ball.kick(direction, power)

func _attack_facing_direction() -> Vector2:
	if absf(facing_direction.x) > absf(facing_direction.y):
		return facing_direction
	return attack_direction.normalized()

func _attempt_tackle() -> void:
	if tackle_cooldown > 0.0:
		return
	tackle_cooldown = tackle_cooldown_seconds
	tackle_attempted.emit(global_position)
	if is_instance_valid(ball) and global_position.distance_to(ball.global_position) <= ball_control_radius * 1.15:
		var knock_direction: Vector2 = (ball.global_position - global_position).normalized()
		if knock_direction.is_zero_approx():
			knock_direction = facing_direction
		ball.kick(knock_direction, 0.36)

func _update_ball_reference() -> void:
	if not is_instance_valid(ball):
		ball = get_node_or_null(ball_path) as FootballBall2D

func _build_visual() -> void:
	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	shadow.color = Color(0.0, 0.0, 0.0, 0.22)
	shadow.position = Vector2(3.0, 6.0)
	shadow.polygon = PackedVector2Array([Vector2(-15, -9), Vector2(0, -15), Vector2(15, -9), Vector2(15, 9), Vector2(0, 15), Vector2(-15, 9)])
	add_child(shadow)
	var body := Polygon2D.new()
	body.name = "PlayerBody"
	body.color = team_color if team_color != TEAM_GREEN else TEAM_GREEN
	body.polygon = PackedVector2Array([Vector2(-15, -9), Vector2(0, -15), Vector2(15, -9), Vector2(15, 9), Vector2(0, 15), Vector2(-15, 9)])
	add_child(body)
	var number := Label.new()
	number.name = "SquadNumber"
	number.text = str(squad_number)
	number.position = Vector2(-11, -10)
	number.size = Vector2(22, 20)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 12)
	number.add_theme_color_override("font_color", NAVY)
	add_child(number)
	var direction_marker := Polygon2D.new()
	direction_marker.name = "FacingMarker"
	direction_marker.color = GOLD
	direction_marker.position = Vector2(0.0, -19.0)
	direction_marker.polygon = PackedVector2Array([Vector2(0, -6), Vector2(-4, 1), Vector2(4, 1)])
	add_child(direction_marker)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15.0
	shape.shape = circle
	add_child(shape)

func _build_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "PlayerControlsLayer"
	hud_layer.layer = 5
	add_child(hud_layer)
	var touch_controls := VIRTUAL_CONTROLS_SCRIPT.new() as Control
	touch_controls.name = "VirtualTouchControls"
	touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_controls.joystick_moved.connect(_on_joystick_moved)
	hud_layer.add_child(touch_controls)
	var stamina_label := Label.new()
	stamina_label.text = "STAMINA"
	stamina_label.position = Vector2(28.0, 22.0)
	stamina_label.add_theme_font_size_override("font_size", 12)
	stamina_label.add_theme_color_override("font_color", Color(0.94, 0.96, 0.91))
	hud_layer.add_child(stamina_label)
	stamina_bar = _make_bar(Vector2(28.0, 43.0), Vector2(190.0, 14.0), TEAM_GREEN)
	hud_layer.add_child(stamina_bar)
	var shot_label := Label.new()
	shot_label.text = "SHOT POWER"
	shot_label.anchor_left = 0.5
	shot_label.anchor_right = 0.5
	shot_label.anchor_top = 1.0
	shot_label.anchor_bottom = 1.0
	shot_label.offset_left = -95.0
	shot_label.offset_right = 95.0
	shot_label.offset_top = -96.0
	shot_label.offset_bottom = -74.0
	shot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shot_label.add_theme_font_size_override("font_size", 12)
	shot_label.add_theme_color_override("font_color", Color(0.94, 0.96, 0.91))
	hud_layer.add_child(shot_label)
	shot_bar = _make_bar(Vector2.ZERO, Vector2(240.0, 16.0), GOLD)
	shot_bar.anchor_left = 0.5
	shot_bar.anchor_right = 0.5
	shot_bar.anchor_top = 1.0
	shot_bar.anchor_bottom = 1.0
	shot_bar.offset_left = -120.0
	shot_bar.offset_right = 120.0
	shot_bar.offset_top = -70.0
	shot_bar.offset_bottom = -54.0
	shot_bar.value = 0.0
	hud_layer.add_child(shot_bar)

func _make_bar(location: Vector2, dimensions: Vector2, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = location
	bar.size = dimensions
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.03, 0.06, 0.12, 0.9)
	background.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _on_joystick_moved(direction: Vector2) -> void:
	joystick_direction = direction
