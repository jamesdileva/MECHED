extends RefCounted
## Turn logic (implementation-guide §4): determines the active entity, begins
## and ends turns, budgets movement, enforces turn validity. Carries no weapon
## or AI logic (§4) — discrete actions arrive via submit_action(), continuous
## movement intent via apply_movement(); both come from any driver (the player
## input shim today, the AI planner in S15+).

const MatchStateScript := preload("res://scripts/match/match_state.gd")
const EndTurnAction := preload("res://scripts/match/action_end_turn.gd")

const TURN_TIME := 15.0
const MOVE_BUDGET := 3.0

var state := MatchStateScript.new()


func begin_match(entity_names: PackedStringArray) -> void:
	state.begin_match(entity_names, MOVE_BUDGET, TURN_TIME)


## Per-tick turn progression. The turn timer is the fallback that guarantees
## turns advance even when a driver stalls.
func tick(delta: float) -> void:
	if not state.is_in_move_phase():
		return
	state.turn_time_left -= delta
	if state.turn_time_left <= 0.0:
		end_turn(state.active_index)


## Discrete actions (implementation-guide §5). Only the active entity may act;
## anything else is rejected — the simulation itself prevents illegal play.
func submit_action(action, actor_index: int) -> bool:
	if not state.started or actor_index != state.active_index:
		return false
	if action is EndTurnAction:
		end_turn(actor_index)
		return true
	return false


## Continuous movement intent from the active driver. Returns the effective
## axis (0.0 when this entity may not move now) and consumes the movement
## budget proportional to |axis| * delta. The final consuming tick may move a
## hair past the budget — frame granularity, accepted.
func apply_movement(actor_index: int, axis: float, delta: float) -> float:
	if actor_index != state.active_index or not state.can_move():
		return 0.0
	state.movement_budget_left = maxf(0.0, state.movement_budget_left - absf(axis) * delta)
	return axis


func end_turn(actor_index: int) -> void:
	if not state.started or actor_index != state.active_index:
		return
	state.active_index = (state.active_index + 1) % state.entity_names.size()
	state.turn_number += 1
	state.phase = MatchStateScript.Phase.MOVE
	state.movement_budget_left = MOVE_BUDGET
	state.turn_time_left = TURN_TIME
