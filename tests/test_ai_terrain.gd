extends "res://tests/test_base.gd"
## S17 AI terrain awareness — the roadmap verification as executable tests:
## an arena where terrain manipulation is clearly advantageous, and the AI's
## shot-value model discovers it. Enemy on the bridge -> shell the pillar;
## enemy near a cliff out of damage range -> shell the ground beside them;
## enemy in the open -> just hit them.

const AI_DRIVER := "res://scripts/ai/ai_driver.gd"
const GRID := "res://scripts/terrain/terrain_grid.gd"
const LAYOUT := "res://scripts/terrain/terrain_layout.gd"
const ROCKET := "res://data/weapons/rocket.tres"
const EPS := 0.0001


func _driver():
	return load(AI_DRIVER)


func _rocket_stats() -> Dictionary:
	return load(ROCKET).effective(null)


func _standard_arena():
	var g = load(GRID).new()
	g.create(240, 48, 0.25, -30.0, 8.0)
	var structures: Array = load(LAYOUT).build_standard_layout(g)
	return {"grid": g, "structures": structures}


func test_bridge_collapse_shot_outranks_direct_hit() -> void:
	# The enemy stands ON the bridge (x=21). Three candidate impacts:
	# a direct hit there stacks damage + footing + collapse (best of all),
	# a pillar-only shot collapses without damage (8.0), and a plain direct
	# hit on flat ground is worth only 7.0 — so dropping them into the
	# ravine beats a plain 40-damage hit.
	var arena = _standard_arena()
	var driver = _driver()
	var stats: Dictionary = _rocket_stats()
	var enemy_pos := Vector3(21, 0.775, 0)
	var enemy_surface: float = arena["grid"].query_surface_y(21)
	var direct_on_bridge: float = driver.shot_value(Vector3(21, 0.5, 0), stats,
			enemy_pos, enemy_surface, arena["grid"], arena["structures"])
	var pillar_only: float = driver.shot_value(Vector3(21, -2.25, 0), stats,
			enemy_pos, enemy_surface, arena["grid"], arena["structures"])
	assert_almost_equal(direct_on_bridge, 12.0, 0.1,
			"direct hit on the bridge stacks damage + footing + collapse")
	assert_almost_equal(pillar_only, 8.0, 0.1, "pillar shot = footing + collapse, no damage")
	var flat_grid = load(GRID).new()
	load(LAYOUT).fill_world_rect(flat_grid, Rect2(-30, -4, 60, 4), true)
	var plain_direct: float = driver.shot_value(Vector3(0, 0.5, 0), stats,
			Vector3(0, 0.875, 0), 0.0, flat_grid, [])
	assert_almost_equal(plain_direct, 7.0, 0.1, "a plain direct hit = damage + footing only")
	assert_true(pillar_only > plain_direct,
			"collapsing the bridge beats a plain 40-damage hit (8.0 > 7.0)")
	assert_true(direct_on_bridge > pillar_only,
			"when damage AND collapse stack, take the direct hit (12.0 > 8.0)")


func test_shove_shot_beats_out_of_range_direct() -> void:
	# The enemy stands at the plateau edge, 3.5m away: outside the Rocket's
	# 2.5m damage radius. A blast BEHIND them (away from the drop) shoves
	# them off; an equally distant blast overhead earns nothing.
	var arena = _standard_arena()
	var driver = _driver()
	var stats: Dictionary = _rocket_stats()
	var enemy_pos := Vector3(24.5, 1.5, 0)
	var enemy_surface: float = arena["grid"].query_surface_y(24.5)
	var shove: float = driver.shot_value(Vector3(28, 1.5, 0), stats, enemy_pos,
			enemy_surface, arena["grid"], arena["structures"])
	var harmless: float = driver.shot_value(Vector3(24.5, 5.0, 0), stats, enemy_pos,
			enemy_surface, arena["grid"], arena["structures"])
	assert_almost_equal(shove, 3.0, 0.1, "the behind-blast is valued as a shove-off")
	assert_almost_equal(harmless, 0.0, EPS, "same range, wrong side: no shove credit")
	assert_true(shove > harmless,
			"shelling the ground behind the edge-stander is the winning play")


func test_footing_carve_stacks_with_direct_damage() -> void:
	var arena = _standard_arena()
	var driver = _driver()
	var stats: Dictionary = _rocket_stats()
	var enemy_pos := Vector3(0, 0.875, 0)
	var enemy_surface: float = arena["grid"].query_surface_y(0)
	# A shell landing on their feet deals damage AND undermines the footing.
	var combined: float = driver.shot_value(Vector3(0.3, 0.3, 0), stats, enemy_pos,
			enemy_surface, arena["grid"], arena["structures"])
	assert_true(combined > 4.0,
			"direct damage + footing destruction stack (%.2f)" % combined)


func test_open_field_prefers_the_direct_hit() -> void:
	# Enemy in the open at 8m: direct damage is the best value on the board —
	# no terrain opportunity should outrank it.
	var g = load(GRID).new()
	g.create(240, 48, 0.25, -30.0, 8.0)
	load(LAYOUT).fill_world_rect(g, Rect2(-30, -4, 60, 4), true)
	var driver = _driver()
	var stats: Dictionary = _rocket_stats()
	var enemy_pos := Vector3(8, 0.875, 0)
	var enemy_surface: float = g.query_surface_y(8)
	var direct: float = driver.shot_value(Vector3(8, 1.2, 0), stats, enemy_pos,
			enemy_surface, g, [])
	var anywhere_else: float = driver.shot_value(Vector3(-6, 0.5, 0), stats, enemy_pos,
			enemy_surface, g, [])
	assert_true(direct > anywhere_else,
			"in the open the AI just shoots you (%.2f > %.2f)" % [direct, anywhere_else])


func test_solver_picks_the_highest_value_shot() -> void:
	# End-to-end through the solver: with the enemy on the bridge, the chosen
	# plan's value comes from the terrain opportunity, not raw proximity.
	var arena = _standard_arena()
	var driver = _driver()
	var weapon_stats: Array = [{"slot": 0, "stats": _rocket_stats()}]
	var enemy_pos := Vector3(21, 0.775, 0)
	var enemy_surface: float = arena["grid"].query_surface_y(21)
	var plan: Dictionary = driver.solve_shot(
			Vector3(14, 1.5, 0), enemy_pos, 1.0, Vector2.ZERO, weapon_stats,
			enemy_surface, arena["grid"], arena["structures"])
	assert_true(plan["value"] > 4.0,
			"the solver discovered the terrain opportunity (value %.2f)" % plan["value"])
	assert_equal(plan["slot"], 0, "the Rocket is the tool for the job")


func test_no_terrain_reduces_to_direct_only() -> void:
	# Backward compatibility (S15): with no terrain, value = direct damage,
	# i.e. the old min-miss behavior.
	var driver = _driver()
	var weapon_stats: Array = [{"slot": 0, "stats": _rocket_stats()}]
	var plan: Dictionary = driver.solve_shot(
			Vector3(0, 1, 0), Vector3(10, 1, 0), 1.0, Vector2.ZERO, weapon_stats)
	assert_true(plan["miss"] < 3.0, "without terrain the solver still lands on target")
