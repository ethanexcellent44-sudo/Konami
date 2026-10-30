extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var team_scene: PackedScene = load("res://scenes/team_management.tscn")
	if team_scene == null:
		_fail("Team management scene failed to load")
		return
	var team_screen: Control = team_scene.instantiate() as Control
	root.add_child(team_screen)
	await process_frame
	var profile: Node = root.get_node_or_null("ProfileStore")
	var roster: Array = team_screen.get("roster")
	var lineup: Array = team_screen.get("lineup_ids")
	if roster.size() != 16 or lineup.size() != 11:
		_fail("Team screen did not load a 16-player roster and starting XI")
		team_screen.queue_free()
		return
	var detail_panel: VBoxContainer = team_screen.get("detail_panel") as VBoxContainer
	if detail_panel == null or detail_panel.get_child_count() < 9:
		_fail("Player card details and six attribute rows were not rendered")
		team_screen.queue_free()
		return
	team_screen.call("_on_formation_selected", 1)
	if str(team_screen.get("formation")) != "4-4-2" or str(profile.get("team_formation")) != "4-4-2":
		_fail("Formation selection did not update and persist the profile setting")
		team_screen.queue_free()
		return
	var reserve_id: String = str(roster[11].get("id", ""))
	var outgoing_id: String = str(lineup[1])
	team_screen.call("_on_roster_player_selected", reserve_id)
	team_screen.call("_on_slot_selected", 1)
	roster = team_screen.get("roster")
	lineup = team_screen.get("lineup_ids")
	if str(lineup[1]) != reserve_id:
		_fail("Selected reserve was not promoted into the chosen starting slot")
		team_screen.queue_free()
		return
	if not lineup.has(outgoing_id) and not roster.any(func(player: Dictionary) -> bool: return str(player.get("id", "")) == outgoing_id):
		_fail("Outgoing starter was not retained in the squad roster")
		team_screen.queue_free()
		return
	var saved_lineup: PackedStringArray = profile.get("team_lineup")
	if saved_lineup.size() != 11 or saved_lineup[1] != reserve_id:
		_fail("Starting XI changes were not saved to the profile")
		team_screen.queue_free()
		return
	print("PASS: squad roster, player stats, formation persistence, and reserve substitution")
	team_screen.queue_free()
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
