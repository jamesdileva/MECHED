extends RefCounted

const GameModeScript := preload("res://scripts/match/game_mode.gd")
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
## never dominating. Maps override the instance value (S21 wind rules).
## Default wind cap; Balance overrides the instance value at setup (S21/S24).
const WIND_MAX := 5.0

var started := false
var turn_number := 0
var entity_names: PackedStringArray = []
var active_index := -1
var phase: int = Phase.INACTIVE
var movement_energy_left := 0.0
var turn_time_left := 0.0
var mech_health: Dictionary = {}
## Starting-health instance value (S24): Balance sets it at match setup.
var starting_health := STARTING_HEALTH
## Per-entity maximum health (from MechDefinitions, S19 HUD bars scale to it).
var health_max: Dictionary = {}
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
## Wind cap instance value (S24): Balance sets it at match setup.
var wind_cap := WIND_MAX
## Gravity instance value (S24): Balance sets it at match setup; the AI shot
## solver reads it to stay in sync with real flight.
var gravity := 30.0

## S31 game mode: rule resource + per-mode runtime. Mode logic is pure over
## entity positions (headless-testable); null mode = plain Elimination.
var game_mode: Resource = null
var mode_objectives: Array = []
var hold_progress: Dictionary = {}
var race_progress: Dictionary = {}
var siege_survive_time := 0.0
var rng := RandomNumberGenerator.new()
## Per-map wind cap (S21 wind rules); the const WIND_MAX is the default.
var wind_max := WIND_MAX
var match_result := &""
## The display name of the winner (S20 victory overlay reads this).
var winner := ""


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
	health_max.clear()
	for entity_name in names:
		mech_health[entity_name] = starting_health
	jetpack_fuel.clear()
	fuel_max.clear()
	weapon_loadouts.clear()
	active_weapon_index.clear()
	hold_progress.clear()
	race_progress.clear()
	siege_survive_time = 0.0
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


func set_entity_max_health(entity_name: String, value: float) -> void:
	health_max[entity_name] = value


func entity_max_health(entity_name: String) -> float:
	return health_max.get(entity_name, starting_health)


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
	winner = winner_name
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


## Per-turn wind roll: random direction, capped by the map's wind_max
## (GunBound convention). The per-match seeded RNG keeps rolls deterministic
## for replay.
func roll_wind() -> Vector2:
	var angle := rng.randf_range(0.0, TAU)
	var strength := rng.randf_range(0.0, wind_max)
	wind = Vector2.from_angle(angle) * strength
	return wind


func entity_health(entity_name: String) -> float:
	return mech_health.get(entity_name, 0.0)


## S31: wires the mode rule + the map's objectives (converted by kind).
func setup_mode(mode: Resource, objectives: Array) -> void:
	game_mode = mode
	mode_objectives = objectives.duplicate(true)
	hold_progress.clear()
	race_progress.clear()
	for entity_name in entity_names:
		hold_progress[entity_name] = 0.0
		race_progress[entity_name] = 0


func _control_zones() -> Array:
	return mode_objectives.filter(func(o): return o != null and o["kind"] == "control_zone")


func _checkpoints() -> Array:
	var out: Array = mode_objectives.filter(func(o): return o != null and o["kind"] == "checkpoint")
	out.sort_custom(func(a, b): return a["order"] < b["order"])
	return out


func _in_region(pos: Vector2, region: Rect2) -> bool:
	return pos.x >= region.position.x and pos.x <= region.end.x 			and pos.y >= region.position.y and pos.y <= region.end.y


## S31 mode tick (pure over entity positions). Returns the winner's display
## name when a mode win condition is met, else "".
func tick_mode(delta: float, entity_positions: Dictionary,
		siege_target_down: bool) -> String:
	if game_mode == null or match_result != &"":
		return ""
	match int(game_mode.win_condition):
		GameModeScript.WinCondition.CONTROL:
			return _tick_control(delta, entity_positions)
		GameModeScript.WinCondition.MOBILITY_RACE:
			return _tick_race(entity_positions)
		GameModeScript.WinCondition.SIEGE:
			return _tick_siege(delta, entity_positions, siege_target_down)
		GameModeScript.WinCondition.SURVIVE:
			return _tick_survive(entity_positions)
	return ""


## SURVIVE (S32): when the turn limit is reached, the mech with more
## remaining health wins; a tie continues the match past the limit.
func _tick_survive(entity_positions: Dictionary) -> String:
	if turn_number < int(game_mode.survive_turns):
		return ""
	var best_name := ""
	var best_health := -1.0
	for entity_name in entity_positions:
		var hp: float = entity_health(entity_name)
		if hp <= 0.0:
			continue
		if hp > best_health:
			best_health = hp
			best_name = entity_name
		elif hp == best_health:
			return ""
	if best_health <= 0.0:
		return ""
	return best_name


func _tick_control(delta: float, entity_positions: Dictionary) -> String:
	var zones := _control_zones()
	if zones.is_empty():
		return ""
	for entity_name in entity_positions:
		if not hold_progress.has(entity_name):
			hold_progress[entity_name] = 0.0
		var pos: Vector2 = entity_positions[entity_name]
		for zone in zones:
			if _in_region(pos, zone["region"]):
				hold_progress[entity_name] = hold_progress.get(entity_name, 0.0) + delta
				if hold_progress[entity_name] >= game_mode.hold_time_to_win:
					return entity_name
				break
	return ""


func _tick_race(entity_positions: Dictionary) -> String:
	var checkpoints := _checkpoints()
	if checkpoints.is_empty():
		return ""
	for entity_name in entity_positions:
		var progress: int = race_progress.get(entity_name, 0)
		if progress >= checkpoints.size():
			continue
		var gate: Dictionary = checkpoints[progress]
		if _in_region(entity_positions[entity_name], gate["region"]):
			race_progress[entity_name] = progress + 1
			if race_progress[entity_name] >= checkpoints.size():
				return entity_name
	return ""


func _tick_siege(delta: float, entity_positions: Dictionary,
		siege_target_down: bool) -> String:
	# 1v1 roles: entity index 0 is the ATTACKER (collapse the target before
	# the turn limit), index 1 is the DEFENDER. Turn-based pacing: the limit
	# is counted in turns, not seconds.
	if siege_target_down:
		return entity_names[0] if entity_names.size() > 0 else ""
	if turn_number > game_mode.siege_turns:
		return entity_names[1] if entity_names.size() > 1 else ""
	return ""
