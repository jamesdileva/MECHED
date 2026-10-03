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

const CHARGE_TIME := 1.2
## Placeholder AI think time before passing (S15 replaces this driver).
const DUMMY_TURN_DELAY := 1.5

@export var player_index := 0

var turn_manager
var entities: Array[Node] = []
var _dummy_wait := 0.0
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
		entity.sync_health(max_health)
	add_to_group("match_controller")


func _physics_process(delta: float) -> void:
	if entities.is_empty() or turn_manager == null:
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
			_drive_dummy(mech, i, delta)


func _zero_intent(mech) -> void:
	mech.move_axis = 0.0
	mech.want_jump = false
	mech.want_dash = false
	mech.aim_axis = 0.0
	mech.charge = 0.0


## Placeholder opponent (real AI is S15+): no movement, brief pause, pass.
func _drive_dummy(mech, _index: int, delta: float) -> void:
	_zero_intent(mech)
	_dummy_wait += delta
	if _dummy_wait >= DUMMY_TURN_DELAY:
		_dummy_wait = 0.0
		turn_manager.submit_action(EndTurnAction.new(),
				turn_manager.state.active_index)


func _drive_player(mech, index: int, delta: float) -> void:
	mech.aim_axis = InputLayer.get_aim_axis()
	# Movement intents are move-phase only and stop when energy runs out.
	# Fire/end-turn stay available on an empty energy bar.
	var in_move_phase: bool = turn_manager.state.is_in_move_phase()
	var may_move: bool = turn_manager.state.can_move()
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

	if in_move_phase:
		if InputLayer.is_action_pressed("fire"):
			mech.charge = minf(mech.charge + delta / CHARGE_TIME, 1.0)
		elif InputLayer.is_action_just_released("fire") and mech.charge > 0.0:
			var action = FireAction.new()
			action.power = mech.charge
			if turn_manager.submit_action(action, index):
				_spawn_projectile(mech, mech.charge)
			mech.charge = 0.0

		if InputLayer.is_action_just_pressed("end_turn"):
			turn_manager.submit_action(EndTurnAction.new(), index)


func _spawn_projectile(mech, power: float) -> void:
	var projectile = PROJECTILE_SCENE.instantiate()
	var muzzle: Node3D = mech.get_node("Visual/AimPivot/Muzzle")
	# Set the transform BEFORE the body enters the physics space: a body added
	# at the origin registers one frame inside the terrain (the origin is
	# underground) and detonates at the shooter's feet.
	projectile.position = muzzle.global_position
	projectile.set_shooter(mech)
	get_tree().current_scene.add_child(projectile)
	projectile.launch(Ballistics.launch_velocity(mech.aim_angle, mech.facing(), power))
	projectile.exploded.connect(_on_projectile_exploded, CONNECT_ONE_SHOT)


func _on_projectile_exploded(position: Vector3) -> void:
	_resolve_impact.call_deferred(position)


## Runs deferred: the explosion signal arrives while the physics space is
## locked, and the sphere query below needs it unlocked.
func _resolve_impact(position: Vector3) -> void:
	var fx = EXPLOSION_SCENE.instantiate()
	fx.blast_radius = Ballistics.EXPLOSION_RADIUS
	get_tree().current_scene.add_child(fx)
	fx.global_position = position

	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Knockback.KNOCKBACK_RADIUS
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
			var damage := Ballistics.damage_falloff(dist)
			if damage > 0.0:
				_apply_damage(collider, damage)
			var impulse: Vector3 = Knockback.impulse(
					collider.global_position, position,
					collider.is_on_floor(), collider.mass)
			if impulse != Vector3.ZERO:
				# Physics owns what the impulse becomes (guide §10): arcs,
				# terrain, falling — the next move_and_slide integrates it.
				collider.velocity += impulse

	if terrain != null:
		terrain.apply_explosion(position, Ballistics.EXPLOSION_RADIUS)

	turn_manager.finish_resolution()


## MatchState.mech_health is the source of truth; the mech node gets a mirror.
func _apply_damage(mech: Node, amount: float) -> void:
	var entity_name := String(mech.display_name())
	var new_health: float = turn_manager.state.apply_damage(entity_name, amount)
	mech.sync_health(new_health)


func status_line() -> String:
	if turn_manager == null or not turn_manager.state.started:
		return "match not started"
	var s = turn_manager.state
	if s.is_resolving():
		return "turn %d | %s | resolving" % [s.turn_number, s.active_entity_name()]
	return "turn %d | %s | energy %.0f | timer %.1fs" % [
		s.turn_number, s.active_entity_name(), s.movement_energy_left, s.turn_time_left,
	]
