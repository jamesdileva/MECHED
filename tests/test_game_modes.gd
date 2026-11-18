extends "res://tests/test_base.gd"
## S31 game modes: win conditions evaluated purely over entity positions —
## Control hold accumulation, Mobility Race checkpoints, Siege demolition vs
## turn limit, and per-map mode support filtering.

const MATCH_STATE := "res://scripts/match/match_state.gd"
const GAME_MODE := "res://scripts/match/game_mode.gd"
const MODE_SELECT := "res://scenes/menus/mode_select.tscn"
const EPS := 0.0001

var _names := PackedStringArray(["Strider", "Standard"])


func _state(mode_name: String, objectives: Array) -> Object:
	var s = load(MATCH_STATE).new()
	s.begin_match(_names, 100.0, 15.0, 5)
	var mode: Resource = load("res://data/modes/%s.tres" % mode_name.to_lower().replace(" ", "_"))
	s.setup_mode(mode, objectives)
	return s


func _control_zone() -> Array:
	return [{"objective_name": "zone", "kind": "control_zone",
			"region": Rect2(0, 0, 4, 4), "order": 0, "structure_name": ""}]


func _checkpoints() -> Array:
	var out: Array = []
	for i in 3:
		out.append({"objective_name": "cp%d" % i, "kind": "checkpoint",
				"region": Rect2(i * 10, 0, 2, 4), "order": i, "structure_name": ""})
	return out


func test_control_accumulates_hold_inside_zone() -> void:
	var s = _state("Control", _control_zone())
	var positions := {"Strider": Vector2(1, 1), "Standard": Vector2(30, 1)}
	var winner := ""
	for i in int(s.game_mode.hold_time_to_win):
		winner = s.tick_mode(1.0, positions, false)
		if winner != "":
			break
	assert_equal(winner, "Strider",
			"first to complete the hold wins (%ds)" % int(s.game_mode.hold_time_to_win))


func test_control_pauses_when_outside_the_zone() -> void:
	var s = _state("Control", _control_zone())
	var inside := {"Strider": Vector2(1, 1)}
	s.tick_mode(2.0, inside, false)
	var outside := {"Strider": Vector2(40, 1)}
	for i in 5:
		s.tick_mode(1.0, outside, false)
	assert_almost_equal(s.hold_progress["Strider"], 2.0, EPS,
			"time spent outside the zone does not count (2s banked)")
	# 2s banked + 8s more = 10 → wins.
	var back := {"Strider": Vector2(1, 1)}
	var winner := ""
	for i in 8:
		winner = s.tick_mode(1.0, back, false)
	assert_equal(winner, "Strider", "hold completes after returning")


func test_race_progresses_through_ordered_checkpoints() -> void:
	var s = _state("Mobility Race", _checkpoints())
	var pos := {"Strider": Vector2(1, 1), "Standard": Vector2(100, 1)}
	# At checkpoint 0 (x 0..2): progress 0 → 1.
	assert_equal(s.tick_mode(0.016, pos, false), "", "no win at the first gate")
	assert_equal(s.race_progress["Strider"], 1, "checkpoint 0 reached")
	# Jump to checkpoint 2 region without visiting 1: NOT counted.
	var skipped := {"Strider": Vector2(21, 1)}
	s.tick_mode(0.016, skipped, false)
	assert_equal(s.race_progress["Strider"], 1, "checkpoints must be visited in order")
	# Through gate 1 then gate 2 → wins.
	var at1 := {"Strider": Vector2(11, 1), "Standard": Vector2(100, 1)}
	s.tick_mode(0.016, at1, false)
	var at2 := {"Strider": Vector2(21, 1), "Standard": Vector2(100, 1)}
	var winner: String = s.tick_mode(0.016, at2, false)
	assert_equal(winner, "Strider", "final checkpoint wins the race")


func test_siege_attacker_wins_by_demolition() -> void:
	var s = _state("Siege", [])
	var winner: String = s.tick_mode(0.016, {}, true)
	assert_equal(winner, "Strider", "attacker (first entity) wins by collapsing the target")


func test_siege_defender_wins_on_turn_limit() -> void:
	var s = _state("Siege", [])
	# Burn turns past the siege limit: each turn increments turn_number.
	var tm = load("res://scripts/match/turn_manager.gd").new()
	tm.begin_match(_names)
	tm.state.game_mode = s.game_mode
	tm.state.setup_mode(s.game_mode, [])
	var turns := int(s.game_mode.siege_turns)
	for i in turns:
		tm.submit_action(load("res://scripts/match/action_end_turn.gd").new(), i % 2)
	assert_true(int(tm.state.turn_number) >= turns,
			"turn limit reached after alternating turns")
	# Siege expiry is evaluated on the mode tick: turn_number > siege_turns.
	var s2 = load(MATCH_STATE).new()
	s2.begin_match(_names, 100.0, 15.0, 5)
	s2.game_mode = s.game_mode
	s2.setup_mode(s.game_mode, [])
	s2.turn_number = turns + 1
	var winner: String = s2.tick_mode(0.016, {}, false)
	assert_equal(winner, "Standard", "defender (second entity) wins the limit")


func test_maps_declare_supported_modes() -> void:
	var canyon: Resource = load("res://data/maps/canyon.tres")
	var islands: Resource = load("res://data/maps/floating_islands.tres")
	var ruins: Resource = load("res://data/maps/industrial_ruins.tres")
	assert_true("Siege" in canyon.supported_modes, "Canyon supports Siege (bridge)")
	assert_true("Siege" in ruins.supported_modes, "Ruins supports Siege (scaffold)")
	assert_true(not ("Siege" in islands.supported_modes),
			"Islands has no structure — Siege unsupported")
	assert_true("Mobility Race" in islands.supported_modes,
			"Islands is the Mobility Race map")


func test_mode_select_scene_lists_supported_modes() -> void:
	var scene: PackedScene = load("res://scenes/menus/mode_select.tscn")
	assert_true(scene != null, "mode_select.tscn loads")
	if scene == null:
		return
	var select: Node = scene.instantiate()
	assert_true(select.get_node_or_null("%ModeButtons") != null, "mode buttons container exists")
	select.free()
