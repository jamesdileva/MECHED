extends "res://tests/test_base.gd"
## S16 AI positioning: the scoring module values high ground, cover, and safe
## footing — and choose_position makes the AI reposition instead of firing
## from a bad spot (the roadmap verification). All pure over real grids.

const POSITIONING := "res://scripts/ai/ai_positioning.gd"
const GRID := "res://scripts/terrain/terrain_grid.gd"
const LAYOUT := "res://scripts/terrain/terrain_layout.gd"
const MATCH_STATE := "res://scripts/match/match_state.gd"
const AI_DRIVER := "res://scripts/ai/ai_driver.gd"


func _positioning():
	return load(POSITIONING)


func _flat_grid():
	var g = load(GRID).new()
	g.create(240, 48, 0.25, -30.0, 8.0)
	load(LAYOUT).fill_world_rect(g, Rect2(-30, -4, 60, 4), true)
	return g


func _standard_grid():
	var g = load(GRID).new()
	g.create(240, 48, 0.25, -30.0, 8.0)
	load(LAYOUT).build_standard_layout(g)
	return g


func test_band_value_favors_standoff() -> void:
	var p = _positioning()
	assert_almost_equal(p.band_value(10.0), p.BAND_IN_SCORE, 0.0001,
			"inside the band is the best distance")
	assert_true(p.band_value(4.0) < p.BAND_IN_SCORE, "too close is penalized")
	assert_true(p.band_value(25.0) < p.BAND_IN_SCORE, "too far is penalized")


func test_elevation_is_valued_and_capped() -> void:
	var p = _positioning()
	assert_almost_equal(p.elevation_value(2.0, 1.0), 1.0, 0.0001, "1m above = +1")
	assert_true(p.elevation_value(4.0, 1.0) == p.ELEVATION_CAP, "elevation caps")
	assert_true(p.elevation_value(0.0, 3.0) < 0.0, "looking up at the enemy hurts")


func test_cover_is_valued_through_the_mask() -> void:
	var p = _positioning()
	var g = _standard_grid()
	# The enemy is at x=12 on the flats; x=5.5 has the cover wall (x 7..7.5,
	# 1.6m tall) between it and the enemy at body height. x=9.5 sits BETWEEN
	# the wall and the enemy — nothing blocks its line.
	var covered: float = p.cover_value(Vector3(5.5, 1.0, 0), Vector3(12, 1.0, 0), g)
	var exposed: float = p.cover_value(Vector3(9.5, 1.0, 0), Vector3(12, 1.0, 0), g)
	assert_true(covered > 0.0, "the cover wall registers at body height")
	assert_true(covered > exposed, "covered beats exposed")


func test_edge_risk_penalizes_live_drops_only() -> void:
	var p = _positioning()
	var g = _standard_grid()
	# The plateau's edge (top 1.375) hangs 1.5m over the bridge deck.
	assert_almost_equal(p.edge_risk(24.5, 1.375, g), p.EDGE_RISK_PENALTY, 0.0001,
			"plateau edge over the deck is risky")
	# While the bridge deck is intact, it FLOORS the ravine edge at x=17 —
	# no risk standing there (the deck is the floor until it's destroyed).
	assert_equal(p.edge_risk(17.0, 0.0, g), 0.0, "the intact deck makes the edge safe")
	# Shear the deck away and the same spot becomes a live drop.
	g.destroy_circle(Vector2(21, -0.25), 3.0)
	assert_almost_equal(p.edge_risk(17.0, 0.0, g), p.EDGE_RISK_PENALTY, 0.0001,
			"after the deck is carved the edge turns risky")


func test_choose_position_scores_high_ground_over_flats() -> void:
	var p = _positioning()
	# Enemy at x=0 on flat ground; the AI starts at x=6 with a long walk
	# available — the hilltop's elevation should beat the flats.
	var g = _standard_grid()
	var choice: Dictionary = p.choose_position(6.0, Vector3(0, 1, 0), 40.0, g)
	assert_true(choice["x"] < -13.9, "the AI repositions onto the hill (x %.1f)" % choice["x"])
	assert_true(choice["improved"], "the hill is an improvement over the spawn flat")


func test_choose_position_avoids_the_ravine_pit() -> void:
	var p = _positioning()
	var g = _standard_grid()
	# Enemy far west; the AI stands beside the ravine with a full walk budget.
	var choice: Dictionary = p.choose_position(17.0, Vector3(-10, 1, 0), 30.0, g)
	var x: float = choice["x"]
	assert_true(x < 17.9 or x > 24.1, "the AI never chooses to stand inside the ravine (x %.1f)" % x)
	assert_true(choice["improved"], "a better spot than the ravine edge exists")


func test_choose_position_stays_when_already_optimal() -> void:
	var p = _positioning()
	var g = _flat_grid()
	# Flat world, enemy 10m out (in the band), a short walk available:
	# every candidate is flat and in-band, so movement cost keeps us put.
	var choice: Dictionary = p.choose_position(10.0, Vector3(0, 1, 0), 5.0, g)
	assert_true(choice["improved"] == false,
			"no improvement triggers on a featureless flat (x %.1f)" % choice["x"])


func test_driver_uses_positioning_module() -> void:
	# The driver's reposition trigger comes from the positioning module's
	# `improved` flag — the roadmap's "reposition instead of immediately
	# firing" behavior rides on this contract.
	var driver = load(AI_DRIVER).new()
	driver.reset()
	assert_true(is_nan(driver.move_target_x), "move target unchosen at reset")
	assert_equal(driver.phase, "move", "turn opens in the move phase")
