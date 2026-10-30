extends Control
class_name VirtualTouchControls

signal joystick_moved(direction: Vector2)
signal action_triggered(action_name: String, pressed: bool)

var joystick_active: bool = false
var joystick_touch_id: int = -1
var joystick_base_pos: Vector2 = Vector2(110, -110) # relative to bottom-left
var joystick_origin: Vector2 = Vector2.ZERO
var joystick_handle_pos: Vector2 = Vector2.ZERO
var joystick_radius: float = 65.0
var joystick_deadzone: float = 0.15
var joystick_vector: Vector2 = Vector2.ZERO

class TouchButton:
	var name: String
	var action: String
	var label: String
	var sub_label: String
	var color: Color
	var pos: Vector2 # relative to bottom-right
	var base_x: float
	var radius: float
	var is_pressed: bool = false
	var touch_id: int = -1

var buttons: Array[TouchButton] = []
var active_in_possession: bool = true
var control_scale: float = 1.0
var button_horizontal_offset: float = 0.0

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = MOUSE_FILTER_PASS

	_setup_buttons()

func _setup_buttons() -> void:
	buttons.clear()

	# PASS (Bottom)
	var btn_pass := TouchButton.new()
	btn_pass.name = "btn_pass"
	btn_pass.action = "pass_ball"
	btn_pass.label = "PASS"
	btn_pass.sub_label = "J"
	btn_pass.color = Color(0.18, 0.48, 0.92)
	btn_pass.pos = Vector2(-155, -85)
	btn_pass.radius = 36.0
	buttons.append(btn_pass)

	# THROUGH BALL (Top)
	var btn_through := TouchButton.new()
	btn_through.name = "btn_through"
	btn_through.action = "through_ball"
	btn_through.label = "THROUGH"
	btn_through.sub_label = "I"
	btn_through.color = Color(0.12, 0.68, 0.58)
	btn_through.pos = Vector2(-155, -205)
	btn_through.radius = 36.0
	buttons.append(btn_through)

	# SHOOT (Right)
	var btn_shoot := TouchButton.new()
	btn_shoot.name = "btn_shoot"
	btn_shoot.action = "shoot_ball"
	btn_shoot.label = "SHOOT"
	btn_shoot.sub_label = "K"
	btn_shoot.color = Color(0.92, 0.28, 0.25)
	btn_shoot.pos = Vector2(-85, -145)
	btn_shoot.radius = 38.0
	buttons.append(btn_shoot)

	# SPRINT / DASH (Left)
	var btn_sprint := TouchButton.new()
	btn_sprint.name = "btn_sprint"
	btn_sprint.action = "sprint"
	btn_sprint.label = "SPRINT"
	btn_sprint.sub_label = "F"
	btn_sprint.color = Color(0.95, 0.62, 0.12)
	btn_sprint.pos = Vector2(-225, -145)
	btn_sprint.radius = 36.0
	buttons.append(btn_sprint)

	# SLIDE TACKLE (Lower-Left Defend)
	var btn_tackle := TouchButton.new()
	btn_tackle.name = "btn_tackle"
	btn_tackle.action = "slide_tackle"
	btn_tackle.label = "SLIDE"
	btn_tackle.sub_label = "L"
	btn_tackle.color = Color(0.88, 0.42, 0.2)
	btn_tackle.pos = Vector2(-285, -85)
	btn_tackle.radius = 32.0
	buttons.append(btn_tackle)

	# SWITCH DEFENDER (Upper-Left Defend)
	var btn_switch := TouchButton.new()
	btn_switch.name = "btn_switch"
	btn_switch.action = "switch_player"
	btn_switch.label = "SWITCH"
	btn_switch.sub_label = "SPACE"
	btn_switch.color = Color(0.58, 0.32, 0.88)
	btn_switch.pos = Vector2(-285, -205)
	btn_switch.radius = 32.0
	buttons.append(btn_switch)

	var btn_keeper := TouchButton.new()
	btn_keeper.name = "btn_keeper"
	btn_keeper.action = "keeper_distribute"
	btn_keeper.label = "KEEP"
	btn_keeper.sub_label = "H"
	btn_keeper.color = Color(0.18, 0.65, 0.42)
	btn_keeper.pos = Vector2(-225, -85)
	btn_keeper.radius = 32.0
	buttons.append(btn_keeper)
	for btn in buttons:
		btn.base_x = btn.pos.x

func set_possession_context(in_possession: bool) -> void:
	active_in_possession = in_possession
	for btn in buttons:
		if btn.name == "btn_sprint":
			btn.label = "DASH" if in_possession else "PRESS"
		elif btn.name == "btn_through":
			btn.label = "THRU" if in_possession else "COVER"
		elif btn.name == "btn_pass":
			btn.label = "PASS" if in_possession else "TACKLE"
			btn.action = "pass_ball" if in_possession else "standing_tackle"
		elif btn.name == "btn_keeper":
			btn.label = "KEEP" if not in_possession else "KEEP"
	queue_redraw()

func set_control_scale(scale_value: float) -> void:
	control_scale = clampf(scale_value, 0.75, 1.4)
	queue_redraw()

func set_control_layout(joystick_x: float, button_offset: float) -> void:
	joystick_base_pos.x = clampf(joystick_x, 50.0, 240.0)
	button_horizontal_offset = clampf(button_offset, 0.0, 150.0)
	for btn in buttons:
		btn.pos.x = btn.base_x - button_horizontal_offset
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_drag(event.index, event.position)
	elif event is InputEventMouseButton:
		_handle_touch(99, event.position, event.pressed)
	elif event is InputEventMouseMotion:
		if joystick_touch_id == 99 or _has_button_touch_id(99):
			_handle_drag(99, event.position)

func _has_button_touch_id(id: int) -> bool:
	for btn in buttons:
		if btn.touch_id == id:
			return true
	return false

func _handle_touch(touch_id: int, pos: Vector2, pressed: bool) -> void:
	var screen_size := get_viewport_rect().size
	var joy_center := Vector2(joystick_base_pos.x, screen_size.y + joystick_base_pos.y)

	if pressed:
		# Check if touch is on joystick zone (left 45% of screen, bottom 55%)
		if pos.x < screen_size.x * 0.45 and pos.y > screen_size.y * 0.45:
			if not joystick_active:
				joystick_active = true
				joystick_touch_id = touch_id
				joystick_origin = pos
				var diff := pos - joystick_origin
				if diff.length() > joystick_radius:
					diff = diff.normalized() * joystick_radius
				joystick_handle_pos = diff
				_update_joystick_vector()
				queue_redraw()
				return

		# Check buttons
		for btn in buttons:
			var btn_center := Vector2(screen_size.x + btn.pos.x, screen_size.y + btn.pos.y)
			if pos.distance_to(btn_center) <= btn.radius * control_scale * 1.25 and not btn.is_pressed:
				btn.is_pressed = true
				btn.touch_id = touch_id
				_dispatch_action(btn.action, true)
				queue_redraw()
				return
	else:
		# Release
		if joystick_active and joystick_touch_id == touch_id:
			joystick_active = false
			joystick_touch_id = -1
			joystick_origin = joy_center
			joystick_handle_pos = Vector2.ZERO
			joystick_vector = Vector2.ZERO
			joystick_moved.emit(Vector2.ZERO)
			queue_redraw()

		for btn in buttons:
			if btn.touch_id == touch_id:
				btn.is_pressed = false
				btn.touch_id = -1
				_dispatch_action(btn.action, false)
				queue_redraw()

func _handle_drag(touch_id: int, pos: Vector2) -> void:
	var screen_size := get_viewport_rect().size
	if joystick_active and joystick_touch_id == touch_id:
		var diff := pos - joystick_origin
		if diff.length() > joystick_radius:
			diff = diff.normalized() * joystick_radius
		joystick_handle_pos = diff
		_update_joystick_vector()
		queue_redraw()

	for btn in buttons:
		if btn.touch_id == touch_id:
			var btn_center := Vector2(screen_size.x + btn.pos.x, screen_size.y + btn.pos.y)
			if pos.distance_to(btn_center) > btn.radius * control_scale * 1.6:
				btn.is_pressed = false
				btn.touch_id = -1
				_dispatch_action(btn.action, false)
				queue_redraw()

func _update_joystick_vector() -> void:
	var norm := joystick_handle_pos / joystick_radius
	var len := norm.length()
	if len < joystick_deadzone:
		joystick_vector = Vector2.ZERO
	else:
		var remapped_len := (len - joystick_deadzone) / (1.0 - joystick_deadzone)
		joystick_vector = norm.normalized() * clampf(remapped_len, 0.0, 1.0)
	joystick_moved.emit(joystick_vector)

func _dispatch_action(action_name: String, pressed: bool) -> void:
	action_triggered.emit(action_name, pressed)
	if InputMap.has_action(action_name):
		if pressed:
			Input.action_press(action_name)
		else:
			Input.action_release(action_name)

func get_movement_vector() -> Vector2:
	return joystick_vector

func _draw() -> void:
	var screen_size := get_viewport_rect().size

	# 1. Virtual Joystick
	var joy_center := joystick_origin if joystick_active else Vector2(joystick_base_pos.x, screen_size.y + joystick_base_pos.y)
	var ring_color := Color(0.12, 0.70, 0.86, 0.65) if joystick_active else Color(0.25, 0.69, 0.78, 0.45)
	draw_circle(joy_center, joystick_radius + 8.0, Color(0.02, 0.05, 0.07, 0.42))
	draw_arc(joy_center, joystick_radius + 2.0, 0.0, TAU, 32, ring_color, 2.5)
	draw_line(joy_center - Vector2(joystick_radius * 0.7, 0), joy_center + Vector2(joystick_radius * 0.7, 0), Color(0.4, 0.8, 0.9, 0.28), 1.0)
	draw_line(joy_center - Vector2(0, joystick_radius * 0.7), joy_center + Vector2(0, joystick_radius * 0.7), Color(0.4, 0.8, 0.9, 0.28), 1.0)
	var thumb_pos := joy_center + joystick_handle_pos
	var thumb_r := 26.0
	var thumb_col := Color(0.18, 0.87, 0.92, 0.9) if joystick_active else Color(0.8, 0.9, 0.95, 0.55)
	draw_circle(thumb_pos, thumb_r, thumb_col)
	draw_arc(thumb_pos, thumb_r, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.95), 1.5)

	# 2. Action Buttons
	var default_font := ThemeDB.fallback_font
	for btn in buttons:
		var btn_center := Vector2(screen_size.x + btn.pos.x, screen_size.y + btn.pos.y)
		var r := btn.radius * control_scale * (0.94 if btn.is_pressed else 1.0)
		var bg_col := btn.color
		bg_col.a = 0.90 if btn.is_pressed else 0.68
		draw_circle(btn_center + Vector2(0, 4), r, Color(0.0, 0.0, 0.0, 0.30))
		draw_circle(btn_center, r, bg_col)
		draw_arc(btn_center, r, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.85 if btn.is_pressed else 0.5), 1.8)
		if is_instance_valid(default_font):
			var font_size := int(r * 0.38)
			var string_size := default_font.get_string_size(btn.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos := btn_center - Vector2(string_size.x * 0.5, -string_size.y * 0.35)
			draw_string(default_font, text_pos, btn.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.98, 0.98, 0.98))
			var sub_size := int(maxi(10, r * 0.28))
			var sub_string_size := default_font.get_string_size(btn.sub_label, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_size)
			var sub_pos := btn_center + Vector2(-sub_string_size.x * 0.5, r * 0.4)
			draw_string(default_font, sub_pos, btn.sub_label, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_size, Color(0.06, 0.14, 0.11, 0.95))
