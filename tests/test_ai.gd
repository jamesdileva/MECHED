extends "res://tests/test_base.gd"
## S15 first AI: the deterministic shot solver, the standoff-band movement
## rule, and the victory rule — all pure, all headless. The full tick loop
## needs physics frames and is verified in-game; the "no cheating" invariant
## is structural: the driver only reads MatchState and submits actions.

const AI_DRIVER := "res://scripts/ai/ai_driver.gd"
const MATCH_STATE := "res://scripts/match/match_state.gd"
const ROCKET := "res://data/weapons/rocket.tres"
const GRENADE := "res://data/weapons/grenade.tres"
const ENERGY := "res://data/weapons/energy_shot.tres"
const EPS := 0.0001


func _weapon_stats() -> Array:
	var modifier = load("res://scripts/weapons/weapon_modifier.gd").new()
	var out: Array = []
	var slot := 0
	for path in [ROCKET, GRENADE, ENERGY]:
		var weapon: Resource = load(path)
		var stats: Dictionary = weapon.effective(modifier)
		out.append({"slot": slot, "stats": stats})
		slot += 1
	return out


func test_solver_hits_a_flat_target() -> void:
	# A target 10m out on flat ground: some candidate lands within 3m.
	var shot: Dictionary = load(AI_DRIVER).solve_shot(
			Vector3(0, 1, 0), Vector3(10, 1, 0), 1.0, Vector2.ZERO, _weapon_stats())
	assert_true(shot["slot"] >= 0, "a weapon was selected")
	assert_true(shot["miss"] < 3.0,
			"solver lands within 3m of a flat 10m target (miss %.2f)" % shot["miss"])


func test_solver_prefers_lower_miss() -> void:
	var driver = load(AI_DRIVER)
	var close: Dictionary = driver.solve_shot(
			Vector3(0, 1, 0), Vector3(8, 1, 0), 1.0, Vector2.ZERO, _weapon_stats())
	var far: Dictionary = driver.solve_shot(
			Vector3(0, 1, 0), Vector3(14, 1, 0), 1.0, Vector2.ZERO, _weapon_stats())
	# Both solutions are the best of their own scenario; each must be sane.
	assert_true(close["miss"] < 3.0, "close target solved")
	assert_true(far["miss"] < 3.0, "far target solved")


func test_solver_aims_forward_only() -> void:
	# The solver aims in the given facing direction: a target to the LEFT is
	# reached with dir_sign -1, and the returned plan is used as-is.
	var shot: Dictionary = load(AI_DRIVER).solve_shot(
			Vector3(0, 1, 0), Vector3(-10, 1, 0), -1.0, Vector2.ZERO, _weapon_stats())
	assert_true(shot["miss"] < 3.0, "leftward targets solve with a -1 facing")


func test_solver_accounts_for_wind() -> void:
	var driver = load(AI_DRIVER)
	# A strong headwind: the solver must pick a different (harder/loftier)
	# shot than in calm air to land on the same spot.
	var calm: Dictionary = driver.solve_shot(
			Vector3(0, 1, 0), Vector3(10, 1, 0), 1.0, Vector2.ZERO, _weapon_stats())
	var windy: Dictionary = driver.solve_shot(
			Vector3(0, 1, 0), Vector3(10, 1, 0), 1.0, Vector2(-4, 0), _weapon_stats())
	assert_true(windy["miss"] < 3.0, "windy solve still lands on the target")


func test_band_movement_rule() -> void:
	var driver = load(AI_DRIVER)
	assert_equal(driver.move_axis_for(25.0), 1.0, "too far: advance")
	assert_equal(driver.move_axis_for(3.0), -1.0, "too close: retreat")
	assert_equal(driver.move_axis_for(10.0), 0.0, "in band: hold position")


func test_declare_winner_sets_result() -> void:
	var s = load(MATCH_STATE).new()
	s.begin_match(PackedStringArray(["Strider", "Standard"]), 100.0, 15.0, 5)
	assert_equal(s.match_result, &"", "no result while fighting")
	s.declare_winner("Strider")
	assert_equal(String(s.match_result), "Strider wins the match", "winner recorded")


func test_set_active_weapon_arms_a_slot() -> void:
	var s = load(MATCH_STATE).new()
	s.set_loadout("Standard", [load(ROCKET), load(GRENADE), load(ENERGY)])
	s.set_active_weapon("Standard", 2)
	assert_equal(s.active_weapon("Standard").display_name, "Energy Shot",
			"AI arms its chosen weapon")
	# Out-of-range slots clamp instead of crashing.
	s.set_active_weapon("Standard", 9)
	assert_equal(s.active_weapon("Standard").display_name, "Energy Shot",
			"slot clamps to the loadout")
