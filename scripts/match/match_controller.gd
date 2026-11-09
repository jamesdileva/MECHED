extends Node
## Presentation-facing shim for the match simulation (implementation-guide §3:
## simulation separate from presentation).
##
## Reads InputLayer ONLY for the active player entity and zeroes intent for
## every other mech — that is the structural guarantee behind "a player cannot
## move during another entity's turn". TurnManager still validates every
## submit (defense in depth). The dummy opponent has no driver: it receives
## zeroed intent and its turn ends via the turn timer until the AI (S15+)
## replaces it.
##
## Fire flow: hold fire charges (0–1 over CHARGE_TIME), release submits a
## FireAction; on acceptance the turn is RESOLVING and the projectile spawns
## from the mech's muzzle. Impact (deferred — space state is locked during
## physics callbacks) applies falloff damage through MatchState and finishes
## the resolution.

const TurnManagerScript := preload("res://scripts/match/turn_manager.gd")
const EndTurnAction := preload("res://scripts/match/action_end_turn.gd")
const FireAction := preload("res://scripts/match/action_fire.gd")
const Ballistics := preload("res://scripts/combat/ballistics.gd")
const Knockback := preload("res://scripts/combat/knockback.gd")
const PROJECTILE_SCENE := preload("res://scenes/projectiles/projectile.tscn")
const EXPLOSION_SCENE := preload("res://scenes/projectiles/explosion_effect.tscn")
const WEAPON_ROCKET := preload("res://data/weapons/rocket.tres")
const WEAPON_GRENADE := preload("res://data/weapons/grenade.tres")
const WEAPON_ENERGY := preload("res://data/weapons/energy_shot.tres")
const ProjectileScript := preload("res://scripts/projectiles/projectile.gd")
const AIDriverScript := preload("res://scripts/ai/ai_driver.gd")
const AIDifficultyScript := preload("res://scripts/ai/ai_difficulty.gd")

const CHARGE_TIME := 1.2
## Universal weapons (S11): the default loadout every chassis equips when its
## definition does not name a specific one.
const DEFAULT_WEAPONS: Array = [WEAPON_ROCKET, WEAPON_GRENADE, WEAPON_ENERGY]

@export var player_index := 0
## AI difficulty preset name (S18): "Easy" / "Normal" / "Hard" / "Expert".
## Hard is the default so the S16/S17 behaviors ship enabled.
@export var ai_difficulty := "Hard"

var turn_manager
var entities: Array[Node] = []
var _ai = null
## Shells in flight (S12 multi-shot): the turn resolves when the count
## reaches zero, no matter which shell dies first.
var _pending_shells := 0
## Destructible terrain (terrain_system.gd), wired by Main. Craters are carved
## at every projectile impact before the turn resolves.
var terrain = null


## Wires the entity list (index = turn order) and begins the match.
## Plain-Array parameter so callers can pass [$A, $B] node literals directly.
## Definitions (if assigned) are applied first and their display names become
## the entity keys used by MatchState and the HUD.
func setup(p_entities: Array) -> void:
	entities.assign(p_entities)
	turn_manager = TurnManagerScript.new()
	var names := PackedStringArray()
	for entity in entities:
		entity.apply_definition(entity.definition)
		names.append(String(entity.display_name()))
	turn_manager.begin_match(names)
	for entity in entities:
		var entity_name := String(entity.display_name())
		var max_health: float = entity.definition.max_health \
				if entity.definition != null else turn_manager.state.STARTING_HEALTH
		turn_manager.state.set_entity_health(entity_name, max_health)
		turn_manager.state.set_entity_max_health(entity_name, max_health)
		entity.sync_health(max_health)
		if entity.definition != null and entity.definition.jetpack_fuel > 0.0:
			turn_manager.state.set_fuel_limit(entity_name, entity.definition.jetpack_fuel)
		# Universal weapons: definitions may narrow the loadout, otherwise
		# every chassis equips the full set.
		var loadout: Array = entity.definition.weapons \
				if entity.definition != null and not entity.definition.weapons.is_empty() \
				else DEFAULT_WEAPONS
		turn_manager.state.set_loadout(entity_name, loadout)
	add_to_group("match_controller")


func _physics_process(delta: float) -> void:
	if entities.is_empty() or turn_manager == null:
		return
	# Match over (S15): freeze — intents zeroed, turns stopped, result shown.
	if turn_manager.state.match_result != &"":
		for mech in entities:
			_zero_intent(mech)
		return
	turn_manager.tick(delta)
	var active: int = turn_manager.state.active_index
	for i in entities.size():
		var mech = entities[i]
		if i != active:
			_zero_intent(mech)
		elif i == player_index:
			_drive_player(mech, i, delta)
		else:
			_drive_ai(mech, i, delta)
	_consume_ai_fire()


func _zero_intent(mech) -> void:
	mech.move_axis = 0.0
	mech.want_jump = false
	mech.want_dash = false
	mech.want_thrust = false
	mech.aim_axis = 0.0
	mech.charge = 0.0
	# The anchor is a per-turn stance: it drops when your turn ends.
	mech.anchored = false


## The AI opponent's driver (S15/S16): the ai_driver state machine sets intent,
## the match layer consumes its fire request through the shared release path.
func _drive_ai(mech, index: int, delta: float) -> void:
	if _ai == null:
		_ai = AIDriverScript.new()
		_ai.difficulty = AIDifficultyScript.profile_for(ai_difficulty)
	var enemies: Array = entities.filter(func(e): return e != mech)
	_ai.update(mech, enemies, turn_manager.state, turn_manager, terrain, delta)


## Shared release path for every driver (player + AI): submit the FireAction
## and spawn the shell. Nobody else spawns projectiles.
func _release_fire(mech, index: int, power: float) -> void:
	var action = FireAction.new()
	action.power = power
	action.weapon_index = turn_manager.state.active_weapon_slot(
			String(mech.display_name()))
	if turn_manager.submit_action(action, index):
		_spawn_projectile(mech, power)
	mech.charge = 0.0


## Hand-off from the AI driver: it asks for a release, the match layer fires.
func _consume_ai_fire() -> void:
	if _ai == null or _ai.fire_request < 0.0:
		return
	var power: float = _ai.fire_request
	_ai.fire_request = -1.0
	var ai_index: int = -1
	for i in entities.size():
		if i != player_index:
			ai_index = i
			break
	if ai_index >= 0:
		_release_fire(entities[ai_index], ai_index, power)


func _drive_player(mech, index: int, delta: float) -> void:
	mech.aim_axis = InputLayer.get_aim_axis()
	# Movement intents are move-phase only and stop when energy runs out.
	# Fire/end-turn stay available on an empty energy bar.
	var in_move_phase: bool = turn_manager.state.is_in_move_phase()
	var may_move: bool = turn_manager.state.can_move()
	if in_move_phase and InputLayer.is_action_just_pressed("use_ability"):
		mech.anchored = not mech.anchored
	# An anchored Bastion plants: no walk, no jump, no dash, no thrust —
	# blast immunity is paid for with total immobility.
	if mech.anchored:
		may_move = false
	mech.move_axis = InputLayer.get_move_axis() if may_move else 0.0
	# Requested distance (|axis| × max_speed × dt), never actual displacement —
	# a mech knocked back by a blast must not pay energy for it.
	if may_move:
		turn_manager.spend_movement(index, absf(mech.move_axis) * mech.max_speed() * delta)
	# Jump costs energy and is refused by the simulation when unaffordable.
	mech.want_jump = (may_move
			and InputLayer.is_action_just_pressed("jump")
			and mech.is_on_floor()
			and turn_manager.spend_jump(index))
	# Dash burst (S08): grounded, edge-triggered, energy-gated; dash-less
	# chassis refuse it in can_dash().
	mech.want_dash = (may_move
			and InputLayer.is_action_just_pressed("dash")
			and mech.is_on_floor()
			and mech.can_dash()
			and turn_manager.spend_dash(index, mech.dash_cost()))
	# Jetpack (S09): hold jump while airborne to thrust. Fuel drains per tick
	# through the turn manager; a refused spend cuts thrust (empty tank).
	mech.want_thrust = (may_move
			and not mech.is_on_floor()
			and InputLayer.is_action_pressed("jump")
			and mech.can_thrust()
			and turn_manager.spend_fuel(index, mech.fuel_burn() * delta))

	if in_move_phase:
		if InputLayer.is_action_pressed("fire"):
			mech.charge = minf(mech.charge + delta / CHARGE_TIME, 1.0)
		elif InputLayer.is_action_just_released("fire") and mech.charge > 0.0:
			_release_fire(mech, index, mech.charge)

		if InputLayer.is_action_just_pressed("cycle_weapon"):
			turn_manager.state.cycle_weapon(String(mech.display_name()))

		if InputLayer.is_action_just_pressed("end_turn"):
			turn_manager.submit_action(EndTurnAction.new(), index)


func _spawn_projectile(mech, power: float) -> void:
	var weapon = turn_manager.state.active_weapon(String(mech.display_name()))
	if weapon == null:
		return
	var modifier = mech.definition.weapon_modifier if mech.definition != null else null
	var stats: Dictionary = weapon.effective(modifier)
	# The signature system (S12): the mech's transformation layers its identity
	# onto the base weapon — stats and behavior (count/spread/homing).
	var transformation = modifier.transformation_for(weapon.display_name) \
			if modifier != null else null
	if transformation != null:
		stats = transformation.apply(stats)
	var muzzle: Node3D = mech.get_node("Visual/AimPivot/Muzzle")
	var count: int = stats.get("projectile_count", 1)
	var spread: float = stats.get("spread_degrees", 0.0)
	var homing: float = stats.get("homing_strength", 0.0)
	var target := _nearest_enemy(mech)
	for i in count:
		var projectile = PROJECTILE_SCENE.instantiate()
		projectile.position = muzzle.global_position
		projectile.set_shooter(mech)
		projectile.gravity_mult = stats["gravity_mult"]
		projectile.bounces_left = stats["bounces"]
		projectile.bounciness = stats["bounciness"]
		projectile.wind_accel = Vector3(
				turn_manager.state.wind.x, turn_manager.state.wind.y, 0.0)
		projectile.impact_stats = stats
		if homing > 0.0 and target != null:
			projectile.set_homing(target, homing)
		get_tree().current_scene.add_child(projectile)
		var angle: float = mech.aim_angle \
				+ ProjectileScript.spread_offset(i, count, spread)
		projectile.launch(Ballistics.launch_velocity(
				angle, mech.facing(), power, stats["speed_min"], stats["speed_max"]))
		projectile.exploded.connect(_on_projectile_exploded, CONNECT_ONE_SHOT)
		_pending_shells += 1


## Locked at launch: the guidance target (nearest opposing mech).
func _nearest_enemy(shooter) -> Node:
	var best: Node = null
	var best_dist := INF
	for entity in entities:
		if entity == shooter:
			continue
		var dist: float = entity.global_position.distance_to(shooter.global_position)
		if dist < best_dist:
			best_dist = dist
			best = entity
	return best


func _on_projectile_exploded(position: Vector3, stats: Dictionary) -> void:
	_pending_shells -= 1
	var is_final := _pending_shells <= 0
	_resolve_impact.call_deferred(position, stats, is_final)


## Runs deferred: the explosion signal arrives while the physics space is
## locked, and the sphere query below needs it unlocked.
func _resolve_impact(position: Vector3, stats: Dictionary, is_final: bool) -> void:
	var fx = EXPLOSION_SCENE.instantiate()
	fx.blast_radius = stats.get("explosion_radius", Ballistics.EXPLOSION_RADIUS)
	get_tree().current_scene.add_child(fx)
	fx.global_position = position

	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = stats.get("knockback_radius", Knockback.KNOCKBACK_RADIUS)
	params.shape = sphere
	params.transform = Transform3D(Basis(), position)
	params.collide_with_bodies = true
	# One query serves damage AND knockback: the blast pushes farther than it
	# hurts, and each module zeroes itself past its own radius.
	var hits := get_viewport().world_3d.direct_space_state.intersect_shape(params, 16)
	for hit in hits:
		var collider = hit.get("collider")
		if collider is Node and collider.is_in_group("mech"):
			var dist: float = (collider.global_position - position).length()
			var damage: float = Ballistics.damage_falloff(dist,
					stats.get("explosion_radius", Ballistics.EXPLOSION_RADIUS),
					stats.get("damage_max", Ballistics.MAX_DAMAGE),
					stats.get("direct_hit_radius", Ballistics.DIRECT_HIT_RADIUS))
			if damage > 0.0:
				_apply_damage(collider, damage)
			var impulse: Vector3 = Knockback.impulse(
					collider.global_position, position,
					collider.is_on_floor(), collider.mass, collider.anchored,
					stats.get("knockback_force", Knockback.KNOCKBACK_FORCE),
					stats.get("knockback_radius", Knockback.KNOCKBACK_RADIUS))
			if impulse != Vector3.ZERO:
				# Physics owns what the impulse becomes (guide §10): arcs,
				# terrain, falling — the next move_and_slide integrates it.
				collider.velocity += impulse

	if terrain != null:
		# Crater size scales with the weapon's terrain damage (S11: grenades
		# dig, energy shots scorch; S12 transformations layer on top).
		var carve: float = stats.get("explosion_radius", Ballistics.EXPLOSION_RADIUS) \
				* stats.get("terrain_damage_mult", 1.0)
		terrain.apply_explosion(position, carve)

	# Multi-shot (S12): every submunition resolves independently; the turn
	# passes only after the LAST shell dies.
	if is_final:
		turn_manager.finish_resolution()


## MatchState.mech_health is the source of truth; the mech node gets a mirror.
func _apply_damage(mech: Node, amount: float) -> void:
	var entity_name := String(mech.display_name())
	var new_health: float = turn_manager.state.apply_damage(entity_name, amount)
	mech.sync_health(new_health)
	# Minimal victory rule (S15): a chassis at zero health ends the match —
	# the survivor takes the result. Full match flow arrives in S20.
	if new_health <= 0.0:
		for other_name in turn_manager.state.entity_names:
			if other_name != entity_name:
				turn_manager.state.declare_winner(other_name)


func status_line() -> String:
	if turn_manager == null or not turn_manager.state.started:
		return "match not started"
	# Match result (S15) takes over the line when the match ends.
	if turn_manager.state.match_result != &"":
		return String(turn_manager.state.match_result)
	var s = turn_manager.state
	if s.is_resolving():
		return "turn %d | %s | resolving" % [s.turn_number, s.active_entity_name()]
	return "turn %d | %s | energy %.0f | timer %.1fs | wind %s %.1f" % [
		s.turn_number, s.active_entity_name(), s.movement_energy_left,
		s.turn_time_left, wind_arrow(s.wind), s.wind.length(),
	]


## 8-way compass arrow for the wind vector (screen: +x right, +y up).
func wind_arrow(wind: Vector2) -> String:
	if wind.length() < 0.05:
		return "·"
	const ARROWS := ["→", "↗", "↑", "↖", "←", "↙", "↓", "↘"]
	return ARROWS[wrapi(roundi(wind.angle() / (TAU / 8.0)), 0, 8)]
