extends Control

const MATCH_SCENE: PackedScene = preload("res://scenes/main.tscn")
const TEAM_DATA_PATH: String = "res://data/teams.json"
const PLAYER_DATA_PATH: String = "res://data/players.json"
const NAVY: Color = Color("#0b1530")
const GREEN: Color = Color("#22e07a")
const GOLD: Color = Color("#f0a500")
const PAPER: Color = Color("#f3f6f2")
const MUTED: Color = Color("#a8b2c6")

var content_title: Label
var content_detail: Label
var status_label: Label
var coin_label: Label
var level_label: Label
var nav_buttons: Dictionary = {}
var active_section: String = "HOME"
var music_slider: HSlider
var sfx_slider: HSlider

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_interface()
	_build_settings_controls()
	_refresh_account()
	show_section("HOME")

func _draw() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), NAVY)
	for index in range(36):
		var y: float = float(index) * viewport_size.y / 36.0
		var band_color: Color = Color(0.10, 0.16, 0.27, 0.12 if index % 2 == 0 else 0.04)
		draw_rect(Rect2(0.0, y, viewport_size.x, viewport_size.y / 36.0 + 1.0), band_color)
	var pitch_rect := Rect2(viewport_size.x * 0.57, viewport_size.y * 0.12, viewport_size.x * 0.37, viewport_size.y * 0.70)
	var pitch_frame := Rect2(pitch_rect.position - Vector2(8, 8), pitch_rect.size + Vector2(16, 16))
	draw_rect(pitch_frame, Color(0.22, 0.29, 0.34, 0.28))
	draw_rect(pitch_rect, Color(0.04, 0.26, 0.17, 0.86))
	for stripe_index in range(10):
		var stripe_y: float = pitch_rect.position.y + pitch_rect.size.y * float(stripe_index) / 10.0
		var stripe_color: Color = Color(0.10, 0.53, 0.29, 0.34 if stripe_index % 2 == 0 else 0.14)
		draw_rect(Rect2(pitch_rect.position.x, stripe_y, pitch_rect.size.x, pitch_rect.size.y / 10.0), stripe_color)
	draw_rect(pitch_rect, Color(0.74, 0.90, 0.80, 0.62), false, 2.0)
	draw_line(Vector2(pitch_rect.position.x, pitch_rect.position.y + pitch_rect.size.y * 0.5), Vector2(pitch_rect.end.x, pitch_rect.position.y + pitch_rect.size.y * 0.5), Color(0.74, 0.90, 0.80, 0.52), 2.0)
	draw_arc(pitch_rect.get_center(), pitch_rect.size.x * 0.12, 0.0, TAU, 48, Color(0.74, 0.90, 0.80, 0.56), 2.0)
	var box_width: float = pitch_rect.size.x * 0.40
	var box_height: float = pitch_rect.size.y * 0.15
	draw_rect(Rect2(pitch_rect.position.x + (pitch_rect.size.x - box_width) * 0.5, pitch_rect.position.y, box_width, box_height), Color(0.74, 0.90, 0.80, 0.56), false, 2.0)
	draw_rect(Rect2(pitch_rect.position.x + (pitch_rect.size.x - box_width) * 0.5, pitch_rect.end.y - box_height, box_width, box_height), Color(0.74, 0.90, 0.80, 0.56), false, 2.0)
	var team_positions: Array[Vector2] = [
		Vector2(0.27, 0.25), Vector2(0.43, 0.21), Vector2(0.62, 0.30), Vector2(0.75, 0.42),
		Vector2(0.19, 0.52), Vector2(0.37, 0.62), Vector2(0.55, 0.53), Vector2(0.79, 0.67),
		Vector2(0.33, 0.81), Vector2(0.64, 0.82), Vector2(0.88, 0.53)
	]
	for index in range(team_positions.size()):
		var position: Vector2 = pitch_rect.position + team_positions[index] * pitch_rect.size
		var marker_color: Color = GREEN if index < 6 else PAPER
		draw_circle(position, 7.0, marker_color)
		draw_circle(position, 9.0, Color(0.02, 0.06, 0.10, 0.72), false, 1.5)
	draw_circle(pitch_rect.position + Vector2(pitch_rect.size.x * 0.57, pitch_rect.size.y * 0.46), 5.0, GOLD)
	for side_index in range(6):
		var side_x: float = pitch_rect.position.x - 12.0 - side_index * 2.0
		draw_rect(Rect2(side_x, pitch_rect.position.y + 20.0, 2.0, pitch_rect.size.y - 40.0), Color(0.64, 0.74, 0.6, 0.28))

func _build_interface() -> void:
	var top_bar := ColorRect.new()
	top_bar.color = Color(0.025, 0.055, 0.12, 0.96)
	top_bar.anchor_right = 1.0
	top_bar.offset_bottom = 78.0
	add_child(top_bar)
	var logo := _make_label("ETHAN", 25, PAPER)
	logo.position = Vector2(48, 22)
	logo.size = Vector2(190, 40)
	add_child(logo)
	var accent := ColorRect.new()
	accent.color = GREEN
	accent.position = Vector2(48, 64)
	accent.size = Vector2(72, 3)
	add_child(accent)
	var brand_line := _make_label("FOOTBALL CLUB", 10, MUTED)
	brand_line.position = Vector2(127, 31)
	brand_line.size = Vector2(130, 24)
	add_child(brand_line)

	level_label = _make_label("LV. 01", 14, PAPER)
	level_label.anchor_left = 1.0
	level_label.anchor_right = 1.0
	level_label.offset_left = -326
	level_label.offset_right = -230
	level_label.offset_top = 29
	level_label.offset_bottom = 53
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(level_label)
	var level_track := ColorRect.new()
	level_track.color = Color(0.25, 0.31, 0.43, 0.9)
	level_track.anchor_left = 1.0
	level_track.anchor_right = 1.0
	level_track.offset_left = -218
	level_track.offset_right = -170
	level_track.offset_top = 34
	level_track.offset_bottom = 44
	add_child(level_track)
	var level_fill := ColorRect.new()
	level_fill.color = GREEN
	level_fill.anchor_left = 1.0
	level_fill.anchor_right = 1.0
	level_fill.offset_left = -218
	level_fill.offset_right = -194
	level_fill.offset_top = 34
	level_fill.offset_bottom = 44
	add_child(level_fill)
	var coin_icon := _make_label("C", 15, NAVY)
	coin_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_icon.anchor_left = 1.0
	coin_icon.anchor_right = 1.0
	coin_icon.offset_left = -151
	coin_icon.offset_right = -127
	coin_icon.offset_top = 27
	coin_icon.offset_bottom = 51
	var coin_circle := Panel.new()
	coin_circle.anchor_left = 1.0
	coin_circle.anchor_right = 1.0
	coin_circle.offset_left = -151
	coin_circle.offset_right = -127
	coin_circle.offset_top = 27
	coin_circle.offset_bottom = 51
	var circle_style := StyleBoxFlat.new()
	circle_style.bg_color = GOLD
	circle_style.set_corner_radius_all(12)
	coin_circle.add_theme_stylebox_override("panel", circle_style)
	add_child(coin_circle)
	add_child(coin_icon)
	coin_label = _make_label("12,450", 16, PAPER)
	coin_label.anchor_left = 1.0
	coin_label.anchor_right = 1.0
	coin_label.offset_left = -116
	coin_label.offset_right = -42
	coin_label.offset_top = 27
	coin_label.offset_bottom = 52
	add_child(coin_label)

	var section_kicker := _make_label("SEASON 01     /     MATCHDAY", 12, GREEN)
	section_kicker.position = Vector2(78, 137)
	section_kicker.size = Vector2(400, 24)
	add_child(section_kicker)
	var title := _make_label("PLAY THE\nBEAUTIFUL GAME", 46, PAPER)
	title.position = Vector2(74, 176)
	title.size = Vector2(580, 126)
	title.add_theme_font_size_override("font_size", 46)
	add_child(title)
	var description := _make_label("Build your club. Own the pitch.\nYour next great moment starts here.", 17, MUTED)
	description.position = Vector2(80, 312)
	description.size = Vector2(470, 58)
	add_child(description)

	var quick_button := _make_button("QUICK MATCH", true, 80, 408, 330, 62)
	quick_button.pressed.connect(_start_quick_match)
	add_child(quick_button)
	var career_button := _make_button("CAREER", false, 80, 487, 158, 54)
	career_button.pressed.connect(_start_career)
	add_child(career_button)
	var online_button := _make_button("ONLINE", false, 252, 487, 158, 54)
	online_button.pressed.connect(func() -> void: _show_status("Online matches are not available yet."))
	add_child(online_button)

	var content_backing := Panel.new()
	content_backing.position = Vector2(795, 140)
	content_backing.size = Vector2(375, 300)
	var content_style := StyleBoxFlat.new()
	content_style.bg_color = Color(0.025, 0.06, 0.13, 0.96)
	content_style.border_color = Color(0.35, 0.53, 0.64, 0.28)
	content_style.set_border_width_all(1)
	content_style.set_corner_radius_all(6)
	content_backing.add_theme_stylebox_override("panel", content_style)
	add_child(content_backing)
	var spotlight_label := _make_label("CLUB SPOTLIGHT", 11, GREEN)
	spotlight_label.position = Vector2(820, 164)
	spotlight_label.size = Vector2(300, 24)
	add_child(spotlight_label)
	content_title = _make_label("ETHAN FC", 28, PAPER)
	content_title.position = Vector2(820, 197)
	content_title.size = Vector2(315, 42)
	add_child(content_title)
	content_detail = _make_label("4-3-3   /   CLUB LEVEL 01\nReady for a new challenge.", 14, MUTED)
	content_detail.position = Vector2(820, 246)
	content_detail.size = Vector2(315, 62)
	add_child(content_detail)
	var squad_button := _make_button("MY TEAM", false, 820, 336, 150, 46)
	squad_button.pressed.connect(_open_team_management)
	add_child(squad_button)
	var shop_button := _make_button("VISIT SHOP", false, 984, 336, 150, 46)
	shop_button.pressed.connect(_open_progression)
	add_child(shop_button)

	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color(0.025, 0.055, 0.12, 0.98)
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_top = -74
	bottom_bar.anchor_right = 1.0
	add_child(bottom_bar)
	var nav_names: Array[String] = ["HOME", "SQUAD", "EVENTS", "SHOP", "SETTINGS"]
	for index in range(nav_names.size()):
		var nav_name: String = nav_names[index]
		var nav_button := Button.new()
		nav_button.text = nav_name
		nav_button.flat = true
		nav_button.focus_mode = Control.FOCUS_NONE
		nav_button.anchor_left = 0.5
		nav_button.anchor_right = 0.5
		nav_button.anchor_top = 1.0
		nav_button.anchor_bottom = 1.0
		var center_offset: float = (float(index) - 2.0) * 150.0
		nav_button.offset_left = center_offset - 66.0
		nav_button.offset_right = center_offset + 66.0
		nav_button.offset_top = -64.0
		nav_button.offset_bottom = -10.0
		nav_button.add_theme_font_size_override("font_size", 13)
		nav_button.add_theme_color_override("font_color", MUTED)
		nav_button.add_theme_color_override("font_hover_color", PAPER)
		if nav_name == "SQUAD":
			nav_button.pressed.connect(_open_team_management)
		elif nav_name == "SHOP" or nav_name == "EVENTS":
			nav_button.pressed.connect(_open_progression)
		else:
			nav_button.pressed.connect(func() -> void: show_section(nav_name))
		add_child(nav_button)
		nav_buttons[nav_name] = nav_button

	status_label = _make_label("", 13, GOLD)
	status_label.anchor_left = 0.5
	status_label.anchor_right = 0.5
	status_label.anchor_top = 1.0
	status_label.anchor_bottom = 1.0
	status_label.offset_left = -280.0
	status_label.offset_right = 280.0
	status_label.offset_top = -112.0
	status_label.offset_bottom = -84.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_button(text: String, is_primary: bool, x: float, y: float, width: float, height: float) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(x, y)
	button.size = Vector2(width, height)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = GREEN if is_primary else Color(0.035, 0.08, 0.16, 0.98)
	normal.border_color = GREEN if not is_primary else Color(0.0, 0.0, 0.0, 0.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 14.0
	normal.content_margin_right = 14.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.40, 0.96, 0.65) if is_primary else Color(0.08, 0.15, 0.25)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", NAVY if is_primary else PAPER)
	button.add_theme_color_override("font_hover_color", NAVY if is_primary else GREEN)
	button.add_theme_color_override("font_pressed_color", NAVY)
	return button

func _refresh_account() -> void:
	level_label.text = "LV. %02d" % ProfileStore.player_level
	coin_label.text = _format_number(ProfileStore.coins)

func _format_number(value: int) -> String:
	var digits: String = str(maxi(value, 0))
	var formatted: String = ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits.substr(index, 1)
	return formatted

func _build_settings_controls() -> void:
	if is_instance_valid(music_slider) or is_instance_valid(sfx_slider):
		return
	var settings_panel := Panel.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.position = Vector2(820.0, 180.0)
	settings_panel.size = Vector2(360.0, 240.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.06, 0.13, 0.96)
	style.border_color = Color(0.35, 0.53, 0.64, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	settings_panel.add_theme_stylebox_override("panel", style)
	add_child(settings_panel)
	var settings_title := _make_label("AUDIO", 12, GREEN)
	settings_title.position = Vector2(840.0, 205.0)
	settings_title.size = Vector2(180.0, 24.0)
	add_child(settings_title)
	var music_label := _make_label("MUSIC", 11, MUTED)
	music_label.position = Vector2(840.0, 240.0)
	music_label.size = Vector2(120.0, 20.0)
	add_child(music_label)
	music_slider = HSlider.new()
	music_slider.name = "MusicVolumeSlider"
	music_slider.position = Vector2(840.0, 260.0)
	music_slider.size = Vector2(300.0, 24.0)
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = ProfileStore.music_volume
	music_slider.value_changed.connect(_on_music_volume_changed)
	add_child(music_slider)
	var sfx_label := _make_label("SFX", 11, MUTED)
	sfx_label.position = Vector2(840.0, 300.0)
	sfx_label.size = Vector2(120.0, 20.0)
	add_child(sfx_label)
	sfx_slider = HSlider.new()
	sfx_slider.name = "SfxVolumeSlider"
	sfx_slider.position = Vector2(840.0, 320.0)
	sfx_slider.size = Vector2(300.0, 24.0)
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = ProfileStore.effects_volume
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	add_child(sfx_slider)

func _on_music_volume_changed(value: float) -> void:
	ProfileStore.music_volume = value
	AudioManager.set_music_volume(value)
	ProfileStore.save_profile()
	if is_instance_valid(content_detail):
		content_detail.text = "Music %d%%    SFX %d%%\nFull controls are available from the match pause menu." % [roundi(ProfileStore.music_volume * 100.0), roundi(ProfileStore.effects_volume * 100.0)]

func _on_sfx_volume_changed(value: float) -> void:
	ProfileStore.effects_volume = value
	AudioManager.set_sfx_volume(value)
	ProfileStore.save_profile()
	if is_instance_valid(content_detail):
		content_detail.text = "Music %d%%    SFX %d%%\nFull controls are available from the match pause menu." % [roundi(ProfileStore.music_volume * 100.0), roundi(ProfileStore.effects_volume * 100.0)]

func show_section(section: String) -> void:
	active_section = section
	if section == "SETTINGS":
		_build_settings_controls()
		if is_instance_valid(music_slider):
			music_slider.set_value_no_signal(ProfileStore.music_volume)
		if is_instance_valid(sfx_slider):
			sfx_slider.set_value_no_signal(ProfileStore.effects_volume)
	for nav_name: String in nav_buttons:
		var nav_button: Button = nav_buttons[nav_name]
		nav_button.add_theme_color_override("font_color", GREEN if nav_name == section else MUTED)
	match section:
		"HOME":
			content_title.text = "ETHAN FC"
			content_detail.text = "4-3-3   /   CLUB LEVEL %02d\nReady for a new challenge." % ProfileStore.player_level
		"SQUAD":
			content_title.text = "MY TEAM"
			content_detail.text = _get_roster_summary()
		"EVENTS":
			content_title.text = "MATCH EVENTS"
			content_detail.text = "Career season: %s\nLeague points: %d" % ["ACTIVE" if ProfileStore.career_active else "NOT STARTED", ProfileStore.career_points]
		"SHOP":
			content_title.text = "CLUB SHOP"
			content_detail.text = "Coin balance: %s\nPack store arrives in the progression step." % _format_number(ProfileStore.coins)
		"SETTINGS":
			content_title.text = "SETTINGS"
			content_detail.text = "Music %d%%    SFX %d%%\nFull controls are available from the match pause menu." % [roundi(ProfileStore.music_volume * 100.0), roundi(ProfileStore.effects_volume * 100.0)]
		_:
			content_title.text = "ETHAN FC"
			content_detail.text = "Choose a mode to get started."

func _get_roster_summary() -> String:
	var file := FileAccess.open(PLAYER_DATA_PATH, FileAccess.READ)
	if file == null:
		return "Fictional club roster unavailable."
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return "Fictional club roster could not be read."
	var players: Array = parsed.get("players", [])
	return "%d fictional players\nFormation editor arrives in the team-building step." % players.size()

func _start_quick_match() -> void:
	GameState.start_match("ethan_fc")
	get_tree().change_scene_to_packed(MATCH_SCENE)

func _open_team_management() -> void:
	get_tree().change_scene_to_file("res://scenes/team_management.tscn")

func _open_progression() -> void:
	get_tree().change_scene_to_file("res://scenes/progression_shop.tscn")

func _start_career() -> void:
	ProfileStore.start_career()
	GameState.start_match("ethan_fc")
	get_tree().change_scene_to_packed(MATCH_SCENE)

func _show_status(message: String) -> void:
	status_label.text = message
