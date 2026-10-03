extends RefCounted
## Turn logic (implementation-guide §4): determines the active entity, begins
## and ends turns, budgets movement energy, enforces turn validity, and owns
## the move→resolving phase transition when a FireAction lands. Carries no
## weapon or AI logic (§4) — discrete actions arrive via submit_action(),
## movement spending via spend_movement/spend_jump; both come from any driver
## (the player input shim today, the AI planner in S15+).

const MatchStateScript := preload("res://scripts/match/match_state.gd")
const EndTurnAction := preload("res://scripts/match/action_end_turn.gd")
const FireAction := preload("res://scripts/match/action_fire.gd")

const TURN_TIME := 15.0
## Movement economy (S07, roadmap example): walking costs per meter, jumping
## a flat chunk. Dash joins with the first mobility mech (S08).
const ENERGY_PER_TURN := 100.0
const WALK_COST_PER_M := 1.0
const JUMP_COST := 10.0

var state := MatchStateScript.new()


func begin_match(entity_names: PackedStringArray) -> void:
	state.begin_match(entity_names, ENERGY_PER_TURN, TURN_TIME)


## Per-tick turn progression. The turn timer is the fallback that guarantees
## turns advance even when a driver stalls; it pauses during projectile
## resolution (a shot in flight must not eat the next driver's clock).
func tick(delta: float) -> void:
	if not state.is_in_move_phase():
		return
	state.turn_time_left -= delta
	if state.turn_time_left <= 0.0:
		end_turn(state.active_index)


## Discrete actions (implementation-guide §5). Only the active entity may act,
## and only in the phase that allows the action; anything else is rejected —
## the simulation itself prevents illegal play.
func submit_action(action, actor_index: int) -> bool:
	if not state.started or actor_index != state.active_index:
		return false
	if action is EndTurnAction:
		if not state.is_in_move_phase():
			return false
		end_turn(actor_index)
		return true
	if action is FireAction:
		if not state.is_in_move_phase():
			return false
		state.phase = MatchStateScript.Phase.RESOLVING
		return true
	return false


## The match layer calls this when the projectile has resolved (impact or
## lifetime end); it passes play to the next entity.
func finish_resolution() -> void:
	if state.is_resolving():
		end_turn(state.active_index)


## Walk spending. `meters` is the requested distance (|axis| × max_speed × dt
## — requested, not displaced, so being knocked back never costs the victim).
## Returns whether movement is permitted; the driver zeroes its axis when it
## is not.
func spend_movement(actor_index: int, meters: float) -> bool:
	if actor_index != state.active_index or not state.can_move():
		return false
	state.movement_energy_left = maxf(
			0.0, state.movement_energy_left - meters * WALK_COST_PER_M)
	return true


## Flat jump cost. Returns false (and refuses the jump) when unaffordable.
func spend_jump(actor_index: int) -> bool:
	if actor_index != state.active_index or not state.can_move():
		return false
	if state.movement_energy_left < JUMP_COST:
		return false
	state.movement_energy_left -= JUMP_COST
	return true


func end_turn(actor_index: int) -> void:
	if not state.started or actor_index != state.active_index:
		return
	state.active_index = (state.active_index + 1) % state.entity_names.size()
	state.turn_number += 1
	state.phase = MatchStateScript.Phase.MOVE
	state.movement_energy_left = ENERGY_PER_TURN
	state.turn_time_left = TURN_TIME
