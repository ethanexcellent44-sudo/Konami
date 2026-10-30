extends SceneTree

var goal_events: int = 0
var kickoff_events: int = 0
var restart_events: Array[String] = []
var finished_events: int = 0
var foul_events: int = 0

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var pitch_scene: PackedScene = load("res://scenes/pitch_2d.tscn")
	if pitch_scene == null:
		_fail("2D pitch scene failed to load")
		return
	var pitch: Node2D = pitch_scene.instantiate() as Node2D
	root.add_child(pitch)
	await physics_frame
	var rules: Node = pitch.get_node_or_null("MatchRules2D")
	var ball: RigidBody2D = pitch.get_node_or_null("FootballBall2D") as RigidBody2D
	var game_state: Node = root.get_node_or_null("GameState")
	if rules == null or ball == null:
		_fail("2D match rules or ball failed to initialize")
		pitch.queue_free()
		return
	if str(rules.get("match_state")) != "live":
		_fail("Match did not enter live play after kickoff")
		pitch.queue_free()
		return
	var pause_panel: Control = rules.get_node("MatchRulesHUD/PausePanel") as Control
	var pause_overlay: Control = rules.get_node("MatchRulesHUD/PauseOverlay") as Control
	var score_label: Label = rules.get_node("MatchRulesHUD/ScoreClockPanel/ScoreLabel") as Label
	var touch_controls: Control = pitch.get_node("Player2D/PlayerControlsLayer/VirtualTouchControls") as Control
	var touch_toggle: CheckButton = rules.get_node("MatchRulesHUD/PausePanel/TouchControlsToggle") as CheckButton
	if pause_panel == null or pause_overlay == null or score_label == null or touch_controls == null or touch_toggle == null:
		_fail("Match HUD is missing expected score or pause controls")
		pitch.queue_free()
		return
	rules.call("toggle_pause")
	if str(rules.get("match_state")) != "paused" or not pause_panel.visible or not pause_overlay.visible or not paused:
		_fail("Pause action did not freeze play and show the pause menu")
		pitch.queue_free()
		return
	touch_toggle.button_pressed = false
	touch_toggle.toggled.emit(false)
	if touch_controls.visible:
		_fail("Pause touch toggle did not hide virtual controls")
		pitch.queue_free()
		return
	touch_toggle.button_pressed = true
	touch_toggle.toggled.emit(true)
	if not touch_controls.visible:
		_fail("Pause touch toggle did not restore virtual controls")
		pitch.queue_free()
		return
	rules.call("toggle_pause")
	if str(rules.get("match_state")) != "live" or pause_panel.visible or pause_overlay.visible or paused:
		_fail("Resume action did not hide the menu and resume play")
		pitch.queue_free()
		return

	game_state.goal.connect(func(_team_id: String, _scorer_id: String) -> void: goal_events += 1)
	game_state.kickoff.connect(func(_team_id: String) -> void: kickoff_events += 1)
	game_state.match_finished.connect(func(_home: int, _away: int) -> void: finished_events += 1)
	game_state.foul.connect(func(_team: String, _player: String, _reason: String) -> void: foul_events += 1)
	rules.connect("restart_awarded", func(kind: String, team: String) -> void: restart_events.append(kind + ":" + team))

	ball.global_position = Vector2(640.0, 20.0)
	rules.call("_check_ball_boundaries")
	if int(rules.get("home_score")) != 1 or goal_events != 1:
		_fail("Ball crossing the upper goal did not award a home goal")
		pitch.queue_free()
		return
	if not score_label.text.contains("1"):
		_fail("Match HUD score did not update after a goal")
		pitch.queue_free()
		return
	if str(rules.get("match_state")) != "restart":
		_fail("Scored goal did not enter kickoff restart state")
		pitch.queue_free()
		return

	rules.set("match_state", "live")
	rules.set("last_touch_team", "home")
	ball.global_position = Vector2(22.0, 360.0)
	rules.call("_check_ball_boundaries")
	if restart_events.is_empty() or restart_events[0] != "throw_in:away":
		_fail("Touchline exit did not award a throw-in to the opposite team")
		pitch.queue_free()
		return
	if kickoff_events != 1:
		_fail("Non-kickoff restarts incorrectly emitted kickoff events")
		pitch.queue_free()
		return
	var away_players: Array = rules.get("away_team").get("players")
	var nearest_restart_player_distance: float = INF
	for restart_player: Node2D in away_players:
		nearest_restart_player_distance = minf(nearest_restart_player_distance, restart_player.global_position.distance_to(ball.global_position))
	if nearest_restart_player_distance > 40.0:
		_fail("Awarded restart player was not positioned at the ball")
		pitch.queue_free()
		return

	rules.set("match_state", "live")
	rules.set("last_touch_team", "home")
	ball.global_position = Vector2(220.0, 18.0)
	rules.call("_check_ball_boundaries")
	if restart_events.size() < 2 or restart_events[1] != "goal_kick:away":
		_fail("Goal-line exit after an attacking touch did not award a goal kick")
		pitch.queue_free()
		return

	rules.set("match_state", "live")
	var human_player: Node2D = pitch.get_node("Player2D") as Node2D
	var away_players_for_foul: Array = rules.get("away_team").get("players")
	(away_players_for_foul[5] as Node2D).global_position = human_player.global_position + Vector2(12.0, 0.0)
	rules.call("_on_human_tackle", human_player.global_position)
	if foul_events != 1 or restart_events.size() < 3 or restart_events[2] != "free_kick:away":
		_fail("A close tackle foul did not emit a foul event and award a free kick")
		pitch.queue_free()
		return

	rules.set("match_state", "live")
	rules.set("current_half", 1)
	rules.set("elapsed_seconds", 90.0)
	rules.set("half_duration_seconds", 90.0)
	rules.call("_update_clock")
	if str(rules.get("match_state")) != "half_time" or not paused:
		_fail("First half did not stop at halftime")
		pitch.queue_free()
		return
	rules.call("_on_period_button_pressed")
	if int(rules.get("current_half")) != 2 or str(rules.get("match_state")) != "live":
		_fail("Continue action did not begin the second half")
		pitch.queue_free()
		return
	rules.set("elapsed_seconds", 180.0)
	rules.set("half_duration_seconds", 90.0)
	rules.call("_update_clock")
	if str(rules.get("match_state")) != "full_time" or finished_events != 1:
		_fail("Second-half expiry did not emit full-time match result")
		pitch.queue_free()
		return
	print("PASS: kickoff, goals, throw-ins, goal kicks, halftime, and full-time flow")
	paused = false
	pitch.queue_free()
	quit()

func _fail(message: String) -> void:
	push_error(message)
	paused = false
	quit(1)
