extends "res://tests/test_base.gd"
## S03 turn rules. TurnManager + MatchState are pure RefCounted objects, so
## the entire turn flow — alternation, validation, budget, timer — is tested
## headless with no scene tree at all. These tests are the executable version
## of the roadmap's S03 verification: two entities alternate turns, and no
## entity acts during another's turn.

const TURN_MANAGER := "res://scripts/match/turn_manager.gd"
const END_TURN_ACTION := "res://scripts/match/action_end_turn.gd"
const FIRE_ACTION := "res://scripts/match/action_fire.gd"


func _begin():
	# TurnManager is RefCounted: no Node cleanup registration, and the handle
	# stays untyped because a `-> Node` annotation rejects RefCounted at
	# runtime (that assignment error aborts the test before any assert).
	var tm = load(TURN_MANAGER).new()
	tm.begin_match(PackedStringArray(["Mech", "DummyMech"]))
	return tm


func _fire(tm, actor: int, power := 0.5) -> bool:
	var action = load(FIRE_ACTION).new()
	action.power = power
	return tm.submit_action(action, actor)


func test_begin_match_activates_first_entity() -> void:
	var tm = _begin()
	var s = tm.state
	assert_true(s.started, "match started")
	assert_equal(s.active_index, 0, "first entity is active")
	assert_equal(s.turn_number, 1, "turn numbering starts at 1")
	assert_true(s.is_in_move_phase(), "turn opens in the move phase")
	assert_equal(s.movement_budget_left, tm.MOVE_BUDGET, "movement budget is full")
	assert_equal(s.turn_time_left, tm.TURN_TIME, "turn timer is full")


func test_end_turn_action_advances_and_resets() -> void:
	var tm = _begin()
	var accepted: bool = tm.submit_action(load(END_TURN_ACTION).new(), 0)
	assert_true(accepted, "active entity may end the turn")
	var s = tm.state
	assert_equal(s.active_index, 1, "play passes to the next entity")
	assert_equal(s.turn_number, 2, "turn number increments")
	assert_true(s.is_in_move_phase(), "next turn opens in the move phase")
	assert_equal(s.movement_budget_left, tm.MOVE_BUDGET, "budget refreshed")
	assert_equal(s.turn_time_left, tm.TURN_TIME, "timer refreshed")


func test_turn_wraps_around_all_entities() -> void:
	var tm = _begin()
	tm.submit_action(load(END_TURN_ACTION).new(), 0)
	tm.submit_action(load(END_TURN_ACTION).new(), 1)
	var s = tm.state
	assert_equal(s.active_index, 0, "turn order wraps to the first entity")
	assert_equal(s.turn_number, 3, "turn number keeps counting across the wrap")


func test_non_active_actor_cannot_end_turn() -> void:
	var tm = _begin()
	var accepted: bool = tm.submit_action(load(END_TURN_ACTION).new(), 1)
	assert_true(not accepted, "end turn from a non-active entity is rejected")
	assert_equal(tm.state.active_index, 0, "turn state unchanged")


func test_turn_timer_expires_and_advances() -> void:
	var tm = _begin()
	tm.tick(tm.TURN_TIME + 0.1)
	assert_equal(tm.state.active_index, 1, "timer expiry passes the turn")
	assert_equal(tm.state.turn_number, 2, "timer expiry counts as a full turn")


func test_tick_before_match_begin_is_noop() -> void:
	var tm = load(TURN_MANAGER).new()
	tm.tick(1.0)
	assert_equal(tm.state.active_index, -1, "nothing active before begin_match")


func test_movement_budget_consumes_only_when_moving() -> void:
	var tm = _begin()
	var axis: float = tm.apply_movement(0, 0.0, 0.5)
	assert_equal(axis, 0.0, "zero axis stays zero")
	assert_equal(tm.state.movement_budget_left, tm.MOVE_BUDGET, "standing still costs nothing")
	axis = tm.apply_movement(0, 1.0, 0.5)
	assert_equal(axis, 1.0, "allowed axis passes through unchanged")
	assert_equal(tm.state.movement_budget_left, tm.MOVE_BUDGET - 0.5, "moving consumes budget")


func test_non_active_actor_cannot_move() -> void:
	var tm = _begin()
	var axis: float = tm.apply_movement(1, 1.0, 0.5)
	assert_equal(axis, 0.0, "movement during another entity's turn is suppressed")
	assert_equal(tm.state.movement_budget_left, tm.MOVE_BUDGET, "no budget consumed")


func test_exhausted_budget_stops_movement_without_ending_turn() -> void:
	var tm = _begin()
	var steps := int(ceil(tm.MOVE_BUDGET / 0.1)) + 1
	for i in steps:
		tm.apply_movement(0, 1.0, 0.1)
	assert_equal(tm.state.movement_budget_left, 0.0, "budget drains to zero")
	assert_equal(tm.apply_movement(0, 1.0, 0.1), 0.0, "empty budget suppresses movement")
	assert_equal(tm.state.active_index, 0, "empty budget does not auto-end the turn")
	assert_true(tm.state.can_move() == false, "can_move is false on an empty budget")


func test_fire_action_starts_resolution() -> void:
	var tm = _begin()
	assert_true(_fire(tm, 0), "active entity may fire")
	var s = tm.state
	assert_true(s.is_resolving(), "fire puts the turn into resolution")
	assert_equal(s.active_index, 0, "resolution keeps the same active entity")


func test_cannot_act_again_while_resolving() -> void:
	var tm = _begin()
	_fire(tm, 0)
	assert_true(_fire(tm, 0) == false, "double fire is rejected")
	assert_equal(tm.apply_movement(0, 1.0, 0.5), 0.0, "movement is locked while resolving")
	assert_true(tm.submit_action(load(END_TURN_ACTION).new(), 0) == false,
			"end turn is locked while resolving")
	tm.tick(20.0)
	assert_true(tm.state.is_resolving(), "turn timer pauses during resolution")
	assert_equal(tm.state.active_index, 0, "resolution still holds the turn")


func test_finish_resolution_advances_turn() -> void:
	var tm = _begin()
	_fire(tm, 0)
	tm.finish_resolution()
	var s = tm.state
	assert_equal(s.active_index, 1, "resolved shot passes play on")
	assert_equal(s.turn_number, 2, "next turn is numbered")
	assert_true(s.is_in_move_phase(), "next turn opens in the move phase")
	assert_equal(s.movement_budget_left, tm.MOVE_BUDGET, "budget refreshed")


func test_damage_is_tracked_in_match_state() -> void:
	var tm = _begin()
	var s = tm.state
	assert_equal(s.entity_health("Mech"), s.STARTING_HEALTH, "entities start at full health")
	assert_equal(s.apply_damage("Mech", 40.0), 60.0, "damage reduces health")
	assert_equal(s.entity_health("Mech"), 60.0, "health is readable from state")
	assert_equal(s.apply_damage("Mech", 200.0), 0.0, "health clamps at zero")
