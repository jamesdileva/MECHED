extends RefCounted
## The first AI opponent (S15): deterministic tactical reasoning through the
## SAME interfaces players use — TurnManager spending, FireAction, mech
## intent vars. No cheating (implementation-guide §11): it reads MatchState
## and submits actions; it never touches health, positions, or physics.
##
## Pipeline (roadmap S15): move into the standoff band → solve the shot
## (wind-aware simulate_flight over candidate angle/power per loadout weapon)
## → aim → charge → fire. Difficulty scaling (S18) = candidate counts and
## band tuning, not accuracy cheats.

const Ballistics := preload("res://scripts/combat/ballistics.gd")
const Positioning := preload("res://scripts/ai/ai_positioning.gd")

const PREFERRED_MIN := 6.0
const PREFERRED_MAX := 18.0
const SOLVE_ANGLES: Array = [30.0, 45.0, 60.0, 75.0]
const SOLVE_POWERS: Array = [0.5, 0.75, 1.0]
const CHARGE_TIME := 1.2
## Walking at least this long before firing guarantees facing has flipped.
const MIN_FACE_TIME := 0.4

## Turn state machine: move → fire → (idle until the turn ends).
var phase := "move"
var last_turn := -1
var plan: Dictionary = {}
var _face_time := 0.0
## The tactical position chosen this turn (S16); NAN until chosen.
var move_target_x := NAN
## Set when the driver wants the match layer to release a shot at this power;
## consumed (and reset to -1) by the match layer — the driver stays decoupled
## from projectile spawning.
var fire_request := -1.0


func reset() -> void:
	phase = "move"
	plan = {}
	_face_time = 0.0
	move_target_x = NAN
	fire_request = -1.0


## Per-tick driver update. Call only while this mech is the active entity and
## the match is not over. `terrain` is the pure grid wrapper (or null).
func update(mech, enemies: Array, state, tm, terrain, delta: float) -> void:
	if state.turn_number != last_turn:
		last_turn = state.turn_number
		reset()
	mech.move_axis = 0.0
	mech.want_jump = false
	mech.want_dash = false
	mech.want_thrust = false
	mech.aim_axis = 0.0
	if not state.is_in_move_phase():
		return
	var target := _nearest_alive(mech, enemies)
	if target == null:
		return
	match phase:
		"move":
			_move_phase(mech, target, state, tm, terrain, delta)
		"fire":
			_fire_phase(mech, state, delta)
		_:
			pass


func _move_phase(mech, target, state, tm, terrain, delta: float) -> void:
	# S16: choose a tactical position once per turn and walk there —
	# repositioning instead of immediately firing when a better spot exists.
	if is_nan(move_target_x):
		var walk_range: float = state.movement_energy_left
		move_target_x = Positioning.choose_position(
				mech.position.x, target.global_position, walk_range, terrain)["x"]
	var to_target: float = target.global_position.x - mech.global_position.x
	var at_position := absf(mech.position.x - move_target_x) < 0.5
	if at_position:
		# Face the target before solving: a short walk flips the visual yaw
		# the launch direction comes from.
		if _face_time >= MIN_FACE_TIME:
			plan = solve_shot(mech.global_position + Vector3(0, 1.0, 0),
					target.global_position, signf(to_target), state.wind,
					_loadout_stats(mech, state))
			if plan.has("slot"):
				state.set_active_weapon(String(mech.display_name()), plan["slot"])
			mech.aim_angle = plan.get("angle", 45.0)
			phase = "fire"
			return
		_face_time += delta
		mech.move_axis = 1.0 if to_target > 0.0 else -1.0
	else:
		mech.move_axis = 1.0 if mech.position.x < move_target_x else -1.0
	tm.spend_movement(tm.state.active_index,
			absf(mech.move_axis) * mech.max_speed() * delta)


func _fire_phase(mech, state, delta: float) -> void:
	mech.aim_angle = plan.get("angle", 45.0)
	var power: float = plan.get("power", 1.0)
	mech.charge = minf(mech.charge + delta / CHARGE_TIME, power)
	if mech.charge >= power - 0.01:
		# Release through the match layer; the driver never spawns shells.
		fire_request = power
		phase = "done"


## Wind-aware shot solver: best (weapon, angle, power) by simulated miss
## distance. Pure — headless-testable. `weapon_stats` entries are
## {slot, stats} dictionaries in firing order.
static func solve_shot(origin: Vector3, target_pos: Vector3, dir_sign: float,
		wind: Vector2, weapon_stats: Array) -> Dictionary:
	var best := {"miss": INF, "slot": -1, "angle": 45.0, "power": 1.0}
	for entry in weapon_stats:
		var stats: Dictionary = entry["stats"]
		for angle in SOLVE_ANGLES:
			for power in SOLVE_POWERS:
				var vel: Vector3 = Ballistics.launch_velocity(
						angle, dir_sign, power, stats["speed_min"], stats["speed_max"])
				var result: Dictionary = Ballistics.simulate_flight(
						origin, vel, wind, 1.0 / 60.0)
				var miss: float = result["position"].distance_to(target_pos)
				if miss < best["miss"]:
					best = {"miss": miss, "slot": entry["slot"],
							"angle": angle, "power": power}
	return best


## The mech's per-weapon effective stats (S11 modifier + S12 transformation).
func _loadout_stats(mech, state) -> Array:
	var entity_name := String(mech.display_name())
	var modifier = mech.definition.weapon_modifier if mech.definition != null else null
	var out: Array = []
	var loadout: Array = state.weapon_loadouts.get(entity_name, [])
	for slot in loadout.size():
		var stats: Dictionary = loadout[slot].effective(modifier)
		var transformation = modifier.transformation_for(loadout[slot].display_name) \
				if modifier != null else null
		if transformation != null:
			stats = transformation.apply(stats)
		out.append({"slot": slot, "stats": stats})
	return out


func _nearest_alive(mech, enemies: Array) -> Node:
	var best: Node = null
	var best_dist := INF
	for enemy in enemies:
		var dist: float = enemy.global_position.distance_to(mech.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best
