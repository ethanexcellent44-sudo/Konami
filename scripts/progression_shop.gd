extends Control

const PLAYER_DATA_PATH: String = "res://data/players.json"
const NAVY: Color = Color("#0b1530")
const GREEN: Color = Color("#22e07a")
const GOLD: Color = Color("#f0a500")
const PAPER: Color = Color("#f3f6f2")
const MUTED: Color = Color("#a8b2c6")
const BASIC_PACK_COST: int = 800
const PREMIUM_PACK_COST: int = 1800

var player_pool: Array[Dictionary] = []
var coin_label: Label
var status_label: Label
var daily_button: Button
var daily_detail: Label
var mission_rows: Dictionary = {}
var owned_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_player_pool()
	_build_ui()
	_refresh_all()

func _load_player_pool() -> void:
	var file := FileAccess.open(PLAYER_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	for player: Variant in parsed.get("players", []):
		if player is Dictionary:
			player_pool.append(player)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = NAVY
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
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
	var title := _make_label("CLUB PROGRESSION", 23, PAPER)
	title.position = Vector2(170.0, 22.0)
	title.size = Vector2(400.0, 34.0)
	add_child(title)
	var level := _make_label("LEVEL %02d   /   %d XP" % [ProfileStore.player_level, ProfileStore.player_experience], 12, GREEN)
	level.anchor_left = 1.0
	level.anchor_right = 1.0
	level.offset_left = -460.0
	level.offset_right = -285.0
	level.offset_top = 27.0
	level.offset_bottom = 48.0
	add_child(level)
	coin_label = _make_label("COINS  %s" % _format_number(ProfileStore.coins), 15, GOLD)
	coin_label.anchor_left = 1.0
	coin_label.anchor_right = 1.0
	coin_label.offset_left = -260.0
	coin_label.offset_right = -32.0
	coin_label.offset_top = 25.0
	coin_label.offset_bottom = 51.0
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(coin_label)

	var daily_panel := _make_panel(Vector2(34.0, 105.0), Vector2(360.0, 202.0), Color(0.025, 0.06, 0.13, 0.97), GREEN)
	add_child(daily_panel)
	var daily_title := _make_label("DAILY REWARD", 14, GREEN)
	daily_title.position = Vector2(58.0, 127.0)
	daily_title.size = Vector2(260.0, 24.0)
	add_child(daily_title)
	daily_detail = _make_label("Claim today's club bonus", 16, PAPER)
	daily_detail.position = Vector2(58.0, 167.0)
	daily_detail.size = Vector2(300.0, 54.0)
	daily_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(daily_detail)
	daily_button = _make_button("CLAIM DAILY REWARD", true)
	daily_button.position = Vector2(58.0, 237.0)
	daily_button.size = Vector2(305.0, 48.0)
	daily_button.pressed.connect(_claim_daily_reward)
	add_child(daily_button)

	var missions_panel := _make_panel(Vector2(34.0, 332.0), Vector2(590.0, 306.0), Color(0.025, 0.06, 0.13, 0.97), Color(0.38, 0.52, 0.72, 0.52))
	add_child(missions_panel)
	var missions_title := _make_label("CLUB MISSIONS", 14, GREEN)
	missions_title.position = Vector2(58.0, 354.0)
	missions_title.size = Vector2(260.0, 24.0)
	add_child(missions_title)
	_add_mission_row("play_3", "MATCH READY", "Play 3 matches", Vector2(58.0, 394.0))
	_add_mission_row("win_2", "WIN TWO", "Win 2 matches", Vector2(58.0, 465.0))
	_add_mission_row("score_5", "FIVE GOALS", "Score 5 goals", Vector2(58.0, 536.0))

	var shop_panel := _make_panel(Vector2(652.0, 105.0), Vector2(594.0, 533.0), Color(0.025, 0.06, 0.13, 0.97), Color(0.38, 0.52, 0.72, 0.52))
	add_child(shop_panel)
	var shop_title := _make_label("PLAYER PACKS", 14, GREEN)
	shop_title.position = Vector2(676.0, 127.0)
	shop_title.size = Vector2(280.0, 24.0)
	add_child(shop_title)
	var shop_caption := _make_label("Fictional player cards  /  duplicate-free", 12, MUTED)
	shop_caption.position = Vector2(676.0, 154.0)
	shop_caption.size = Vector2(500.0, 22.0)
	add_child(shop_caption)
	_add_pack_card("STARTER PACK", "3 player cards  /  guaranteed common or better", BASIC_PACK_COST, Vector2(676.0, 194.0), false)
	_add_pack_card("CLUB PACK", "3 player cards  /  rare chance increased", PREMIUM_PACK_COST, Vector2(676.0, 333.0), true)
	owned_label = _make_label("OWNED PLAYERS  /  0", 12, GOLD)
	owned_label.position = Vector2(676.0, 491.0)
	owned_label.size = Vector2(500.0, 22.0)
	add_child(owned_label)
	var roster_scroll := ScrollContainer.new()
	roster_scroll.name = "OwnedPlayersScroll"
	roster_scroll.position = Vector2(676.0, 518.0)
	roster_scroll.size = Vector2(535.0, 94.0)
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(roster_scroll)
	var owned_list := VBoxContainer.new()
	owned_list.name = "OwnedPlayersList"
	owned_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_scroll.add_child(owned_list)
	var footer := _make_label("Level-ups grant 250 coins per level. Match rewards add coins and XP.", 11, MUTED)
	footer.position = Vector2(42.0, 667.0)
	footer.size = Vector2(850.0, 22.0)
	add_child(footer)
	status_label = _make_label("", 13, GOLD)
	status_label.anchor_left = 0.5
	status_label.anchor_right = 0.5
	status_label.anchor_top = 1.0
	status_label.anchor_bottom = 1.0
	status_label.offset_left = -260.0
	status_label.offset_right = 260.0
	status_label.offset_top = -50.0
	status_label.offset_bottom = -24.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)

func _add_mission_row(mission_id: String, title_text: String, description: String, location: Vector2) -> void:
	var row_panel := _make_panel(location, Vector2(540.0, 58.0), Color(0.04, 0.09, 0.17, 0.94), Color(0.35, 0.48, 0.66, 0.25))
	add_child(row_panel)
	var mission_title := _make_label(title_text, 11, PAPER)
	mission_title.position = location + Vector2(14.0, 8.0)
	mission_title.size = Vector2(130.0, 18.0)
	add_child(mission_title)
	var mission_detail := _make_label(description, 10, MUTED)
	mission_detail.position = location + Vector2(14.0, 31.0)
	mission_detail.size = Vector2(190.0, 18.0)
	add_child(mission_detail)
	var progress_label := _make_label("0 / 0", 11, GOLD)
	progress_label.position = location + Vector2(240.0, 20.0)
	progress_label.size = Vector2(72.0, 18.0)
	add_child(progress_label)
	var claim_button := _make_button("CLAIM", false)
	claim_button.position = location + Vector2(400.0, 9.0)
	claim_button.size = Vector2(124.0, 40.0)
	claim_button.pressed.connect(func() -> void: _claim_mission(mission_id))
	add_child(claim_button)
	mission_rows[mission_id] = {"progress": progress_label, "button": claim_button}

func _add_pack_card(title_text: String, description: String, cost: int, location: Vector2, premium: bool) -> void:
	var border: Color = GOLD if premium else GREEN
	var pack_panel := _make_panel(location, Vector2(540.0, 120.0), Color(0.04, 0.09, 0.17, 0.98), border)
	add_child(pack_panel)
	var pack_title := _make_label(title_text, 16, PAPER)
	pack_title.position = location + Vector2(18.0, 17.0)
	pack_title.size = Vector2(300.0, 25.0)
	add_child(pack_title)
	var pack_description := _make_label(description, 11, MUTED)
	pack_description.position = location + Vector2(18.0, 51.0)
	pack_description.size = Vector2(315.0, 42.0)
	pack_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(pack_description)
	var purchase_button := _make_button("BUY  %s" % _format_number(cost), premium)
	purchase_button.position = location + Vector2(368.0, 34.0)
	purchase_button.size = Vector2(150.0, 50.0)
	purchase_button.pressed.connect(func() -> void: _purchase_pack(cost, 3, premium))
	add_child(purchase_button)

func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_panel(location: Vector2, dimensions: Vector2, background_color: Color, border_color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = location
	panel.size = dimensions
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

func _refresh_all() -> void:
	coin_label.text = "COINS  %s" % _format_number(ProfileStore.coins)
	daily_button.disabled = not ProfileStore.can_claim_daily_reward()
	daily_button.text = "CLAIMED TODAY" if daily_button.disabled else "CLAIM DAILY REWARD"
	daily_detail.text = "Streak %d days  /  Today's reward: %d coins" % [ProfileStore.daily_reward_streak, 250 + ProfileStore.daily_reward_streak * 50]
	for mission_id: String in mission_rows:
		var mission: Dictionary = ProfileStore.get_mission_progress(mission_id)
		var row: Dictionary = mission_rows[mission_id]
		(row.progress as Label).text = "%d / %d   +%d" % [int(mission.progress), int(mission.target), int(mission.reward)]
		var claimed: bool = ProfileStore.claimed_missions.has(mission_id)
		(row.button as Button).disabled = claimed or int(mission.progress) < int(mission.target)
		(row.button as Button).text = "CLAIMED" if claimed else "CLAIM"
	_refresh_owned_players()

func _claim_daily_reward() -> void:
	var reward: Dictionary = ProfileStore.claim_daily_reward()
	if bool(reward.get("claimed", false)):
		_show_status("DAILY BONUS  /  +%d COINS  /  STREAK %d" % [int(reward.coins), int(reward.streak)])
	else:
		_show_status("DAILY REWARD ALREADY CLAIMED")
	_refresh_all()

func _claim_mission(mission_id: String) -> void:
	if ProfileStore.claim_mission(mission_id):
		_show_status("MISSION COMPLETE  /  COINS ADDED")
	else:
		_show_status("MISSION NOT READY")
	_refresh_all()

func _purchase_pack(cost: int, card_count: int, premium: bool) -> void:
	var result: Dictionary = ProfileStore.purchase_player_pack_bundle(cost, card_count, player_pool)
	if not bool(result.get("purchased", false)):
		_show_status("NOT ENOUGH COINS OR NO NEW CARDS AVAILABLE")
		_refresh_all()
		return
	var awarded_names: Array[String] = []
	var rare_bonus: int = 0
	for player: Dictionary in result.get("players", []):
		awarded_names.append(str(player.get("name", player.get("id", "Player"))))
		if premium and str(player.get("rarity", "common")) == "rare":
			rare_bonus += 75
	if rare_bonus > 0:
		ProfileStore.coins += rare_bonus
		ProfileStore.save_profile()
	_show_status("PACK: " + ", ".join(awarded_names))
	_refresh_all()

func _refresh_owned_players() -> void:
	owned_label.text = "OWNED PLAYER CARDS  /  %d" % ProfileStore.owned_player_ids.size()
	var list: VBoxContainer = get_node("OwnedPlayersScroll/OwnedPlayersList") as VBoxContainer
	for child: Node in list.get_children():
		child.queue_free()
	var player_by_id: Dictionary = {}
	for player: Dictionary in player_pool:
		player_by_id[str(player.get("id", ""))] = player
	for player_id: String in ProfileStore.owned_player_ids:
		if not player_by_id.has(player_id):
			continue
		var player: Dictionary = player_by_id[player_id]
		var card_label := _make_label("%s  %s  %02d  /  %s" % [str(player.get("position", "-")), str(player.get("name", "Player")), int(player.get("overall", 0)), str(player.get("rarity", "common")).to_upper()], 11, GOLD if str(player.get("rarity", "common")) == "rare" else PAPER)
		card_label.custom_minimum_size.y = 20.0
		list.add_child(card_label)

func _format_number(value: int) -> String:
	var text: String = str(maxi(value, 0))
	var formatted: String = ""
	for index in range(text.length()):
		if index > 0 and (text.length() - index) % 3 == 0:
			formatted += ","
		formatted += text.substr(index, 1)
	return formatted

func _show_status(message: String) -> void:
	status_label.text = message

func _return_home() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
