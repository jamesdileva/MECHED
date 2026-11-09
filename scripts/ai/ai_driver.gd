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
const AIDifficultyScript := preload("res://scripts/ai/ai_difficulty.gd")

## Aim clamp mirrored from mech.gd (noise must never exceed the barrel range).
const AIM_MIN_DEG := -10.0
const AIM_MAX_DEG := 90.0

## Shot-value scale (S17): direct damage in HP maps to a 0..4 tactical range
## so it competes honestly against the terrain-opportunity bonuses.
const DIRECT_DAMAGE_SCALE := 0.1
const FOOTING_VALUE := 3.0
const COLLAPSE_VALUE := 5.0
const SHOVE_VALUE := 3.0

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
## Difficulty profile (S18) — set by the match layer; empty falls back to
## Normal.
var difficulty: Dictionary = {}
## Set when the driver wants the match layer to release a shot at this power;
## consumed (and reset to -1) by the match layer — the driver stays decoupled
## from projectile spawning.
var fire_request := -1.0


func _profile() -> Dictionary:
	return difficulty if not difficulty.is_empty() \
			else AIDifficultyScript.profile_for("Normal")


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
	var prof := _profile()
	# S16/S18: choose a tactical position once per turn (positioning-enabled
	# profiles) and walk there — Easy falls back to the simple band-walk.
	if is_nan(move_target_x):
		if prof["positioning"] and terrain != null:
			var walk_range: float = state.movement_energy_left
			move_target_x = Positioning.choose_position(
					mech.position.x, target.global_position, walk_range, terrain,
					-27.0, 27.0, prof["positioning_step"])["x"]
		else:
			var to_target_x: float = target.global_position.x - mech.global_position.x
			var dist := absf(to_target_x)
			if dist > PREFERRED_MAX:
				move_target_x = target.global_position.x \
						- signf(to_target_x) * (PREFERRED_MIN + PREFERRED_MAX) * 0.5
			elif dist < PREFERRED_MIN:
				move_target_x = target.global_position.x \
						+ signf(to_target_x) * (PREFERRED_MIN - dist + 1.0)
			else:
				move_target_x = mech.position.x
	var to_target: float = target.global_position.x - mech.global_position.x
	var at_position := absf(mech.position.x - move_target_x) < 0.5
	if at_position:
		# Face the target before solving: a short walk flips the visual yaw
		# the launch direction comes from.
		if _face_time >= MIN_FACE_TIME:
			var enemy_surface_y: float = terrain.query_surface_y(target.position.x) \
					if terrain != null else NAN
			var structures: Array = terrain.structures \
					if terrain != null and "structures" in terrain else []
			var value_terrain = terrain if prof["terrain_aware"] else null
			plan = solve_shot(mech.global_position + Vector3(0, 1.0, 0),
					target.global_position, signf(to_target), state.wind,
					_loadout_stats(mech, state), enemy_surface_y, value_terrain,
					structures, prof["angles"], prof["powers"])
			if plan.has("slot"):
				state.set_active_weapon(String(mech.display_name()), plan["slot"])
			# Imperfect targeting (S18): noise draws from the per-match seeded
			# RNG — misses feel organic without accuracy cheats.
			var noise: float = prof["aim_noise_deg"]
			mech.aim_angle = clampf(plan.get("angle", 45.0)
					+ state.rng.randf_range(-noise, noise), AIM_MIN_DEG, AIM_MAX_DEG)
			phase = "fire"
			return
		_face_time += delta
		mech.move_axis = 1.0 if to_target > 0.0 else -1.0
	else:
		mech.move_axis = 1.0 if mech.position.x < move_target_x else -1.0
	tm.spend_movement(tm.state.active_index,
			absf(mech.move_axis) * mech.max_speed() * delta)


func _fire_phase(mech, state, delta: float) -> void:
	var prof := _profile()
	mech.aim_angle = clampf(plan.get("angle", 45.0)
			+ state.rng.randf_range(-prof["aim_noise_deg"], prof["aim_noise_deg"]),
			AIM_MIN_DEG, AIM_MAX_DEG)
	# Ability usage (S18): Normal+ plants the anchor while shelling — blast
	# immunity is the reward for standing still. It drops when the turn ends.
	if prof["uses_anchor"] and not mech.anchored:
		mech.anchored = true
	var power: float = plan.get("power", 1.0)
	mech.charge = minf(mech.charge + delta / CHARGE_TIME, power)
	if mech.charge >= power - 0.01:
		# Release through the match layer; the driver never spawns shells.
		fire_request = power
		phase = "done"


## Tactical value of a shell landing at impact_pos (S17): direct damage,
## footing destruction under the enemy, collapsible-structure collapse, and
## edge shove-off. Pure — headless-testable. This is what makes the AI shoot
## the bridge pillar instead of the mech standing on it.
static func shot_value(impact_pos: Vector3, stats: Dictionary, enemy_pos: Vector3,
		enemy_surface_y: float, terrain, structures: Array) -> float:
	var dist: float = impact_pos.distance_to(enemy_pos)
	var radius: float = stats["explosion_radius"]
	var value: float = Ballistics.damage_falloff(dist, radius,
			stats["damage_max"], stats["direct_hit_radius"]) * DIRECT_DAMAGE_SCALE
	# Footing destruction: a crater under the enemy's feet drops them.
	if not is_nan(enemy_surface_y) \
			and impact_pos.distance_to(Vector3(enemy_pos.x, enemy_surface_y, 0.0)) \
					<= radius * 1.2:
		value += FOOTING_VALUE
	# Structure collapse: the enemy stands on a collapsible region and the
	# blast reaches its anchors (the bridge pillar under their feet).
	var grid = terrain.grid if terrain != null and "grid" in terrain else terrain
	if grid != null and "cell_center" in grid:
		for structure in structures:
			var region: Rect2 = structure["region"]
			if enemy_pos.x < region.position.x or enemy_pos.x > region.end.x:
				continue
			if structure["anchors"].is_empty():
				continue
			var anchor: Vector2 = structure["anchors"][0]
			var anchor_cell: Vector2 = grid.cell_center(anchor.x, anchor.y)
			var anchor_pos: Vector3 = Vector3(anchor_cell.x, anchor_cell.y, 0.0)
			if impact_pos.distance_to(anchor_pos) <= radius + 1.0:
				value += COLLAPSE_VALUE
	# Shove-off: the enemy stands near a live drop and the blast lands on the
	# side AWAY from the edge — knockback pushes them off. A blast between
	# the enemy and the edge pushes them to safety, which earns nothing.
	if terrain != null and Positioning.edge_risk(enemy_pos.x, enemy_surface_y, terrain) > 0.0:
		if dist <= stats.get("knockback_radius", 5.0):
			var enemy_surface: float = enemy_surface_y if not is_nan(enemy_surface_y) \
					else enemy_pos.y
			var drop_right: bool = _is_drop(terrain, enemy_pos.x + 2.0, enemy_surface)
			var drop_left: bool = _is_drop(terrain, enemy_pos.x - 2.0, enemy_surface)
			# Knockback pushes the target AWAY from the blast: to shove them
			# into a drop on one side, the blast must land on the OPPOSITE side.
			if drop_right and impact_pos.x < enemy_pos.x - 0.5:
				value += SHOVE_VALUE
			elif drop_left and impact_pos.x > enemy_pos.x + 0.5:
				value += SHOVE_VALUE
	return value


## Is the column at world x a drop relative to surface_y (carved through, or
## a step of EDGE_DROP_M or more down)?
static func _is_drop(terrain, x: float, surface_y: float) -> bool:
	var s: float = terrain.query_surface_y(x)
	return is_nan(s) or surface_y - s >= Positioning.EDGE_DROP_M


## Wind-aware shot solver: best (weapon, angle, power) by TACTICAL VALUE
## (S17) — direct damage, terrain destruction, or shove-off, whichever the
## simulated impact is worth most. Tie-break: closer landing. With no terrain
## the value reduces to direct damage, i.e. the S15 min-miss behavior.
static func solve_shot(origin: Vector3, target_pos: Vector3, dir_sign: float,
		wind: Vector2, weapon_stats: Array, enemy_surface_y := NAN,
		terrain = null, structures: Array = [], angles: Array = SOLVE_ANGLES,
		powers: Array = SOLVE_POWERS) -> Dictionary:
	var best := {"value": -INF, "miss": INF, "slot": -1, "angle": 45.0, "power": 1.0}
	for entry in weapon_stats:
		var stats: Dictionary = entry["stats"]
		for angle in angles:
			for power in powers:
				var vel: Vector3 = Ballistics.launch_velocity(
						angle, dir_sign, power, stats["speed_min"], stats["speed_max"])
				var result: Dictionary = Ballistics.simulate_flight(
						origin, vel, wind, 1.0 / 60.0)
				var impact: Vector3 = result["position"]
				var miss: float = impact.distance_to(target_pos)
				var value: float = shot_value(impact, stats, target_pos,
						enemy_surface_y, terrain, structures)
				if value > best["value"] + 0.001 \
						or (absf(value - best["value"]) <= 0.001 and miss < best["miss"]):
					best = {"value": value, "miss": miss, "slot": entry["slot"],
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
