extends Node3D

const PlayerScript = preload("res://scripts/football_player.gd")
const OpponentScript = preload("res://scripts/football_opponent.gd")
const GoalkeeperScript = preload("res://scripts/football_goalkeeper.gd")
const CameraScript = preload("res://scripts/follow_camera.gd")
const HudScript = preload("res://scripts/match_hud.gd")
const SoundManagerScript = preload("res://scripts/sound_manager.gd")
const ReplayScript = preload("res://scripts/match_replay.gd")

const FIELD_WIDTH: float = 34.0
const FIELD_LENGTH: float = 52.0
const GOAL_Z: float = -25.7
const HOME_FORMATION: Array[Vector3] = [
	Vector3(-11.0, 0.1, 12.0), Vector3(-4.0, 0.1, 15.0),
	Vector3(4.0, 0.1, 15.0), Vector3(11.0, 0.1, 12.0),
	Vector3(-6.0, 0.1, 5.0), Vector3(0.0, 0.1, 7.0),
	Vector3(6.0, 0.1, 5.0), Vector3(-12.0, 0.1, -6.0),
	Vector3(0.0, 0.1, -9.0), Vector3(12.0, 0.1, -6.0)
]
const HOME_TEAM_FORMATION_INDICES: Array[int] = [8, 0, 1, 2, 3, 4, 5, 6, 7, 9]
const AWAY_TEAM_FORMATION_INDICES: Array[int] = [8, 6, 2, 0, 1, 3, 4, 5, 7, 9]
const AWAY_SQUAD_NUMBERS: Array[int] = [11, 2, 4, 5, 3, 6, 8, 7, 10, 9]
const HOME_SQUAD_NUMBERS: Array[int] = [2, 4, 5, 3, 6, 8, 7, 11, 9, 10]
const OUTFIELD_PLAYER_COUNT: int = 10
const MAX_SUBSTITUTIONS: int = 5

var player: FootballPlayer
var home_team: Array[FootballPlayer] = []
var bench: Array[FootballPlayer] = []
var opponent: FootballOpponent
var away_team: Array[FootballOpponent] = []
var home_goalkeeper: FootballGoalkeeper
var away_goalkeeper: FootballGoalkeeper
var ball: RigidBody3D
var hud: MatchHud
var sound_manager: SoundManager
var follow_camera: FollowCamera
var replay: MatchReplay
var home_score: int = 0
var away_score: int = 0
var reset_lock: float = 0.0
var training_goal_count: int = 0
var training_mode: bool = false
var opponent_speed_scale: float = 1.0
var last_ball_owner: String = ""
var restart_team: String = "home"
var next_kickoff_team: String = "home"
var restart_offside_exempt: bool = false
var last_kick_offside_exempt: bool = false
var active_touch_direction: Vector2 = Vector2.ZERO
var local_multiplayer: bool = false
var set_piece_mode: bool = false
var penalty_mode: bool = false
var next_restart_type: String = "kickoff"
var set_piece_aim: Vector3 = Vector3(0.0, 0.0, -1.0)
var set_piece_wall: Array[MeshInstance3D] = []
var rain_particles: GPUParticles3D
var challenge_type: String = ""
var challenge_score: int = 0
var challenge_time_left: float = 0.0
var challenge_active: bool = false
var substitutions_made: int = 0

func _ready() -> void:
	sound_manager = SoundManagerScript.new()
	add_child(sound_manager)

	_build_lighting()
	_build_pitch()
	_build_stadium_surrounds()
	_build_goal("North", GOAL_Z)
	_build_goal("South", -GOAL_Z)
	_build_set_piece_wall()
	_build_player_and_ball()
	_build_teammates()
	_build_bench()
	_build_opponent()
	_build_goalkeepers()
	_build_camera()

	hud = HudScript.new()
	add_child(hud)

	# Wire up radar
	if is_instance_valid(hud.radar):
		hud.radar.home_team = home_team
		hud.radar.away_team = away_team
		hud.radar.home_gk = home_goalkeeper
		hud.radar.away_gk = away_goalkeeper
		hud.radar.ball = ball
		hud.radar.active_player = player

	# Wire up touch controls
	if is_instance_valid(hud.touch_controls):
		hud.touch_controls.joystick_moved.connect(_on_touch_joystick_moved)
	hud.camera_view_requested.connect(_cycle_camera_view)
	hud.set_camera_view_name(follow_camera.get_view_name())

	# Wire up match events
	hud.restart_match_requested.connect(_restart_match)
	hud.half_time_continued.connect(_start_second_half)
	hud.training_mode_requested.connect(_set_training_mode)
	hud.match_settings_changed.connect(_set_match_settings)
	hud.audio_settings_changed.connect(_set_audio_settings)
	hud.tactical_preset_changed.connect(_set_tactical_preset)
	hud.opponent_style_changed.connect(_set_opponent_style)
	hud.substitution_requested.connect(_make_substitution)
	hud.local_multiplayer_changed.connect(_set_local_multiplayer)
	hud.training_challenge_requested.connect(_start_training_challenge)
	hud.accessibility_changed.connect(hud.set_accessibility)
	hud.weather_changed.connect(_set_weather)
	hud.career_upgrade_requested.connect(_apply_career_upgrade)
	hud.lineup_requested.connect(_show_lineup)
	hud.competition_table_requested.connect(_show_competition_table)
	away_goalkeeper.distribution_targets = away_team
	home_goalkeeper.distribution_targets = home_team
	hud.load_profile_settings(ProfileStore)
	_set_match_settings(ProfileStore.half_length, ProfileStore.difficulty, ProfileStore.home_color, ProfileStore.away_color)
	_set_tactical_preset(ProfileStore.tactical_preset)
	_set_opponent_style(ProfileStore.opponent_style)
	_set_local_multiplayer(ProfileStore.local_multiplayer_enabled)
	_set_audio_settings(ProfileStore.music_volume, ProfileStore.effects_volume)
	_apply_career_upgrades()
	_apply_competition_variant()
	replay = ReplayScript.new()
	replay.name = "MatchReplay"
	replay.tracked_nodes = [player, opponent, ball, follow_camera]
	replay.tracked_nodes.append_array(home_team.slice(1))
	replay.tracked_nodes.append_array(away_team.slice(1))
	add_child(replay)
	hud.replay_command_requested.connect(replay.handle_command)
	replay.replay_state_changed.connect(hud.set_replay_active)

	_connect_player_signals(player)
	next_restart_type = "kickoff"
	_reset_play(Vector3(0.0, 0.45, 0.0), next_kickoff_team)
	sound_manager.play_whistle(true)

func _build_launch_screen() -> void:
	var launch_layer := CanvasLayer.new()
	launch_layer.name = "EthanLaunchScreen"
	launch_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	launch_layer.layer = 10
	add_child(launch_layer)
	var panel := Control.new()
	panel.name = "LaunchPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	launch_layer.add_child(panel)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.012, 0.035, 0.03, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(backdrop)
	var left_wash := ColorRect.new()
	left_wash.color = Color(0.012, 0.045, 0.037, 0.97)
	left_wash.anchor_right = 0.57
	left_wash.anchor_bottom = 1.0
	panel.add_child(left_wash)
	var accent := ColorRect.new()
	accent.color = Color(0.83, 0.92, 0.28)
	accent.anchor_left = 0.075
	accent.anchor_right = 0.12
	accent.anchor_top = 0.13
	accent.anchor_bottom = 0.136
	panel.add_child(accent)
	var eyebrow := Label.new()
	eyebrow.text = "THE ETHAN CUP     /     MATCHDAY 01"
	eyebrow.anchor_left = 0.075
	eyebrow.anchor_right = 0.54
	eyebrow.anchor_top = 0.16
	eyebrow.anchor_bottom = 0.205
	eyebrow.add_theme_font_size_override("font_size", 15)
	eyebrow.add_theme_color_override("font_color", Color(0.77, 0.86, 0.72))
	panel.add_child(eyebrow)
	var title := Label.new()
	title.text = "ETHAN"
	title.anchor_left = 0.07
	title.anchor_right = 0.56
	title.anchor_top = 0.22
	title.anchor_bottom = 0.39
	title.add_theme_font_size_override("font_size", 92)
	title.add_theme_color_override("font_color", Color(0.96, 0.98, 0.89))
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "FOOTBALL CLUB  /  EST. 2026"
	subtitle.anchor_left = 0.08
	subtitle.anchor_right = 0.54
	subtitle.anchor_top = 0.385
	subtitle.anchor_bottom = 0.43
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.83, 0.91, 0.32))
	panel.add_child(subtitle)
	var fixture := Label.new()
	fixture.text = "HOME\nETHAN FC"
	fixture.anchor_left = 0.08
	fixture.anchor_right = 0.27
	fixture.anchor_top = 0.49
	fixture.anchor_bottom = 0.59
	fixture.add_theme_font_size_override("font_size", 20)
	fixture.add_theme_color_override("font_color", Color(0.96, 0.98, 0.89))
	panel.add_child(fixture)
	var versus := Label.new()
	versus.text = "VS"
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	versus.anchor_left = 0.27
	versus.anchor_right = 0.36
	versus.anchor_top = 0.505
	versus.anchor_bottom = 0.55
	versus.add_theme_font_size_override("font_size", 16)
	versus.add_theme_color_override("font_color", Color(0.83, 0.91, 0.32))
	panel.add_child(versus)
	var away_fixture := Label.new()
	away_fixture.text = "AWAY\nVISITORS"
	away_fixture.anchor_left = 0.37
	away_fixture.anchor_right = 0.55
	away_fixture.anchor_top = 0.49
	away_fixture.anchor_bottom = 0.59
	away_fixture.add_theme_font_size_override("font_size", 20)
	away_fixture.add_theme_color_override("font_color", Color(0.96, 0.98, 0.89))
	panel.add_child(away_fixture)
	var lineup := Label.new()
	lineup.text = "01     CAPTAIN                         10\n02     WIDE PLAYMAKER             07\n03     CENTRE FORWARD             09"
	lineup.anchor_left = 0.08
	lineup.anchor_right = 0.54
	lineup.anchor_top = 0.61
	lineup.anchor_bottom = 0.75
	lineup.add_theme_font_size_override("font_size", 14)
	lineup.add_theme_color_override("font_color", Color(0.77, 0.86, 0.78))
	panel.add_child(lineup)
	var pitch := Panel.new()
	pitch.name = "LaunchPitchGraphic"
	pitch.anchor_left = 0.65
	pitch.anchor_right = 0.92
	pitch.anchor_top = 0.19
	pitch.anchor_bottom = 0.81
	var pitch_style := StyleBoxFlat.new()
	pitch_style.bg_color = Color(0.08, 0.24, 0.15, 0.88)
	pitch_style.border_color = Color(0.82, 0.9, 0.67, 0.55)
	pitch_style.set_border_width_all(1)
	pitch.add_theme_stylebox_override("panel", pitch_style)
	panel.add_child(pitch)
	var halfway := ColorRect.new()
	halfway.color = Color(0.82, 0.9, 0.67, 0.55)
	halfway.anchor_left = 0.04
	halfway.anchor_right = 0.96
	halfway.anchor_top = 0.5
	halfway.anchor_bottom = 0.5
	halfway.offset_bottom = 1
	pitch.add_child(halfway)
	var centre_spot := ColorRect.new()
	centre_spot.color = Color(0.91, 0.94, 0.77, 0.9)
	centre_spot.anchor_left = 0.49
	centre_spot.anchor_right = 0.51
	centre_spot.anchor_top = 0.495
	centre_spot.anchor_bottom = 0.505
	pitch.add_child(centre_spot)
	var center_ring := Panel.new()
	center_ring.anchor_left = 0.32
	center_ring.anchor_right = 0.68
	center_ring.anchor_top = 0.39
	center_ring.anchor_bottom = 0.61
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	ring_style.border_color = Color(0.82, 0.9, 0.67, 0.55)
	ring_style.set_border_width_all(1)
	ring_style.set_corner_radius_all(100)
	center_ring.add_theme_stylebox_override("panel", ring_style)
	pitch.add_child(center_ring)
	for marker in [Vector2(0.25, 0.35), Vector2(0.72, 0.3), Vector2(0.53, 0.24), Vector2(0.4, 0.62), Vector2(0.65, 0.7)]:
		var player_marker := ColorRect.new()
		player_marker.color = Color(0.84, 0.93, 0.31) if marker.x < 0.5 else Color(0.94, 0.94, 0.87)
		player_marker.anchor_left = marker.x
		player_marker.anchor_right = marker.x
		player_marker.anchor_top = marker.y
		player_marker.anchor_bottom = marker.y
		player_marker.offset_left = -4
		player_marker.offset_right = 4
		player_marker.offset_top = -4
		player_marker.offset_bottom = 4
		pitch.add_child(player_marker)
	var pitch_caption := Label.new()
	pitch_caption.text = "KICK-OFF  /  90 MIN"
	pitch_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pitch_caption.anchor_left = 0.61
	pitch_caption.anchor_right = 0.96
	pitch_caption.anchor_top = 0.84
	pitch_caption.anchor_bottom = 0.89
	pitch_caption.add_theme_font_size_override("font_size", 13)
	pitch_caption.add_theme_color_override("font_color", Color(0.83, 0.91, 0.32))
	panel.add_child(pitch_caption)
	var play_button := Button.new()
	play_button.name = "PlayMatchButton"
	play_button.text = "KICK OFF     >"
	play_button.anchor_left = 0.08
	play_button.anchor_right = 0.34
	play_button.anchor_top = 0.79
	play_button.anchor_bottom = 0.88
	play_button.add_theme_font_size_override("font_size", 21)
	var primary_style := StyleBoxFlat.new()
	primary_style.bg_color = Color(0.83, 0.92, 0.28)
	primary_style.set_corner_radius_all(4)
	primary_style.content_margin_left = 20
	primary_style.content_margin_right = 20
	play_button.add_theme_stylebox_override("normal", primary_style)
	play_button.add_theme_stylebox_override("hover", primary_style)
	play_button.add_theme_stylebox_override("pressed", primary_style)
	play_button.add_theme_color_override("font_color", Color(0.025, 0.065, 0.04))
	play_button.add_theme_color_override("font_hover_color", Color(0.025, 0.065, 0.04))
	play_button.pressed.connect(func() -> void: _start_from_launch(false, launch_layer))
	panel.add_child(play_button)
	var training_button := Button.new()
	training_button.name = "TrainingButton"
	training_button.text = "TRAINING"
	training_button.anchor_left = 0.36
	training_button.anchor_right = 0.55
	training_button.anchor_top = 0.79
	training_button.anchor_bottom = 0.88
	training_button.add_theme_font_size_override("font_size", 17)
	training_button.pressed.connect(func() -> void: _start_from_launch(true, launch_layer))
	panel.add_child(training_button)
	var footer := Label.new()
	footer.text = "ARROWS MOVE     F SPRINT     J PASS     K SHOOT     P PAUSE"
	footer.anchor_left = 0.08
	footer.anchor_right = 0.9
	footer.anchor_top = 0.93
	footer.anchor_bottom = 0.97
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.72, 0.81, 0.72, 0.9))
	panel.add_child(footer)
	get_tree().paused = true
	hud.running = false
	sound_manager.play_ethan_theme()

func _start_from_launch(start_training: bool, launch_layer: CanvasLayer) -> void:
	if start_training:
		training_mode = true
		hud.set_training_mode(true)
	launch_layer.queue_free()
	get_tree().paused = false
	hud.running = true
	sound_manager.stop_ethan_theme()

func _on_touch_joystick_moved(vec: Vector2) -> void:
	active_touch_direction = vec
	if is_instance_valid(player):
		player.virtual_movement_direction = vec

func _connect_player_signals(p: FootballPlayer) -> void:
	if not p.shot_charge_changed.is_connected(_on_shot_charge_changed):
		p.shot_charge_changed.connect(_on_shot_charge_changed)
	if not p.ball_kicked.is_connected(_on_ball_kicked):
		p.ball_kicked.connect(_on_ball_kicked)
	if not p.stamina_changed.is_connected(_on_stamina_changed):
		p.stamina_changed.connect(_on_stamina_changed)
	if not p.slide_started.is_connected(_on_slide_started):
		p.slide_started.connect(_on_slide_started)
	if not p.slide_hit.is_connected(_on_slide_hit):
		p.slide_hit.connect(_on_slide_hit)
	if not p.through_ball_triggered.is_connected(_on_through_ball_triggered):
		p.through_ball_triggered.connect(_on_through_ball_triggered)
	if not p.standing_tackle_won.is_connected(_on_standing_tackle_won):
		p.standing_tackle_won.connect(_on_standing_tackle_won)
	if not p.foul_committed.is_connected(_on_player_foul):
		p.foul_committed.connect(_on_player_foul)
	if not p.training_action.is_connected(_on_training_action):
		p.training_action.connect(_on_training_action)

func _disconnect_player_signals(p: FootballPlayer) -> void:
	if p.shot_charge_changed.is_connected(_on_shot_charge_changed):
		p.shot_charge_changed.disconnect(_on_shot_charge_changed)
	if p.ball_kicked.is_connected(_on_ball_kicked):
		p.ball_kicked.disconnect(_on_ball_kicked)
	if p.stamina_changed.is_connected(_on_stamina_changed):
		p.stamina_changed.disconnect(_on_stamina_changed)
	if p.slide_started.is_connected(_on_slide_started):
		p.slide_started.disconnect(_on_slide_started)
	if p.slide_hit.is_connected(_on_slide_hit):
		p.slide_hit.disconnect(_on_slide_hit)
	if p.through_ball_triggered.is_connected(_on_through_ball_triggered):
		p.through_ball_triggered.disconnect(_on_through_ball_triggered)
	if p.standing_tackle_won.is_connected(_on_standing_tackle_won):
		p.standing_tackle_won.disconnect(_on_standing_tackle_won)
	if p.foul_committed.is_connected(_on_player_foul):
		p.foul_committed.disconnect(_on_player_foul)
	if p.training_action.is_connected(_on_training_action):
		p.training_action.disconnect(_on_training_action)

func _on_shot_charge_changed(charge: float, is_charging: bool) -> void:
	if is_instance_valid(hud):
		hud.update_shot_power(charge, is_charging)

func _on_ball_kicked(power_ratio: float) -> void:
	last_kick_offside_exempt = restart_offside_exempt
	restart_offside_exempt = false
	next_restart_type = "open_play"
	if set_piece_mode:
		set_piece_mode = false
		player.set_piece_aiming = false
		hud.set_set_piece_mode(false)
		_set_wall_visible(false)
	if is_instance_valid(sound_manager):
		sound_manager.play_kick(power_ratio)
	Input.vibrate_handheld(35, clampf(power_ratio, 0.2, 1.0))
	if is_instance_valid(hud) and power_ratio > 0.45:
		hud.record_shot(true)

func _on_stamina_changed(curr: float, max_v: float) -> void:
	if is_instance_valid(hud):
		hud.update_stamina(curr, max_v)

func _on_slide_started() -> void:
	if is_instance_valid(sound_manager):
		sound_manager.play_slide()

func _on_slide_hit() -> void:
	Input.vibrate_handheld(70, 0.8)
	if is_instance_valid(sound_manager):
		sound_manager.play_tackle()
	if is_instance_valid(hud):
		hud.record_tackle(true)
		hud.announce("GREAT SLIDE TACKLE!")

func _on_through_ball_triggered(target: FootballPlayer) -> void:
	if last_kick_offside_exempt or not _is_offside_target(target):
		if is_instance_valid(hud):
			hud.announce("THROUGH BALL!")
		return
	var restart_position := Vector3(target.global_position.x, 0.45, target.global_position.z)
	_award_free_kick(restart_position, "away", "OFFSIDE! INDIRECT FREE KICK")
	next_restart_type = "indirect_free_kick"

func _is_offside_target(target: FootballPlayer) -> bool:
	if not is_instance_valid(target) or away_team.size() < 1:
		return false
	var second_last_defender_z := _get_second_last_defender_z("away")
	return target.global_position.z < -0.1 and target.global_position.z < second_last_defender_z and target.global_position.z < ball.global_position.z

func _get_second_last_defender_z(defending_team: String) -> float:
	var defender_positions: Array[float] = []
	var defenders: Array = []
	if defending_team == "away":
		defenders = away_team
	else:
		defenders = home_team
	for defender in defenders:
		if is_instance_valid(defender):
			defender_positions.append(defender.global_position.z)
	var goalkeeper: FootballGoalkeeper = away_goalkeeper if defending_team == "away" else home_goalkeeper
	if is_instance_valid(goalkeeper):
		defender_positions.append(goalkeeper.global_position.z)
	if defender_positions.size() < 2:
		return -INF if defending_team == "away" else INF
	defender_positions.sort()
	return defender_positions[1] if defending_team == "away" else defender_positions[defender_positions.size() - 2]

func _on_player_foul(foul_position: Vector3) -> void:
	var restart_position := Vector3(clampf(foul_position.x, -14.0, 14.0), 0.45, clampf(foul_position.z, -23.0, 23.0))
	var is_penalty := absf(foul_position.x) < 8.0 and foul_position.z > 18.0
	if is_penalty:
		restart_position = Vector3(0.0, 0.45, 20.0)
	_award_free_kick(restart_position, "away", "FOUL! PENALTY KICK" if is_penalty else "FOUL! DIRECT FREE KICK")

func _on_opponent_foul(foul_position: Vector3) -> void:
	var is_penalty := absf(foul_position.x) < 8.0 and foul_position.z < -18.0
	var restart_position := Vector3(clampf(foul_position.x, -14.0, 14.0), 0.45, clampf(foul_position.z, -23.0, 23.0))
	if is_penalty:
		restart_position = Vector3(0.0, 0.45, -20.0)
	_award_free_kick(restart_position, "home", "FOUL! PENALTY KICK" if is_penalty else "FOUL! DIRECT FREE KICK")

func _award_free_kick(restart_position: Vector3, restart_owner: String, announcement: String) -> void:
	if reset_lock > 0.0:
		return
	reset_lock = 1.4
	if is_instance_valid(hud):
		hud.announce(announcement)
	if is_instance_valid(sound_manager):
		sound_manager.play_whistle(false)
	next_restart_type = "penalty" if announcement.contains("PENALTY") else "free_kick"
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		_reset_play(restart_position, restart_owner)
	)

func _on_training_action(action_name: String) -> void:
	if not challenge_active or action_name != challenge_type:
		return
	challenge_score += 1
	hud.set_challenge_status(challenge_type, challenge_score, challenge_time_left, true)

func _start_training_challenge(challenge: String) -> void:
	if challenge not in ["shooting", "passing", "defending"]:
		push_warning("Unknown training challenge: %s" % challenge)
		return
	challenge_type = challenge
	challenge_score = 0
	challenge_time_left = 60.0
	challenge_active = true
	training_mode = true
	hud.set_training_mode(true)
	hud.running = false
	hud.pause_modal.visible = false
	get_tree().paused = false
	hud.set_challenge_status(challenge_type, challenge_score, challenge_time_left, true)
	hud.announce("%s CHALLENGE: 60 SECONDS" % challenge.to_upper())

func _set_local_multiplayer(enabled: bool) -> void:
	local_multiplayer = enabled
	if is_instance_valid(opponent):
		opponent.local_human_controlled = enabled
		if enabled:
			opponent.position = Vector3(0.0, 0.1, -9.0)
			opponent.velocity = Vector3.ZERO

func _set_opponent_style(style_index: int) -> void:
	for away_player in away_team:
		if is_instance_valid(away_player):
			away_player.tactical_style = clampi(style_index, 0, 2)

func _make_substitution(player_index: int, reserve_index: int) -> void:
	if substitutions_made >= MAX_SUBSTITUTIONS or player_index < 0 or player_index >= home_team.size() or reserve_index < 0 or reserve_index >= bench.size():
		return
	var outgoing := home_team[player_index]
	var incoming := bench[reserve_index]
	if not is_instance_valid(outgoing) or not is_instance_valid(incoming):
		return
	if outgoing.has_ball:
		incoming.has_ball = true
		ball.set_meta("owner", incoming.name)
		ball.freeze = true
		incoming.global_position = outgoing.global_position
		incoming.facing = outgoing.facing
	home_team[player_index] = incoming
	bench[reserve_index] = outgoing
	outgoing.is_user_controlled = false
	outgoing.has_ball = false
	outgoing.visible = false
	outgoing.collision_layer = 0
	outgoing.collision_mask = 0
	outgoing.set_physics_process(false)
	outgoing.set_process(false)
	outgoing.global_position = Vector3(40.0 + float(reserve_index) * 2.0, 0.1, 40.0)
	incoming.visible = true
	incoming.collision_layer = 2
	incoming.collision_mask = 1
	incoming.set_physics_process(true)
	incoming.set_process(true)
	incoming.stamina = incoming.max_stamina
	incoming.walk_speed = 5.8 + float(ProfileStore.player_speed_upgrade) * 0.12
	incoming.sprint_speed = 8.7 + float(ProfileStore.player_speed_upgrade) * 0.18
	incoming.min_shot_power = 15.0 + float(ProfileStore.player_shot_upgrade) * 0.5
	incoming.max_shot_power = 28.0 + float(ProfileStore.player_shot_upgrade) * 0.8
	incoming.tactical_preset = ProfileStore.tactical_preset
	incoming.teammates = home_team
	for home_player in home_team:
		home_player.teammates = home_team
		home_player.all_opponents = away_team
	for away_player in away_team:
		away_player.home_players = home_team
	if is_instance_valid(hud.radar):
		hud.radar.home_team = home_team
	if player == outgoing:
		_switch_to_player(incoming)
	if is_instance_valid(replay) and not replay.tracked_nodes.has(incoming):
		replay.tracked_nodes.append(incoming)
	hud.announce("SUBSTITUTION: %s ON" % incoming.name.to_upper())
	substitutions_made += 1

func _apply_career_upgrades() -> void:
	for home_player in home_team:
		home_player.walk_speed += float(ProfileStore.player_speed_upgrade) * 0.12
		home_player.sprint_speed += float(ProfileStore.player_speed_upgrade) * 0.18
		home_player.min_shot_power += float(ProfileStore.player_shot_upgrade) * 0.5
		home_player.max_shot_power += float(ProfileStore.player_shot_upgrade) * 0.8

func _apply_career_upgrade(attribute: String) -> void:
	for home_player in home_team:
		if attribute == "speed":
			home_player.walk_speed += 0.12
			home_player.sprint_speed += 0.18
		elif attribute == "shot":
			home_player.min_shot_power += 0.5
			home_player.max_shot_power += 0.8

func _apply_competition_variant() -> void:
	if not is_instance_valid(hud):
		return
	if ProfileStore.tournament_active:
		hud.set_competition_title(ProfileStore.get_tournament_opponent_name())
	elif ProfileStore.career_active:
		hud.set_competition_title(ProfileStore.get_career_opponent_name())
	else:
		hud.set_competition_title("Training XI")
		for away_player in away_team:
			away_player.move_speed = 5.4 * opponent_speed_scale
		return
	var variant_index := ProfileStore.tournament_fixture_index if ProfileStore.tournament_active else (6 - ProfileStore.career_fixtures_remaining if ProfileStore.career_active else 0)
	var away_colors: Array[Color] = [Color(0.82, 0.16, 0.18), Color(0.15, 0.38, 0.72), Color(0.58, 0.2, 0.7), Color(0.85, 0.52, 0.13), Color(0.1, 0.55, 0.52), Color(0.35, 0.4, 0.48)]
	_set_team_kit(away_team, away_colors[posmod(variant_index, away_colors.size())])
	var speed_variation := 0.9 + float(posmod(variant_index * 7, 5)) * 0.05
	for away_player in away_team:
		away_player.move_speed = 5.4 * opponent_speed_scale * speed_variation

func _set_weather(weather_index: int) -> void:
	var sun := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if is_instance_valid(sun):
		sun.light_energy = 1.3 if weather_index == 0 else (0.55 if weather_index == 1 else 0.85)
		sun.rotation_degrees = Vector3(-25.0, -30.0, 0.0) if weather_index == 1 else Vector3(-55.0, -30.0, 0.0)
	if weather_index == 2:
		if not is_instance_valid(rain_particles):
			rain_particles = GPUParticles3D.new()
			rain_particles.name = "RainParticles"
			rain_particles.amount = 700
			rain_particles.lifetime = 1.5
			rain_particles.position = Vector3(0.0, 11.0, 0.0)
			rain_particles.emitting = true
			var process_material := ParticleProcessMaterial.new()
			process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			process_material.emission_box_extents = Vector3(17.0, 0.5, 26.0)
			process_material.direction = Vector3(0.0, -1.0, 0.0)
			process_material.spread = 5.0
			process_material.gravity = Vector3(0.0, -22.0, 0.0)
			process_material.initial_velocity_min = 14.0
			process_material.initial_velocity_max = 19.0
			rain_particles.process_material = process_material
			var rain_mesh := QuadMesh.new()
			rain_mesh.size = Vector2(0.025, 0.16)
			rain_particles.draw_pass_1 = rain_mesh
			add_child(rain_particles)
		rain_particles.emitting = true
	elif is_instance_valid(rain_particles):
		rain_particles.emitting = false

func _on_standing_tackle_won() -> void:
	Input.vibrate_handheld(50, 0.65)
	if is_instance_valid(hud):
		hud.record_tackle(true)
		hud.announce("CLEAN STANDING TACKLE!")
	if is_instance_valid(sound_manager):
		sound_manager.play_tackle()

func _set_training_mode(enabled: bool) -> void:
	training_mode = enabled
	if is_instance_valid(hud):
		hud.set_training_mode(enabled)
		hud.announce("TRAINING DRILL ACTIVE" if enabled else "MATCH MODE ACTIVE")
	if is_instance_valid(hud.pause_modal) and hud.pause_modal.visible:
		hud.toggle_pause()

func _set_match_settings(half_length: float, difficulty: float, home_color_index: int, away_color_index: int) -> void:
	if is_instance_valid(hud):
		hud.half_duration = half_length
	opponent_speed_scale = difficulty
	for away_player in away_team:
		if is_instance_valid(away_player):
			away_player.move_speed = 5.4 * opponent_speed_scale
	var home_colors: Array[Color] = [Color(0.12, 0.45, 0.88), Color(0.08, 0.62, 0.32), Color(0.82, 0.16, 0.18), Color(0.95, 0.68, 0.12)]
	var away_colors: Array[Color] = [Color(0.82, 0.16, 0.18), Color(0.12, 0.45, 0.88), Color(0.08, 0.62, 0.32), Color(0.95, 0.68, 0.12)]
	_set_team_kit(home_team, home_colors[clampi(home_color_index, 0, home_colors.size() - 1)])
	_set_team_kit(away_team, away_colors[clampi(away_color_index, 0, away_colors.size() - 1)])

func _set_tactical_preset(preset_index: int) -> void:
	for teammate in home_team:
		if is_instance_valid(teammate):
			teammate.tactical_preset = clampi(preset_index, 0, 2)

func _set_audio_settings(music_volume: float, effects_volume: float) -> void:
	if is_instance_valid(sound_manager):
		sound_manager.set_music_volume(music_volume)
		sound_manager.set_effects_volume(effects_volume)

func _show_lineup() -> void:
	var active_names: Array[String] = []
	var reserve_names: Array[String] = []
	for home_player in home_team:
		active_names.append("%s  |  %s" % [home_player.name, "CAPTAIN" if home_player.name == "Player" else "FIELD PLAYER"])
	for reserve in bench:
		reserve_names.append(reserve.name)
	hud.show_lineup(active_names, reserve_names)

func _show_competition_table() -> void:
	var result_list: Array[Dictionary] = ProfileStore.tournament_results if not ProfileStore.tournament_results.is_empty() else ProfileStore.career_results
	var active_competition := ProfileStore.tournament_active or ProfileStore.career_active
	var table_text := "POINTS: %d   GOAL DIFFERENCE: %d\n\n" % [
		ProfileStore.tournament_points if not ProfileStore.tournament_results.is_empty() else ProfileStore.career_points,
		ProfileStore.tournament_goal_difference if not ProfileStore.tournament_results.is_empty() else ProfileStore.career_goal_difference
	]
	for index in range(6):
		if index < result_list.size():
			var result: Dictionary = result_list[index]
			table_text += "%d. %s  %d-%d  |  %d pts\n" % [
				index + 1,
				result.get("opponent", "Opponent"),
				int(result.get("home_score", 0)),
				int(result.get("away_score", 0)),
				int(result.get("points", 0))
			]
		else:
			var upcoming_name := ProfileStore.get_tournament_fixture_name(index) if not ProfileStore.tournament_results.is_empty() or ProfileStore.tournament_active else ProfileStore.get_career_fixture_name(index)
			table_text += "%d. %s  |  %s\n" % [index + 1, upcoming_name, "UPCOMING" if active_competition else "NOT PLAYED"]
	hud.show_competition_table(table_text)

func _set_team_kit(team: Array, kit_color: Color) -> void:
	for footballer: Node3D in team:
		if not is_instance_valid(footballer):
			continue
		var torso := footballer.get_node_or_null("Torso") as MeshInstance3D
		if is_instance_valid(torso):
			torso.material_override = _material(kit_color, 0.55)

func _request_keeper_distribution() -> void:
	if home_goalkeeper.has_ball:
		home_goalkeeper.request_distribution()
	elif away_goalkeeper.has_ball:
		away_goalkeeper.request_distribution()

func _unhandled_input(event: InputEvent) -> void:
	var touch_position := Vector2.ZERO
	var is_tap := false
	if event is InputEventScreenTouch and event.pressed:
		touch_position = event.position
		is_tap = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		touch_position = event.position
		is_tap = true
	if not is_tap or not is_instance_valid(follow_camera):
		return
	for teammate: FootballPlayer in home_team:
		if teammate == player or not is_instance_valid(teammate):
			continue
		if follow_camera.unproject_position(teammate.global_position + Vector3.UP * 1.1).distance_to(touch_position) < 48.0:
			_switch_to_player(teammate)
			return

func _process(delta: float) -> void:
	if not is_instance_valid(hud) or not is_instance_valid(ball) or not is_instance_valid(player):
		return
	reset_lock = maxf(0.0, reset_lock - delta)
	if challenge_active:
		challenge_time_left = maxf(0.0, challenge_time_left - delta)
		hud.set_challenge_status(challenge_type, challenge_score, challenge_time_left, true)
		if challenge_time_left <= 0.0:
			ProfileStore.update_drill_best(challenge_type, challenge_score)
			challenge_active = false
			hud.set_challenge_status("", challenge_score, 0.0, false)
			hud.announce("%s CHALLENGE SCORE: %d" % [challenge_type.to_upper(), challenge_score])
			challenge_type = ""
	_update_controlled_player()
	if set_piece_mode:
		_process_set_piece_aim()
	if Input.is_action_just_pressed("camera_view"):
		_cycle_camera_view()

	if Input.is_action_just_pressed("switch_player") and not player.has_ball:
		_switch_to_closest_defender()
	if Input.is_action_just_pressed("keeper_distribute"):
		_request_keeper_distribution()
	var owner_name := str(ball.get_meta("owner", ""))
	if not owner_name.is_empty():
		last_ball_owner = owner_name

	var any_opp_has_ball := false
	for opp in away_team:
		if is_instance_valid(opp) and opp.has_ball:
			any_opp_has_ball = true
			break

	if is_instance_valid(hud):
		hud.set_possession(player.has_ball, any_opp_has_ball, home_team.size(), player.name != "Player")
		if is_instance_valid(hud.radar):
			hud.radar.active_player = player

	if reset_lock > 0.0:
		return

	if ball.global_position.z < GOAL_Z and absf(ball.global_position.x) < 3.6 and ball.global_position.y < 3.1:
		Input.vibrate_handheld(180, 1.0)
		if training_mode:
			training_goal_count += 1
			hud.set_training_goals(training_goal_count)
			if challenge_active and challenge_type == "shooting":
				challenge_score += 5
				hud.set_challenge_status(challenge_type, challenge_score, challenge_time_left, true)
		else:
			home_score += 1
		hud.set_score(home_score, away_score)
		hud.show_goal_banner("TRAINING" if training_mode else "HOME TEAM")
		if is_instance_valid(replay):
			replay.play_highlight()
		if not training_mode:
			hud.announce("GOAL! HOME TEAM SCORES!")
		if is_instance_valid(sound_manager):
			sound_manager.play_net()
			sound_manager.play_whistle(true)
			sound_manager.play_cheer()
		reset_lock = 2.4
		next_restart_type = "kickoff"
		next_kickoff_team = "away"
		get_tree().create_timer(2.8, true).timeout.connect(func() -> void: _reset_play(Vector3(0.0, 0.45, 0.0), next_kickoff_team))
	elif ball.global_position.z > -GOAL_Z and absf(ball.global_position.x) < 3.6 and ball.global_position.y < 3.1:
		Input.vibrate_handheld(180, 1.0)
		if not training_mode:
			away_score += 1
		hud.set_score(home_score, away_score)
		hud.show_goal_banner("AWAY TEAM")
		if is_instance_valid(replay):
			replay.play_highlight()
		hud.announce("GOAL! AWAY TEAM SCORES!")
		if is_instance_valid(sound_manager):
			sound_manager.play_net()
			sound_manager.play_whistle(true)
			sound_manager.play_cheer()
		reset_lock = 2.4
		next_restart_type = "kickoff"
		next_kickoff_team = "home"
		get_tree().create_timer(2.8, true).timeout.connect(func() -> void: _reset_play(Vector3(0.0, 0.45, 0.0), next_kickoff_team))
	elif absf(ball.global_position.x) > FIELD_WIDTH * 0.5 + 1.0 or absf(ball.global_position.z) > FIELD_LENGTH * 0.5 + 1.0:
		if absf(ball.global_position.z) > FIELD_LENGTH * 0.5 + 1.0 and absf(ball.global_position.x) < 6.0 and ball.global_position.y < 3.5:
			hud.announce("SO CLOSE!")
			if is_instance_valid(sound_manager):
				sound_manager.play_cheer()
		next_restart_type = _get_set_piece_type()
		restart_team = _get_set_piece_team()
		var restart_position := _get_set_piece_position()
		hud.announce(_get_set_piece_announcement())
		if is_instance_valid(sound_manager):
			sound_manager.play_whistle(false)
		reset_lock = 1.2
		get_tree().create_timer(1.0).timeout.connect(func() -> void: _reset_play(restart_position, restart_team))

func _build_set_piece_wall() -> void:
	for index in range(3):
		var wall_player := MeshInstance3D.new()
		wall_player.name = "SetPieceWall%d" % index
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.42
		capsule.height = 1.8
		wall_player.mesh = capsule
		var wall_material := StandardMaterial3D.new()
		wall_material.albedo_color = Color(0.82, 0.18, 0.12)
		wall_player.material_override = wall_material
		wall_player.visible = false
		add_child(wall_player)
		set_piece_wall.append(wall_player)

func _set_wall_visible(enabled: bool) -> void:
	for wall_player in set_piece_wall:
		wall_player.visible = enabled

func _process_set_piece_aim() -> void:
	var aim_input := Input.get_axis("move_left", "move_right")
	set_piece_aim.x = clampf(set_piece_aim.x + aim_input * get_process_delta_time() * 0.9, -0.7, 0.7)
	set_piece_aim = Vector3(set_piece_aim.x, 0.0, -1.0).normalized()
	player.facing = set_piece_aim
	player.rotation.y = atan2(-set_piece_aim.x, -set_piece_aim.z)
	player.shot_aim_direction = set_piece_aim
	player.shot_charge = 0.35
	player._update_aim_arrow()
	if Input.is_action_just_pressed("pass_ball") or Input.is_action_just_pressed("shoot_ball"):
		set_piece_mode = false
		player.set_piece_aiming = false
		hud.set_set_piece_mode(false)
		_set_wall_visible(false)

func _get_set_piece_announcement() -> String:
	if next_restart_type == "corner":
		return "Corner kick awarded"
	if next_restart_type == "goal_kick":
		return "Goal kick awarded"
	return "Throw-in awarded"

func _get_set_piece_type() -> String:
	if absf(ball.global_position.z) > FIELD_LENGTH * 0.5 + 1.0:
		return "goal_kick" if _last_touching_team() == _attacking_team_at_goal_line() else "corner"
	return "throw_in"

func _get_set_piece_team() -> String:
	var last_touch_team := _last_touching_team()
	if absf(ball.global_position.z) > FIELD_LENGTH * 0.5 + 1.0:
		var attacking_team := _attacking_team_at_goal_line()
		if last_touch_team == attacking_team:
			return "away" if attacking_team == "home" else "home"
		return attacking_team
	return "away" if last_touch_team == "home" else "home"

func _get_set_piece_position() -> Vector3:
	if next_restart_type == "throw_in":
		var touchline_x := signf(ball.global_position.x) * FIELD_WIDTH * 0.5
		return Vector3(touchline_x, 0.45, clampf(ball.global_position.z, -FIELD_LENGTH * 0.5, FIELD_LENGTH * 0.5))
	var goal_line_sign := signf(ball.global_position.z)
	if next_restart_type == "corner":
		return Vector3(signf(ball.global_position.x) * FIELD_WIDTH * 0.5, 0.45, goal_line_sign * FIELD_LENGTH * 0.5)
	return Vector3(clampf(ball.global_position.x, -4.5, 4.5), 0.45, goal_line_sign * (FIELD_LENGTH * 0.5 - 3.5))

func _last_touching_team() -> String:
	return "home" if last_ball_owner.is_empty() or last_ball_owner == "Player" or last_ball_owner.begins_with("Teammate") or last_ball_owner.begins_with("Reserve") else "away"

func _attacking_team_at_goal_line() -> String:
	return "home" if ball.global_position.z < 0.0 else "away"

func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.07, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.82, 0.78)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.shadow_blur = 1.0
	add_child(sun)

	# Secondary stadium fill light
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-45.0, 140.0, 0.0)
	fill.light_energy = 0.55
	add_child(fill)

func _build_pitch() -> void:
	# Stadium apron / perimeter track
	var track_mat := _material(Color(0.2, 0.22, 0.25), 0.95)
	_add_box("StadiumApron", Vector3(48.0, 0.16, 68.0), Vector3(0, -0.15, 0), track_mat)

	# Alternating lawn mowing stripes
	var dark_turf := _material(Color(0.11, 0.36, 0.19), 0.96)
	var light_turf := _material(Color(0.14, 0.44, 0.23), 0.94)
	var num_stripes := 10
	var stripe_len: float = FIELD_LENGTH / float(num_stripes)
	for i in range(num_stripes):
		var z_pos := -FIELD_LENGTH * 0.5 + (float(i) + 0.5) * stripe_len
		var mat: Material = light_turf if i % 2 == 0 else dark_turf
		_add_box("TurfStripe%d" % i, Vector3(FIELD_WIDTH, 0.2, stripe_len), Vector3(0, -0.12, z_pos), mat)

	var ground := StaticBody3D.new()
	ground.name = "PitchCollision"
	ground.position.y = -0.1
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(FIELD_WIDTH, 0.2, FIELD_LENGTH)
	ground_shape.shape = ground_box
	ground.add_child(ground_shape)
	add_child(ground)

	# Full field lines
	var line_material := _material(Color(0.92, 0.96, 0.88), 0.8)
	var line_y := 0.018

	# Touchlines & Halfway
	_add_box("Touchline North", Vector3(FIELD_WIDTH, 0.025, 0.12), Vector3(0, line_y, -FIELD_LENGTH * 0.5), line_material)
	_add_box("Touchline South", Vector3(FIELD_WIDTH, 0.025, 0.12), Vector3(0, line_y, FIELD_LENGTH * 0.5), line_material)
	_add_box("Touchline West", Vector3(0.12, 0.025, FIELD_LENGTH), Vector3(-FIELD_WIDTH * 0.5, line_y, 0), line_material)
	_add_box("Touchline East", Vector3(0.12, 0.025, FIELD_LENGTH), Vector3(FIELD_WIDTH * 0.5, line_y, 0), line_material)
	_add_box("Halfway Line", Vector3(FIELD_WIDTH, 0.02, 0.1), Vector3(0, line_y, 0), line_material)
	_add_disc("Center Spot", 0.14, Vector3(0, line_y + 0.005, 0), line_material)

	# Center Circle (radius 5.5m)
	_add_circle_line(Vector3(0, line_y, 0), 5.5, line_material, 36)

	# North Penalty Area & 6-Yard Box
	_add_box("Penalty Area North", Vector3(16.0, 0.02, 0.1), Vector3(0, line_y, -FIELD_LENGTH * 0.5 + 8.0), line_material)
	_add_box("Penalty Side Left North", Vector3(0.1, 0.02, 8.0), Vector3(-8.0, line_y, -FIELD_LENGTH * 0.5 + 4.0), line_material)
	_add_box("Penalty Side Right North", Vector3(0.1, 0.02, 8.0), Vector3(8.0, line_y, -FIELD_LENGTH * 0.5 + 4.0), line_material)
	_add_box("Goal Area North", Vector3(9.0, 0.02, 0.1), Vector3(0, line_y, -FIELD_LENGTH * 0.5 + 3.5), line_material)
	_add_box("Goal Area Left North", Vector3(0.1, 0.02, 3.5), Vector3(-4.5, line_y, -FIELD_LENGTH * 0.5 + 1.75), line_material)
	_add_box("Goal Area Right North", Vector3(0.1, 0.02, 3.5), Vector3(4.5, line_y, -FIELD_LENGTH * 0.5 + 1.75), line_material)
	var north_penalty_spot := Vector3(0, line_y + 0.005, -FIELD_LENGTH * 0.5 + 6.0)
	_add_disc("Penalty Spot North", 0.12, north_penalty_spot, line_material)
	var arc_angle := acos(2.0 / 9.15)
	_add_arc_line("Penalty Arc North", north_penalty_spot, 9.15, -arc_angle, arc_angle, line_material, 28)

	# South Penalty Area & 6-Yard Box
	_add_box("Penalty Area South", Vector3(16.0, 0.02, 0.1), Vector3(0, line_y, FIELD_LENGTH * 0.5 - 8.0), line_material)
	_add_box("Penalty Side Left South", Vector3(0.1, 0.02, 8.0), Vector3(-8.0, line_y, FIELD_LENGTH * 0.5 - 4.0), line_material)
	_add_box("Penalty Side Right South", Vector3(0.1, 0.02, 8.0), Vector3(8.0, line_y, FIELD_LENGTH * 0.5 - 4.0), line_material)
	_add_box("Goal Area South", Vector3(9.0, 0.02, 0.1), Vector3(0, line_y, FIELD_LENGTH * 0.5 - 3.5), line_material)
	_add_box("Goal Area Left South", Vector3(0.1, 0.02, 3.5), Vector3(-4.5, line_y, FIELD_LENGTH * 0.5 - 1.75), line_material)
	_add_box("Goal Area Right South", Vector3(0.1, 0.02, 3.5), Vector3(4.5, line_y, FIELD_LENGTH * 0.5 - 1.75), line_material)
	var south_penalty_spot := Vector3(0, line_y + 0.005, FIELD_LENGTH * 0.5 - 6.0)
	_add_disc("Penalty Spot South", 0.12, south_penalty_spot, line_material)
	_add_arc_line("Penalty Arc South", south_penalty_spot, 9.15, PI - arc_angle, PI + arc_angle, line_material, 28)

	# Corner Arcs (1.0m radius)
	_add_corner_arc(Vector3(-FIELD_WIDTH * 0.5, line_y, -FIELD_LENGTH * 0.5), 1.0, 0.0, line_material)
	_add_corner_arc(Vector3(FIELD_WIDTH * 0.5, line_y, -FIELD_LENGTH * 0.5), 1.0, PI * 0.5, line_material)
	_add_corner_arc(Vector3(FIELD_WIDTH * 0.5, line_y, FIELD_LENGTH * 0.5), 1.0, PI, line_material)
	_add_corner_arc(Vector3(-FIELD_WIDTH * 0.5, line_y, FIELD_LENGTH * 0.5), 1.0, PI * 1.5, line_material)

func _add_circle_line(center: Vector3, radius: float, material: Material, segments: int) -> void:
	var step := TAU / float(segments)
	var seg_len := radius * step * 1.05
	for i in range(segments):
		var angle := float(i) * step
		var mid_angle := angle + step * 0.5
		var pos := center + Vector3(sin(mid_angle) * radius, 0.0, cos(mid_angle) * radius)
		var box := _add_box("CircleSeg%d" % i, Vector3(0.09, 0.02, seg_len), pos, material)
		box.rotation.y = mid_angle

func _add_arc_line(label: String, center: Vector3, radius: float, start_angle: float, end_angle: float, material: Material, segments: int) -> void:
	var step := (end_angle - start_angle) / float(segments)
	var segment_length := radius * step * 1.08
	for index in range(segments):
		var angle := start_angle + float(index) * step
		var midpoint_angle := angle + step * 0.5
		var segment_position := center + Vector3(sin(midpoint_angle) * radius, 0.0, cos(midpoint_angle) * radius)
		var arc_segment := _add_box("%s%d" % [label, index], Vector3(0.09, 0.02, segment_length), segment_position, material)
		arc_segment.rotation.y = midpoint_angle

func _add_disc(label: String, radius: float, location: Vector3, material: Material) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	disc.name = label
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.018
	disc.mesh = cylinder
	disc.position = location
	disc.material_override = material
	add_child(disc)
	return disc

func _add_corner_arc(corner: Vector3, radius: float, start_rot: float, material: Material) -> void:
	var segments := 8
	var step := (PI * 0.5) / float(segments)
	var seg_len := radius * step * 1.08
	for i in range(segments):
		var angle := start_rot + float(i) * step
		var mid_angle := angle + step * 0.5
		var pos := corner + Vector3(sin(mid_angle) * radius, 0.0, cos(mid_angle) * radius)
		var box := _add_box("CornerSeg%d" % i, Vector3(0.09, 0.02, seg_len), pos, material)
		box.rotation.y = mid_angle

func _build_stadium_surrounds() -> void:
	# 4 Corner Flags
	var flag_mat := _material(Color(0.95, 0.2, 0.15), 0.4)
	var staff_mat := _material(Color(0.95, 0.95, 0.92), 0.3)
	var corner_coords := [
		Vector3(-FIELD_WIDTH * 0.5, 0, -FIELD_LENGTH * 0.5),
		Vector3(FIELD_WIDTH * 0.5, 0, -FIELD_LENGTH * 0.5),
		Vector3(-FIELD_WIDTH * 0.5, 0, FIELD_LENGTH * 0.5),
		Vector3(FIELD_WIDTH * 0.5, 0, FIELD_LENGTH * 0.5)
	]
	for idx in range(corner_coords.size()):
		var pt: Vector3 = corner_coords[idx]
		_add_cylinder("FlagStaff%d" % idx, 0.025, 1.4, pt + Vector3(0, 0.7, 0), staff_mat)
		var flag := _add_box("Flag%d" % idx, Vector3(0.35, 0.24, 0.02), pt + Vector3(0.18, 1.25, 0), flag_mat)
		flag.rotation.y = PI * 0.25

	# Perimeter LED Sponsor Boards
	var sponsor_colors := [
		Color(0.08, 0.42, 0.88), Color(0.95, 0.82, 0.12),
		Color(0.1, 0.65, 0.35), Color(0.88, 0.18, 0.22)
	]
	var side_span := 14
	var board_len: float = (FIELD_LENGTH + 4.0) / float(side_span)
	for i in range(side_span):
		var z_pos := -(FIELD_LENGTH + 4.0) * 0.5 + (float(i) + 0.5) * board_len
		var mat := _material(sponsor_colors[i % sponsor_colors.size()], 0.45)
		_add_box("WestBoard%d" % i, Vector3(0.18, 0.88, board_len * 0.96), Vector3(-FIELD_WIDTH * 0.5 - 2.2, 0.44, z_pos), mat)
		_add_box("EastBoard%d" % i, Vector3(0.18, 0.88, board_len * 0.96), Vector3(FIELD_WIDTH * 0.5 + 2.2, 0.44, z_pos), mat)

	# North/South Boards behind goals
	for i in range(3):
		var mat := _material(sponsor_colors[i % sponsor_colors.size()], 0.45)
		# North Left & Right
		_add_box("NorthBoardL%d" % i, Vector3(3.8, 0.88, 0.18), Vector3(-13.5 + i * 4.0, 0.44, -FIELD_LENGTH * 0.5 - 2.6), mat)
		_add_box("NorthBoardR%d" % i, Vector3(3.8, 0.88, 0.18), Vector3(5.5 + i * 4.0, 0.44, -FIELD_LENGTH * 0.5 - 2.6), mat)
		# South Left & Right
		_add_box("SouthBoardL%d" % i, Vector3(3.8, 0.88, 0.18), Vector3(-13.5 + i * 4.0, 0.44, FIELD_LENGTH * 0.5 + 2.6), mat)
		_add_box("SouthBoardR%d" % i, Vector3(3.8, 0.88, 0.18), Vector3(5.5 + i * 4.0, 0.44, FIELD_LENGTH * 0.5 + 2.6), mat)

	# 4 Stadium Floodlight Pylons
	var steel_mat := _material(Color(0.28, 0.3, 0.33), 0.5)
	var lamp_mat := _material(Color(0.95, 0.98, 0.88), 0.2)
	var tower_coords := [
		Vector3(-22.0, 0, -32.0), Vector3(22.0, 0, -32.0),
		Vector3(-22.0, 0, 32.0), Vector3(22.0, 0, 32.0)
	]
	for idx in range(tower_coords.size()):
		var pt: Vector3 = tower_coords[idx]
		_add_cylinder("Pylon%d" % idx, 0.25, 14.0, pt + Vector3(0, 7.0, 0), steel_mat)
		_add_box("PylonHead%d" % idx, Vector3(3.2, 0.5, 0.8), pt + Vector3(0, 14.0, 0), steel_mat)
		for lamp_i in range(3):
			_add_box("Lamp%d_%d" % [idx, lamp_i], Vector3(0.65, 0.35, 0.2), pt + Vector3(-1.0 + lamp_i * 1.0, 14.0, -0.4 if pt.z < 0 else 0.4), lamp_mat)

func _build_goal(label: String, goal_z: float) -> void:
	var post_material := _material(Color(0.94, 0.96, 0.92), 0.3)
	var back_sign: float = -1.0 if goal_z < 0.0 else 1.0
	var depth: float = 2.4
	var back_z: float = goal_z + back_sign * depth

	# Goal frame
	_add_cylinder(label + " Left Goal Post", 0.13, 3.0, Vector3(-3.6, 1.5, goal_z), post_material)
	_add_cylinder(label + " Right Goal Post", 0.13, 3.0, Vector3(3.6, 1.5, goal_z), post_material)
	var crossbar := _add_cylinder(label + " Goal Crossbar", 0.13, 7.2, Vector3(0, 3.0, goal_z), post_material)
	crossbar.rotation.z = PI * 0.5

	# Rear support framing
	var rear_frame_mat := _material(Color(0.72, 0.76, 0.75), 0.5)
	_add_cylinder(label + " Rear Left Post", 0.08, 2.7, Vector3(-3.6, 1.35, back_z), rear_frame_mat)
	_add_cylinder(label + " Rear Right Post", 0.08, 2.7, Vector3(3.6, 1.35, back_z), rear_frame_mat)
	var rear_top_bar := _add_cylinder(label + " Rear Top Bar", 0.08, 7.2, Vector3(0.0, 2.7, back_z), rear_frame_mat)
	rear_top_bar.rotation.z = PI * 0.5
	var rear_ground_bar := _add_cylinder(label + " Rear Ground Bar", 0.08, 7.2, Vector3(0.0, 0.05, back_z), rear_frame_mat)
	rear_ground_bar.rotation.z = PI * 0.5

	# Visual Net Panels
	var net_material := StandardMaterial3D.new()
	net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net_material.albedo_color = Color(0.92, 0.96, 0.98, 0.45)
	net_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	net_material.roughness = 0.95

	_add_box(label + " Net Back", Vector3(7.2, 2.7, 0.04), Vector3(0.0, 1.35, back_z), net_material)
	_add_box(label + " Net Top", Vector3(7.2, 0.04, depth), Vector3(0.0, 2.85, goal_z + back_sign * depth * 0.5), net_material)
	_add_box(label + " Net Left", Vector3(0.04, 2.7, depth), Vector3(-3.6, 1.35, goal_z + back_sign * depth * 0.5), net_material)
	_add_box(label + " Net Right", Vector3(0.04, 2.7, depth), Vector3(3.6, 1.35, goal_z + back_sign * depth * 0.5), net_material)

	# Net & Goal Physical Collision
	var net_body := StaticBody3D.new()
	net_body.name = label + " GoalCollision"
	net_body.collision_layer = 1
	net_body.collision_mask = 0

	var left_post_col := CollisionShape3D.new()
	var left_post_shape := CylinderShape3D.new()
	left_post_shape.radius = 0.13
	left_post_shape.height = 3.0
	left_post_col.shape = left_post_shape
	left_post_col.position = Vector3(-3.6, 1.5, goal_z)
	net_body.add_child(left_post_col)

	var right_post_col := CollisionShape3D.new()
	var right_post_shape := CylinderShape3D.new()
	right_post_shape.radius = 0.13
	right_post_shape.height = 3.0
	right_post_col.shape = right_post_shape
	right_post_col.position = Vector3(3.6, 1.5, goal_z)
	net_body.add_child(right_post_col)

	var crossbar_col := CollisionShape3D.new()
	var crossbar_shape := CylinderShape3D.new()
	crossbar_shape.radius = 0.13
	crossbar_shape.height = 7.2
	crossbar_col.shape = crossbar_shape
	crossbar_col.position = Vector3(0.0, 3.0, goal_z)
	crossbar_col.rotation.z = PI * 0.5
	net_body.add_child(crossbar_col)

	var back_wall_col := CollisionShape3D.new()
	var back_wall_shape := BoxShape3D.new()
	back_wall_shape.size = Vector3(7.4, 3.2, 0.25)
	back_wall_col.shape = back_wall_shape
	back_wall_col.position = Vector3(0.0, 1.5, back_z + back_sign * 0.12)
	net_body.add_child(back_wall_col)

	var left_net_col := CollisionShape3D.new()
	var left_net_shape := BoxShape3D.new()
	left_net_shape.size = Vector3(0.25, 3.2, depth)
	left_net_col.shape = left_net_shape
	left_net_col.position = Vector3(-3.7, 1.5, goal_z + back_sign * depth * 0.5)
	net_body.add_child(left_net_col)

	var right_net_col := CollisionShape3D.new()
	var right_net_shape := BoxShape3D.new()
	right_net_shape.size = Vector3(0.25, 3.2, depth)
	right_net_col.shape = right_net_shape
	right_net_col.position = Vector3(3.7, 1.5, goal_z + back_sign * depth * 0.5)
	net_body.add_child(right_net_col)

	var top_net_col := CollisionShape3D.new()
	var top_net_shape := BoxShape3D.new()
	top_net_shape.size = Vector3(7.4, 0.25, depth)
	top_net_col.shape = top_net_shape
	top_net_col.position = Vector3(0.0, 3.05, goal_z + back_sign * depth * 0.5)
	net_body.add_child(top_net_col)

	add_child(net_body)

func _create_football_texture() -> ImageTexture:
	var width := 256
	var height := 128
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.96, 0.96, 0.93))

	var patch_centers := [
		Vector2(0.25, 0.25), Vector2(0.75, 0.25),
		Vector2(0.0, 0.5), Vector2(0.5, 0.5), Vector2(1.0, 0.5),
		Vector2(0.25, 0.75), Vector2(0.75, 0.75)
	]

	for y in range(height):
		var ny := float(y) / float(height)
		for x in range(width):
			var nx := float(x) / float(width)
			var min_dist := 999.0
			for center in patch_centers:
				var dx: float = absf(nx - center.x)
				if dx > 0.5:
					dx = 1.0 - dx
				var dy: float = absf(ny - center.y) * 2.0
				var dist: float = sqrt(dx * dx * 4.0 + dy * dy)
				if dist < min_dist:
					min_dist = dist
			if min_dist < 0.21:
				img.set_pixel(x, y, Color(0.11, 0.12, 0.14))
			elif min_dist < 0.25:
				img.set_pixel(x, y, Color(0.85, 0.22, 0.18))
			elif min_dist < 0.27:
				img.set_pixel(x, y, Color(0.72, 0.72, 0.70))
	return ImageTexture.create_from_image(img)

func _build_player_and_ball() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	player.collision_layer = 2
	player.collision_mask = 1
	player.position = Vector3(0, 0.1, 10.0)
	player.formation_offset = HOME_FORMATION[HOME_TEAM_FORMATION_INDICES[0]]
	add_child(player)

	var body_collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 1.8
	body_collision.shape = capsule
	body_collision.position.y = 0.9
	player.add_child(body_collision)

	_add_footballer_visual(player, Color(0.12, 0.45, 0.88), 10, Color(0.14, 0.11, 0.08))

	var marker := MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.16, 0.16, 0.55)
	marker.mesh = marker_mesh
	marker.position = Vector3(0, 1.05, -0.43)
	marker.material_override = _material(Color(0.98, 0.86, 0.25), 0.3)
	player.add_child(marker)

	ball = RigidBody3D.new()
	ball.name = "Ball"
	ball.collision_layer = 8
	ball.collision_mask = 7
	ball.position = Vector3(0, 0.45, 8.3)
	ball.mass = 0.45
	ball.linear_damp = 0.5
	ball.angular_damp = 0.8
	ball.continuous_cd = true
	ball.physics_material_override = _physics_material()
	add_child(ball)

	var ball_collision := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.34
	ball_collision.shape = sphere_shape
	ball.add_child(ball_collision)

	var ball_mesh := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.34
	sphere_mesh.height = 0.68
	ball_mesh.mesh = sphere_mesh
	var ball_mat := StandardMaterial3D.new()
	ball_mat.albedo_texture = _create_football_texture()
	ball_mat.roughness = 0.35
	ball_mesh.material_override = ball_mat
	ball.add_child(ball_mesh)

	player.ball = ball
	player.has_ball = true
	ball.set_meta("owner", player.name)
	ball.freeze = true
	ball.global_position = player.global_position + player.facing * 1.05 + Vector3.UP * 0.38
	home_team = [player]
	player.teammates = home_team

func _build_teammates() -> void:
	var hair_colors := [Color(0.72, 0.58, 0.25), Color(0.08, 0.08, 0.08), Color(0.3, 0.2, 0.1), Color(0.12, 0.12, 0.12)]
	for index in range(OUTFIELD_PLAYER_COUNT - 1):
		var teammate := PlayerScript.new() as FootballPlayer
		var team_index := index + 1
		var formation_index := HOME_TEAM_FORMATION_INDICES[team_index]
		teammate.name = "Teammate%d" % team_index
		teammate.is_user_controlled = false
		teammate.formation_offset = HOME_FORMATION[formation_index]
		teammate.collision_layer = 2
		teammate.collision_mask = 1
		teammate.position = HOME_FORMATION[formation_index]
		teammate.ball = ball
		add_child(teammate)

		var body_collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.48
		capsule.height = 1.8
		body_collision.shape = capsule
		body_collision.position.y = 0.9
		teammate.add_child(body_collision)
		_add_footballer_visual(teammate, Color(0.12, 0.45, 0.88), HOME_SQUAD_NUMBERS[formation_index], hair_colors[index % hair_colors.size()])
		home_team.append(teammate)

	for teammate in home_team:
		teammate.teammates = home_team

func _build_bench() -> void:
	var reserve_colors := [Color(0.65, 0.78, 0.9), Color(0.9, 0.72, 0.35), Color(0.55, 0.72, 0.62), Color(0.78, 0.62, 0.52), Color(0.7, 0.68, 0.9)]
	for index in range(MAX_SUBSTITUTIONS):
		var reserve := PlayerScript.new() as FootballPlayer
		reserve.name = "Reserve%d" % (index + 1)
		reserve.is_user_controlled = false
		reserve.collision_layer = 0
		reserve.collision_mask = 0
		reserve.position = Vector3(40.0 + float(index) * 2.0, 0.1, 40.0)
		reserve.ball = ball
		add_child(reserve)
		var body_collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.48
		capsule.height = 1.8
		body_collision.shape = capsule
		body_collision.position.y = 0.9
		reserve.add_child(body_collision)
		_add_footballer_visual(reserve, reserve_colors[index], 12 + index, Color(0.12, 0.12, 0.12))
		reserve.set_physics_process(false)
		reserve.set_process(false)
		bench.append(reserve)

func _build_opponent() -> void:
	opponent = OpponentScript.new()
	opponent.name = "Opponent"
	opponent.role = "striker"
	opponent.collision_layer = 4
	opponent.collision_mask = 1
	opponent.position = Vector3(0, 0.1, -9.0)
	opponent.ball = ball
	opponent.player = player
	add_child(opponent)

	var body_collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 1.8
	body_collision.shape = capsule
	body_collision.position.y = 0.9
	opponent.add_child(body_collision)

	_add_footballer_visual(opponent, Color(0.86, 0.19, 0.16), 11, Color(0.18, 0.12, 0.08))
	opponent.ball_kicked.connect(func(power_ratio: float) -> void:
		if is_instance_valid(sound_manager):
			sound_manager.play_kick(power_ratio)
		if is_instance_valid(hud) and power_ratio > 0.45:
			hud.record_shot(false)
	)

	# Opponent Midfielder (#8)
	var away_mid := OpponentScript.new() as FootballOpponent
	away_mid.name = "OpponentMidfielder"
	away_mid.role = "midfielder"
	away_mid.collision_layer = 4
	away_mid.collision_mask = 1
	away_mid.position = Vector3(5.0, 0.1, -13.0)
	away_mid.ball = ball
	away_mid.player = player
	add_child(away_mid)

	var mid_col := CollisionShape3D.new()
	var mid_cap := CapsuleShape3D.new()
	mid_cap.radius = 0.48
	mid_cap.height = 1.8
	mid_col.shape = mid_cap
	mid_col.position.y = 0.9
	away_mid.add_child(mid_col)
	_add_footballer_visual(away_mid, Color(0.86, 0.19, 0.16), 8, Color(0.3, 0.2, 0.1))
	away_mid.ball_kicked.connect(func(power_ratio: float) -> void:
		if is_instance_valid(sound_manager):
			sound_manager.play_kick(power_ratio)
		if is_instance_valid(hud) and power_ratio > 0.45:
			hud.record_shot(false)
	)

	# Opponent Defender (#4)
	var away_def := OpponentScript.new() as FootballOpponent
	away_def.name = "OpponentDefender"
	away_def.role = "defender"
	away_def.collision_layer = 4
	away_def.collision_mask = 1
	away_def.position = Vector3(-5.0, 0.1, -17.0)
	away_def.ball = ball
	away_def.player = player
	add_child(away_def)

	var def_col := CollisionShape3D.new()
	var def_cap := CapsuleShape3D.new()
	def_cap.radius = 0.48
	def_cap.height = 1.8
	def_col.shape = def_cap
	def_col.position.y = 0.9
	away_def.add_child(def_col)
	_add_footballer_visual(away_def, Color(0.86, 0.19, 0.16), 4, Color(0.08, 0.08, 0.08))
	away_def.ball_kicked.connect(func(power_ratio: float) -> void:
		if is_instance_valid(sound_manager):
			sound_manager.play_kick(power_ratio)
		if is_instance_valid(hud) and power_ratio > 0.45:
			hud.record_shot(false)
	)

	away_team = [opponent, away_mid, away_def]
	for index in range(3, OUTFIELD_PLAYER_COUNT):
		var away_player := OpponentScript.new() as FootballOpponent
		away_player.name = "OpponentPlayer%d" % (index + 1)
		away_player.role = "midfielder" if index < 7 else "striker"
		away_player.collision_layer = 4
		away_player.collision_mask = 1
		away_player.position = Vector3(HOME_FORMATION[index].x, 0.1, -HOME_FORMATION[index].z)
		away_player.ball = ball
		away_player.player = player
		add_child(away_player)
		var player_collision := CollisionShape3D.new()
		var player_capsule := CapsuleShape3D.new()
		player_capsule.radius = 0.48
		player_capsule.height = 1.8
		player_collision.shape = player_capsule
		player_collision.position.y = 0.9
		away_player.add_child(player_collision)
		_add_footballer_visual(away_player, Color(0.86, 0.19, 0.16), AWAY_SQUAD_NUMBERS[index], Color(0.18, 0.12, 0.08))
		away_player.ball_kicked.connect(func(power_ratio: float) -> void:
			if is_instance_valid(sound_manager):
				sound_manager.play_kick(power_ratio)
			if is_instance_valid(hud) and power_ratio > 0.45:
				hud.record_shot(false)
		)
		away_team.append(away_player)
	for index in range(away_team.size()):
		var away_player := away_team[index]
		var formation_index := AWAY_TEAM_FORMATION_INDICES[index]
		away_player.position = Vector3(HOME_FORMATION[formation_index].x, 0.1, -HOME_FORMATION[formation_index].z)
		away_player.role = "defender" if formation_index < 4 else ("midfielder" if formation_index < 7 else "striker")
	for opp in away_team:
		opp.teammates = away_team
		opp.home_players = home_team
		opp.foul_committed.connect(_on_opponent_foul)

	for tm in home_team:
		tm.all_opponents = away_team

func _build_goalkeepers() -> void:
	away_goalkeeper = GoalkeeperScript.new()
	away_goalkeeper.name = "AwayGoalkeeper"
	away_goalkeeper.team = "away"
	away_goalkeeper.goal_z = GOAL_Z
	away_goalkeeper.facing_z = 1.0
	away_goalkeeper.position = Vector3(0.0, 0.1, -24.4)
	away_goalkeeper.collision_layer = 4
	away_goalkeeper.collision_mask = 1
	away_goalkeeper.ball = ball
	add_child(away_goalkeeper)

	var away_col := CollisionShape3D.new()
	var away_cap := CapsuleShape3D.new()
	away_cap.radius = 0.48
	away_cap.height = 1.8
	away_col.shape = away_cap
	away_col.position.y = 0.9
	away_goalkeeper.add_child(away_col)
	_add_goalkeeper_visual(away_goalkeeper, Color(0.96, 0.88, 0.15))
	away_goalkeeper.shot_saved.connect(func(_t: String) -> void:
		if is_instance_valid(hud):
			hud.announce("GREAT SAVE BY AWAY GK!")
		if is_instance_valid(sound_manager):
			sound_manager.play_save()
	)

	home_goalkeeper = GoalkeeperScript.new()
	home_goalkeeper.name = "HomeGoalkeeper"
	home_goalkeeper.team = "home"
	home_goalkeeper.goal_z = -GOAL_Z
	home_goalkeeper.facing_z = -1.0
	home_goalkeeper.position = Vector3(0.0, 0.1, 24.4)
	home_goalkeeper.collision_layer = 2
	home_goalkeeper.collision_mask = 1
	home_goalkeeper.ball = ball
	add_child(home_goalkeeper)

	var home_col := CollisionShape3D.new()
	var home_cap := CapsuleShape3D.new()
	home_cap.radius = 0.48
	home_cap.height = 1.8
	home_col.shape = home_cap
	home_col.position.y = 0.9
	home_goalkeeper.add_child(home_col)
	_add_goalkeeper_visual(home_goalkeeper, Color(0.18, 0.76, 0.38))
	home_goalkeeper.shot_saved.connect(func(_t: String) -> void:
		if is_instance_valid(hud):
			hud.announce("GREAT SAVE BY HOME GK!")
		if is_instance_valid(sound_manager):
			sound_manager.play_save()
	)

func _build_camera() -> void:
	follow_camera = CameraScript.new() as FollowCamera
	follow_camera.name = "FollowCamera"
	follow_camera.target = player
	follow_camera.ball = ball
	follow_camera.position = Vector3(0, 7.5, 19)
	add_child(follow_camera)
	follow_camera.current = true

func _cycle_camera_view() -> void:
	if not is_instance_valid(follow_camera):
		return
	follow_camera.set_view_mode(follow_camera.view_mode + 1)
	if is_instance_valid(hud):
		hud.set_camera_view_name(follow_camera.get_view_name())

func _update_controlled_player() -> void:
	if not is_instance_valid(ball) or home_team.is_empty():
		return
	var owner_name := str(ball.get_meta("owner", ""))
	for teammate in home_team:
		if teammate.name == owner_name:
			if player != teammate:
				_disconnect_player_signals(player)
				player.is_user_controlled = false
				player = teammate
				player.is_user_controlled = true
				player.virtual_movement_direction = active_touch_direction
				_connect_player_signals(player)
				follow_camera.target = player
				opponent.player = player
			break

func _switch_to_closest_defender() -> void:
	if not is_instance_valid(ball) or home_team.size() < 2:
		return

	var next_player: FootballPlayer
	var closest_distance := INF
	for teammate in home_team:
		if teammate == player or not is_instance_valid(teammate):
			continue
		var distance := teammate.global_position.distance_squared_to(ball.global_position)
		if distance < closest_distance:
			closest_distance = distance
			next_player = teammate

	if not is_instance_valid(next_player):
		return

	_switch_to_player(next_player)

func _switch_to_player(next_player: FootballPlayer) -> void:
	if not is_instance_valid(next_player) or next_player == player:
		return
	_disconnect_player_signals(player)
	player.is_user_controlled = false
	player = next_player
	player.is_user_controlled = true
	_connect_player_signals(player)
	follow_camera.target = player
	for opp in away_team:
		if is_instance_valid(opp):
			opp.player = player

func _start_second_half() -> void:
	if not is_instance_valid(hud):
		return
	get_tree().paused = false
	hud.match_end_modal.visible = false
	hud.match_period = 3
	hud.elapsed = hud.half_duration
	hud.running = true
	next_kickoff_team = "away"
	_reset_play(Vector3(0.0, 0.45, 0.0), next_kickoff_team)

func _restart_match() -> void:
	get_tree().paused = false
	if is_instance_valid(hud):
		hud.reset_match()
	home_score = 0
	away_score = 0
	substitutions_made = 0
	next_kickoff_team = "home"
	restart_offside_exempt = false
	_apply_competition_variant()
	_reset_play()

func _reset_play(restart_position: Vector3 = Vector3(0.0, 0.45, 8.3), restart_owner: String = "home") -> void:
	reset_lock = 1.1
	set_piece_mode = false
	penalty_mode = false
	if is_instance_valid(player):
		player.set_piece_aiming = false
	hud.set_set_piece_mode(false)
	_set_wall_visible(false)
	if is_instance_valid(hud):
		hud.update_shot_power(0.0, false)
	if is_instance_valid(sound_manager):
		sound_manager.play_whistle(true)
	if is_instance_valid(player):
		_disconnect_player_signals(player)
	for index in range(home_team.size()):
		var teammate := home_team[index]
		teammate.has_ball = false
		teammate.velocity = Vector3.ZERO
		teammate.velocity.y = 0.0
		teammate.is_sliding = false
		teammate.slide_timer = 0.0
		teammate.slide_cooldown = 0.0
		teammate.stamina = teammate.max_stamina
		teammate.virtual_movement_direction = Vector2.ZERO
		teammate._cancel_shot()
		teammate.is_user_controlled = teammate == home_team[0]
		var formation_index := HOME_TEAM_FORMATION_INDICES[index]
		teammate.formation_offset = HOME_FORMATION[formation_index]
		teammate.position = HOME_FORMATION[formation_index]
		if restart_position == Vector3(0.0, 0.45, 0.0) and teammate != player:
			teammate.position = Vector3(HOME_FORMATION[formation_index].x * 0.4, 0.1, 6.0 + absf(HOME_FORMATION[formation_index].z) * 0.45)
		teammate.facing = Vector3(0, 0, -1)
	player = home_team[0]
	_connect_player_signals(player)
	follow_camera.target = player
	for opp in away_team:
		opp.has_ball = false
		opp.velocity = Vector3.ZERO
		opp.is_sliding = false
		opp.slide_timer = 0.0
		opp.slide_cooldown = 0.0
		opp.kick_cooldown = 0.0
		opp.pass_cooldown = 0.0
		var away_index := away_team.find(opp)
		var formation_index: int = AWAY_TEAM_FORMATION_INDICES[away_index]
		opp.position = Vector3(HOME_FORMATION[formation_index].x, 0.1, -HOME_FORMATION[formation_index].z)
		if restart_position == Vector3(0.0, 0.45, 0.0):
			opp.position = Vector3(HOME_FORMATION[formation_index].x * 0.4, 0.1, -6.0 - absf(HOME_FORMATION[formation_index].z) * 0.45)
		opp.role = "defender" if formation_index < 4 else ("midfielder" if formation_index < 7 else "striker")
		opp.facing = Vector3(0, 0, 1)
		opp.player = player
	if is_instance_valid(home_goalkeeper):
		home_goalkeeper.reset_position()
	if is_instance_valid(away_goalkeeper):
		away_goalkeeper.reset_position()
	ball.freeze = true
	ball.remove_meta("owner")
	ball.global_position = restart_position
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	if restart_position == Vector3(0.0, 0.45, 0.0):
		player.position = Vector3(0.0, 0.1, 1.0) if restart_owner == "home" else Vector3(0.0, 0.1, 7.0)
		player.facing = Vector3(0.0, 0.0, -1.0)
		player.has_ball = restart_owner == "home"
		var kickoff_owner: String = "opponent"
		if restart_owner == "home":
			kickoff_owner = str(player.name)
		ball.set_meta("owner", kickoff_owner)
		if restart_owner == "away":
			opponent.position = Vector3(0.0, 0.1, -1.0)
			opponent.facing = Vector3(0.0, 0.0, 1.0)
			opponent.has_ball = true
		ball.freeze = true
		ball.global_position = Vector3(0.0, 0.45, 0.0)
	else:
		if restart_owner == "home":
			player.position = Vector3(restart_position.x, 0.1, restart_position.z + (1.0 if restart_position.z < 0.0 else -1.0))
			player.facing = Vector3(0.0, 0.0, -1.0)
			player.has_ball = true
			ball.set_meta("owner", player.name)
		else:
			opponent.position = Vector3(restart_position.x, 0.1, restart_position.z + (1.0 if restart_position.z < 0.0 else -1.0))
			opponent.facing = Vector3(0.0, 0.0, 1.0)
			opponent.has_ball = true
			ball.set_meta("owner", "opponent")
		ball.freeze = true
		ball.global_position = restart_position
		set_piece_mode = restart_owner == "home"
		penalty_mode = set_piece_mode and next_restart_type == "penalty"
		player.set_piece_aiming = set_piece_mode
		set_piece_aim = Vector3(0.0, 0.0, -1.0)
		if set_piece_mode:
			player.facing = set_piece_aim
			hud.set_set_piece_mode(true, penalty_mode, next_restart_type)
			_set_wall_visible(next_restart_type == "free_kick" or next_restart_type == "corner")
			for index in range(set_piece_wall.size()):
				if next_restart_type == "corner":
					set_piece_wall[index].position = Vector3(clampf(restart_position.x * 0.42 + (float(index) - 1.0) * 2.5, -9.0, 9.0), 0.9, restart_position.z + 5.0)
					var target_material := set_piece_wall[index].material_override as StandardMaterial3D
					target_material.albedo_color = Color(0.15, 0.85, 0.95)
				else:
					set_piece_wall[index].position = Vector3((float(index) - 1.0) * 0.95, 0.9, restart_position.z - 4.0)
					var wall_material := set_piece_wall[index].material_override as StandardMaterial3D
					wall_material.albedo_color = Color(0.82, 0.18, 0.12)
		else:
			hud.set_set_piece_mode(false)
			_set_wall_visible(false)
			restart_offside_exempt = next_restart_type in ["throw_in", "goal_kick", "corner"]

func _add_box(label: String, size: Vector3, location: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = location
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return mesh_instance

func _add_footballer_visual(character: CharacterBody3D, shirt_color: Color, number: int = 10, hair_color: Color = Color(0.12, 0.09, 0.07)) -> void:
	var body_scale := 0.96 + float(posmod(number * 13, 9)) * 0.01
	var shoulder_width := 0.95 + float(posmod(number * 5, 5)) * 0.025
	character.scale = Vector3(shoulder_width, body_scale, 1.0)
	var skin_tones: Array[Color] = [
		Color(0.91, 0.68, 0.51), Color(0.72, 0.46, 0.31),
		Color(0.48, 0.29, 0.19), Color(0.82, 0.57, 0.40),
		Color(0.60, 0.38, 0.27), Color(0.94, 0.75, 0.60)
	]
	var skin := _material(skin_tones[posmod(number * 7, skin_tones.size())], 0.62)
	var shirt := _material(shirt_color, 0.72)
	var shirt_trim := _material(shirt_color.lightened(0.24), 0.58)
	var shorts := _material(Color(0.035, 0.055, 0.075), 0.78)
	var sock := _material(Color(0.91, 0.93, 0.88), 0.76)
	var sock_trim := _material(shirt_color, 0.62)
	var hair_mat := _material(hair_color, 0.92)
	var boot_mat := _material(Color(0.055, 0.065, 0.075), 0.32)
	var boot_trim := _material(Color(0.92, 0.72, 0.22), 0.38)
	var number_mat := _material(Color(0.97, 0.96, 0.88), 0.52)
	var eye_white := _material(Color(0.96, 0.92, 0.84), 0.48)
	var eye_dark := _material(Color(0.12, 0.075, 0.052), 0.38)

	_add_capsule_part(character, "Torso", 0.34, 0.92, Vector3(0, 1.25, 0), shirt)
	_add_box_part(character, "JerseySideLeft", Vector3(0.055, 0.58, 0.3), Vector3(-0.31, 1.27, -0.005), shirt_trim)
	_add_box_part(character, "JerseySideRight", Vector3(0.055, 0.58, 0.3), Vector3(0.31, 1.27, -0.005), shirt_trim)
	_add_box_part(character, "JerseyHem", Vector3(0.48, 0.045, 0.34), Vector3(0, 0.82, 0), shirt_trim)
	_add_cylinder_part(character, "Neck", 0.105, 0.18, Vector3(0, 1.78, 0), skin)
	_add_box_part(character, "NumberPlate", Vector3(0.3, 0.38, 0.035), Vector3(0, 1.35, 0.185), number_mat)
	_add_box_part(character, "ChestBadge", Vector3(0.12, 0.15, 0.035), Vector3(0.19, 1.49, -0.19), boot_trim)
	_add_box_part(character, "CollarBand", Vector3(0.24, 0.065, 0.24), Vector3(0, 1.71, 0), shirt_trim)

	var head := _add_sphere_part(character, "Head", 0.22, Vector3(0, 1.91, 0), skin)
	head.scale = Vector3(0.92, 1.12, 0.92)
	var hair := _add_sphere_part(character, "Hair", 0.225, Vector3(0, 2.015, 0.005), hair_mat)
	hair.scale = Vector3(1.0, 0.78, 0.98)
	_add_sphere_part(character, "EarLeft", 0.052, Vector3(-0.215, 1.91, 0), skin)
	_add_sphere_part(character, "EarRight", 0.052, Vector3(0.215, 1.91, 0), skin)
	_add_sphere_part(character, "EyeLeft", 0.027, Vector3(-0.078, 1.96, -0.195), eye_white)
	_add_sphere_part(character, "EyeRight", 0.027, Vector3(0.078, 1.96, -0.195), eye_white)
	_add_sphere_part(character, "PupilLeft", 0.013, Vector3(-0.078, 1.96, -0.218), eye_dark)
	_add_sphere_part(character, "PupilRight", 0.013, Vector3(0.078, 1.96, -0.218), eye_dark)
	_add_box_part(character, "BrowLeft", Vector3(0.075, 0.018, 0.025), Vector3(-0.078, 2.005, -0.196), hair_mat)
	_add_box_part(character, "BrowRight", Vector3(0.075, 0.018, 0.025), Vector3(0.078, 2.005, -0.196), hair_mat)
	_add_sphere_part(character, "Nose", 0.035, Vector3(0, 1.91, -0.22), skin)
	_add_box_part(character, "Mouth", Vector3(0.075, 0.014, 0.012), Vector3(0, 1.855, -0.212), eye_dark)
	_add_sphere_part(character, "EyeGlintLeft", 0.007, Vector3(-0.084, 1.969, -0.23), eye_white)
	_add_sphere_part(character, "EyeGlintRight", 0.007, Vector3(0.072, 1.969, -0.23), eye_white)

	match number % 3:
		0:
			_add_sphere_part(character, "HairTop", 0.13, Vector3(0, 2.12, -0.005), hair_mat)
		1:
			_add_sphere_part(character, "HairSweep", 0.15, Vector3(0.06, 2.105, -0.035), hair_mat)
			_add_sphere_part(character, "HairBack", 0.16, Vector3(0, 1.95, 0.105), hair_mat)
		2:
			_add_sphere_part(character, "HairBack", 0.16, Vector3(0, 1.95, 0.105), hair_mat)

	_add_box_part(character, "Shorts", Vector3(0.66, 0.35, 0.4), Vector3(0, 0.77, 0), shorts)
	_add_box_part(character, "ShortsStripeLeft", Vector3(0.035, 0.23, 0.42), Vector3(-0.3, 0.77, 0), shirt_trim)
	_add_box_part(character, "ShortsStripeRight", Vector3(0.035, 0.23, 0.42), Vector3(0.3, 0.77, 0), shirt_trim)
	var left_leg := _add_limb_part(character, "LeftLeg", 0.14, 0.78, Vector3(-0.2, 0.65, 0), sock)
	var right_leg := _add_limb_part(character, "RightLeg", 0.14, 0.78, Vector3(0.2, 0.65, 0), sock)
	for leg in [left_leg, right_leg]:
		_add_box_part(leg, "SockBand", Vector3(0.23, 0.06, 0.23), Vector3(0, -0.21, -0.005), sock_trim)
		_add_box_part(leg, "Boot", Vector3(0.19, 0.13, 0.38), Vector3(0, -0.59, -0.075), boot_mat)
		_add_box_part(leg, "BootStripe", Vector3(0.035, 0.09, 0.23), Vector3(0, -0.565, -0.12), boot_trim)
		for stud_z in [-0.19, -0.07, 0.05]:
			_add_cylinder_part(leg, "BootStud", 0.026, 0.035, Vector3(0, -0.65, stud_z), boot_trim)

	var left_arm := _add_limb_part(character, "LeftArm", 0.12, 0.72, Vector3(-0.43, 1.51, 0), shirt)
	left_arm.rotation.z = -0.18
	var right_arm := _add_limb_part(character, "RightArm", 0.12, 0.72, Vector3(0.43, 1.51, 0), shirt)
	right_arm.rotation.z = 0.18
	_add_sphere_part(left_arm, "Hand", 0.095, Vector3(0, -0.5, 0), skin)
	_add_sphere_part(right_arm, "Hand", 0.095, Vector3(0, -0.5, 0), skin)
	_add_cylinder_part(left_arm, "SleeveBand", 0.125, 0.07, Vector3(0, 0.02, 0), shirt_trim)
	_add_cylinder_part(right_arm, "SleeveBand", 0.125, 0.07, Vector3(0, 0.02, 0), shirt_trim)

	# Captain Armband (for #10)
	if number == 10:
		var armband_mat := _material(Color(0.98, 0.85, 0.15), 0.3)
		_add_box_part(left_arm, "Armband", Vector3(0.14, 0.12, 0.14), Vector3(0, -0.16, 0), armband_mat)

func _add_goalkeeper_visual(character: CharacterBody3D, shirt_color: Color) -> void:
	_add_footballer_visual(character, shirt_color, 1, Color(0.1, 0.1, 0.1))
	var glove_mat := _material(Color(0.98, 0.98, 0.98), 0.35)
	var glove_trim := _material(Color(0.12, 0.18, 0.14), 0.5)
	var left_arm := character.get_node("LeftArm") as Node3D
	var right_arm := character.get_node("RightArm") as Node3D
	_add_box_part(left_arm, "LeftGlove", Vector3(0.2, 0.2, 0.2), Vector3(0, -0.5, 0), glove_mat)
	_add_box_part(right_arm, "RightGlove", Vector3(0.2, 0.2, 0.2), Vector3(0, -0.5, 0), glove_mat)
	_add_box_part(left_arm, "LeftGloveCuff", Vector3(0.19, 0.09, 0.18), Vector3(0, -0.37, 0), glove_trim)
	_add_box_part(right_arm, "RightGloveCuff", Vector3(0.19, 0.09, 0.18), Vector3(0, -0.37, 0), glove_trim)

func _add_capsule_part(parent: Node3D, label: String, radius: float, height: float, location: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	capsule.radial_segments = 24
	capsule.rings = 12
	mesh_instance.mesh = capsule
	mesh_instance.position = location
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_limb_part(parent: Node3D, label: String, radius: float, height: float, location: Vector3, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = location
	parent.add_child(pivot)
	_add_capsule_part(pivot, "LimbMesh", radius, height, Vector3(0, -height * 0.36, 0), material)
	return pivot

func _add_cylinder_part(parent: Node3D, label: String, radius: float, height: float, location: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	mesh_instance.mesh = cylinder
	mesh_instance.position = location
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_sphere_part(parent: Node3D, label: String, radius: float, location: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	mesh_instance.mesh = sphere
	mesh_instance.position = location
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_box_part(parent: Node3D, label: String, size: Vector3, location: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = location
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_cylinder(label: String, radius: float, height: float, location: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	mesh_instance.mesh = cylinder
	mesh_instance.position = location
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return mesh_instance

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return material

func _physics_material() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = 0.58
	material.bounce = 0.48
	return material
