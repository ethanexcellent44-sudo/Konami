extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var profile: Node = root.get_node_or_null("ProfileStore")
	if profile == null:
		_fail("ProfileStore autoload is missing")
		return
	var saved_path: String = str(profile.get("save_path"))
	var profile_state: Dictionary = _capture_profile(profile)
	profile.set("save_path", "user://progression_test_%d.cfg" % Time.get_ticks_usec())
	profile.set("coins", 2000)
	profile.set("player_level", 1)
	profile.set("player_experience", 0)
	profile.set("owned_player_ids", PackedStringArray())
	profile.set("team_lineup", PackedStringArray(["owned_a"]))
	profile.set("daily_reward_last_claim", "")
	profile.set("daily_reward_streak", 0)
	profile.set("mission_matches_played", 0)
	profile.set("mission_match_wins", 0)
	profile.set("mission_goals_scored", 0)
	profile.set("claimed_missions", PackedStringArray())

	var award: int = int(profile.call("award_match_progress", 2, 1))
	if award <= 0 or int(profile.get("coins")) <= 2000:
		_fail("Match rewards did not grant coins")
		_restore_profile(profile, saved_path, profile_state)
		return
	var mission: Dictionary = profile.call("get_mission_progress", "play_3")
	if int(mission.progress) != 1:
		_fail("Match did not increment mission progress")
		_restore_profile(profile, saved_path, profile_state)
		return
	profile.set("mission_matches_played", 3)
	profile.set("mission_match_wins", 2)
	profile.set("mission_goals_scored", 5)
	if not bool(profile.call("claim_mission", "win_2")) or bool(profile.call("claim_mission", "win_2")):
		_fail("Mission rewards were not claimable exactly once")
		_restore_profile(profile, saved_path, profile_state)
		return

	var daily_reward: Dictionary = profile.call("claim_daily_reward")
	if not bool(daily_reward.get("claimed", false)) or bool(profile.call("can_claim_daily_reward")):
		_fail("Daily reward did not enforce a once-per-day claim")
		_restore_profile(profile, saved_path, profile_state)
		return

	var pack_pool: Array[Dictionary] = [
		{"id": "owned_a", "name": "Already Owned", "rarity": "common"},
		{"id": "pack_a", "name": "Pack Player A", "rarity": "common"},
		{"id": "pack_b", "name": "Pack Player B", "rarity": "rare"}
	]
	var coins_before_pack: int = int(profile.get("coins"))
	var pack_result: Dictionary = profile.call("purchase_player_pack", 500, pack_pool)
	if not bool(pack_result.get("purchased", false)) or int(profile.get("coins")) != coins_before_pack - 500:
		_fail("Player pack purchase did not deduct its price")
		_restore_profile(profile, saved_path, profile_state)
		return
	var packed_player: Dictionary = pack_result.get("player", {})
	if str(packed_player.get("id", "")) == "owned_a" or not profile.get("owned_player_ids").has(str(packed_player.get("id", ""))):
		_fail("Player pack granted a duplicate or failed to save ownership")
		_restore_profile(profile, saved_path, profile_state)
		return
	profile.set("coins", 0)
	if bool(profile.call("purchase_player_pack", 500, pack_pool).get("purchased", false)):
		_fail("Pack purchase succeeded without enough coins")
		_restore_profile(profile, saved_path, profile_state)
		return
	profile.set("coins", 2000)
	profile.set("owned_player_ids", PackedStringArray())
	profile.set("team_lineup", PackedStringArray())
	var bundle_result: Dictionary = profile.call("purchase_player_pack_bundle", 900, 2, pack_pool)
	var bundle_players: Array = bundle_result.get("players", [])
	if not bool(bundle_result.get("purchased", false)) or bundle_players.size() != 2 or int(profile.get("coins")) != 1100:
		_fail("Multi-card pack did not grant unique cards for one exact price")
		_restore_profile(profile, saved_path, profile_state)
		return
	if str(bundle_players[0].get("id", "")) == str(bundle_players[1].get("id", "")):
		_fail("A player pack granted the same player twice")
		_restore_profile(profile, saved_path, profile_state)
		return

	print("PASS: match XP/coins, missions, daily rewards, and duplicate-free packs")
	_restore_profile(profile, saved_path, profile_state)
	quit()

func _capture_profile(profile: Node) -> Dictionary:
	var state: Dictionary = {}
	for property_name: String in [
		"coins", "player_level", "player_experience", "owned_player_ids", "team_lineup",
		"daily_reward_last_claim", "daily_reward_streak", "mission_match_wins",
		"mission_matches_played", "mission_goals_scored", "claimed_missions"
	]:
		state[property_name] = profile.get(property_name)
	return state

func _restore_profile(profile: Node, saved_path: String, state: Dictionary) -> void:
	for property_name: String in state:
		profile.set(property_name, state[property_name])
	profile.set("save_path", saved_path)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
