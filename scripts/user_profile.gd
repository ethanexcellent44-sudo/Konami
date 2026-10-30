extends Node
class_name UserProfile

const SAVE_PATH := "user://ethan_profile.cfg"
var save_path: String = SAVE_PATH

var half_length: float = 90.0
var difficulty: float = 1.0
var home_color: int = 0
var away_color: int = 0
var touch_scale: float = 1.0
var joystick_x: float = 110.0
var action_button_offset: float = 0.0
var music_volume: float = 0.7
var effects_volume: float = 0.85
var player_level: int = 1
var player_experience: int = 0
var coins: int = 12450
var team_formation: String = "4-3-3"
var team_lineup: PackedStringArray = PackedStringArray()
var owned_player_ids: PackedStringArray = PackedStringArray()
var daily_reward_last_claim: String = ""
var daily_reward_streak: int = 0
var mission_match_wins: int = 0
var mission_matches_played: int = 0
var mission_goals_scored: int = 0
var claimed_missions: PackedStringArray = PackedStringArray()
var tournament_played: int = 0
var tournament_wins: int = 0
var tournament_draws: int = 0
var tournament_losses: int = 0
var best_shooting_score: int = 0
var best_passing_score: int = 0
var tournament_active: bool = false
var tournament_matches_remaining: int = 0
var tournament_points: int = 0
var tournament_goal_difference: int = 0
var tournament_fixture_index: int = 0
var tournament_results: Array[Dictionary] = []
var tactical_preset: int = 1
var match_history: Array[Dictionary] = []
var key_bindings: Dictionary = {}
var opponent_style: int = 1
var career_active: bool = false
var career_fixtures_remaining: int = 6
var career_points: int = 0
var career_goal_difference: int = 0
var career_upgrade_points: int = 0
var career_results: Array[Dictionary] = []
var player_speed_upgrade: int = 0
var player_shot_upgrade: int = 0
var local_multiplayer_enabled: bool = false
var game_speed: float = 1.0
var ui_scale: float = 1.0
var high_contrast: bool = false
var weather_mode: int = 0
var training_best_defending: int = 0

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	_ensure_gamepad_bindings()
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	for property_name in [
		"half_length", "difficulty", "home_color", "away_color", "touch_scale",
		"joystick_x", "action_button_offset", "music_volume", "effects_volume",
		"player_level", "player_experience", "coins", "team_formation", "tournament_played", "tournament_wins",
		"tournament_draws", "tournament_losses", "best_shooting_score", "best_passing_score",
		"tournament_active", "tournament_matches_remaining", "tournament_points",
		"tournament_goal_difference", "tournament_fixture_index",
		"tactical_preset", "key_bindings", "opponent_style", "career_active",
		"career_fixtures_remaining", "career_points", "career_goal_difference",
		"career_upgrade_points", "player_speed_upgrade", "player_shot_upgrade",
		"local_multiplayer_enabled", "game_speed", "ui_scale", "high_contrast",
		"weather_mode", "training_best_defending"
	]:
		set(property_name, config.get_value("profile", property_name, get(property_name)))
	var loaded_history: Variant = config.get_value("profile", "match_history", [])
	match_history.clear()
	if loaded_history is Array:
		for summary in loaded_history:
			if summary is Dictionary:
				match_history.append(summary)
	var loaded_tournament_results: Variant = config.get_value("profile", "tournament_results", [])
	tournament_results.clear()
	if loaded_tournament_results is Array:
		for result in loaded_tournament_results:
			if result is Dictionary:
				tournament_results.append(result)
	var loaded_career_results: Variant = config.get_value("profile", "career_results", [])
	career_results.clear()
	if loaded_career_results is Array:
		for result in loaded_career_results:
			if result is Dictionary:
				career_results.append(result)
	var loaded_bindings: Variant = config.get_value("profile", "key_bindings", {})
	if loaded_bindings is Dictionary:
		key_bindings = loaded_bindings
	_apply_key_bindings()
	var loaded_lineup: Variant = config.get_value("profile", "team_lineup", PackedStringArray())
	if loaded_lineup is PackedStringArray:
		team_lineup = loaded_lineup
	elif loaded_lineup is Array:
		team_lineup = PackedStringArray(loaded_lineup)
	var loaded_owned_players: Variant = config.get_value("profile", "owned_player_ids", PackedStringArray())
	if loaded_owned_players is PackedStringArray:
		owned_player_ids = loaded_owned_players
	elif loaded_owned_players is Array:
		owned_player_ids = PackedStringArray(loaded_owned_players)
	var loaded_missions: Variant = config.get_value("profile", "claimed_missions", PackedStringArray())
	if loaded_missions is PackedStringArray:
		claimed_missions = loaded_missions
	elif loaded_missions is Array:
		claimed_missions = PackedStringArray(loaded_missions)

func save_profile() -> void:
	var config := ConfigFile.new()
	for property_name in [
		"half_length", "difficulty", "home_color", "away_color", "touch_scale",
		"joystick_x", "action_button_offset", "music_volume", "effects_volume",
		"player_level", "player_experience", "coins", "team_formation", "tournament_played", "tournament_wins",
		"tournament_draws", "tournament_losses", "best_shooting_score", "best_passing_score",
		"tournament_active", "tournament_matches_remaining", "tournament_points",
		"tournament_goal_difference", "tournament_fixture_index",
		"tactical_preset", "match_history", "key_bindings", "opponent_style",
		"career_active", "career_fixtures_remaining", "career_points",
		"career_goal_difference", "career_upgrade_points", "player_speed_upgrade",
		"player_shot_upgrade", "local_multiplayer_enabled", "game_speed", "ui_scale",
		"high_contrast", "weather_mode", "training_best_defending"
	]:
		config.set_value("profile", property_name, get(property_name))
	config.set_value("profile", "team_lineup", team_lineup)
	config.set_value("profile", "owned_player_ids", owned_player_ids)
	config.set_value("profile", "daily_reward_last_claim", daily_reward_last_claim)
	config.set_value("profile", "daily_reward_streak", daily_reward_streak)
	config.set_value("profile", "mission_match_wins", mission_match_wins)
	config.set_value("profile", "mission_matches_played", mission_matches_played)
	config.set_value("profile", "mission_goals_scored", mission_goals_scored)
	config.set_value("profile", "claimed_missions", claimed_missions)
	config.set_value("profile", "tournament_results", tournament_results)
	config.set_value("profile", "career_results", career_results)
	config.save(save_path)

func set_key_binding(action_name: String, physical_keycode: int) -> void:
	key_bindings[action_name] = physical_keycode
	_apply_key_binding(action_name, physical_keycode)
	save_profile()

func start_tournament() -> void:
	career_active = false
	career_results.clear()
	tournament_active = true
	tournament_matches_remaining = 6
	tournament_points = 0
	tournament_goal_difference = 0
	tournament_fixture_index = 0
	tournament_results.clear()
	save_profile()

func record_tournament_result(home_score: int, away_score: int) -> bool:
	if not tournament_active:
		return false
	var opponent_name := get_tournament_opponent_name()
	tournament_played += 1
	tournament_matches_remaining = maxi(0, tournament_matches_remaining - 1)
	tournament_goal_difference += home_score - away_score
	tournament_fixture_index += 1
	if home_score > away_score:
		tournament_wins += 1
		tournament_points += 3
	elif home_score == away_score:
		tournament_draws += 1
		tournament_points += 1
	else:
		tournament_losses += 1
	tournament_results.append({
		"opponent": opponent_name,
		"home_score": home_score,
		"away_score": away_score,
		"points": 3 if home_score > away_score else (1 if home_score == away_score else 0)
	})
	if tournament_matches_remaining == 0:
		tournament_active = false
	save_profile()
	return true

func get_tournament_opponent_name() -> String:
	var opponent_names := ["Harbor Athletic", "Pinebridge FC", "Redvale Rovers", "Northgate United", "Lakeview City", "Eastfield Town"]
	return opponent_names[posmod(tournament_fixture_index, opponent_names.size())]

func get_tournament_fixture_name(index: int) -> String:
	var opponent_names := ["Harbor Athletic", "Pinebridge FC", "Redvale Rovers", "Northgate United", "Lakeview City", "Eastfield Town"]
	return opponent_names[posmod(index, opponent_names.size())]

func start_career() -> void:
	tournament_active = false
	tournament_results.clear()
	career_active = true
	career_fixtures_remaining = 6
	career_points = 0
	career_goal_difference = 0
	career_upgrade_points = 0
	career_results.clear()
	save_profile()

func record_career_result(home_score: int, away_score: int) -> void:
	if not career_active:
		return
	var opponent_name := get_career_opponent_name()
	career_fixtures_remaining = maxi(0, career_fixtures_remaining - 1)
	career_goal_difference += home_score - away_score
	career_results.append({
		"opponent": opponent_name,
		"home_score": home_score,
		"away_score": away_score,
		"points": 3 if home_score > away_score else (1 if home_score == away_score else 0)
	})
	if home_score > away_score:
		career_points += 3
		career_upgrade_points += 2
	elif home_score == away_score:
		career_points += 1
		career_upgrade_points += 1
	if career_fixtures_remaining == 0:
		career_active = false
	save_profile()

func get_career_opponent_name() -> String:
	return get_career_fixture_name(6 - career_fixtures_remaining)

func get_career_fixture_name(index: int) -> String:
	var opponent_names := ["Meadow FC", "Stonehaven", "Westport Albion", "Cedar United", "Southbank Rovers", "Hillcrest"]
	return opponent_names[posmod(index, opponent_names.size())]

func purchase_upgrade(attribute: String) -> bool:
	if career_upgrade_points <= 0:
		return false
	if attribute == "speed":
		player_speed_upgrade += 1
	elif attribute == "shot":
		player_shot_upgrade += 1
	else:
		return false
	career_upgrade_points -= 1
	save_profile()
	return true

func record_match(summary: Dictionary) -> void:
	match_history.push_front(summary.duplicate(true))
	if match_history.size() > 10:
		match_history.resize(10)
	save_profile()

func _apply_key_bindings() -> void:
	for action_name: String in key_bindings:
		_apply_key_binding(action_name, int(key_bindings[action_name]))

func _apply_key_binding(action_name: String, physical_keycode: int) -> void:
	if not InputMap.has_action(action_name):
		return
	var events := InputMap.action_get_events(action_name)
	for event in events:
		if event is InputEventKey:
			InputMap.action_erase_event(action_name, event)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	key_event.keycode = physical_keycode
	InputMap.action_add_event(action_name, key_event)

func _ensure_gamepad_bindings() -> void:
	var stick_actions := {
		"move_left": [0, -1.0],
		"move_right": [0, 1.0],
		"move_forward": [1, -1.0],
		"move_back": [1, 1.0]
	}
	for action_name: String in stick_actions:
		var has_axis := false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventJoypadMotion and event.device == 0:
				has_axis = true
				break
		if not has_axis:
			var axis_event := InputEventJoypadMotion.new()
			axis_event.device = 0
			axis_event.axis = stick_actions[action_name][0]
			axis_event.axis_value = stick_actions[action_name][1]
			InputMap.action_add_event(action_name, axis_event)
	var button_actions := {
		"pass_ball": JOY_BUTTON_A,
		"shoot_ball": JOY_BUTTON_B,
		"through_ball": JOY_BUTTON_X,
		"sprint": JOY_BUTTON_Y,
		"slide_tackle": JOY_BUTTON_RIGHT_SHOULDER,
		"switch_player": JOY_BUTTON_LEFT_SHOULDER,
		"camera_view": JOY_BUTTON_RIGHT_STICK,
		"pause_game": JOY_BUTTON_START
	}
	for action_name: String in button_actions:
		var has_button := false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventJoypadButton and event.device == 0:
				has_button = true
				break
		if not has_button:
			var button_event := InputEventJoypadButton.new()
			button_event.device = 0
			button_event.button_index = button_actions[action_name]
			InputMap.action_add_event(action_name, button_event)
	var local_actions := {
		"p2_move_left": [KEY_A, 0, -1.0],
		"p2_move_right": [KEY_D, 0, 1.0],
		"p2_move_forward": [KEY_W, 1, -1.0],
		"p2_move_back": [KEY_S, 1, 1.0]
	}
	for action_name: String in local_actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var axis_value: Array = local_actions[action_name]
		var has_key := false
		var has_axis := false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				has_key = true
			elif event is InputEventJoypadMotion and event.device == 1:
				has_axis = true
		if not has_key:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = axis_value[0]
			key_event.keycode = axis_value[0]
			InputMap.action_add_event(action_name, key_event)
		if not has_axis:
			var axis_event := InputEventJoypadMotion.new()
			axis_event.device = 1
			axis_event.axis = axis_value[1]
			axis_event.axis_value = axis_value[2]
			InputMap.action_add_event(action_name, axis_event)
	var p2_buttons := {
		"p2_pass": [KEY_U, JOY_BUTTON_A],
		"p2_shoot": [KEY_O, JOY_BUTTON_B],
		"p2_sprint": [KEY_I, JOY_BUTTON_X],
		"p2_tackle": [KEY_P, JOY_BUTTON_RIGHT_SHOULDER]
	}
	for action_name: String in p2_buttons:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var bindings: Array = p2_buttons[action_name]
		var key_found := false
		var button_found := false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				key_found = true
			elif event is InputEventJoypadButton and event.device == 1:
				button_found = true
		if not key_found:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = bindings[0]
			key_event.keycode = bindings[0]
			InputMap.action_add_event(action_name, key_event)
		if not button_found:
			var button_event := InputEventJoypadButton.new()
			button_event.device = 1
			button_event.button_index = bindings[1]
			InputMap.action_add_event(action_name, button_event)

func award_experience(amount: int) -> void:
	var previous_level: int = player_level
	player_experience += maxi(0, amount)
	while player_experience >= player_level * 100:
		player_experience -= player_level * 100
		player_level += 1
	if player_level > previous_level:
		coins += (player_level - previous_level) * 250
	save_profile()

func award_match_progress(home_score: int, away_score: int) -> int:
	var coin_reward: int = 100 + home_score * 20 + (150 if home_score > away_score else 50 if home_score == away_score else 0)
	coins += coin_reward
	mission_matches_played += 1
	mission_goals_scored += maxi(0, home_score)
	if home_score > away_score:
		mission_match_wins += 1
	award_experience(50 + home_score * 5 + (25 if home_score > away_score else 0))
	save_profile()
	return coin_reward

func can_claim_daily_reward() -> bool:
	return daily_reward_last_claim != Time.get_date_string_from_system()

func claim_daily_reward() -> Dictionary:
	if not can_claim_daily_reward():
		return {"claimed": false, "coins": 0, "streak": daily_reward_streak}
	var today: String = Time.get_date_string_from_system()
	var today_date: Dictionary = Time.get_date_dict_from_system()
	var yesterday_unix: int = int(Time.get_unix_time_from_datetime_dict(today_date)) - 86400
	var yesterday_parts: Dictionary = Time.get_datetime_dict_from_unix_time(yesterday_unix)
	var yesterday: String = "%04d-%02d-%02d" % [int(yesterday_parts.get("year", 0)), int(yesterday_parts.get("month", 0)), int(yesterday_parts.get("day", 0))]
	daily_reward_streak = mini(daily_reward_streak + 1, 7) if daily_reward_last_claim == yesterday else 1
	var reward_coins: int = 250 + (daily_reward_streak - 1) * 50
	coins += reward_coins
	daily_reward_last_claim = today
	save_profile()
	return {"claimed": true, "coins": reward_coins, "streak": daily_reward_streak}

func get_mission_progress(mission_id: String) -> Dictionary:
	match mission_id:
		"play_3":
			return {"progress": mini(mission_matches_played, 3), "target": 3, "reward": 400}
		"win_2":
			return {"progress": mini(mission_match_wins, 2), "target": 2, "reward": 600}
		"score_5":
			return {"progress": mini(mission_goals_scored, 5), "target": 5, "reward": 500}
		_:
			return {"progress": 0, "target": 1, "reward": 0}

func claim_mission(mission_id: String) -> bool:
	if claimed_missions.has(mission_id):
		return false
	var mission: Dictionary = get_mission_progress(mission_id)
	if int(mission.progress) < int(mission.target):
		return false
	coins += int(mission.reward)
	claimed_missions.append(mission_id)
	save_profile()
	return true

func purchase_player_pack(cost: int, player_pool: Array[Dictionary]) -> Dictionary:
	return purchase_player_pack_bundle(cost, 1, player_pool)

func purchase_player_pack_bundle(cost: int, card_count: int, player_pool: Array[Dictionary]) -> Dictionary:
	if cost <= 0 or card_count <= 0 or coins < cost or player_pool.is_empty():
		return {"purchased": false, "player": {}}
	var eligible: Array[Dictionary] = _eligible_pack_players(player_pool)
	if eligible.is_empty():
		return {"purchased": false, "player": {}}
	coins -= cost
	var picked_players: Array[Dictionary] = []
	for card_index in range(mini(card_count, eligible.size())):
		var picked_index: int = randi_range(0, eligible.size() - 1)
		var picked_player: Dictionary = eligible.pop_at(picked_index)
		var player_id: String = str(picked_player.get("id", ""))
		owned_player_ids.append(player_id)
		picked_players.append(picked_player.duplicate(true))
	save_profile()
	return {"purchased": true, "players": picked_players, "player": picked_players[0]}

func _eligible_pack_players(player_pool: Array[Dictionary]) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for player: Dictionary in player_pool:
		var player_id: String = str(player.get("id", ""))
		if not owned_player_ids.has(player_id) and not team_lineup.has(player_id):
			eligible.append(player)
	return eligible

func update_drill_best(drill: String, score: int) -> void:
	if drill == "shooting":
		best_shooting_score = maxi(best_shooting_score, score)
	elif drill == "passing":
		best_passing_score = maxi(best_passing_score, score)
	elif drill == "defending":
		training_best_defending = maxi(training_best_defending, score)
	save_profile()