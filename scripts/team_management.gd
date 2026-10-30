extends Control

const TEAM_DATA_PATH: String = "res://data/teams.json"
const PLAYER_DATA_PATH: String = "res://data/players.json"
const NAVY: Color = Color("#0b1530")
const GREEN: Color = Color("#22e07a")
const GOLD: Color = Color("#f0a500")
const PAPER: Color = Color("#f3f6f2")
const MUTED: Color = Color("#a8b2c6")
const SLOT_ORDER_433: Array[String] = ["GK", "LB", "CB", "CB", "RB", "CM", "CM", "CM", "LW", "ST", "RW"]
const SLOT_ORDER_442: Array[String] = ["GK", "LB", "CB", "CB", "RB", "LM", "CM", "CM", "RM", "ST", "ST"]

var roster: Array[Dictionary] = []
var lineup_ids: Array[String] = []
var formation: String = "4-3-3"
var selected_roster_id: String = ""
var slot_buttons: Array[Button] = []
var roster_container: VBoxContainer
var detail_panel: VBoxContainer
var formation_button: OptionButton
var status_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_data()
	_build_ui()
	_refresh_lineup()
	_refresh_roster()
	_show_player_detail(_get_selected_player())

func _load_data() -> void:
	var teams: Dictionary = _read_json(TEAM_DATA_PATH)
	var players: Dictionary = _read_json(PLAYER_DATA_PATH)
	var team_data: Dictionary = {}
	for entry: Variant in teams.get("teams", []):
		if entry is Dictionary and str(entry.get("id", "")) == "ethan_fc":
			team_data = entry
			break
	if team_data.is_empty():
		push_error("Ethan FC team data is missing")
		return
	formation = str(ProfileStore.team_formation)
	if formation not in ["4-3-3", "4-4-2"]:
		formation = str(team_data.get("formation", "4-3-3"))
	var player_by_id: Dictionary = {}
	for player_entry: Variant in players.get("players", []):
		if player_entry is Dictionary:
			player_by_id[str(player_entry.get("id", ""))] = player_entry
	var starter_ids: Array = team_data.get("player_ids", [])
	for player_id: String in starter_ids:
		if player_by_id.has(player_id):
			roster.append(player_by_id[player_id])
			lineup_ids.append(player_id)
	for player_id: String in team_data.get("reserve_ids", []):
		if player_by_id.has(player_id):
			roster.append(player_by_id[player_id])
	var saved_lineup: PackedStringArray = ProfileStore.team_lineup
	if saved_lineup.size() == 11:
		var valid_saved_lineup: bool = true
		var unique_ids: Dictionary = {}
		for player_id: String in saved_lineup:
			if not player_by_id.has(player_id) or unique_ids.has(player_id):
				valid_saved_lineup = false
				break
			unique_ids[player_id] = true
		if valid_saved_lineup:
			lineup_ids.clear()
			for player_id: String in saved_lineup:
				lineup_ids.append(player_id)

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var result: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return result as Dictionary if result is Dictionary else {}

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = NAVY
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var wash := ColorRect.new()
	wash.color = Color(0.11, 0.18, 0.29, 0.12)
	wash.anchor_right = 1.0
	wash.anchor_bottom = 1.0
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	var top_bar := ColorRect.new()
	top_bar.color = Color(0.025, 0.055, 0.12, 0.98)
	top_bar.anchor_right = 1.0
	top_bar.offset_bottom = 76.0
	add_child(top_bar)
	var back_button := _make_button("<  HOME", false)
	back_button.position = Vector2(28.0, 18.0)
	back_button.size = Vector2(118.0, 42.0)
	back_button.pressed.connect(_return_home)
	add_child(back_button)
	var heading := _make_label("SQUAD MANAGEMENT", 23, PAPER)
	heading.position = Vector2(170.0, 22.0)
	heading.size = Vector2(440.0, 34.0)
	add_child(heading)
	var club_tag := _make_label("ETHAN FC   /   FIRST TEAM", 11, GREEN)
	club_tag.position = Vector2(174.0, 52.0)
	club_tag.size = Vector2(300.0, 18.0)
	add_child(club_tag)
	var formation_caption := _make_label("FORMATION", 11, MUTED)
	formation_caption.anchor_left = 1.0
	formation_caption.anchor_right = 1.0
	formation_caption.offset_left = -306.0
	formation_caption.offset_right = -214.0
	formation_caption.offset_top = 24.0
	formation_caption.offset_bottom = 44.0
	add_child(formation_caption)
	formation_button = OptionButton.new()
	formation_button.name = "FormationOption"
	formation_button.anchor_left = 1.0
	formation_button.anchor_right = 1.0
	formation_button.offset_left = -204.0
	formation_button.offset_right = -34.0
	formation_button.offset_top = 17.0
	formation_button.offset_bottom = 55.0
	formation_button.add_item("4-3-3")
	formation_button.add_item("4-4-2")
	formation_button.select(0 if formation == "4-3-3" else 1)
	formation_button.item_selected.connect(_on_formation_selected)
	add_child(formation_button)

	var left_panel := _make_panel(Color(0.025, 0.06, 0.13, 0.96), Color(0.35, 0.53, 0.64, 0.25))
	left_panel.position = Vector2(28.0, 98.0)
	left_panel.size = Vector2(610.0, 554.0)
	add_child(left_panel)
	var lineup_title := _make_label("STARTING XI", 13, GREEN)
	lineup_title.position = Vector2(50.0, 113.0)
	lineup_title.size = Vector2(300.0, 24.0)
	add_child(lineup_title)
	var formation_subtitle := _make_label("SELECT A SLOT, THEN A PLAYER TO SWAP", 10, MUTED)
	formation_subtitle.position = Vector2(50.0, 138.0)
	formation_subtitle.size = Vector2(460.0, 18.0)
	add_child(formation_subtitle)
	var pitch := Panel.new()
	pitch.name = "FormationPitch"
	pitch.position = Vector2(56.0, 176.0)
	pitch.size = Vector2(550.0, 440.0)
	var pitch_style := StyleBoxFlat.new()
	pitch_style.bg_color = Color(0.055, 0.30, 0.18, 0.95)
	pitch_style.border_color = Color(0.72, 0.88, 0.78, 0.42)
	pitch_style.set_border_width_all(1)
	pitch_style.set_corner_radius_all(3)
	pitch.add_theme_stylebox_override("panel", pitch_style)
	add_child(pitch)
	var pitch_lines := _make_label("────────────────────────────────", 10, Color(0.78, 0.91, 0.82, 0.42))
	pitch_lines.position = Vector2(105.0, 392.0)
	pitch_lines.size = Vector2(420.0, 20.0)
	add_child(pitch_lines)

	var right_panel := _make_panel(Color(0.025, 0.06, 0.13, 0.96), Color(0.35, 0.53, 0.64, 0.25))
	right_panel.position = Vector2(662.0, 98.0)
	right_panel.size = Vector2(590.0, 554.0)
	add_child(right_panel)
	var roster_heading := _make_label("SQUAD", 13, GREEN)
	roster_heading.position = Vector2(686.0, 113.0)
	roster_heading.size = Vector2(300.0, 24.0)
	add_child(roster_heading)
	var roster_hint := _make_label("TAP A CARD TO INSPECT OR SWAP", 10, MUTED)
	roster_hint.position = Vector2(686.0, 138.0)
	roster_hint.size = Vector2(350.0, 18.0)
	add_child(roster_hint)
	var roster_scroll := ScrollContainer.new()
	roster_scroll.name = "RosterScroll"
	roster_scroll.position = Vector2(682.0, 170.0)
	roster_scroll.size = Vector2(332.0, 455.0)
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(roster_scroll)
	roster_container = VBoxContainer.new()
	roster_container.name = "RosterCards"
	roster_container.custom_minimum_size.x = 315.0
	roster_container.add_theme_constant_override("separation", 7)
	roster_scroll.add_child(roster_container)
	var divider := ColorRect.new()
	divider.color = Color(0.45, 0.58, 0.72, 0.25)
	divider.position = Vector2(1028.0, 174.0)
	divider.size = Vector2(1.0, 450.0)
	add_child(divider)
	detail_panel = VBoxContainer.new()
	detail_panel.name = "PlayerDetails"
	detail_panel.position = Vector2(1048.0, 178.0)
	detail_panel.size = Vector2(184.0, 430.0)
	detail_panel.add_theme_constant_override("separation", 10)
	add_child(detail_panel)
	status_label = _make_label("", 12, GOLD)
	status_label.anchor_left = 0.5
	status_label.anchor_right = 0.5
	status_label.anchor_top = 1.0
	status_label.anchor_bottom = 1.0
	status_label.offset_left = -280.0
	status_label.offset_right = 280.0
	status_label.offset_top = -60.0
	status_label.offset_bottom = -32.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)

func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_panel(background_color: Color, border_color: Color) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	var normal := StyleBoxFlat.new()
	normal.bg_color = GREEN if primary else Color(0.04, 0.09, 0.17, 0.98)
	normal.border_color = GREEN if not primary else Color(0.0, 0.0, 0.0, 0.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.36, 0.93, 0.61) if primary else Color(0.09, 0.16, 0.27)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", NAVY if primary else PAPER)
	button.add_theme_color_override("font_hover_color", NAVY if primary else GREEN)
	return button

func _refresh_lineup() -> void:
	for old_button: Button in slot_buttons:
		old_button.queue_free()
	slot_buttons.clear()
	var formation_slots: Array[String] = SLOT_ORDER_433.duplicate() if formation == "4-3-3" else SLOT_ORDER_442.duplicate()
	var row_indices: Array[Array] = [[0], [1, 2, 3, 4], [5, 6, 7] if formation == "4-3-3" else [5, 6, 7, 8], [8, 9, 10] if formation == "4-3-3" else [9, 10]]
	var row_y: Array[float] = [564.0, 450.0, 342.0, 228.0]
	for row_index in range(row_indices.size()):
		var slots: Array = row_indices[row_index]
		var spacing: float = 500.0 / float(maxi(1, slots.size()))
		for column_index in range(slots.size()):
			var lineup_index: int = int(slots[column_index])
			if lineup_index >= lineup_ids.size() or lineup_index >= formation_slots.size():
				continue
			if formation == "4-4-2" and lineup_index >= 9:
				formation_slots[lineup_index] = "ST"
			var player: Dictionary = _player_by_id(lineup_ids[lineup_index])
			var card := Button.new()
			card.name = "LineupSlot_%d" % lineup_index
			card.position = Vector2(78.0 + spacing * (float(column_index) + 0.5) - 48.0, row_y[row_index])
			card.size = Vector2(96.0, 58.0)
			card.text = "%s  %02d\n%s" % [formation_slots[lineup_index], int(player.get("overall", 0)), str(player.get("name", "Player"))]
			card.focus_mode = Control.FOCUS_NONE
			card.add_theme_font_size_override("font_size", 10)
			var is_selected: bool = selected_roster_id == lineup_ids[lineup_index]
			var slot_style := StyleBoxFlat.new()
			slot_style.bg_color = Color(0.03, 0.12, 0.10, 0.96) if not is_selected else Color(0.10, 0.24, 0.16, 0.98)
			slot_style.border_color = GOLD if is_selected else GREEN
			slot_style.set_border_width_all(1)
			slot_style.set_corner_radius_all(4)
			card.add_theme_stylebox_override("normal", slot_style)
			card.add_theme_stylebox_override("hover", slot_style)
			card.add_theme_color_override("font_color", PAPER)
			card.pressed.connect(func() -> void: _on_slot_selected(lineup_index))
			add_child(card)
			slot_buttons.append(card)

func _refresh_roster() -> void:
	for child: Node in roster_container.get_children():
		child.queue_free()
	for player: Dictionary in roster:
		var card := Button.new()
		card.name = "RosterCard_" + str(player.get("id", ""))
		card.custom_minimum_size = Vector2(310.0, 58.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.text = "%s  %02d   %s\n%s    %s" % [str(player.get("position", "-")), int(player.get("overall", 0)), str(player.get("name", "Player")), str(player.get("rarity", "common")).to_upper(), "STARTING XI" if lineup_ids.has(str(player.get("id", ""))) else "RESERVE"]
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_font_size_override("font_size", 12)
		var rarity_color: Color = GOLD if str(player.get("rarity", "common")) == "rare" else Color(0.12, 0.19, 0.31, 0.98)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.04, 0.09, 0.17, 0.98)
		card_style.border_color = rarity_color
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(4)
		card.add_theme_stylebox_override("normal", card_style)
		card.add_theme_stylebox_override("hover", card_style)
		card.add_theme_color_override("font_color", PAPER)
		var player_id: String = str(player.get("id", ""))
		card.pressed.connect(func() -> void: _on_roster_player_selected(player_id))
		roster_container.add_child(card)

func _show_player_detail(player: Dictionary) -> void:
	for child: Node in detail_panel.get_children():
		child.queue_free()
	var overall := _make_label("%02d" % int(player.get("overall", 0)), 34, GOLD)
	overall.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_panel.add_child(overall)
	var position_label := _make_label(str(player.get("position", "PLAYER")), 12, GREEN)
	position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_panel.add_child(position_label)
	var name_label := _make_label(str(player.get("name", "Select a player")), 15, PAPER)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(name_label)
	var rarity_label := _make_label(str(player.get("rarity", "common")).to_upper() + " CARD", 10, GOLD if str(player.get("rarity", "common")) == "rare" else MUTED)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_panel.add_child(rarity_label)
	var stats: Dictionary = player.get("stats", {})
	for stat_name: String in ["PAC", "SHO", "PAS", "DRI", "DEF", "PHY"]:
		var value: int = int(stats.get(stat_name, 0))
		var stat_row := HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 5)
		var stat_label := _make_label(stat_name, 10, MUTED)
		stat_label.custom_minimum_size.x = 34.0
		stat_row.add_child(stat_label)
		var stat_bar := ProgressBar.new()
		stat_bar.custom_minimum_size = Vector2(92.0, 14.0)
		stat_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_bar.min_value = 0
		stat_bar.max_value = 100
		stat_bar.value = value
		stat_bar.show_percentage = false
		var background := StyleBoxFlat.new()
		background.bg_color = Color(0.08, 0.12, 0.20)
		background.set_corner_radius_all(3)
		var fill := StyleBoxFlat.new()
		fill.bg_color = GREEN if value >= 70 else GOLD if value >= 55 else Color(0.83, 0.53, 0.28)
		fill.set_corner_radius_all(3)
		stat_bar.add_theme_stylebox_override("background", background)
		stat_bar.add_theme_stylebox_override("fill", fill)
		stat_row.add_child(stat_bar)
		var value_label := _make_label(str(value), 10, PAPER)
		value_label.custom_minimum_size.x = 23.0
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_row.add_child(value_label)
		detail_panel.add_child(stat_row)

func _get_selected_player() -> Dictionary:
	return _player_by_id(selected_roster_id if not selected_roster_id.is_empty() else lineup_ids[0] if not lineup_ids.is_empty() else "")

func _player_by_id(player_id: String) -> Dictionary:
	for player: Dictionary in roster:
		if str(player.get("id", "")) == player_id:
			return player
	return {}

func _on_roster_player_selected(player_id: String) -> void:
	selected_roster_id = player_id
	_show_player_detail(_player_by_id(player_id))
	var slot_index: int = lineup_ids.find(player_id)
	if slot_index >= 0:
		status_label.text = "IN STARTING XI  /  SELECT ANOTHER SLOT TO SWAP"
	else:
		status_label.text = "SELECT A STARTING SLOT TO REPLACE"
	_refresh_lineup()
	_refresh_roster()

func _on_slot_selected(slot_index: int) -> void:
	if selected_roster_id.is_empty():
		selected_roster_id = lineup_ids[slot_index]
		_show_player_detail(_player_by_id(selected_roster_id))
		_refresh_lineup()
		return
	var current_index: int = lineup_ids.find(selected_roster_id)
	if current_index < 0:
		var reserve_index: int = -1
		for index in range(roster.size()):
			if str(roster[index].get("id", "")) == selected_roster_id:
				reserve_index = index
				break
		if reserve_index < 0:
			return
		var outgoing_id: String = lineup_ids[slot_index]
		lineup_ids[slot_index] = selected_roster_id
		roster[reserve_index] = _player_by_id(outgoing_id)
	else:
		var swap_id: String = lineup_ids[slot_index]
		lineup_ids[slot_index] = selected_roster_id
		lineup_ids[current_index] = swap_id
	selected_roster_id = lineup_ids[slot_index]
	_save_lineup()
	_refresh_lineup()
	_refresh_roster()
	_show_player_detail(_player_by_id(selected_roster_id))
	status_label.text = "LINE-UP UPDATED  /  %s" % formation

func _on_formation_selected(index: int) -> void:
	formation = "4-3-3" if index == 0 else "4-4-2"
	ProfileStore.team_formation = formation
	ProfileStore.save_profile()
	_refresh_lineup()
	status_label.text = "FORMATION SAVED  /  " + formation

func _save_lineup() -> void:
	var saved_ids: PackedStringArray = []
	for player_id: String in lineup_ids:
		saved_ids.append(player_id)
	ProfileStore.team_lineup = saved_ids
	ProfileStore.save_profile()

func _return_home() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
