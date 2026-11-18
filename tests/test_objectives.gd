extends "res://tests/test_base.gd"
## S32 objective system refinement: the five objective kinds from the
## roadmap are formalized, and the SURVIVE win condition is a genuinely new
## defensive mode — highest remaining health at the turn limit wins.

const MATCH_STATE := "res://scripts/match/match_state.gd"
const TURN_MANAGER := "res://scripts/match/turn_manager.gd"
const GAME_MODE := "res://scripts/match/game_mode.gd"


func _survive_state():
	var s = load(MATCH_STATE).new()
	s.begin_match(PackedStringArray(["Strider", "Standard"]), 100.0, 15.0, 5)
	var mode: Resource = load("res://data/modes/survive.tres")
	s.setup_mode(mode, [])
	return {"state": s, "mode": mode}


func test_survive_mode_resource_exists() -> void:
	var mode: Resource = load("res://data/modes/survive.tres")
	assert_true(mode != null, "survive.tres loads")
	assert_equal(mode.mode_name, "Survive", "survive mode name")
	assert_equal(int(mode.win_condition), 4, "SURVIVE win condition")


func test_survive_mode_wins_at_turn_limit_by_health() -> void:
	var arena = _survive_state()
	var s = arena["state"]
	# Damage Standard so Strider has more health at the limit.
	s.apply_damage("Standard", 30.0)
	# Advance turns to the limit.
	for i in int(arena["mode"].survive_turns):
		s.turn_number = i + 1
	var positions := {"Strider": Vector2(0, 0), "Standard": Vector2(10, 0)}
	var winner: String = s.tick_mode(0.016, positions, false)
	assert_equal(winner, "Strider",
			"at the turn limit, higher health wins (Strider 100 vs Standard 70)")


func test_survive_mode_tie_continues() -> void:
	var arena = _survive_state()
	var s = arena["state"]
	# Both at full health: tied at the limit → no winner yet.
	for i in int(arena["mode"].survive_turns):
		s.turn_number = i + 1
	assert_equal(s.tick_mode(0.016, {"Strider": Vector2(0, 0), "Standard": Vector2(10, 0)},
			false), "", "tied health continues the match")


func test_survive_turn_limit_gates_the_evaluation() -> void:
	var arena = _survive_state()
	var s = arena["state"]
	s.apply_damage("Standard", 30.0)
	# Before the limit: no winner declared yet.
	s.turn_number = int(arena["mode"].survive_turns) - 1
	assert_equal(s.tick_mode(0.016, {}, false), "", "no win before the turn limit")


func test_objective_kind_constants_match_roadmap() -> void:
	var obj = load("res://scripts/terrain/map_objective.gd")
	assert_equal(obj.KIND_CAPTURE, "control_zone", "Capture = control zone hold")
	assert_equal(obj.KIND_DESTROY, "siege_target", "Destroy = structure demolition")
	assert_equal(obj.KIND_REACH, "checkpoint", "Reach = ordered checkpoints")
	# SURVIVE and ESCORT are mode-level rules (no map region needed for
	# survive; escort needs NPCs from S43).


func test_all_maps_support_survive() -> void:
	for path in ["res://data/maps/canyon.tres", "res://data/maps/floating_islands.tres",
			"res://data/maps/industrial_ruins.tres"]:
		var map: Resource = load(path)
		assert_true("Survive" in map.supported_modes,
				"%s supports Survive (it needs no map objectives)" % path.get_file())
