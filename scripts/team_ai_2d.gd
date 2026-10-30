extends Node2D
class_name TeamAI2D

signal ai_pass_decided(team_id: String, passer_index: int, receiver_index: int)
signal pressing_player_changed(team_id: String, player_index: int)

@export var team_id: String = "ethan_fc"
@export var formation: String = "4-3-3"
@export var attacks_up: bool = true
@export var team_color: Color = Color("#22e07a")
@export var human_player_index: int = -1
@export var decision_interval: float = 0.22
@export var press_distance: float = 245.0
@export var pass_range: float = 125.0

const PLAYER_SCRIPT: GDScript = preload("res://scripts/player_controller_2d.gd")
const TEAM_DATA_PATH: String = "res://data/teams.json"
const BALL_PATH: NodePath = NodePath("../FootballBall2D")
const PLAYER_BALL_PATH: NodePath = NodePath("../FootballBall2D")
const FIELD_SIZE: Vector2 = Vector2(1280.0, 720.0)

var players: Array[FootballPlayer2D] = []
var opposing_team: TeamAI2D
var ball: FootballBall2D
var decision_timer: float = 0.0
var pressing_player_index: int = -1
var last_pass_receiver: int = -1
var possession_player_index: int = -1
var last_decision: String = "shape"
var _last_pressing_player_index: int = -1
var _kick_cooldown: float = 0.0
var _formation_positions: Array[Vector2] = []

func _ready() -> void:
	_load_team_definition()
	ball = get_node_or_null(BALL_PATH) as FootballBall2D
	_formation_positions = _get_formation_positions(formation)
	_build_players()

func rebuild_formation() -> void:
	_formation_positions = _get_formation_positions(formation)
	for player_index in range(mini(players.size(), _formation_positions.size())):
		var player: FootballPlayer2D = players[player_index]
		var target: Vector2 = _formation_position(_formation_positions[player_index])
		player.global_position = target
		player.set_ai_target(target)

func _load_team_definition() -> void:
	var file := FileAccess.open(TEAM_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	for team_data: Variant in parsed.get("teams", []):
		if not team_data is Dictionary or str(team_data.get("id", "")) != team_id:
			continue
		formation = str(team_data.get("formation", formation))
		team_color = Color(str(team_data.get("primary_color", team_color.to_html())))
		return

func _physics_process(delta: float) -> void:
	if not is_instance_valid(ball):
		ball = get_node_or_null(BALL_PATH) as FootballBall2D
	if not is_instance_valid(ball) or players.is_empty():
		return
	decision_timer -= delta
	_kick_cooldown = maxf(0.0, _kick_cooldown - delta)
	if decision_timer > 0.0:
		return
	decision_timer = decision_interval
	_update_team_ai()

func _build_players() -> void:
	for player_index in range(11):
		var is_human: bool = player_index == human_player_index
		var player: FootballPlayer2D
		if is_human:
			player = get_parent().get_node_or_null("Player2D") as FootballPlayer2D
			if not is_instance_valid(player):
				push_error("Team %s cannot find its configured human Player2D" % team_id)
				continue
		else:
			player = PLAYER_SCRIPT.new() as FootballPlayer2D
			player.name = "%s_Player_%02d" % [team_id, player_index + 1]
			player.ball_path = PLAYER_BALL_PATH
			player.is_human_controlled = false
			player.collision_layer = 2
			player.collision_mask = 1
			add_child(player)
		player.team_color = team_color
		player.squad_number = player_index + 1
		player.global_position = _formation_position(_formation_positions[player_index])
		player.set_ai_target(player.global_position)
		players.append(player)

func _get_formation_positions(formation_name: String) -> Array[Vector2]:
	var positions: Array[Vector2] = [Vector2(0.5, 0.92)]
	var defender_row: Array[float] = [0.16, 0.39, 0.61, 0.84]
	var midfield_row: Array[float]
	var forward_row: Array[float]
	match formation_name:
		"4-4-2":
			midfield_row = [0.12, 0.37, 0.63, 0.88]
			forward_row = [0.35, 0.65]
			positions.append_array(_make_row(0.70, defender_row))
			positions.append_array(_make_row(0.47, midfield_row))
			positions.append_array(_make_row(0.23, forward_row))
		_:
			midfield_row = [0.20, 0.50, 0.80]
			forward_row = [0.14, 0.50, 0.86]
			positions.append_array(_make_row(0.70, defender_row))
			positions.append_array(_make_row(0.47, midfield_row))
			positions.append_array(_make_row(0.23, forward_row))
	return positions

func _make_row(depth: float, horizontal_positions: Array[float]) -> Array[Vector2]:
	var row: Array[Vector2] = []
	for horizontal_position: float in horizontal_positions:
		row.append(Vector2(horizontal_position, depth))
	return row

func _formation_position(normalized_position: Vector2) -> Vector2:
	var horizontal_position: float = (normalized_position.x - 0.5) * FIELD_SIZE.x * 0.78
	var vertical_position: float = (normalized_position.y - 0.5) * FIELD_SIZE.y * 0.82
	if not attacks_up:
		vertical_position = -vertical_position
	return FIELD_SIZE * 0.5 + Vector2(horizontal_position, vertical_position)

func _update_team_ai() -> void:
	if players.size() != 11:
		return
	var own_nearest_index: int = _nearest_player_index(players, ball.global_position)
	var opponent_players: Array[FootballPlayer2D] = opposing_team.players if is_instance_valid(opposing_team) else []
	var opposition_distance: float = _nearest_distance(opponent_players, ball.global_position)
	var own_distance: float = players[own_nearest_index].global_position.distance_to(ball.global_position)
	var team_has_ball: bool = own_distance < 46.0 and (opposition_distance > own_distance + 4.0 or opposition_distance > 52.0)
	possession_player_index = own_nearest_index if team_has_ball else -1
	pressing_player_index = -1
	if not team_has_ball and own_distance <= press_distance:
		pressing_player_index = own_nearest_index
	if pressing_player_index != _last_pressing_player_index:
		_last_pressing_player_index = pressing_player_index
		pressing_player_changed.emit(team_id, pressing_player_index)

	var ball_offset: Vector2 = (ball.global_position - FIELD_SIZE * 0.5) * 0.16
	for player_index in range(players.size()):
		var player: FootballPlayer2D = players[player_index]
		if player_index == human_player_index:
			continue
		var target: Vector2 = _formation_position(_formation_positions[player_index])
		var should_sprint: bool = false
		if player_index == 0:
			target = Vector2(clampf(ball.global_position.x, 340.0, 940.0), FIELD_SIZE.y * (0.08 if attacks_up else 0.92))
			should_sprint = absf(ball.global_position.x - player.global_position.x) > 130.0
		elif player_index == pressing_player_index:
			target = ball.global_position
			should_sprint = true
		else:
			target += ball_offset
			if team_has_ball and player_index == own_nearest_index:
				target = ball.global_position
			should_sprint = player.global_position.distance_to(target) > 200.0
		player.set_ai_target(_clamp_to_field(target), should_sprint)

	if team_has_ball and own_nearest_index != human_player_index and _kick_cooldown <= 0.0:
		_try_ai_distribution(own_nearest_index)
		if last_decision != "pass" and last_decision != "shot":
			last_decision = "possession"
	elif pressing_player_index >= 0:
		last_decision = "press"
	else:
		last_decision = "shape"

func _try_ai_distribution(passer_index: int) -> void:
	var passer: FootballPlayer2D = players[passer_index]
	if passer.global_position.distance_to(ball.global_position) > 50.0:
		return
	var receiver_index: int = _best_forward_receiver(passer_index)
	if receiver_index < 0:
		return
	var receiver: FootballPlayer2D = players[receiver_index]
	var direction: Vector2 = (receiver.global_position - ball.global_position).normalized()
	var goal_y: float = 18.0 if attacks_up else FIELD_SIZE.y - 18.0
	var distance_to_goal: float = absf(ball.global_position.y - goal_y)
	var shot_opportunity: bool = distance_to_goal < 190.0 and absf(ball.global_position.x - FIELD_SIZE.x * 0.5) < 220.0
	if shot_opportunity:
		passer.ai_kick(Vector2(0.0, -1.0 if attacks_up else 1.0), 0.72)
		last_decision = "shot"
	else:
		passer.ai_kick(direction, 0.7 if receiver.global_position.distance_to(ball.global_position) > pass_range else 0.48)
		last_pass_receiver = receiver_index
		last_decision = "pass"
		ai_pass_decided.emit(team_id, passer_index, receiver_index)
	_kick_cooldown = 1.1

func _best_forward_receiver(passer_index: int) -> int:
	var best_index: int = -1
	var best_score: float = -INF
	var passer_position: Vector2 = players[passer_index].global_position
	for candidate_index in range(players.size()):
		if candidate_index == passer_index or candidate_index == 0 or candidate_index == human_player_index:
			continue
		var candidate: FootballPlayer2D = players[candidate_index]
		var forward_gain: float = (passer_position.y - candidate.global_position.y) if attacks_up else (candidate.global_position.y - passer_position.y)
		if forward_gain < 28.0:
			continue
		var distance: float = passer_position.distance_to(candidate.global_position)
		if distance > 330.0:
			continue
		var score: float = forward_gain - distance * 0.22
		if score > best_score:
			best_score = score
			best_index = candidate_index
	return best_index

func _nearest_player_index(team_players: Array[FootballPlayer2D], location: Vector2) -> int:
	var nearest_index: int = 0
	var nearest_distance: float = INF
	for player_index in range(team_players.size()):
		var distance: float = team_players[player_index].global_position.distance_squared_to(location)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = player_index
	return nearest_index

func _nearest_distance(team_players: Array[FootballPlayer2D], location: Vector2) -> float:
	var nearest: float = INF
	for player: FootballPlayer2D in team_players:
		nearest = minf(nearest, player.global_position.distance_to(location))
	return nearest

func _clamp_to_field(location: Vector2) -> Vector2:
	return Vector2(clampf(location.x, 42.0, FIELD_SIZE.x - 42.0), clampf(location.y, 42.0, FIELD_SIZE.y - 42.0))
