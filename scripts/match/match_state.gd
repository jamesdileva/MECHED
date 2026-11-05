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
## Wind strength cap (S14): m/s² of drift against 30 gravity — meaningful,
## never dominating.
const WIND_MAX := 5.0

var started := false
var turn_number := 0
var entity_names: PackedStringArray = []
var active_index := -1
var phase: int = Phase.INACTIVE
var movement_energy_left := 0.0
var turn_time_left := 0.0
var mech_health: Dictionary = {}
## Per-entity jetpack fuel (S09): current and per-turn maximum. Entities
## without a jetpack simply have 0.
var jetpack_fuel: Dictionary = {}
var fuel_max: Dictionary = {}
## Universal weapons (S11): per-entity loadout of WeaponDefinitions and the
## armed slot. Every chassis can equip every weapon.
var weapon_loadouts: Dictionary = {}
var active_weapon_index: Dictionary = {}
## Environmental state (architecture.md §3): wind as a 2D vector in the
## gameplay plane (±X tail/headwind, Y updraft/downdraft); magnitude is
## strength. Re-rolled every turn from the per-match seeded RNG.
var wind := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var match_result := &""


func begin_match(names: PackedStringArray, energy_per_turn: float, turn_time: float,
		seed := -1) -> void:
	started = true
	turn_number = 1
	entity_names = names
	active_index = 0
	phase = Phase.MOVE
	movement_energy_left = energy_per_turn
	turn_time_left = turn_time
	mech_health.clear()
	for entity_name in names:
		mech_health[entity_name] = STARTING_HEALTH
	jetpack_fuel.clear()
	fuel_max.clear()
	weapon_loadouts.clear()
	active_weapon_index.clear()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	roll_wind()


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


## The active entity may move while the turn's movement energy lasts.
func can_move() -> bool:
	return is_in_move_phase() and movement_energy_left > 0.0


## Authoritative health mutation. Returns the new health (clamped at 0).
func apply_damage(entity_name: String, amount: float) -> float:
	var hp: float = maxf(0.0, entity_health(entity_name) - amount)
	mech_health[entity_name] = hp
	return hp


## Direct initialization (definitions set per-entity max health at setup).
func set_entity_health(entity_name: String, value: float) -> void:
	mech_health[entity_name] = value


## Registers a jetpack and fills its tank (setup-time, per definition).
func set_fuel_limit(entity_name: String, limit: float) -> void:
	fuel_max[entity_name] = limit
	jetpack_fuel[entity_name] = limit


func entity_fuel(entity_name: String) -> float:
	return jetpack_fuel.get(entity_name, 0.0)


## Turn transition: the active entity's tank refills (fuel is a per-turn pool).
func refill_fuel(entity_name: String) -> void:
	jetpack_fuel[entity_name] = fuel_max.get(entity_name, 0.0)


## Equips a weapon loadout (S11); slot 0 is armed.
func set_loadout(entity_name: String, weapons: Array) -> void:
	weapon_loadouts[entity_name] = weapons.duplicate()
	active_weapon_index[entity_name] = 0


## Direct slot arming (S15 AI weapon selection).
func set_active_weapon(entity_name: String, slot: int) -> void:
	var loadout: Array = weapon_loadouts.get(entity_name, [])
	active_weapon_index[entity_name] = clampi(slot, 0, maxi(loadout.size() - 1, 0))


## Match end (S15): the winner's display name goes into the result.
func declare_winner(winner_name: String) -> void:
	match_result = StringName("%s wins the match" % winner_name)


## Cycles to the next weapon; wraps around. Single-weapon loadouts are a no-op.
func cycle_weapon(entity_name: String) -> void:
	var loadout: Array = weapon_loadouts.get(entity_name, [])
	if loadout.size() < 2:
		return
	var slot: int = (int(active_weapon_index.get(entity_name, 0)) + 1) % loadout.size()
	active_weapon_index[entity_name] = slot


func active_weapon_slot(entity_name: String) -> int:
	return int(active_weapon_index.get(entity_name, 0))


func active_weapon(entity_name: String) -> Resource:
	var loadout: Array = weapon_loadouts.get(entity_name, [])
	if loadout.is_empty():
		return null
	return loadout[active_weapon_slot(entity_name) % loadout.size()]


## Direct wind set (tests and future map rules); magnitude is uncapped here —
## rolls are capped by WIND_MAX.
func set_wind(value: Vector2) -> void:
	wind = value


## Per-turn wind roll: random direction, capped strength (GunBound convention).
## The per-match seeded RNG keeps rolls deterministic for replay.
func roll_wind() -> Vector2:
	var angle := rng.randf_range(0.0, TAU)
	var strength := rng.randf_range(0.0, WIND_MAX)
	wind = Vector2.from_angle(angle) * strength
	return wind


func entity_health(entity_name: String) -> float:
	return mech_health.get(entity_name, 0.0)
