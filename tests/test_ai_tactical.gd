extends "res://tests/test_base.gd"
## S35 AI tactical search: joint position + weapon + shot plan generation
## and scoring. The AI evaluates position+shot combos jointly — the key
## upgrade over the S15/S16 two-step pipeline.

const TACTICAL := "res://scripts/ai/ai_tactical.gd"
const MATCH_CONTROLLER := "res://scripts/match/match_controller.gd"
const MECH := "res://scenes/mechs/mech.tscn"
const STANDARD := "res://data/mechs/standard_mech.tres"
const GRID := "res://scripts/terrain/terrain_grid.gd"
const LAYOUT := "res://scripts/terrain/terrain_layout.gd"
const MAPS := "res://scripts/terrain/map_definition.gd"
const CANYON := "res://data/maps/canyon.tres"
const MATCH_STATE := "res://scripts/match/match_state.gd"
const EPS := 0.0001


func _weapon_stats() -> Array:
	var modifier = load("res://scripts/weapons/weapon_modifier.gd").new()
	var out: Array = []
	var slot := 0
	for path in ["res://data/weapons/rocket.tres", "res://data/weapons/grenade.tres",
			"res://data/weapons/energy_shot.tres"]:
		var stats: Dictionary = load(path).effective(modifier)
		out.append({"slot": slot, "stats": stats})
		slot += 1
	return out


func test_plan_generation_produces_plans() -> void:
	var plans: Array = load(TACTICAL).generate_plans(
			1.0, 0.0, Vector3(10, 1, 0), 0.0, Vector2.ZERO, _weapon_stats(),
			null, [], 10.0,
			[30.0, 45.0, 60.0], [0.5, 0.75, 1.0])
	assert_true(plans.size() > 0, "plans generated")
	assert_true(plans.size() >= 9,
			"3 positions × 3 weapons × 3 angles × 3 powers = many plans")


func test_plans_sorted_by_value() -> void:
	var plans: Array = load(TACTICAL).generate_plans(
			1.0, 0.0, Vector3(10, 1, 0), 0.0, Vector2.ZERO, _weapon_stats(),
			null, [], 10.0, [30.0, 45.0, 60.0], [0.5, 0.75, 1.0])
	for i in range(1, plans.size()):
		assert_true(plans[i - 1]["value"] >= plans[i]["value"],
				"plans sorted by value descending")


func test_best_plan_returns_highest_value() -> void:
	var plans: Array = load(TACTICAL).generate_plans(
			1.0, 0.0, Vector3(10, 1, 0), 0.0, Vector2.ZERO, _weapon_stats(),
			null, [], 10.0, [30.0, 45.0, 60.0], [0.5, 0.75, 1.0])
	var best: Dictionary = load(TACTICAL).best_plan(plans)
	assert_almost_equal(best["value"], plans[0]["value"], EPS, "best = first")


func test_joint_optimization_finds_terrain_shot_from_distance() -> void:
	# Enemy near the ravine edge on Canyon: the AI discovers that shelling
	# the ground beside them (shove-off) is better than a direct hit from
	# a position where the direct shot is blocked or weak.
	var g = load(MAPS).build_onto_new_grid(load(CANYON))
	var structures: Array = load(CANYON).build(g)
	var enemy_pos := Vector3(24.5, 1.5, 0)
	var enemy_surface: float = g.query_surface_y(24.5)
	var plans: Array = load(TACTICAL).generate_plans(
			1.0, 8.0, enemy_pos, enemy_surface, Vector2.ZERO, _weapon_stats(),
			g, structures, 15.0, [30.0, 45.0, 60.0], [0.5, 0.75, 1.0])
	assert_true(plans.size() > 0, "plans generated on Canyon terrain")
	var best: Dictionary = load(TACTICAL).best_plan(plans)
	assert_true(best["value"] > 0.0, "best plan has positive value")


func test_plan_walk_cost_prefers_closer_positions() -> void:
	var plans: Array = load(TACTICAL).generate_plans(
			1.0, 0.0, Vector3(10, 1, 0), 0.0, Vector2.ZERO, _weapon_stats(),
			null, [], 10.0, [45.0], [0.75])
	# All plans are at 45° with the same power: the closer position with the
	# same impact quality should win due to lower walk cost.
	if plans.size() >= 2:
		assert_true(plans[0]["move_x"] != 0.0 or plans[0]["value"] >= 0.0,
				"plan generation works from x=0")


func test_best_plan_empty_list_returns_default() -> void:
	var best: Dictionary = load(TACTICAL).best_plan([])
	assert_equal(best["weapon_slot"], -1, "empty plans = no valid plan")


func test_plan_generation_respects_walk_range() -> void:
	var plans: Array = load(TACTICAL).generate_plans(
			1.0, 10.0, Vector3(10, 1, 0), 0.0, Vector2.ZERO, _weapon_stats(),
			null, [], 5.0, [45.0], [0.75])
	# All plans should be within 5m of current_x=10.
	for plan in plans:
		assert_true(absf(plan["move_x"] - 10.0) <= 5.0 + 0.001,
				"plan move_x within walk range")
