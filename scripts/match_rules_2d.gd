extends Node
class_name MatchRules2D

signal score_changed(home_score: int, away_score: int)
signal match_clock_changed(display_time: String)
signal restart_awarded(restart_type: String, team_id: String)
signal match_state_changed(state: String)

@export_range(20.0, 600.0, 5.0) var half_duration_seconds: float = 90.0
@export var pitch_size: Vector2 = Vector2(1280.0, 720.0)
@export var field_origin: Vector2 = Vector2(60.0, 60.0)
@export var field_size: Vector2 = Vector2(1050.0, 680.0)
@export var goal_width: float = 73.2
@export var restart_delay_seconds: float = 1.2

const FIELD_MARGIN_RATIO: float = 0.07
const BALL_RADIUS: float = 12.0

var ball: FootballBall2D
var home_team: TeamAI2D
var away_team: TeamAI2D
var human_player: FootballPlayer2D
var home_score: int = 0
var away_score: int = 0
var elapsed_seconds: float = 0.0
var current_half: int = 1
var match_state: String = "ready"
var last_touch_team: String = "home"
var restart_timer: float = 0.0
var was_paused: bool = false
var _last_ball_position: Vector2 = Vector2.ZERO
var _clock_label: Label
var _score_label: Label
var _period_label: Label
var _status_label: Label
var _period_panel: Panel
var _period_title: Label
var _period_score: Label
var _period_button: Button
var _pause_panel: Panel
var _pause_overlay: ColorRect
var _possession_label: Label
var _touch_controls: Control
var _music_slider: HSlider
var _sfx_slider: HSlider
var _status_time_left: float = 0.0
var _progression_awarded: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ball = get_parent().get_node_or_null("FootballBall2D") as FootballBall2D
	home_team = get_parent().get_node_or_null("HomeTeamAI") as TeamAI2D
	away_team = get_parent().get_node_or_null("AwayTeamAI") as TeamAI2D
	human_player = get_parent().get_node_or_null("Player2D") as FootballPlayer2D
	if not is_instance_valid(ball) or not is_instance_valid(home_team) or not is_instance_valid(away_team):
		push_error("MatchRules2D requires a ball and both teams under its parent pitch")
		return
	_build_hud()
	_touch_controls = human_player.get_node_or_null("PlayerControlsLayer/VirtualTouchControls") if is_instance_valid(human_player) else null
	GameState.goal.connect(_on_global_goal)
	GameState.foul.connect(_on_global_foul)
	GameState.match_period_changed.connect(_on_global_period_changed)
	ball.kicked.connect(_on_ball_kicked)
	if is_instance_valid(human_player):
		human_player.tackle_attempted.connect(_on_human_tackle)
	GameState.start_match("ethan_fc")
	_last_ball_position = ball.global_position
	_begin_kickoff("home", false, false)

func _process(delta: float) -> void:
	if _status_time_left > 0.0 and match_state == "live":
		_status_time_left = maxf(0.0, _status_time_left - delta)
		if _status_time_left == 0.0:
			_set_status("")
	if match_state == "live":
		elapsed_seconds += delta
		_update_clock()
		_detect_last_touch()
		_check_ball_boundaries()
	elif match_state == "restart":
		restart_timer = maxf(0.0, restart_timer - delta)
		if restart_timer <= 0.0:
			_resume_live_play()
	if Input.is_action_just_pressed("pause_game") and match_state in ["live", "paused"]:
		toggle_pause()

func _build_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "MatchRulesHUD"
	hud_layer.layer = 9
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud_layer)
	var score_panel := Panel.new()
	score_panel.name = "ScoreClockPanel"
	score_panel.anchor_left = 0.5
	score_panel.anchor_right = 0.5
	score_panel.offset_left = -208.0
	score_panel.offset_right = 208.0
	score_panel.offset_top = 18.0
	score_panel.offset_bottom = 112.0
	var score_style := StyleBoxFlat.new()
	score_style.bg_color = Color(0.035, 0.07, 0.15, 0.96)
	score_style.border_color = Color(0.94, 0.65, 0.08, 0.9)
	score_style.set_border_width_all(1)
	score_style.set_corner_radius_all(7)
	score_panel.add_theme_stylebox_override("panel", score_style)
	hud_layer.add_child(score_panel)
	var home_marker := ColorRect.new()
	home_marker.color = Color("#22e07a")
	home_marker.position = Vector2(15.0, 19.0)
	home_marker.size = Vector2(4.0, 22.0)
	score_panel.add_child(home_marker)
	var away_marker := ColorRect.new()
	away_marker.color = Color("#f0a500")
	away_marker.anchor_left = 1.0
	away_marker.anchor_right = 1.0
	away_marker.offset_left = -19.0
	away_marker.offset_right = -15.0
	away_marker.offset_top = 19.0
	away_marker.offset_bottom = 41.0
	score_panel.add_child(away_marker)
	_score_label = _make_hud_label("ETH  0  -  0  HBR", 25, Color(0.95, 0.97, 0.92))
	_score_label.name = "ScoreLabel"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.anchor_right = 1.0
	_score_label.offset_top = 8.0
	_score_label.offset_bottom = 43.0
	score_panel.add_child(_score_label)
	_clock_label = _make_hud_label("00:00", 15, Color("#f0a500"))
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.anchor_right = 1.0
	_clock_label.offset_top = 43.0
	_clock_label.offset_bottom = 65.0
	score_panel.add_child(_clock_label)
	var divider := ColorRect.new()
	divider.color = Color(0.65, 0.75, 0.87, 0.2)
	divider.anchor_left = 0.12
	divider.anchor_right = 0.88
	divider.offset_top = 72.0
	divider.offset_bottom = 73.0
	score_panel.add_child(divider)
	_possession_label = _make_hud_label("ETHAN FC  /  KICK-OFF", 10, Color(0.72, 0.83, 0.88))
	_possession_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_possession_label.anchor_right = 1.0
	_possession_label.offset_top = 78.0
	_possession_label.offset_bottom = 96.0
	score_panel.add_child(_possession_label)
	_period_label = _make_hud_label("FIRST HALF", 11, Color(0.72, 0.83, 0.88))
	_period_label.position = Vector2(28.0, 124.0)
	_period_label.size = Vector2(170.0, 22.0)
	hud_layer.add_child(_period_label)
	_status_label = _make_hud_label("", 15, Color("#f0a500"))
	_status_label.anchor_left = 0.5
	_status_label.anchor_right = 0.5
	_status_label.offset_left = -260.0
	_status_label.offset_right = 260.0
	_status_label.offset_top = 118.0
	_status_label.offset_bottom = 148.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_layer.add_child(_status_label)
	var pause_button := Button.new()
	pause_button.text = "II"
	pause_button.tooltip_text = "Pause match"
	pause_button.add_theme_font_size_override("font_size", 18)
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.offset_left = -72.0
	pause_button.offset_right = -24.0
	pause_button.offset_top = 22.0
	pause_button.offset_bottom = 68.0
	pause_button.pressed.connect(toggle_pause)
	hud_layer.add_child(pause_button)
	_build_period_panel(hud_layer)
	_build_pause_panel(hud_layer)

func _make_hud_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _build_period_panel(hud_layer: CanvasLayer) -> void:
	_period_panel = Panel.new()
	_period_panel.name = "PeriodPanel"
	_period_panel.anchor_left = 0.5
	_period_panel.anchor_right = 0.5
	_period_panel.anchor_top = 0.5
	_period_panel.anchor_bottom = 0.5
	_period_panel.offset_left = -220.0
	_period_panel.offset_right = 220.0
	_period_panel.offset_top = -116.0
	_period_panel.offset_bottom = 116.0
	_period_panel.visible = false
	_period_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var period_style := StyleBoxFlat.new()
	period_style.bg_color = Color(0.035, 0.07, 0.15, 0.99)
	period_style.border_color = Color("#22e07a")
	period_style.set_border_width_all(2)
	period_style.set_corner_radius_all(8)
	_period_panel.add_theme_stylebox_override("panel", period_style)
	hud_layer.add_child(_period_panel)
	_period_title = _make_hud_label("HALF TIME", 28, Color(0.95, 0.97, 0.92))
	_period_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_period_title.anchor_right = 1.0
	_period_title.offset_top = 38.0
	_period_title.offset_bottom = 82.0
	_period_panel.add_child(_period_title)
	_period_score = _make_hud_label("ETH  0  -  0  HBR", 18, Color("#f0a500"))
	_period_score.name = "PeriodScore"
	_period_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_period_score.anchor_right = 1.0
	_period_score.offset_top = 92.0
	_period_score.offset_bottom = 122.0
	_period_panel.add_child(_period_score)
	_period_button = Button.new()
	_period_button.text = "CONTINUE"
	_period_button.anchor_left = 0.5
	_period_button.anchor_right = 0.5
	_period_button.offset_left = -100.0
	_period_button.offset_right = 100.0
	_period_button.offset_top = 126.0
	_period_button.offset_bottom = 174.0
	_period_button.pressed.connect(_on_period_button_pressed)
	_period_panel.add_child(_period_button)

func _build_pause_panel(hud_layer: CanvasLayer) -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.color = Color(0.015, 0.03, 0.075, 0.78)
	_pause_overlay.anchor_right = 1.0
	_pause_overlay.anchor_bottom = 1.0
	_pause_overlay.visible = false
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(_pause_overlay)
	_pause_panel = Panel.new()
	_pause_panel.name = "PausePanel"
	_pause_panel.anchor_left = 0.5
	_pause_panel.anchor_right = 0.5
	_pause_panel.anchor_top = 0.5
	_pause_panel.anchor_bottom = 0.5
	_pause_panel.offset_left = -230.0
	_pause_panel.offset_right = 230.0
	_pause_panel.offset_top = -250.0
	_pause_panel.offset_bottom = 250.0
	_pause_panel.visible = false
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var pause_style := StyleBoxFlat.new()
	pause_style.bg_color = Color(0.035, 0.07, 0.15, 0.99)
	pause_style.border_color = Color("#f0a500")
	pause_style.set_border_width_all(2)
	pause_style.set_corner_radius_all(8)
	pause_style.content_margin_left = 24.0
	pause_style.content_margin_right = 24.0
	_pause_panel.add_theme_stylebox_override("panel", pause_style)
	hud_layer.add_child(_pause_panel)
	var kicker := _make_hud_label("ETHAN CUP     /     MATCHDAY", 11, Color("#22e07a"))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.anchor_right = 1.0
	kicker.offset_top = 20.0
	kicker.offset_bottom = 42.0
	_pause_panel.add_child(kicker)
	var title := _make_hud_label("MATCH PAUSED", 28, Color(0.95, 0.97, 0.92))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_right = 1.0
	title.offset_top = 52.0
	title.offset_bottom = 92.0
	_pause_panel.add_child(title)
	var score_summary := _make_hud_label("ETH  %d  -  %d  HBR" % [home_score, away_score], 20, Color("#f0a500"))
	score_summary.name = "PauseScoreSummary"
	score_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_summary.anchor_right = 1.0
	score_summary.offset_top = 104.0
	score_summary.offset_bottom = 136.0
	_pause_panel.add_child(score_summary)
	_add_pause_slider("MUSIC", 158.0, ProfileStore.music_volume, true)
	_add_pause_slider("SOUND EFFECTS", 224.0, ProfileStore.effects_volume, false)
	var touch_toggle := CheckButton.new()
	touch_toggle.name = "TouchControlsToggle"
	touch_toggle.text = "TOUCH CONTROLS"
	touch_toggle.position = Vector2(34.0, 286.0)
	touch_toggle.size = Vector2(300.0, 36.0)
	touch_toggle.button_pressed = true
	touch_toggle.toggled.connect(_on_touch_controls_toggled)
	_pause_panel.add_child(touch_toggle)
	_add_pause_button("RESUME MATCH", 340.0, 44.0, true, toggle_pause)
	_add_pause_button("RESTART MATCH", 394.0, 42.0, false, _restart_match)
	_add_pause_button("RETURN TO HOME", 444.0, 42.0, false, _return_to_home)

func _add_pause_slider(caption: String, top: float, initial_value: float, is_music: bool) -> void:
	var title := _make_hud_label(caption, 11, Color(0.72, 0.83, 0.88))
	title.position = Vector2(34.0, top)
	title.size = Vector2(330.0, 18.0)
	_pause_panel.add_child(title)
	var slider := HSlider.new()
	slider.name = "MusicVolumeSlider" if is_music else "SfxVolumeSlider"
	slider.position = Vector2(34.0, top + 20.0)
	slider.size = Vector2(330.0, 24.0)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	if is_music:
		_music_slider = slider
		slider.value_changed.connect(func(value: float) -> void: AudioManager.set_music_volume(value))
	else:
		_sfx_slider = slider
		slider.value_changed.connect(func(value: float) -> void: AudioManager.set_sfx_volume(value))
	_pause_panel.add_child(slider)

func _add_pause_button(text: String, top: float, height: float, primary: bool, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.offset_left = -160.0
	button.offset_right = 160.0
	button.offset_top = top
	button.offset_bottom = top + height
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#22e07a") if primary else Color(0.06, 0.11, 0.21, 0.98)
	normal.border_color = Color("#22e07a") if not primary else Color(0.0, 0.0, 0.0, 0.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.39, 0.96, 0.64) if primary else Color(0.10, 0.18, 0.31)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color("#0b1530") if primary else Color(0.95, 0.97, 0.92))
	button.pressed.connect(callback)
	_pause_panel.add_child(button)

func _on_touch_controls_toggled(enabled: bool) -> void:
	if is_instance_valid(_touch_controls):
		_touch_controls.visible = enabled

func _restart_match() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _return_to_home() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _detect_last_touch() -> void:
	var nearest_home: float = _nearest_team_distance(home_team.players, ball.global_position)
	var nearest_away: float = _nearest_team_distance(away_team.players, ball.global_position)
	if minf(nearest_home, nearest_away) <= 38.0:
		last_touch_team = "home" if nearest_home <= nearest_away else "away"
		_possession_label.text = "%s FC  /  IN POSSESSION" % ("ETHAN" if last_touch_team == "home" else "HARBOR")
		_possession_label.add_theme_color_override("font_color", Color("#22e07a") if last_touch_team == "home" else Color("#f0a500"))

func _nearest_team_distance(players: Array[FootballPlayer2D], location: Vector2) -> float:
	var nearest: float = INF
	for player: FootballPlayer2D in players:
		nearest = minf(nearest, player.global_position.distance_to(location))
	return nearest

func _nearest_player(players: Array[FootballPlayer2D], location: Vector2, goalkeeper_only: bool = false) -> FootballPlayer2D:
	var selected_player: FootballPlayer2D
	var selected_distance: float = INF
	for player_index in range(players.size()):
		if goalkeeper_only != (player_index == 0):
			continue
		var player: FootballPlayer2D = players[player_index]
		var distance: float = player.global_position.distance_squared_to(location)
		if distance < selected_distance:
			selected_distance = distance
			selected_player = player
	return selected_player

func _check_ball_boundaries() -> void:
	var position: Vector2 = ball.global_position
	var margin: float = pitch_size.y * FIELD_MARGIN_RATIO
	if position.y < margin - BALL_RADIUS:
		if absf(position.x - pitch_size.x * 0.5) <= goal_width * 0.5 - BALL_RADIUS:
			_award_goal("home")
		else:
			_award_goal_line_restart("top")
	elif position.y > pitch_size.y - margin + BALL_RADIUS:
		if absf(position.x - pitch_size.x * 0.5) <= goal_width * 0.5 - BALL_RADIUS:
			_award_goal("away")
		else:
			_award_goal_line_restart("bottom")
	elif position.x < margin - BALL_RADIUS:
		_award_restart("throw_in", "away" if last_touch_team == "home" else "home", Vector2(margin + 8.0, clampf(position.y, margin, pitch_size.y - margin)))
	elif position.x > pitch_size.x - margin + BALL_RADIUS:
		_award_restart("throw_in", "away" if last_touch_team == "home" else "home", Vector2(pitch_size.x - margin - 8.0, clampf(position.y, margin, pitch_size.y - margin)))

func _award_goal(scoring_team: String) -> void:
	if match_state != "live":
		return
	match_state = "restart"
	if scoring_team == "home":
		home_score += 1
	else:
		away_score += 1
	GameState.award_goal(scoring_team, "")
	score_changed.emit(home_score, away_score)
	_update_score()
	_set_status("GOAL!  %s SCORE" % ("ETHAN FC" if scoring_team == "home" else "HARBOR ATHLETIC"))
	_begin_kickoff("away" if scoring_team == "home" else "home", true)

func _award_goal_line_restart(goal_side: String) -> void:
	var attacking_team: String = "home" if goal_side == "top" else "away"
	var restart_team: String
	var restart_type: String
	if last_touch_team == attacking_team:
		restart_team = "away" if attacking_team == "home" else "home"
		restart_type = "goal_kick"
	else:
		restart_team = attacking_team
		restart_type = "corner"
	var restart_position := Vector2(
		pitch_size.x * 0.5,
		pitch_size.y * 0.07 + 26.0 if goal_side == "top" else pitch_size.y * 0.93 - 26.0
	)
	_award_restart(restart_type, restart_team, restart_position)

func _award_restart(restart_type: String, restart_team: String, restart_position: Vector2) -> void:
	if match_state != "live":
		return
	match_state = "restart"
	restart_awarded.emit(restart_type, restart_team)
	var restart_message: String = "%s  /  %s BALL" % [restart_type.to_upper(), "ETHAN" if restart_team == "home" else "HARBOR"]
	_set_status(restart_message)
	_possession_label.text = restart_message
	ball.stop_ball()
	ball.global_position = restart_position
	var restart_players: Array[FootballPlayer2D] = home_team.players if restart_team == "home" else away_team.players
	var restart_player: FootballPlayer2D = _nearest_player(restart_players, restart_position, restart_type == "goal_kick")
	if is_instance_valid(restart_player):
		restart_player.global_position = restart_position + Vector2(0.0, 28.0)
		restart_player.facing_direction = Vector2.UP if restart_team == "home" else Vector2.DOWN
	restart_timer = restart_delay_seconds
	_set_team_processing(false)

func _begin_kickoff(team_id: String, with_delay: bool, emit_event: bool = true) -> void:
	match_state = "restart"
	match_state_changed.emit("kickoff")
	if emit_event:
		GameState.kickoff.emit(team_id)
	ball.stop_ball()
	ball.global_position = pitch_size * 0.5
	if is_instance_valid(home_team):
		home_team.rebuild_formation()
	if is_instance_valid(away_team):
		away_team.rebuild_formation()
	home_team._kick_cooldown = 0.8
	away_team._kick_cooldown = 0.8
	if is_instance_valid(human_player):
		human_player.global_position = Vector2(pitch_size.x * 0.5 - 54.0, pitch_size.y * 0.5 + 78.0)
	restart_timer = restart_delay_seconds if with_delay else 0.0
	_set_team_processing(false)
	_set_status("KICK-OFF  /  %s" % ("ETHAN FC" if team_id == "home" else "HARBOR ATHLETIC"))
	_possession_label.text = "KICK-OFF  /  %s" % ("ETHAN FC" if team_id == "home" else "HARBOR ATHLETIC")
	if not with_delay:
		_resume_live_play()

func _resume_live_play() -> void:
	match_state = "live"
	match_state_changed.emit("live")
	_set_team_processing(true)
	_set_status("")
	if _possession_label.text.begins_with("KICK-OFF"):
		_possession_label.text = "ETHAN FC  /  PLAY ON"

func _set_team_processing(enabled: bool) -> void:
	for team: TeamAI2D in [home_team, away_team]:
		if not is_instance_valid(team):
			continue
		team.set_physics_process(enabled)
		for player: FootballPlayer2D in team.players:
			player.set_physics_process(enabled or player.is_human_controlled)

func _on_period_button_pressed() -> void:
	_period_panel.visible = false
	if current_half == 1 and match_state == "half_time":
		current_half = 2
		elapsed_seconds = half_duration_seconds
		get_tree().paused = false
		GameState.set_match_period("second_half")
		_begin_kickoff("away", false)
	elif match_state == "full_time":
		get_tree().paused = false
		get_tree().reload_current_scene()

func _update_clock() -> void:
	var half_elapsed: float = elapsed_seconds if current_half == 1 else elapsed_seconds - half_duration_seconds
	var game_seconds: int = floori(clampf(half_elapsed / half_duration_seconds, 0.0, 1.0) * 45.0 * 60.0)
	var minutes: int = game_seconds / 60
	var seconds: int = game_seconds % 60
	var clock_text: String = "%02d:%02d" % [minutes, seconds]
	_clock_label.text = clock_text
	match_clock_changed.emit(clock_text)
	if elapsed_seconds >= half_duration_seconds * float(current_half):
		if current_half == 1:
			_show_period_break("half_time", "HALF TIME", "START SECOND HALF")
		else:
			_show_period_break("full_time", "FULL TIME", "PLAY AGAIN")

func _show_period_break(state: String, title_text: String, button_text: String) -> void:
	match_state = state
	match_state_changed.emit(state)
	_set_team_processing(false)
	get_tree().paused = true
	GameState.set_match_period(state)
	if state == "full_time" and not _progression_awarded:
		_progression_awarded = true
		var coin_reward: int = ProfileStore.award_match_progress(home_score, away_score)
		ProfileStore.award_experience(25 if home_score >= away_score else 15)
		_set_status("MATCH REWARDS  /  +%d COINS  /  %d XP" % [coin_reward, 25 if home_score >= away_score else 15])
	_period_title.text = title_text
	_period_score.text = "ETH  %d  -  %d  HBR" % [home_score, away_score]
	_period_button.text = button_text
	_period_panel.visible = true
	_set_status("")

func toggle_pause() -> void:
	if match_state == "live":
		match_state = "paused"
		was_paused = true
		get_tree().paused = true
		_pause_overlay.visible = true
		_pause_panel.visible = true
		(_pause_panel.get_node("PauseScoreSummary") as Label).text = "ETH  %d  -  %d  HBR" % [home_score, away_score]
		match_state_changed.emit("paused")
	elif match_state == "paused":
		match_state = "live"
		was_paused = false
		get_tree().paused = false
		_pause_overlay.visible = false
		_pause_panel.visible = false
		match_state_changed.emit("live")

func _on_ball_kicked(_direction: Vector2, _impulse: float) -> void:
	if match_state == "restart" and restart_timer <= 0.0:
		_resume_live_play()

func _on_human_tackle(tackle_position: Vector2) -> void:
	var nearest_opponent: float = _nearest_team_distance(away_team.players, tackle_position)
	if nearest_opponent < 28.0:
		GameState.report_foul("home", "eth_011", "late_tackle")
		_award_restart("free_kick", "away", ball.global_position)

func _on_global_goal(team_id: String, _scorer_id: String) -> void:
	if team_id == "home":
		_score_label.text = "ETH  %d  -  %d  HBR" % [home_score, away_score]

func _on_global_foul(team_id: String, _player_id: String, _reason: String) -> void:
	_set_status("FOUL  /  %s FREE KICK" % ("ETHAN" if team_id == "away" else "HARBOR"))

func _on_global_period_changed(period: String) -> void:
	_period_label.text = period.replace("_", " ").to_upper()

func _update_score() -> void:
	_score_label.text = "ETH  %d  -  %d  HBR" % [home_score, away_score]

func _set_status(message: String) -> void:
	_status_label.text = message
	_status_time_left = 2.4 if not message.is_empty() else 0.0

func reset_match() -> void:
	home_score = 0
	away_score = 0
	elapsed_seconds = 0.0
	current_half = 1
	_progression_awarded = false
	GameState.start_match("ethan_fc")
	_update_score()
	_begin_kickoff("home", false, false)
