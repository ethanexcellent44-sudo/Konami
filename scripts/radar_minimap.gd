extends Control
class_name RadarMinimap

var field_width: float = 34.0
var field_length: float = 52.0

var home_team: Array = []
var away_team: Array = []
var home_gk: Node3D
var away_gk: Node3D
var ball: Node3D
var active_player: Node3D

var pulse_timer: float = 0.0

func _process(delta: float) -> void:
	pulse_timer += delta * 6.0
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0 or h < 10.0:
		return

	# Pitch Background
	var pitch_rect := Rect2(0, 0, w, h)
	draw_rect(pitch_rect, Color(0.04, 0.14, 0.08, 0.72), true)
	draw_rect(pitch_rect, Color(0.3, 0.65, 0.4, 0.8), false, 1.5)

	# Halfway Line
	var half_y := h * 0.5
	draw_line(Vector2(0, half_y), Vector2(w, half_y), Color(0.9, 0.95, 0.9, 0.45), 1.0)

	# Center Circle
	var center_circle_radius := (5.5 / field_length) * h
	draw_arc(Vector2(w * 0.5, half_y), center_circle_radius, 0.0, TAU, 24, Color(0.9, 0.95, 0.9, 0.45), 1.0)

	# North Penalty Box
	var box_w := (16.0 / field_width) * w
	var box_h := (8.0 / field_length) * h
	draw_rect(Rect2((w - box_w) * 0.5, 0, box_w, box_h), Color(0.9, 0.95, 0.9, 0.4), false, 1.0)

	# South Penalty Box
	draw_rect(Rect2((w - box_w) * 0.5, h - box_h, box_w, box_h), Color(0.9, 0.95, 0.9, 0.4), false, 1.0)

	# Home Outfield Players
	for tm in home_team:
		if is_instance_valid(tm):
			var pt := _world_to_radar(tm.global_position, w, h)
			var is_active: bool = (tm == active_player)
			if is_active:
				var ring_r := 4.5 + sin(pulse_timer) * 1.0
				draw_arc(pt, ring_r, 0.0, TAU, 16, Color(1.0, 0.92, 0.25, 0.9), 1.5)
				draw_circle(pt, 3.2, Color(0.2, 0.85, 1.0))
			else:
				draw_circle(pt, 2.8, Color(0.2, 0.6, 0.95))

	# Home GK
	if is_instance_valid(home_gk):
		var pt_hgk := _world_to_radar(home_gk.global_position, w, h)
		draw_circle(pt_hgk, 3.0, Color(0.15, 0.9, 0.45))

	# Away Outfield Players
	for opp in away_team:
		if is_instance_valid(opp):
			var pt_opp := _world_to_radar(opp.global_position, w, h)
			draw_circle(pt_opp, 2.8, Color(0.95, 0.25, 0.25))

	# Away GK
	if is_instance_valid(away_gk):
		var pt_agk := _world_to_radar(away_gk.global_position, w, h)
		draw_circle(pt_agk, 3.0, Color(0.95, 0.88, 0.15))

	# Match Ball
	if is_instance_valid(ball):
		var pt_ball := _world_to_radar(ball.global_position, w, h)
		draw_circle(pt_ball, 2.4, Color(1.0, 1.0, 0.95))
		draw_arc(pt_ball, 3.4, 0.0, TAU, 12, Color(1.0, 0.95, 0.2, 0.8), 1.0)

func _world_to_radar(world_pos: Vector3, w: float, h: float) -> Vector2:
	var norm_x := clampf((world_pos.x / field_width) + 0.5, 0.02, 0.98)
	var norm_y := clampf((world_pos.z / field_length) + 0.5, 0.02, 0.98)
	return Vector2(norm_x * w, norm_y * h)
