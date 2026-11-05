extends "res://tests/test_base.gd"
## S14 wind: the roadmap scenarios (tailwind, headwind, crosswind, changing
## wind) verified against numeric flight integration. Wind is a 2D vector in
## the gameplay plane — the Y component is our "crosswind" (updraft/downdraft)
## because a side-view game has no out-of-plane axis.

const BALLISTICS := "res://scripts/combat/ballistics.gd"
const MATCH_STATE := "res://scripts/match/match_state.gd"
const TURN_MANAGER := "res://scripts/match/turn_manager.gd"
const EPS := 0.0001

var _origin := Vector3(0, 1, 0)


func _launch(power_speed: float, wind: Vector2) -> Dictionary:
	var b = load(BALLISTICS)
	var vel: Vector3 = b.launch_velocity(45.0, 1.0, power_speed)
	return b.simulate_flight(_origin, vel, wind, 1.0 / 120.0)


func test_wind_step_adds_drift() -> void:
	var b = load(BALLISTICS)
	var v: Vector3 = b.wind_step(Vector3(10, 5, 0), Vector3(2, 0, 0), 0.5)
	assert_equal(v, Vector3(11, 5, 0), "wind accelerates the shell per tick")


func test_tailwind_extends_range() -> void:
	var calm: Dictionary = _launch(0.7, Vector2.ZERO)
	var tail: Dictionary = _launch(0.7, Vector2(4, 0))
	assert_true(tail["range"] > calm["range"],
			"tailwind carries the shell farther (%.2f > %.2f)" % [tail["range"], calm["range"]])


func test_headwind_shortens_range() -> void:
	var calm: Dictionary = _launch(0.7, Vector2.ZERO)
	var head: Dictionary = _launch(0.7, Vector2(-4, 0))
	assert_true(head["range"] < calm["range"],
			"headwind shortens the shot (%.2f < %.2f)" % [head["range"], calm["range"]])


func test_updraft_extends_hangtime() -> void:
	# "Crosswind" in a side-view game is the vertical component.
	var calm: Dictionary = _launch(0.7, Vector2.ZERO)
	var up: Dictionary = _launch(0.7, Vector2(0, 3))
	assert_true(up["time"] > calm["time"],
			"an updraft keeps the shell airborne longer")
	var down: Dictionary = _launch(0.7, Vector2(0, -3))
	assert_true(down["time"] < calm["time"], "a downdraft drops the shell sooner")


func test_zero_wind_matches_analytic_range() -> void:
	var b = load(BALLISTICS)
	var vel: Vector3 = b.launch_velocity(45.0, 1.0, 0.7)
	var analytic: float = b.range_on_ground(_origin, vel)
	var simulated: Dictionary = b.simulate_flight(_origin, vel, Vector2.ZERO, 1.0 / 120.0)
	assert_almost_equal(simulated["range"], analytic, 0.05,
			"unwinded simulation converges on the analytic range")


func test_wind_rolls_stay_capped() -> void:
	var s = load(MATCH_STATE).new()
	s.begin_match(PackedStringArray(["A", "B"]), 100.0, 15.0, 12345)
	for i in 50:
		s.roll_wind()
		assert_true(s.wind.length() <= s.WIND_MAX + EPS,
				"rolled wind never exceeds WIND_MAX")


func test_wind_changes_on_turn_transition() -> void:
	var tm = load(TURN_MANAGER).new()
	# Seeded match: rolls are deterministic, so the change assertion is sound.
	tm.begin_match(PackedStringArray(["A", "B"]))
	var before: Vector2 = tm.state.wind
	tm.submit_action(load("res://scripts/match/action_end_turn.gd").new(), 0)
	assert_true(tm.state.wind != before, "wind re-rolls on turn transition (changing wind)")


func test_seeded_matches_roll_identically() -> void:
	var a = load(MATCH_STATE).new()
	a.begin_match(PackedStringArray(["A", "B"]), 100.0, 15.0, 777)
	var b = load(MATCH_STATE).new()
	b.begin_match(PackedStringArray(["A", "B"]), 100.0, 15.0, 777)
	assert_equal(a.wind, b.wind, "same seed = same opening wind (replay parity)")
	for i in 5:
		a.roll_wind()
		b.roll_wind()
		assert_equal(a.wind, b.wind, "same seed = identical wind sequence")
