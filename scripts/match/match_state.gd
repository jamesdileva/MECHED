extends RefCounted
## Central match state (implementation-guide §3) — pure data and queries, no
## scene dependencies. Reconstructable, headless-testable: the TurnManager
## mutates turn state, the match layer mutates health; presentation only
## reads. Terrain/projectile/objective state join this object in later
## sprints.

enum Phase { INACTIVE, MOVE, RESOLVING }
# The move phase is move + aim + fire (parallel, GunBound-style); RESOLVING
# runs from fire submission until the projectile impact resolves the turn.
# The ability phase inserts between them in S08+ (architecture.md §7).

const STARTING_HEALTH := 100.0

var started := false
var turn_number := 0
var entity_names: PackedStringArray = []
var active_index := -1
var phase: int = Phase.INACTIVE
var movement_budget_left := 0.0
var turn_time_left := 0.0
var mech_health: Dictionary = {}
var match_result := &""


func begin_match(names: PackedStringArray, budget: float, turn_time: float) -> void:
	started = true
	turn_number = 1
	entity_names = names
	active_index = 0
	phase = Phase.MOVE
	movement_budget_left = budget
	turn_time_left = turn_time
	mech_health.clear()
	for entity_name in names:
		mech_health[entity_name] = STARTING_HEALTH


func active_entity_name() -> String:
	if active_index < 0 or active_index >= entity_names.size():
		return "<none>"
	return entity_names[active_index]


func is_active(index: int) -> bool:
	return started and index == active_index


func is_in_move_phase() -> bool:
	return started and phase == Phase.MOVE


func is_resolving() -> bool:
	return started and phase == Phase.RESOLVING


## The active entity may move while the turn's movement budget lasts.
func can_move() -> bool:
	return is_in_move_phase() and movement_budget_left > 0.0


## Authoritative health mutation. Returns the new health (clamped at 0).
func apply_damage(entity_name: String, amount: float) -> float:
	var hp: float = maxf(0.0, entity_health(entity_name) - amount)
	mech_health[entity_name] = hp
	return hp


func entity_health(entity_name: String) -> float:
	return mech_health.get(entity_name, 0.0)
