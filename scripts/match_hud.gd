extends CanvasLayer
class_name MatchHud

const VirtualTouchScript = preload("res://scripts/virtual_touch_controls.gd")
const RadarScript = preload("res://scripts/radar_minimap.gd")
const REMAP_ACTIONS := [
	"move_forward", "move_back", "move_left", "move_right", "pass_ball",
	"shoot_ball", "through_ball", "sprint", "slide_tackle", "standing_tackle",
	"switch_player", "keeper_distribute", "camera_view", "pause_game"
]
const REMAP_LABELS := [
	"Move Up", "Move Down", "Move Left", "Move Right", "Pass", "Shoot",
	"Through Ball", "Sprint", "Slide Tackle", "Standing Tackle",
	"Switch Player", "Keeper", "Camera", "Pause"
]

signal restart_match_requested()
signal half_time_continued()
signal camera_view_requested()
signal training_mode_requested(enabled: bool)
signal match_settings_changed(half_length: float, difficulty: float, home_color: int, away_color: int)
signal audio_settings_changed(music_volume: float, effects_volume: float)
signal tactical_preset_changed(preset_index: int)
signal opponent_style_changed(style_index: int)
signal substitution_requested(player_index: int, reserve_index: int)
signal local_multiplayer_changed(enabled: bool)
signal training_challenge_requested(challenge: String)
signal accessibility_changed(game_speed: float, ui_scale: float, high_contrast: bool)
signal weather_changed(weather_index: int)
signal replay_command_requested(command: String)
signal career_upgrade_requested(attribute: String)
signal lineup_requested()
signal competition_table_requested()

var score_label: Label
var clock_label: Label
var period_label: Label
var status_label: Label
var possession_label: Label
var training_label: Label
var power_bar_panel: Panel
var power_fill: ColorRect
var power_label: Label
var stamina_panel: Panel
var stamina_fill: ColorRect

var touch_controls: VirtualTouchControls
var radar: RadarMinimap

var pause_button: Button
var touch_toggle_button: Button
var camera_view_button: Button
var pause_modal: Control
var goal_overlay: Control
var goal_label: Label
var match_end_modal: Control

var elapsed: float = 0.0
var running: bool = true
var match_period: int = 1 # 1: 1st Half, 2: Half-Time, 3: 2nd Half, 4: Full-Time
var half_duration: float = 90.0 # 90 real seconds = 45 in-game minutes

var home_score: int = 0
var away_score: int = 0
var home_possession_time: float = 0.0
var away_possession_time: float = 0.0
var home_shots: int = 0
var away_shots: int = 0
var home_tackles: int = 0
var away_tackles: int = 0

var touch_controls_enabled: bool = true
var sound_muted: bool = false
var training_mode: bool = false
var half_length_option: OptionButton
var difficulty_option: OptionButton
var home_color_option: OptionButton
var away_color_option: OptionButton
var music_volume_slider: HSlider
var effects_volume_slider: HSlider
var tactical_preset_option: OptionButton
var remap_action_option: OptionButton
var remap_key_button: Button
var waiting_for_key: bool = false
var suppress_pause_press: bool = false
var profile_store: Node
var interface_theme: Theme
var was_running_before_replay: bool = false
var opponent_style_option: OptionButton
var substitute_player_option: OptionButton
var substitute_reserve_option: OptionButton
var training_challenge_option: OptionButton
var weather_option: OptionButton
var high_contrast_toggle: CheckButton
var game_speed_slider: HSlider
var ui_scale_slider: HSlider
var replay_controls: Control
var challenge_label: Label
var set_piece_label: Label
var competition_label: Label
var lineup_modal: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	profile_store = get_node_or_null("/root/ProfileStore")
	_build_theme()
	_build_scoreboard()
	_build_stamina_bar()
	_build_power_bar()
	_build_status_labels()
	_build_radar()
	_build_touch_controls()
	_build_top_buttons()
	_build_goal_overlay()
	_build_pause_modal()
	_build_lineup_modal()
	_build_match_end_modal()
	_apply_theme_recursive(self)
	set_accessibility(profile_store.game_speed, profile_store.ui_scale, profile_store.high_contrast)

func _apply_theme_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).theme = interface_theme
		_apply_theme_recursive(child)

func _surface_style(background: Color, border: Color, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 4.0)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style

func _build_theme() -> void:
	var hud_theme := Theme.new()
	var button_style := _surface_style(Color(0.032, 0.11, 0.08, 0.98), Color(0.85, 0.68, 0.25, 0.9), 8)
	button_style.shadow_size = 2
	button_style.shadow_offset = Vector2.ZERO
	button_style.content_margin_left = 12.0
	button_style.content_margin_right = 12.0
	button_style.content_margin_top = 7.0
	button_style.content_margin_bottom = 7.0
	var button_hover := button_style.duplicate() as StyleBoxFlat
	button_hover.bg_color = Color(0.09, 0.23, 0.15, 1.0)
	button_hover.border_color = Color(0.99, 0.79, 0.24)
	var button_pressed := button_style.duplicate() as StyleBoxFlat
	button_pressed.bg_color = Color(0.17, 0.31, 0.21, 1.0)
	var field_style := _surface_style(Color(0.02, 0.08, 0.06, 0.98), Color(0.29, 0.52, 0.38, 0.72), 7)
	var slider_track := StyleBoxFlat.new()
	slider_track.bg_color = Color(0.12, 0.19, 0.15, 0.96)
	slider_track.set_corner_radius_all(4)
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = Color(0.86, 0.68, 0.26, 1.0)
	slider_fill.set_corner_radius_all(4)
	hud_theme.set_stylebox("normal", "Button", button_style)
	hud_theme.set_stylebox("hover", "Button", button_hover)
	hud_theme.set_stylebox("pressed", "Button", button_pressed)
	hud_theme.set_stylebox("focus", "Button", button_hover)
	hud_theme.set_color("font_color", "Button", Color(0.97, 0.99, 0.93))
	hud_theme.set_color("font_hover_color", "Button", Color(1.0, 0.88, 0.46))
	hud_theme.set_font_size("font_size", "Button", 14)
	for control_type in ["OptionButton", "LineEdit", "SpinBox"]:
		for state in ["normal", "hover", "focus"]:
			hud_theme.set_stylebox(state, control_type, field_style)
	hud_theme.set_stylebox("slider", "HSlider", slider_track)
	hud_theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	hud_theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	hud_theme.set_color("font_color", "Label", Color(0.89, 0.93, 0.86))
	hud_theme.set_color("font_color", "OptionButton", Color(0.97, 0.99, 0.93))
	interface_theme = hud_theme

func _build_scoreboard() -> void:
	var score_panel := Panel.new()
	score_panel.name = "ScorePanel"
	score_panel.add_theme_stylebox_override("panel", _surface_style(Color(0.015, 0.055, 0.04, 0.96), Color(0.82, 0.66, 0.27, 0.92), 12))
	score_panel.anchor_left = 0.5
	score_panel.anchor_right = 0.5
	score_panel.offset_left = -210
	score_panel.offset_right = 210
	score_panel.offset_top = 14
	score_panel.offset_bottom = 112
	add_child(score_panel)
	var stripe := ColorRect.new()
	stripe.color = Color(0.86, 0.68, 0.25, 0.96)
	stripe.size = Vector2(420, 3)
	stripe.position = Vector2.ZERO
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_panel.add_child(stripe)

	score_label = Label.new()
	score_label.text = "ETHAN     0 - 0     VISITORS"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 23)
	score_label.anchor_right = 1.0
	score_label.offset_top = 10
	score_label.offset_bottom = 44
	score_panel.add_child(score_label)

	clock_label = Label.new()
	clock_label.text = "FIRST HALF   00:00"
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.add_theme_font_size_override("font_size", 15)
	clock_label.anchor_right = 1.0
	clock_label.offset_top = 46
	clock_label.offset_bottom = 72
	clock_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.88))
	score_panel.add_child(clock_label)

	var arcade_tag := Label.new()
	arcade_tag.text = "ETHAN CUP  /  EXHIBITION"
	arcade_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arcade_tag.add_theme_font_size_override("font_size", 10)
	arcade_tag.anchor_right = 1.0
	arcade_tag.offset_top = 74
	arcade_tag.offset_bottom = 88
	arcade_tag.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	score_panel.add_child(arcade_tag)
	competition_label = arcade_tag

	var controls := Label.new()
	controls.name = "DesktopControlsHint"
	controls.text = "Arrows: Move  |  F: Sprint  |  J: Pass  |  I: Thru  |  Hold K: Shoot  |  L: Slide  |  Space: Switch  |  C: Camera"
	controls.add_theme_font_size_override("font_size", 13)
	controls.position = Vector2(24, -36)
	controls.anchor_top = 1.0
	controls.anchor_bottom = 1.0
	controls.add_theme_color_override("font_color", Color(0.85, 0.92, 0.88, 0.85))
	add_child(controls)

func _build_stamina_bar() -> void:
	stamina_panel = Panel.new()
	stamina_panel.position = Vector2(24, -66)
	stamina_panel.size = Vector2(188, 24)
	stamina_panel.anchor_top = 1.0
	stamina_panel.anchor_bottom = 1.0
	stamina_panel.add_theme_stylebox_override("panel", _surface_style(Color(0.015, 0.055, 0.04, 0.92), Color(0.78, 0.61, 0.22, 0.78), 5))
	add_child(stamina_panel)

	stamina_fill = ColorRect.new()
	stamina_fill.color = Color(0.2, 0.85, 0.95)
	stamina_fill.position = Vector2(3, 3)
	stamina_fill.size = Vector2(182, 18)
	stamina_panel.add_child(stamina_fill)

	var stam_lbl := Label.new()
	stam_lbl.text = "STAMINA"
	stam_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stam_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stam_lbl.add_theme_font_size_override("font_size", 10)
	stam_lbl.anchor_right = 1.0
	stam_lbl.anchor_bottom = 1.0
	stam_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	stamina_panel.add_child(stam_lbl)

func _build_power_bar() -> void:
	power_bar_panel = Panel.new()
	power_bar_panel.anchor_left = 0.5
	power_bar_panel.anchor_right = 0.5
	power_bar_panel.anchor_top = 1.0
	power_bar_panel.anchor_bottom = 1.0
	power_bar_panel.offset_left = -140
	power_bar_panel.offset_right = 140
	power_bar_panel.offset_top = -148
	power_bar_panel.offset_bottom = -120
	power_bar_panel.add_theme_stylebox_override("panel", _surface_style(Color(0.03, 0.06, 0.04, 0.94), Color(0.78, 0.61, 0.22, 0.85), 8))
	power_bar_panel.visible = false
	add_child(power_bar_panel)

	power_fill = ColorRect.new()
	power_fill.color = Color(0.2, 0.9, 0.3)
	power_fill.position = Vector2(3, 3)
	power_fill.size = Vector2(0, 22)
	power_bar_panel.add_child(power_fill)

	power_label = Label.new()
	power_label.text = "SHOT POWER"
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	power_label.add_theme_font_size_override("font_size", 13)
	power_label.anchor_right = 1.0
	power_label.anchor_bottom = 1.0
	power_label.add_theme_color_override("font_color", Color(0.96, 0.98, 0.96))
	power_bar_panel.add_child(power_label)

func _build_status_labels() -> void:
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.anchor_left = 0.5
	status_label.anchor_right = 0.5
	status_label.offset_left = -240
	status_label.offset_right = 240
	status_label.offset_top = 112
	status_label.offset_bottom = 146
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	add_child(status_label)

	possession_label = Label.new()
	possession_label.text = "BALL: YOU"
	possession_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	possession_label.anchor_left = 1.0
	possession_label.anchor_right = 1.0
	possession_label.offset_left = -260
	possession_label.offset_right = -80
	possession_label.offset_top = 22
	possession_label.offset_bottom = 54
	possession_label.add_theme_font_size_override("font_size", 17)
	possession_label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.55))
	add_child(possession_label)
	var possession_backing := ColorRect.new()
	possession_backing.name = "PossessionBacking"
	possession_backing.color = Color(0.015, 0.055, 0.04, 0.78)
	possession_backing.anchor_left = 1.0
	possession_backing.anchor_right = 1.0
	possession_backing.offset_left = -274
	possession_backing.offset_right = -72
	possession_backing.offset_top = 18
	possession_backing.offset_bottom = 60
	possession_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	possession_backing.z_index = -1
	add_child(possession_backing)

	training_label = Label.new()
	training_label.name = "TrainingGoalsLabel"
	training_label.text = "TRAINING GOALS: 0"
	training_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	training_label.anchor_left = 0.5
	training_label.anchor_right = 0.5
	training_label.offset_left = -180
	training_label.offset_right = 180
	training_label.offset_top = 145
	training_label.offset_bottom = 175
	training_label.add_theme_font_size_override("font_size", 18)
	training_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.72))
	training_label.visible = false
	add_child(training_label)

func _build_radar() -> void:
	radar = RadarScript.new()
	radar.name = "RadarMinimap"
	radar.anchor_left = 0.5
	radar.anchor_right = 0.5
	radar.anchor_top = 1.0
	radar.anchor_bottom = 1.0
	radar.offset_left = -85
	radar.offset_right = 85
	radar.offset_top = -118
	radar.offset_bottom = -12
	radar.size = Vector2(170, 106)
	add_child(radar)
	var radar_frame := ColorRect.new()
	radar_frame.name = "RadarFrame"
	radar_frame.color = Color(0.78, 0.61, 0.22, 0.82)
	radar_frame.anchor_left = 0.5
	radar_frame.anchor_right = 0.5
	radar_frame.anchor_top = 1.0
	radar_frame.anchor_bottom = 1.0
	radar_frame.offset_left = -88
	radar_frame.offset_right = 88
	radar_frame.offset_top = -121
	radar_frame.offset_bottom = -9
	radar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_frame.z_index = -1
	add_child(radar_frame)

func _build_touch_controls() -> void:
	touch_controls = VirtualTouchScript.new()
	touch_controls.name = "VirtualTouchControls"
	add_child(touch_controls)

func _build_top_buttons() -> void:
	# Pause button (top right)
	pause_button = Button.new()
	pause_button.text = "⏸"
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.offset_left = -58
	pause_button.offset_right = -16
	pause_button.offset_top = 16
	pause_button.offset_bottom = 58
	pause_button.add_theme_font_size_override("font_size", 20)
	pause_button.pressed.connect(toggle_pause)
	add_child(pause_button)

	# Touch controls toggle button
	touch_toggle_button = Button.new()
	touch_toggle_button.text = "📱"
	touch_toggle_button.anchor_left = 1.0
	touch_toggle_button.anchor_right = 1.0
	touch_toggle_button.offset_left = -58
	touch_toggle_button.offset_right = -16
	touch_toggle_button.offset_top = 66
	touch_toggle_button.offset_bottom = 104
	touch_toggle_button.add_theme_font_size_override("font_size", 16)
	touch_toggle_button.pressed.connect(toggle_touch_controls)
	add_child(touch_toggle_button)

	camera_view_button = Button.new()
	camera_view_button.name = "CameraViewButton"
	camera_view_button.text = "CAM: FOLLOW"
	camera_view_button.tooltip_text = "Change pitch camera view"
	camera_view_button.anchor_left = 1.0
	camera_view_button.anchor_right = 1.0
	camera_view_button.offset_left = -150
	camera_view_button.offset_right = -16
	camera_view_button.offset_top = 112
	camera_view_button.offset_bottom = 152
	camera_view_button.add_theme_font_size_override("font_size", 14)
	camera_view_button.pressed.connect(func() -> void: camera_view_requested.emit())
	add_child(camera_view_button)

func set_camera_view_name(view_name: String) -> void:
	if is_instance_valid(camera_view_button):
		camera_view_button.text = "CAM: " + view_name

func set_competition_title(away_name: String) -> void:
	if is_instance_valid(competition_label):
		competition_label.text = "ETHAN  VS  " + away_name.to_upper()

func _build_goal_overlay() -> void:
	goal_overlay = Control.new()
	goal_overlay.name = "GoalOverlay"
	goal_overlay.anchor_right = 1.0
	goal_overlay.anchor_bottom = 1.0
	goal_overlay.visible = false
	add_child(goal_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.45)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	goal_overlay.add_child(bg)

	var banner := ColorRect.new()
	banner.color = Color(0.88, 0.12, 0.15, 0.92)
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.anchor_top = 0.38
	banner.anchor_bottom = 0.62
	goal_overlay.add_child(banner)

	goal_label = Label.new()
	goal_label.text = "★ G O A L ! ! ! ★"
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	goal_label.anchor_right = 1.0
	goal_label.anchor_bottom = 1.0
	goal_label.add_theme_font_size_override("font_size", 48)
	goal_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.15))
	banner.add_child(goal_label)

func show_goal_banner(team_name: String) -> void:
	if not is_instance_valid(goal_overlay):
		return
	goal_label.text = "★ G O A L ! ! ! ★\n" + team_name.to_upper() + " SCORES!"
	goal_overlay.visible = true
	var timer := get_tree().create_timer(2.2)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(goal_overlay):
			goal_overlay.visible = false
	)

func _build_pause_modal() -> void:
	pause_modal = Control.new()
	pause_modal.name = "PauseModal"
	pause_modal.anchor_right = 1.0
	pause_modal.anchor_bottom = 1.0
	pause_modal.visible = false
	add_child(pause_modal)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.03, 0.78)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	pause_modal.add_child(bg)

	var box := Panel.new()
	box.name = "PausePanel"
	box.add_theme_stylebox_override("panel", _surface_style(Color(0.025, 0.075, 0.055, 0.985), Color(0.78, 0.61, 0.22, 0.85), 18))
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -220
	box.offset_right = 220
	box.offset_top = -340
	box.offset_bottom = 340
	pause_modal.add_child(box)

	var title := Label.new()
	title.text = "MATCH PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.anchor_right = 1.0
	title.offset_top = 16
	title.offset_bottom = 50
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	box.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "RESUME MATCH"
	resume_btn.offset_left = 60
	resume_btn.offset_right = 380
	resume_btn.offset_top = 70
	resume_btn.offset_bottom = 112
	resume_btn.pressed.connect(toggle_pause)
	box.add_child(resume_btn)

	var restart_btn := Button.new()
	restart_btn.text = "RESTART MATCH"
	restart_btn.offset_left = 60
	restart_btn.offset_right = 380
	restart_btn.offset_top = 126
	restart_btn.offset_bottom = 168
	restart_btn.pressed.connect(func() -> void:
		toggle_pause()
		restart_match_requested.emit()
	)
	box.add_child(restart_btn)

	var toggle_touch_btn := Button.new()
	toggle_touch_btn.text = "TOUCH CONTROLS: ON"
	toggle_touch_btn.offset_left = 60
	toggle_touch_btn.offset_right = 380
	toggle_touch_btn.offset_top = 182
	toggle_touch_btn.offset_bottom = 224
	toggle_touch_btn.pressed.connect(func() -> void:
		toggle_touch_controls()
		toggle_touch_btn.text = "TOUCH CONTROLS: " + ("ON" if touch_controls_enabled else "OFF")
	)
	box.add_child(toggle_touch_btn)

	var stats_lbl := Label.new()
	stats_lbl.name = "PauseStatsLabel"
	stats_lbl.text = "POSSESSION: HOME 50% - 50% AWAY"
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.anchor_right = 1.0
	stats_lbl.offset_top = 250
	stats_lbl.offset_bottom = 320
	stats_lbl.add_theme_font_size_override("font_size", 14)
	stats_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 0.88))
	box.add_child(stats_lbl)

	var training_btn := Button.new()
	training_btn.name = "TrainingModeButton"
	training_btn.text = "START TRAINING DRILL"
	training_btn.offset_left = 60
	training_btn.offset_right = 380
	training_btn.offset_top = 330
	training_btn.offset_bottom = 372
	training_btn.pressed.connect(func() -> void:
		training_mode = not training_mode
		training_btn.text = "END TRAINING DRILL" if training_mode else "START TRAINING DRILL"
		training_mode_requested.emit(training_mode)
	)
	box.add_child(training_btn)

	var tournament_btn := Button.new()
	tournament_btn.name = "TournamentButton"
	tournament_btn.text = "START SIX-MATCH LEAGUE"
	tournament_btn.offset_left = 60
	tournament_btn.offset_right = 380
	tournament_btn.offset_top = 374
	tournament_btn.offset_bottom = 412
	tournament_btn.pressed.connect(func() -> void:
		profile_store.start_tournament()
		tournament_btn.text = "LEAGUE: 6 FIXTURES"
		announce("SIX-MATCH LEAGUE STARTED")
		restart_match_requested.emit()
	)
	box.add_child(tournament_btn)

	remap_action_option = OptionButton.new()
	remap_action_option.position = Vector2(24, 454)
	remap_action_option.size = Vector2(150, 32)
	for action_label in REMAP_LABELS:
		remap_action_option.add_item(action_label)
	box.add_child(remap_action_option)
	remap_key_button = Button.new()
	remap_key_button.text = "REMAP KEY"
	remap_key_button.position = Vector2(185, 454)
	remap_key_button.size = Vector2(175, 32)
	remap_key_button.pressed.connect(func() -> void:
		waiting_for_key = true
		remap_key_button.text = "PRESS A KEY..."
	)
	box.add_child(remap_key_button)

	var tactics_label := Label.new()
	tactics_label.text = "TEAM TACTIC"
	tactics_label.position = Vector2(24, 423)
	tactics_label.add_theme_font_size_override("font_size", 13)
	box.add_child(tactics_label)
	tactical_preset_option = OptionButton.new()
	tactical_preset_option.position = Vector2(170, 418)
	tactical_preset_option.size = Vector2(190, 34)
	tactical_preset_option.add_item("Attacking", 0)
	tactical_preset_option.add_item("Balanced", 1)
	tactical_preset_option.add_item("Defensive", 2)
	tactical_preset_option.select(1)
	tactical_preset_option.item_selected.connect(func(index: int) -> void:
		profile_store.tactical_preset = index
		profile_store.save_profile()
		tactical_preset_changed.emit(index)
	)
	box.add_child(tactical_preset_option)

	var length_label := Label.new()
	length_label.text = "HALF LENGTH"
	length_label.position = Vector2(24, 495)
	length_label.add_theme_font_size_override("font_size", 13)
	box.add_child(length_label)

	half_length_option = OptionButton.new()
	half_length_option.position = Vector2(170, 490)
	half_length_option.size = Vector2(190, 34)
	half_length_option.add_item("45 sec", 45)
	half_length_option.add_item("90 sec", 90)
	half_length_option.add_item("150 sec", 150)
	half_length_option.select(1)
	half_length_option.item_selected.connect(_on_match_setting_changed)
	box.add_child(half_length_option)

	var difficulty_label := Label.new()
	difficulty_label.text = "OPPONENT SPEED"
	difficulty_label.position = Vector2(24, 536)
	difficulty_label.add_theme_font_size_override("font_size", 13)
	box.add_child(difficulty_label)

	difficulty_option = OptionButton.new()
	difficulty_option.position = Vector2(170, 531)
	difficulty_option.size = Vector2(190, 34)
	difficulty_option.add_item("Casual", 80)
	difficulty_option.add_item("Standard", 100)
	difficulty_option.add_item("Fast", 120)
	difficulty_option.select(1)
	difficulty_option.item_selected.connect(_on_match_setting_changed)
	box.add_child(difficulty_option)

	var touch_size_label := Label.new()
	touch_size_label.text = "TOUCH SIZE"
	touch_size_label.position = Vector2(24, 576)
	touch_size_label.add_theme_font_size_override("font_size", 13)
	box.add_child(touch_size_label)

	var touch_size_slider := HSlider.new()
	touch_size_slider.name = "TouchSizeSlider"
	touch_size_slider.position = Vector2(170, 573)
	touch_size_slider.size = Vector2(190, 28)
	touch_size_slider.min_value = 0.75
	touch_size_slider.max_value = 1.4
	touch_size_slider.step = 0.05
	touch_size_slider.value = 1.0
	touch_size_slider.value_changed.connect(func(value: float) -> void:
		if is_instance_valid(touch_controls):
			touch_controls.set_control_scale(value)
			profile_store.touch_scale = value
			profile_store.save_profile()
	)
	box.add_child(touch_size_slider)

	var joystick_layout_slider := HSlider.new()
	joystick_layout_slider.name = "JoystickPositionSlider"
	joystick_layout_slider.position = Vector2(170, 592)
	joystick_layout_slider.size = Vector2(190, 24)
	joystick_layout_slider.min_value = 50.0
	joystick_layout_slider.max_value = 240.0
	joystick_layout_slider.value = 110.0
	joystick_layout_slider.value_changed.connect(_on_touch_layout_changed)
	box.add_child(joystick_layout_slider)
	var joystick_layout_label := Label.new()
	joystick_layout_label.text = "JOYSTICK POSITION"
	joystick_layout_label.position = Vector2(24, 592)
	joystick_layout_label.add_theme_font_size_override("font_size", 13)
	box.add_child(joystick_layout_label)

	var buttons_layout_slider := HSlider.new()
	buttons_layout_slider.name = "ActionButtonsPositionSlider"
	buttons_layout_slider.position = Vector2(170, 621)
	buttons_layout_slider.size = Vector2(190, 24)
	buttons_layout_slider.min_value = 0.0
	buttons_layout_slider.max_value = 150.0
	buttons_layout_slider.value = 0.0
	buttons_layout_slider.value_changed.connect(_on_touch_layout_changed)
	box.add_child(buttons_layout_slider)
	var buttons_layout_label := Label.new()
	buttons_layout_label.text = "BUTTON POSITION"
	buttons_layout_label.position = Vector2(24, 621)
	buttons_layout_label.add_theme_font_size_override("font_size", 13)
	box.add_child(buttons_layout_label)

	var home_color_label := Label.new()
	home_color_label.text = "HOME KIT"
	home_color_label.position = Vector2(24, 650)
	home_color_label.add_theme_font_size_override("font_size", 13)
	box.add_child(home_color_label)
	home_color_option = OptionButton.new()
	home_color_option.position = Vector2(170, 645)
	home_color_option.size = Vector2(190, 32)
	for color_name in ["Blue", "Emerald", "Crimson", "Gold"]:
		home_color_option.add_item(color_name)
	home_color_option.select(0)
	home_color_option.item_selected.connect(_on_match_setting_changed)
	box.add_child(home_color_option)

	var away_color_label := Label.new()
	away_color_label.text = "AWAY KIT"
	away_color_label.position = Vector2(24, 681)
	away_color_label.add_theme_font_size_override("font_size", 13)
	box.add_child(away_color_label)
	away_color_option = OptionButton.new()
	away_color_option.position = Vector2(170, 676)
	away_color_option.size = Vector2(190, 32)
	for color_name in ["Crimson", "Blue", "Emerald", "Gold"]:
		away_color_option.add_item(color_name)
	away_color_option.select(0)
	away_color_option.item_selected.connect(_on_match_setting_changed)
	box.add_child(away_color_option)

	var music_label := Label.new()
	music_label.text = "MUSIC"
	music_label.position = Vector2(24, 712)
	music_label.add_theme_font_size_override("font_size", 13)
	box.add_child(music_label)
	music_volume_slider = HSlider.new()
	music_volume_slider.name = "MusicVolumeSlider"
	music_volume_slider.position = Vector2(170, 709)
	music_volume_slider.size = Vector2(190, 25)
	music_volume_slider.min_value = 0.0
	music_volume_slider.max_value = 1.0
	music_volume_slider.step = 0.05
	music_volume_slider.value = 0.7
	music_volume_slider.value_changed.connect(_on_audio_setting_changed)
	box.add_child(music_volume_slider)

	var effects_label := Label.new()
	effects_label.text = "SFX"
	effects_label.position = Vector2(24, 734)
	effects_label.add_theme_font_size_override("font_size", 13)
	box.add_child(effects_label)
	effects_volume_slider = HSlider.new()
	effects_volume_slider.name = "EffectsVolumeSlider"
	effects_volume_slider.position = Vector2(170, 731)
	effects_volume_slider.size = Vector2(190, 25)
	effects_volume_slider.min_value = 0.0
	effects_volume_slider.max_value = 1.0
	effects_volume_slider.step = 0.05
	effects_volume_slider.value = 0.85
	effects_volume_slider.value_changed.connect(_on_audio_setting_changed)
	box.add_child(effects_volume_slider)

	var opponent_style_label := Label.new()
	opponent_style_label.text = "OPPONENT STYLE"
	opponent_style_label.position = Vector2(24, 778)
	opponent_style_label.add_theme_font_size_override("font_size", 13)
	box.add_child(opponent_style_label)
	opponent_style_option = OptionButton.new()
	opponent_style_option.position = Vector2(170, 773)
	opponent_style_option.size = Vector2(190, 30)
	for style_name in ["Aggressive", "Balanced", "Patient"]:
		opponent_style_option.add_item(style_name)
	opponent_style_option.item_selected.connect(func(index: int) -> void:
		profile_store.opponent_style = index
		profile_store.save_profile()
		opponent_style_changed.emit(index)
	)
	box.add_child(opponent_style_option)

	var sub_label := Label.new()
	sub_label.text = "SUBSTITUTE"
	sub_label.position = Vector2(24, 812)
	sub_label.add_theme_font_size_override("font_size", 13)
	box.add_child(sub_label)
	substitute_player_option = OptionButton.new()
	substitute_player_option.position = Vector2(120, 807)
	substitute_player_option.size = Vector2(100, 30)
	for player_index in range(10):
		substitute_player_option.add_item("OUTFIELD %02d" % (player_index + 1))
	box.add_child(substitute_player_option)
	substitute_reserve_option = OptionButton.new()
	substitute_reserve_option.position = Vector2(228, 807)
	substitute_reserve_option.size = Vector2(90, 30)
	for reserve_index in range(5):
		substitute_reserve_option.add_item("BENCH %d" % (reserve_index + 1))
	box.add_child(substitute_reserve_option)
	var substitute_button := Button.new()
	substitute_button.text = "MAKE SUB"
	substitute_button.position = Vector2(322, 807)
	substitute_button.size = Vector2(80, 30)
	substitute_button.pressed.connect(func() -> void:
		substitution_requested.emit(substitute_player_option.selected, substitute_reserve_option.selected)
	)
	box.add_child(substitute_button)

	var local_multiplayer_button := CheckButton.new()
	local_multiplayer_button.name = "LocalMultiplayerToggle"
	local_multiplayer_button.text = "LOCAL VERSUS (P2: WASD / U O I P)"
	local_multiplayer_button.position = Vector2(24, 844)
	local_multiplayer_button.button_pressed = profile_store.local_multiplayer_enabled
	local_multiplayer_button.toggled.connect(func(enabled: bool) -> void:
		profile_store.local_multiplayer_enabled = enabled
		profile_store.save_profile()
		local_multiplayer_changed.emit(enabled)
	)
	box.add_child(local_multiplayer_button)

	var career_button := Button.new()
	career_button.name = "CareerButton"
	career_button.text = "START CAREER SEASON"
	career_button.position = Vector2(24, 880)
	career_button.size = Vector2(180, 32)
	career_button.pressed.connect(func() -> void:
		profile_store.start_career()
		career_button.text = "CAREER: 6 FIXTURES"
		announce("CAREER SEASON STARTED")
		restart_match_requested.emit()
	)
	box.add_child(career_button)
	var upgrade_button := Button.new()
	upgrade_button.name = "CareerUpgradeButton"
	upgrade_button.text = "UPGRADE SPEED"
	upgrade_button.position = Vector2(210, 880)
	upgrade_button.size = Vector2(190, 32)
	upgrade_button.pressed.connect(func() -> void:
		if profile_store.purchase_upgrade("speed"):
			career_upgrade_requested.emit("speed")
			announce("SPEED UPGRADED")
		else:
			announce("NO CAREER UPGRADE POINTS")
	)
	box.add_child(upgrade_button)
	var shot_upgrade_button := Button.new()
	shot_upgrade_button.name = "CareerShotUpgradeButton"
	shot_upgrade_button.text = "UPGRADE SHOT"
	shot_upgrade_button.position = Vector2(24, 916)
	shot_upgrade_button.size = Vector2(180, 30)
	shot_upgrade_button.pressed.connect(func() -> void:
		if profile_store.purchase_upgrade("shot"):
			career_upgrade_requested.emit("shot")
			announce("SHOT POWER UPGRADED")
		else:
			announce("NO CAREER UPGRADE POINTS")
	)
	box.add_child(shot_upgrade_button)

	training_challenge_option = OptionButton.new()
	training_challenge_option.position = Vector2(24, 954)
	training_challenge_option.size = Vector2(180, 30)
	training_challenge_option.add_item("Shooting")
	training_challenge_option.add_item("Passing")
	training_challenge_option.add_item("Defending")
	box.add_child(training_challenge_option)
	var challenge_button := Button.new()
	challenge_button.text = "START 60S CHALLENGE"
	challenge_button.position = Vector2(210, 954)
	challenge_button.size = Vector2(190, 30)
	challenge_button.pressed.connect(func() -> void:
		var challenge_names := ["shooting", "passing", "defending"]
		training_challenge_requested.emit(challenge_names[training_challenge_option.selected])
	)
	box.add_child(challenge_button)

	weather_option = OptionButton.new()
	weather_option.position = Vector2(24, 990)
	weather_option.size = Vector2(180, 30)
	for weather_name in ["Clear day", "Evening", "Rain"]:
		weather_option.add_item(weather_name)
	weather_option.item_selected.connect(func(index: int) -> void:
		profile_store.weather_mode = index
		profile_store.save_profile()
		weather_changed.emit(index)
	)
	box.add_child(weather_option)
	high_contrast_toggle = CheckButton.new()
	high_contrast_toggle.text = "HIGH CONTRAST HUD"
	high_contrast_toggle.position = Vector2(210, 990)
	high_contrast_toggle.button_pressed = profile_store.high_contrast
	high_contrast_toggle.toggled.connect(func(enabled: bool) -> void:
		profile_store.high_contrast = enabled
		profile_store.save_profile()
		accessibility_changed.emit(profile_store.game_speed, profile_store.ui_scale, enabled)
	)
	box.add_child(high_contrast_toggle)

	var speed_label := Label.new()
	speed_label.text = "GAME SPEED"
	speed_label.position = Vector2(24, 1026)
	speed_label.add_theme_font_size_override("font_size", 13)
	box.add_child(speed_label)
	game_speed_slider = HSlider.new()
	game_speed_slider.position = Vector2(170, 1026)
	game_speed_slider.size = Vector2(190, 24)
	game_speed_slider.min_value = 0.6
	game_speed_slider.max_value = 1.4
	game_speed_slider.step = 0.1
	game_speed_slider.value = profile_store.game_speed
	game_speed_slider.value_changed.connect(func(value: float) -> void:
		profile_store.game_speed = value
		profile_store.save_profile()
		accessibility_changed.emit(value, profile_store.ui_scale, profile_store.high_contrast)
	)
	box.add_child(game_speed_slider)
	var ui_scale_label := Label.new()
	ui_scale_label.text = "UI SIZE"
	ui_scale_label.position = Vector2(24, 1058)
	ui_scale_label.add_theme_font_size_override("font_size", 13)
	box.add_child(ui_scale_label)
	ui_scale_slider = HSlider.new()
	ui_scale_slider.position = Vector2(170, 1058)
	ui_scale_slider.size = Vector2(190, 24)
	ui_scale_slider.min_value = 0.85
	ui_scale_slider.max_value = 1.4
	ui_scale_slider.step = 0.05
	ui_scale_slider.value = profile_store.ui_scale
	ui_scale_slider.value_changed.connect(func(value: float) -> void:
		profile_store.ui_scale = value
		profile_store.save_profile()
		accessibility_changed.emit(profile_store.game_speed, value, profile_store.high_contrast)
	)
	box.add_child(ui_scale_slider)
	var lineup_button := Button.new()
	lineup_button.text = "VIEW TEAM LINE-UP"
	lineup_button.position = Vector2(24, 1092)
	lineup_button.size = Vector2(180, 32)
	lineup_button.pressed.connect(func() -> void: lineup_requested.emit())
	box.add_child(lineup_button)
	var table_button := Button.new()
	table_button.text = "VIEW TABLE"
	table_button.position = Vector2(210, 1092)
	table_button.size = Vector2(190, 32)
	table_button.pressed.connect(func() -> void: competition_table_requested.emit())
	box.add_child(table_button)

	var scroll := ScrollContainer.new()
	scroll.name = "PauseSettingsScroll"
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 8
	scroll.offset_top = 8
	scroll.offset_right = -8
	scroll.offset_bottom = -8
	box.add_child(scroll)
	var content := Control.new()
	content.name = "SettingsContent"
	content.custom_minimum_size = Vector2(420, 1140)
	scroll.add_child(content)
	for child in box.get_children():
		if child == scroll:
			continue
		box.remove_child(child)
		content.add_child(child)

	challenge_label = Label.new()
	challenge_label.name = "ChallengeStatus"
	challenge_label.anchor_left = 0.5
	challenge_label.anchor_right = 0.5
	challenge_label.offset_left = -220
	challenge_label.offset_right = 220
	challenge_label.offset_top = 180
	challenge_label.offset_bottom = 210
	challenge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	challenge_label.add_theme_font_size_override("font_size", 18)
	challenge_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.3))
	challenge_label.visible = false
	add_child(challenge_label)

	set_piece_label = Label.new()
	set_piece_label.anchor_left = 0.5
	set_piece_label.anchor_right = 0.5
	set_piece_label.anchor_top = 1.0
	set_piece_label.anchor_bottom = 1.0
	set_piece_label.offset_left = -260
	set_piece_label.offset_right = 260
	set_piece_label.offset_top = -190
	set_piece_label.offset_bottom = -158
	set_piece_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_piece_label.add_theme_font_size_override("font_size", 18)
	set_piece_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	set_piece_label.visible = false
	add_child(set_piece_label)

	replay_controls = Control.new()
	replay_controls.name = "ReplayControls"
	replay_controls.anchor_left = 0.5
	replay_controls.anchor_right = 0.5
	replay_controls.offset_left = -200
	replay_controls.offset_right = 200
	replay_controls.offset_top = 118
	replay_controls.offset_bottom = 164
	replay_controls.visible = false
	add_child(replay_controls)
	var replay_button_names := ["SLOW", "CAMERA", "SKIP"]
	var replay_commands := ["slow", "camera", "skip"]
	for index in range(replay_button_names.size()):
		var replay_button := Button.new()
		replay_button.text = replay_button_names[index]
		replay_button.position = Vector2(float(index) * 125.0, 0.0)
		replay_button.size = Vector2(110.0, 36.0)
		var command: String = replay_commands[index]
		replay_button.pressed.connect(func() -> void: replay_command_requested.emit(command))
		replay_controls.add_child(replay_button)

func _build_lineup_modal() -> void:
	lineup_modal = Control.new()
	lineup_modal.name = "LineupModal"
	lineup_modal.anchor_right = 1.0
	lineup_modal.anchor_bottom = 1.0
	lineup_modal.visible = false
	add_child(lineup_modal)
	var background := ColorRect.new()
	background.color = Color(0.01, 0.03, 0.02, 0.9)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	lineup_modal.add_child(background)
	var card := Panel.new()
	card.name = "LineupCard"
	card.add_theme_stylebox_override("panel", _surface_style(Color(0.025, 0.075, 0.055, 0.985), Color(0.78, 0.61, 0.22, 0.85), 18))
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -230
	card.offset_right = 230
	card.offset_top = -220
	card.offset_bottom = 220
	lineup_modal.add_child(card)
	var title := Label.new()
	title.name = "LineupTitle"
	title.text = "MATCH LINE-UP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_right = 1.0
	title.offset_top = 22
	title.offset_bottom = 60
	title.add_theme_font_size_override("font_size", 28)
	card.add_child(title)
	var players := Label.new()
	players.name = "LineupPlayers"
	players.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	players.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	players.anchor_right = 1.0
	players.offset_left = 24
	players.offset_right = -24
	players.offset_top = 72
	players.offset_bottom = 300
	players.add_theme_font_size_override("font_size", 20)
	card.add_child(players)
	var close_button := Button.new()
	close_button.text = "BACK TO MATCH"
	close_button.anchor_left = 0.5
	close_button.anchor_right = 0.5
	close_button.offset_left = -110
	close_button.offset_right = 110
	close_button.offset_top = 340
	close_button.offset_bottom = 386
	close_button.pressed.connect(func() -> void: lineup_modal.visible = false)
	card.add_child(close_button)

func show_lineup(active_names: Array[String], reserve_names: Array[String]) -> void:
	var players := lineup_modal.get_node("LineupCard/LineupPlayers") as Label
	(lineup_modal.get_node("LineupCard/LineupTitle") as Label).text = "MATCH LINE-UP"
	var lineup_text := "STARTING XI\n"
	for index in range(active_names.size()):
		lineup_text += "%d. %s\n" % [index + 1, active_names[index]]
	lineup_text += "\nBENCH\n"
	for reserve_name in reserve_names:
		lineup_text += reserve_name + "\n"
	players.text = lineup_text
	lineup_modal.visible = true

func show_competition_table(table_text: String) -> void:
	var title := lineup_modal.get_node("LineupCard/LineupTitle") as Label
	var players := lineup_modal.get_node("LineupCard/LineupPlayers") as Label
	title.text = "LEAGUE FIXTURES & TABLE"
	players.text = table_text
	lineup_modal.visible = true

func _build_match_end_modal() -> void:
	match_end_modal = Control.new()
	match_end_modal.name = "MatchEndModal"
	match_end_modal.anchor_right = 1.0
	match_end_modal.anchor_bottom = 1.0
	match_end_modal.visible = false
	add_child(match_end_modal)

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.03, 0.02, 0.85)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	match_end_modal.add_child(bg)

	var card := Panel.new()
	card.name = "EndCard"
	card.add_theme_stylebox_override("panel", _surface_style(Color(0.025, 0.075, 0.055, 0.985), Color(0.78, 0.61, 0.22, 0.85), 18))
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -260
	card.offset_right = 260
	card.offset_top = -250
	card.offset_bottom = 250
	match_end_modal.add_child(card)

	var title := Label.new()
	title.name = "EndTitle"
	title.text = "FULL TIME - ETHAN CUP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.anchor_right = 1.0
	title.offset_top = 18
	title.offset_bottom = 54
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	card.add_child(title)

	var score_disp := Label.new()
	score_disp.name = "EndScore"
	score_disp.text = "HOME  0 - 0  AWAY"
	score_disp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_disp.add_theme_font_size_override("font_size", 34)
	score_disp.anchor_right = 1.0
	score_disp.offset_top = 64
	score_disp.offset_bottom = 110
	card.add_child(score_disp)

	var stats_text := Label.new()
	stats_text.name = "EndStatsText"
	stats_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_text.add_theme_font_size_override("font_size", 15)
	stats_text.anchor_right = 1.0
	stats_text.offset_top = 120
	stats_text.offset_bottom = 330
	stats_text.add_theme_color_override("font_color", Color(0.85, 0.95, 0.9))
	card.add_child(stats_text)

	var btn_action := Button.new()
	btn_action.name = "EndActionButton"
	btn_action.text = "PLAY AGAIN"
	btn_action.anchor_left = 0.5
	btn_action.anchor_right = 0.5
	btn_action.offset_left = -110
	btn_action.offset_right = 110
	btn_action.offset_top = 370
	btn_action.offset_bottom = 420
	btn_action.pressed.connect(func() -> void:
		match_end_modal.visible = false
		if match_period == 2:
			# Half time continue
			half_time_continued.emit()
		else:
			# New match
			if match_period == 4 and profile_store.tournament_active:
				announce("LEAGUE FIXTURE %d OF 6" % (7 - profile_store.tournament_matches_remaining))
			restart_match_requested.emit()
	)
	card.add_child(btn_action)

func toggle_pause() -> void:
	if not is_instance_valid(pause_modal):
		return
	pause_modal.visible = not pause_modal.visible
	running = not pause_modal.visible and (match_period == 1 or match_period == 3)
	get_tree().paused = pause_modal.visible or match_period == 2 or match_period == 4
	var stats_lbl := pause_modal.get_node_or_null("PausePanel/PauseStatsLabel") as Label
	if not is_instance_valid(stats_lbl):
		stats_lbl = pause_modal.find_child("PauseStatsLabel", true, false) as Label
	if is_instance_valid(stats_lbl):
		stats_lbl.text = _format_stats_string()

func toggle_touch_controls() -> void:
	touch_controls_enabled = not touch_controls_enabled
	if is_instance_valid(touch_controls):
		touch_controls.visible = touch_controls_enabled
	if is_instance_valid(touch_toggle_button):
		touch_toggle_button.modulate = Color(1, 1, 1, 1.0) if touch_controls_enabled else Color(1, 1, 1, 0.45)

func _on_match_setting_changed(_index: int) -> void:
	var half_length := float(half_length_option.get_item_id(half_length_option.selected))
	var difficulty := float(difficulty_option.get_item_id(difficulty_option.selected)) / 100.0
	profile_store.half_length = half_length
	profile_store.difficulty = difficulty
	profile_store.home_color = home_color_option.selected
	profile_store.away_color = away_color_option.selected
	profile_store.save_profile()
	match_settings_changed.emit(half_length, difficulty, home_color_option.selected, away_color_option.selected)

func _on_audio_setting_changed(_value: float) -> void:
	profile_store.music_volume = music_volume_slider.value
	profile_store.effects_volume = effects_volume_slider.value
	profile_store.save_profile()
	audio_settings_changed.emit(music_volume_slider.value, effects_volume_slider.value)

func load_profile_settings(profile: Node) -> void:
	profile_store = profile
	half_duration = profile.half_length
	difficulty_option.select(1 if profile.difficulty >= 0.9 else (0 if profile.difficulty < 0.9 else 2))
	home_color_option.select(clampi(profile.home_color, 0, home_color_option.item_count - 1))
	away_color_option.select(clampi(profile.away_color, 0, away_color_option.item_count - 1))
	music_volume_slider.value = profile.music_volume
	effects_volume_slider.value = profile.effects_volume
	tactical_preset_option.select(clampi(profile.tactical_preset, 0, 2))
	opponent_style_option.select(clampi(profile.opponent_style, 0, 2))
	weather_option.select(clampi(profile.weather_mode, 0, 2))
	high_contrast_toggle.button_pressed = profile.high_contrast
	game_speed_slider.value = clampf(profile.game_speed, 0.6, 1.4)
	ui_scale_slider.value = clampf(profile.ui_scale, 0.85, 1.4)
	var tournament_button := pause_modal.find_child("TournamentButton", true, false) as Button
	if is_instance_valid(tournament_button) and profile.tournament_active:
		tournament_button.text = "LEAGUE: %d FIXTURES LEFT" % profile.tournament_matches_remaining
	var career_button := pause_modal.find_child("CareerButton", true, false) as Button
	if is_instance_valid(career_button) and profile.career_active:
		career_button.text = "CAREER: %d FIXTURES" % profile.career_fixtures_remaining
	var local_toggle := pause_modal.find_child("LocalMultiplayerToggle", true, false) as CheckButton
	if is_instance_valid(local_toggle):
		local_toggle.button_pressed = profile.local_multiplayer_enabled
	accessibility_changed.emit(profile.game_speed, profile.ui_scale, profile.high_contrast)
	weather_changed.emit(profile.weather_mode)
	opponent_style_changed.emit(profile.opponent_style)
	touch_controls.set_control_scale(profile.touch_scale)
	touch_controls.set_control_layout(profile.joystick_x, profile.action_button_offset)
	(pause_modal.find_child("TouchSizeSlider", true, false) as HSlider).value = profile.touch_scale
	(pause_modal.find_child("JoystickPositionSlider", true, false) as HSlider).value = profile.joystick_x
	(pause_modal.find_child("ActionButtonsPositionSlider", true, false) as HSlider).value = profile.action_button_offset
	if is_instance_valid(touch_controls):
		touch_controls.set_control_scale(profile.touch_scale)
		touch_controls.set_control_layout(profile.joystick_x, profile.action_button_offset)

func get_selected_match_settings() -> Array:
	return [
		float(half_length_option.get_item_id(half_length_option.selected)),
		float(difficulty_option.get_item_id(difficulty_option.selected)) / 100.0,
		home_color_option.selected,
		away_color_option.selected
	]

func set_training_mode(enabled: bool) -> void:
	training_mode = enabled
	if is_instance_valid(training_label):
		training_label.visible = enabled
		training_label.text = "TRAINING GOALS: 0"

func set_training_goals(goals: int) -> void:
	if is_instance_valid(training_label):
		training_label.text = "TRAINING GOALS: %d" % goals

func set_set_piece_mode(enabled: bool, penalty: bool = false, restart_type: String = "free_kick") -> void:
	if is_instance_valid(set_piece_label):
		set_piece_label.visible = enabled
		if penalty:
			set_piece_label.text = "PENALTY: AIM WITH LEFT/RIGHT, K SHOOT"
		else:
			match restart_type:
				"throw_in":
					set_piece_label.text = "THROW-IN: AIM, J TO PASS"
				"corner":
					set_piece_label.text = "CORNER: AIM, J TO CROSS"
				"goal_kick":
					set_piece_label.text = "GOAL KICK: AIM, J TO DISTRIBUTE"
				_:
					set_piece_label.text = "FREE KICK: AIM WITH LEFT/RIGHT, K SHOOT"

func set_challenge_status(challenge: String, score: int, time_left: float, active: bool) -> void:
	if not is_instance_valid(challenge_label):
		return
	challenge_label.visible = active or not challenge.is_empty()
	if challenge.is_empty():
		challenge_label.text = ""
	else:
		challenge_label.text = "%s CHALLENGE  %02d  |  %02d SEC" % [challenge.to_upper(), score, ceili(maxf(0.0, time_left))]

func set_replay_active(active: bool) -> void:
	if active:
		was_running_before_replay = running
		running = false
	else:
		running = was_running_before_replay and (match_period == 1 or match_period == 3)
	if is_instance_valid(replay_controls):
		replay_controls.visible = active

func set_accessibility(game_speed: float, display_scale: float, contrast: bool) -> void:
	Engine.time_scale = clampf(game_speed, 0.6, 1.4)
	var clamped_scale := clampf(display_scale, 0.85, 1.4)
	for control: Control in find_children("*", "Control", true, false):
		if not control.has_meta("base_accessible_font_size"):
			control.set_meta("base_accessible_font_size", control.get_theme_font_size("font_size"))
		var base_size := int(control.get_meta("base_accessible_font_size"))
		control.add_theme_font_size_override("font_size", maxi(8, roundi(float(base_size) * clamped_scale)))
	if contrast:
		status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
		possession_label.add_theme_color_override("font_color", Color.WHITE)
		score_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		status_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
		possession_label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.55))
		score_label.remove_theme_color_override("font_color")

func _on_touch_layout_changed(_value: float) -> void:
	var joystick_slider := pause_modal.find_child("JoystickPositionSlider", true, false) as HSlider
	var buttons_slider := pause_modal.find_child("ActionButtonsPositionSlider", true, false) as HSlider
	if is_instance_valid(touch_controls):
		touch_controls.set_control_layout(joystick_slider.value, buttons_slider.value)
		profile_store.joystick_x = joystick_slider.value
		profile_store.action_button_offset = buttons_slider.value
		profile_store.save_profile()

func _process(delta: float) -> void:
	if not running:
		return

	if Input.is_action_just_pressed("pause_game") and not suppress_pause_press:
		toggle_pause()
	suppress_pause_press = false

	elapsed += delta
	_update_match_clock(delta)

func _update_match_clock(_delta: float) -> void:
	if match_period == 1:
		var in_game_seconds := (elapsed / half_duration) * (45.0 * 60.0)
		var total_secs := int(in_game_seconds)
		clock_label.text = "FIRST HALF   %02d:%02d" % [clampi(total_secs / 60, 0, 45), total_secs % 60]
		if elapsed >= half_duration:
			trigger_half_time()
	elif match_period == 3:
		var second_half_elapsed := elapsed - half_duration
		var in_game_seconds := 45.0 * 60.0 + (second_half_elapsed / half_duration) * (45.0 * 60.0)
		var total_secs := int(in_game_seconds)
		clock_label.text = "SECOND HALF   %02d:%02d" % [clampi(total_secs / 60, 45, 90), total_secs % 60]
		if second_half_elapsed >= half_duration:
			trigger_full_time()

func _input(event: InputEvent) -> void:
	if not waiting_for_key or not event is InputEventKey or not event.pressed or event.echo:
		return
	var action_name: String = REMAP_ACTIONS[remap_action_option.selected]
	var physical_keycode: int = event.physical_keycode if event.physical_keycode > 0 else event.keycode
	profile_store.set_key_binding(action_name, physical_keycode)
	waiting_for_key = false
	suppress_pause_press = true
	remap_key_button.text = "BOUND: " + event.as_text()
	get_viewport().set_input_as_handled()

func trigger_half_time() -> void:
	match_period = 2
	running = false
	get_tree().paused = true
	clock_label.text = "HALF TIME"
	announce("HALF TIME WHISTLE!")
	_show_period_modal("HALF TIME BREAK", "START 2ND HALF")

func trigger_full_time() -> void:
	match_period = 4
	running = false
	get_tree().paused = true
	clock_label.text = "FULL TIME"
	announce("FULL TIME! MATCH ENDS!")
	var tournament_was_active: bool = profile_store.tournament_active
	profile_store.record_tournament_result(home_score, away_score)
	var career_was_active: bool = profile_store.career_active
	profile_store.record_career_result(home_score, away_score)
	profile_store.record_match({
		"date": Time.get_datetime_string_from_system(),
		"home_score": home_score,
		"away_score": away_score,
		"stats": _format_stats_string()
	})
	profile_store.award_match_progress(home_score, away_score)
	profile_store.award_experience(25 if home_score >= away_score else 15)
	if tournament_was_active:
		announce("SIX-MATCH LEAGUE COMPLETE!" if not profile_store.tournament_active else "LEAGUE POINTS: %d" % profile_store.tournament_points)
	elif career_was_active:
		announce("CAREER SEASON COMPLETE!" if not profile_store.career_active else "CAREER POINTS: %d" % profile_store.career_points)
	_show_period_modal("LEAGUE COMPLETE" if tournament_was_active and not profile_store.tournament_active else ("SEASON COMPLETE" if career_was_active and not profile_store.career_active else "FULL TIME - ETHAN CUP"), "PLAY AGAIN")

func _show_period_modal(title_text: String, action_text: String) -> void:
	if not is_instance_valid(match_end_modal):
		return
	var card := match_end_modal.get_node_or_null("EndCard")
	if not is_instance_valid(card):
		return
	var title := card.get_node_or_null("EndTitle") as Label
	var score_disp := card.get_node_or_null("EndScore") as Label
	var stats_text := card.get_node_or_null("EndStatsText") as Label
	var btn_action := card.get_node_or_null("EndActionButton") as Button

	if is_instance_valid(title):
		title.text = title_text
	if is_instance_valid(score_disp):
		score_disp.text = "HOME  %d - %d  AWAY" % [home_score, away_score]
	if is_instance_valid(stats_text):
		stats_text.text = _format_stats_string()
	if is_instance_valid(btn_action):
		if match_period == 4 and profile_store.tournament_active:
			btn_action.text = "NEXT LEAGUE MATCH"
		elif match_period == 4 and profile_store.career_active:
			btn_action.text = "NEXT CAREER MATCH"
		else:
			btn_action.text = action_text

	match_end_modal.visible = true

func _format_stats_string() -> String:
	var total_time := home_possession_time + away_possession_time
	var home_pct := 50
	var away_pct := 50
	if total_time > 1.0:
		home_pct = clampi(int((home_possession_time / total_time) * 100.0), 5, 95)
		away_pct = 100 - home_pct

	var summary := "POSSESSION: HOME %d%% - %d%% AWAY\nSHOTS: %d - %d\nTACKLES WON: %d - %d" % [
		home_pct, away_pct, home_shots, away_shots, home_tackles, away_tackles
	]
	var previous_index := 0
	if match_period == 4:
		previous_index = 1 if profile_store.match_history.size() > 1 else -1
	if previous_index >= 0 and previous_index < profile_store.match_history.size():
		var previous: Dictionary = profile_store.match_history[previous_index]
		summary += "\nPREVIOUS: %d - %d" % [int(previous.get("home_score", 0)), int(previous.get("away_score", 0))]
	if profile_store.tournament_active:
		summary += "\nLEAGUE: %d PTS | GD %d | %d LEFT" % [profile_store.tournament_points, profile_store.tournament_goal_difference, profile_store.tournament_matches_remaining]
	if not profile_store.tournament_results.is_empty() and (profile_store.tournament_active or match_period == 4):
		summary += "\nFIXTURES:"
		for index in range(profile_store.tournament_results.size()):
			var fixture: Dictionary = profile_store.tournament_results[index]
			summary += "\n%d. %s %d-%d (%d pts)" % [
				index + 1,
				fixture.get("opponent", "Opponent"),
				int(fixture.get("home_score", 0)),
				int(fixture.get("away_score", 0)),
				int(fixture.get("points", 0))
			]
	if profile_store.career_active:
		summary += "\nCAREER: %d PTS | %d LEFT | %d UPGRADES" % [profile_store.career_points, profile_store.career_fixtures_remaining, profile_store.career_upgrade_points]
	elif match_period == 4 and profile_store.career_fixtures_remaining < 6:
		summary += "\nSEASON TOTAL: %d PTS | GD %d" % [profile_store.career_points, profile_store.career_goal_difference]
	return summary

func update_shot_power(charge: float, is_charging: bool) -> void:
	if not is_instance_valid(power_bar_panel):
		return
	power_bar_panel.visible = is_charging
	if is_charging:
		var clamped := clampf(charge, 0.0, 1.0)
		var max_width: float = 280.0 - 6.0
		power_fill.size.x = max_width * clamped
		if clamped < 0.5:
			power_fill.color = Color(0.2, 0.9, 0.3).lerp(Color(0.95, 0.85, 0.15), clamped * 2.0)
		else:
			power_fill.color = Color(0.95, 0.85, 0.15).lerp(Color(0.95, 0.2, 0.1), (clamped - 0.5) * 2.0)

func update_stamina(current: float, max_val: float) -> void:
	if not is_instance_valid(stamina_fill):
		return
	var ratio := clampf(current / max_val, 0.0, 1.0)
	stamina_fill.size.x = (188.0 - 6.0) * ratio
	if ratio < 0.25:
		stamina_fill.color = Color(0.95, 0.3, 0.2)
	elif ratio < 0.5:
		stamina_fill.color = Color(0.95, 0.8, 0.2)
	else:
		stamina_fill.color = Color(0.2, 0.85, 0.95)

func set_score(home: int, away: int) -> void:
	home_score = home
	away_score = away
	score_label.text = "ETHAN     %d - %d     VISITORS" % [home, away]

func reset_match() -> void:
	elapsed = 0.0
	running = true
	match_period = 1
	get_tree().paused = false
	home_score = 0
	away_score = 0
	home_possession_time = 0.0
	away_possession_time = 0.0
	home_shots = 0
	away_shots = 0
	home_tackles = 0
	away_tackles = 0
	score_label.text = "ETHAN     0 - 0     VISITORS"
	clock_label.text = "FIRST HALF   00:00"
	status_label.text = ""
	goal_overlay.visible = false
	pause_modal.visible = false
	match_end_modal.visible = false
	update_shot_power(0.0, false)
	if is_instance_valid(touch_controls):
		touch_controls.set_possession_context(true)

func record_shot(is_home: bool) -> void:
	if is_home:
		home_shots += 1
	else:
		away_shots += 1

func record_tackle(is_home: bool) -> void:
	if is_home:
		home_tackles += 1
	else:
		away_tackles += 1

func set_possession(player_has_ball: bool, opponent_has_ball: bool, teammate_count: int = 1, controlled_teammate: bool = false) -> void:
	if player_has_ball:
		home_possession_time += get_process_delta_time()
		var carrier := "TEAMMATE" if controlled_teammate else "YOU"
		possession_label.text = "BALL: %s  |  TEAM %d" % [carrier, teammate_count]
		if is_instance_valid(touch_controls):
			touch_controls.set_possession_context(true)
	elif not opponent_has_ball and teammate_count > 1:
		possession_label.text = "BALL: LOOSE  |  TEAM %d" % teammate_count
	elif opponent_has_ball:
		away_possession_time += get_process_delta_time()
		possession_label.text = "BALL: OPPONENT"
		if is_instance_valid(touch_controls):
			touch_controls.set_possession_context(false)
	else:
		possession_label.text = "BALL: LOOSE"

func announce(message: String) -> void:
	status_label.text = message
	var timer := get_tree().create_timer(2.2)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(status_label) and status_label.text == message:
			status_label.text = ""
	)
