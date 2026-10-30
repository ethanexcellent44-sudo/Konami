extends Node2D
class_name FootballPitch2D

signal goal_line_crossed(side: String)

@export var pitch_size: Vector2 = Vector2(1280.0, 720.0)
@export var field_origin: Vector2 = Vector2(60.0, 60.0)
@export var field_size: Vector2 = Vector2(1050.0, 680.0)
@export var goal_width: float = 73.2

const NAVY: Color = Color("#0b1530")
const STADIUM_TINT: Color = Color("#dfe5dc")
const GREEN_DARK: Color = Color("#126b3e")
const GREEN_LIGHT: Color = Color("#1a8f42")
const LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
const LINE_WIDTH: float = 3.0
const TEAM_AI_SCRIPT: GDScript = preload("res://scripts/team_ai_2d.gd")
const MATCH_RULES_SCRIPT: GDScript = preload("res://scripts/match_rules_2d.gd")

var home_team: TeamAI2D
var away_team: TeamAI2D
var formation_button: Button
var active_formation: String = "4-3-3"

func _ready() -> void:
	queue_redraw()
	_build_boundaries()
	_build_teams()
	_build_formation_toggle()
	var match_rules := MATCH_RULES_SCRIPT.new() as MatchRules2D
	match_rules.name = "MatchRules2D"
	add_child(match_rules)

func _build_teams() -> void:
	active_formation = ProfileStore.team_formation if ProfileStore.team_formation in ["4-3-3", "4-4-2"] else "4-3-3"
	home_team = TEAM_AI_SCRIPT.new() as TeamAI2D
	home_team.name = "HomeTeamAI"
	home_team.team_id = "ethan_fc"
	home_team.formation = active_formation
	home_team.attacks_up = true
	home_team.human_player_index = 10
	add_child(home_team)
	away_team = TEAM_AI_SCRIPT.new() as TeamAI2D
	away_team.name = "AwayTeamAI"
	away_team.team_id = "harbor_athletic"
	away_team.formation = "4-4-2"
	away_team.attacks_up = false
	add_child(away_team)
	home_team.opposing_team = away_team
	away_team.opposing_team = home_team

func _build_formation_toggle() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "FormationDemoHUD"
	hud_layer.layer = 7
	add_child(hud_layer)
	formation_button = Button.new()
	formation_button.name = "FormationToggle"
	formation_button.text = "FORMATION  " + active_formation
	formation_button.position = Vector2(28.0, 76.0)
	formation_button.size = Vector2(190.0, 38.0)
	formation_button.pressed.connect(_toggle_formation)
	hud_layer.add_child(formation_button)

func _toggle_formation() -> void:
	active_formation = "4-4-2" if active_formation == "4-3-3" else "4-3-3"
	if is_instance_valid(home_team):
		home_team.formation = active_formation
		home_team.rebuild_formation()
	if is_instance_valid(formation_button):
		formation_button.text = "FORMATION  " + active_formation

func _draw() -> void:
	var stadium_size := pitch_size
	var field_rect := Rect2(field_origin, field_size)
	var pitch_bounds := Rect2(field_origin - Vector2(18.0, 18.0), field_size + Vector2(36.0, 36.0))
	var crowd_top := Rect2(Vector2.ZERO, Vector2(stadium_size.x, field_origin.y))
	var crowd_bottom := Rect2(Vector2(0.0, stadium_size.y - field_origin.y), Vector2(stadium_size.x, field_origin.y))
	var crowd_left := Rect2(Vector2(0.0, field_origin.y), Vector2(field_origin.x, field_size.y))
	var crowd_right := Rect2(Vector2(stadium_size.x - field_origin.x, field_origin.y), Vector2(field_origin.x, field_size.y))
	draw_rect(Rect2(Vector2.ZERO, stadium_size), STADIUM_TINT)
	draw_rect(crowd_top, Color("#2e3440"))
	draw_rect(crowd_bottom, Color("#2e3440"))
	draw_rect(crowd_left, Color("#30373d"))
	draw_rect(crowd_right, Color("#30373d"))
	draw_rect(pitch_bounds, Color(0.16, 0.26, 0.20, 0.7), false, 2.0)
	for segment_index in range(20):
		var stripe_x := field_origin.x + (field_size.x / 20.0) * segment_index
		var stripe_color: Color = GREEN_LIGHT if segment_index % 2 == 0 else GREEN_DARK
		draw_rect(Rect2(Vector2(stripe_x, field_origin.y), Vector2(field_size.x / 20.0, field_size.y)), stripe_color)
	for stripe_index in range(0, 18):
		var stripe_y := field_origin.y + (field_size.y / 18.0) * stripe_index
		draw_line(Vector2(field_origin.x, stripe_y), Vector2(field_origin.x + field_size.x, stripe_y), Color(0.2, 0.2, 0.2, 0.08), 1.0)

	draw_rect(field_rect, Color(0.0, 0.0, 0.0, 0.0), false, LINE_WIDTH)
	draw_line(Vector2(field_rect.get_center().x, field_origin.y), Vector2(field_rect.get_center().x, field_rect.end.y), LINE_COLOR, LINE_WIDTH)
	draw_arc(field_rect.get_center(), 91.5, 0.0, TAU, 64, LINE_COLOR, LINE_WIDTH)
	draw_circle(field_rect.get_center(), 5.0, LINE_COLOR)

	var penalty_width: float = 165.0
	var penalty_height: float = 403.2
	var goal_area_width: float = 55.0
	var goal_area_height: float = 183.2
	var penalty_spot_offset: float = 110.0
	var top_penalty := Rect2(Vector2(field_origin.x, field_origin.y), Vector2(penalty_width, penalty_height))
	var bottom_penalty := Rect2(Vector2(field_origin.x, field_origin.y + field_size.y - penalty_height), Vector2(penalty_width, penalty_height))
	var top_goal_area := Rect2(Vector2(field_origin.x, field_origin.y), Vector2(goal_area_width, goal_area_height))
	var bottom_goal_area := Rect2(Vector2(field_origin.x, field_origin.y + field_size.y - goal_area_height), Vector2(goal_area_width, goal_area_height))
	var top_box_right := Rect2(Vector2(field_origin.x + field_size.x - penalty_width, field_origin.y), Vector2(penalty_width, penalty_height))
	var bottom_box_right := Rect2(Vector2(field_origin.x + field_size.x - penalty_width, field_origin.y + field_size.y - penalty_height), Vector2(penalty_width, penalty_height))
	var top_goal_area_right := Rect2(Vector2(field_origin.x + field_size.x - goal_area_width, field_origin.y), Vector2(goal_area_width, goal_area_height))
	var bottom_goal_area_right := Rect2(Vector2(field_origin.x + field_size.x - goal_area_width, field_origin.y + field_size.y - goal_area_height), Vector2(goal_area_width, goal_area_height))
	draw_rect(top_penalty, LINE_COLOR, false, LINE_WIDTH)
	draw_rect(bottom_penalty, LINE_COLOR, false, LINE_WIDTH)
	draw_rect(top_box_right, LINE_COLOR, false, LINE_WIDTH)
	draw_rect(bottom_box_right, LINE_COLOR, false, LINE_WIDTH)
	draw_rect(top_goal_area, LINE_COLOR, false, LINE_WIDTH)
	draw_rect(bottom_goal_area, LINE_COLOR, false, LINE_WIDTH)
	draw_rect(top_goal_area_right, LINE_COLOR, false, LINE_WIDTH)
	draw_rect(bottom_goal_area_right, LINE_COLOR, false, LINE_WIDTH)

	var penalty_spot_y := field_origin.y + penalty_spot_offset
	var opposite_penalty_spot_y := field_origin.y + field_size.y - penalty_spot_offset
	draw_circle(Vector2(field_origin.x + field_size.x * 0.5, penalty_spot_y), 5.0, LINE_COLOR)
	draw_circle(Vector2(field_origin.x + field_size.x * 0.5, opposite_penalty_spot_y), 5.0, LINE_COLOR)
	var left_arc_center := Vector2(field_origin.x + 11.0, field_origin.y + penalty_height * 0.5)
	var right_arc_center := Vector2(field_origin.x + field_size.x - 11.0, field_origin.y + field_size.y - penalty_height * 0.5)
	draw_arc(left_arc_center, 91.5, PI * 0.5, PI * 1.5, 64, LINE_COLOR, LINE_WIDTH)
	draw_arc(right_arc_center, 91.5, -PI * 0.5, PI * 0.5, 64, LINE_COLOR, LINE_WIDTH)
	for corner_index in range(4):
		var corner_center: Vector2
		var arc_start: float
		var arc_end: float
		if corner_index == 0:
			corner_center = Vector2(field_origin.x, field_origin.y)
			arc_start = 0.0
			arc_end = PI * 0.5
		elif corner_index == 1:
			corner_center = Vector2(field_origin.x + field_size.x, field_origin.y)
			arc_start = PI * 0.5
			arc_end = PI
		elif corner_index == 2:
			corner_center = Vector2(field_origin.x, field_origin.y + field_size.y)
			arc_start = -PI * 0.5
			arc_end = 0.0
		else:
			corner_center = Vector2(field_origin.x + field_size.x, field_origin.y + field_size.y)
			arc_start = PI
			arc_end = PI * 1.5
		draw_arc(corner_center, 10.0, arc_start, arc_end, 20, LINE_COLOR, LINE_WIDTH)

	var top_goal_origin_x := field_origin.x + (field_size.x - goal_width) * 0.5
	var top_goal := Rect2(Vector2(top_goal_origin_x, field_origin.y - 20.0), Vector2(goal_width, 20.0))
	var bottom_goal := Rect2(Vector2(top_goal_origin_x, field_origin.y + field_size.y), Vector2(goal_width, 20.0))
	draw_rect(top_goal, Color(0.9, 0.96, 0.98, 0.18))
	draw_rect(bottom_goal, Color(0.9, 0.96, 0.98, 0.18))
	draw_rect(top_goal, LINE_COLOR, false, LINE_WIDTH)
	draw_rect(bottom_goal, LINE_COLOR, false, LINE_WIDTH)
	for net_index in range(6):
		var net_x := top_goal_origin_x + (goal_width / 6.0) * net_index
		draw_line(Vector2(net_x, field_origin.y), Vector2(net_x, field_origin.y + 20.0), Color(1.0, 1.0, 1.0, 0.12), 1.0)
		draw_line(Vector2(net_x, field_origin.y + field_size.y), Vector2(net_x, field_origin.y + field_size.y - 20.0), Color(1.0, 1.0, 1.0, 0.12), 1.0)

	var ad_board_top := Rect2(Vector2(field_origin.x - 18.0, 0.0), Vector2(field_size.x + 36.0, 14.0))
	var ad_board_bottom := Rect2(Vector2(field_origin.x - 18.0, stadium_size.y - 14.0), Vector2(field_size.x + 36.0, 14.0))
	draw_rect(ad_board_top, Color("#2f4f74"))
	draw_rect(ad_board_bottom, Color("#2f4f74"))
	var side_banner_left := Rect2(Vector2(0.0, field_origin.y - 18.0), Vector2(14.0, field_size.y + 36.0))
	var side_banner_right := Rect2(Vector2(stadium_size.x - 14.0, field_origin.y - 18.0), Vector2(14.0, field_size.y + 36.0))
	draw_rect(side_banner_left, Color("#274d6d"))
	draw_rect(side_banner_right, Color("#274d6d"))

func _build_boundaries() -> void:
	var margin: float = pitch_size.y * 0.07
	var goal_half: float = goal_width * 0.5
	_add_wall("TopGoalLeftPost", Vector2(pitch_size.x * 0.5 - goal_half, margin * 0.5), Vector2(12.0, margin))
	_add_wall("TopGoalRightPost", Vector2(pitch_size.x * 0.5 + goal_half, margin * 0.5), Vector2(12.0, margin))
	_add_wall("BottomGoalLeftPost", Vector2(pitch_size.x * 0.5 - goal_half, pitch_size.y - margin * 0.5), Vector2(12.0, margin))
	_add_wall("BottomGoalRightPost", Vector2(pitch_size.x * 0.5 + goal_half, pitch_size.y - margin * 0.5), Vector2(12.0, margin))

func _add_wall(wall_name: String, location: Vector2, wall_size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.name = wall_name
	wall.position = location
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape_node := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = wall_size
	shape_node.shape = rectangle
	wall.add_child(shape_node)
	add_child(wall)
