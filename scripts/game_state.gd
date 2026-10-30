extends Node

signal kickoff(team_id: String)
signal goal(team_id: String, scorer_id: String)
signal foul(team_id: String, player_id: String, reason: String)
signal match_period_changed(period: String)
signal match_finished(home_score: int, away_score: int)

var home_score: int = 0
var away_score: int = 0
var current_period: String = "pre_match"
var active_match: bool = false

func start_match(first_team_id: String = "ethan") -> void:
	home_score = 0
	away_score = 0
	active_match = true
	set_match_period("first_half")
	kickoff.emit(first_team_id)

func award_goal(team_id: String, scorer_id: String = "") -> void:
	if not active_match:
		return
	if team_id == "home":
		home_score += 1
	elif team_id == "away":
		away_score += 1
	else:
		push_warning("Ignoring goal for unknown team: %s" % team_id)
		return
	goal.emit(team_id, scorer_id)

func report_foul(team_id: String, player_id: String, reason: String) -> void:
	foul.emit(team_id, player_id, reason)

func set_match_period(period: String) -> void:
	current_period = period
	match_period_changed.emit(period)
	if period == "full_time":
		active_match = false
		match_finished.emit(home_score, away_score)
