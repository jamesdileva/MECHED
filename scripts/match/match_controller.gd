extends Node
## Presentation-facing shim for the turn simulation (implementation-guide §3:
## simulation separate from presentation).
##
## Reads InputLayer ONLY for the active player entity and zeroes intent for
## every other mech — that is the structural guarantee behind "a player cannot
## move during another entity's turn". TurnManager still validates every
## submit (defense in depth). The dummy opponent has no driver: it receives
## zeroed intent and its turn ends via the turn timer until the AI (S15+)
## replaces it.

const TurnManagerScript := preload("res://scripts/match/turn_manager.gd")
const EndTurnAction := preload("res://scripts/match/action_end_turn.gd")

@export var player_index := 0

var turn_manager
var entities: Array[Node] = []


## Wires the entity list (index = turn order) and begins the match.
## Plain-Array parameter so callers can pass [$A, $B] node literals directly.
func setup(p_entities: Array) -> void:
	entities.assign(p_entities)
	turn_manager = TurnManagerScript.new()
	var names := PackedStringArray()
	for entity in entities:
		names.append(String(entity.name))
	turn_manager.begin_match(names)
	add_to_group("match_controller")


func _physics_process(delta: float) -> void:
	if entities.is_empty() or turn_manager == null:
		return
	turn_manager.tick(delta)
	var active: int = turn_manager.state.active_index
	for i in entities.size():
		var mech = entities[i]
		if i == active and i == player_index:
			var axis: float = turn_manager.apply_movement(i, InputLayer.get_move_axis(), delta)
			mech.move_axis = axis
			mech.want_jump = InputLayer.is_action_just_pressed("jump")
			if InputLayer.is_action_just_pressed("end_turn"):
				turn_manager.submit_action(EndTurnAction.new(), i)
		else:
			mech.move_axis = 0.0
			mech.want_jump = false


func status_line() -> String:
	if turn_manager == null or not turn_manager.state.started:
		return "match not started"
	var s = turn_manager.state
	return "turn %d | %s | move %.1fs | timer %.1fs" % [
		s.turn_number, s.active_entity_name(), s.movement_budget_left, s.turn_time_left,
	]
