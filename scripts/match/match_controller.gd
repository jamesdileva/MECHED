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
const PROJECTILE_SCENE := preload("res://scenes/projectiles/projectile.tscn")
const EXPLOSION_SCENE := preload("res://scenes/projectiles/explosion_effect.tscn")

const CHARGE_TIME := 1.2

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
	for entity in entities:
		entity.sync_health(turn_manager.state.entity_health(String(entity.name)))
	add_to_group("match_controller")


func _physics_process(delta: float) -> void:
	if entities.is_empty() or turn_manager == null:
		return
	turn_manager.tick(delta)
	var active: int = turn_manager.state.active_index
	for i in entities.size():
		var mech = entities[i]
		if i == active and i == player_index:
			_drive_player(mech, i, delta)
		else:
			mech.move_axis = 0.0
			mech.want_jump = false
			mech.aim_axis = 0.0
			mech.charge = 0.0


func _drive_player(mech, index: int, delta: float) -> void:
	mech.aim_axis = InputLayer.get_aim_axis()
	mech.move_axis = turn_manager.apply_movement(index, InputLayer.get_move_axis(), delta)
	# Movement intents are move-phase only; the turn manager double-checks
	# apply_movement/submit_action, but the mech must never even see a jump
	# or a charging barrel while a shell is in flight.
	var in_move_phase: bool = turn_manager.state.is_in_move_phase()
	mech.want_jump = in_move_phase and InputLayer.is_action_just_pressed("jump")

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
	get_tree().current_scene.add_child(projectile)
	var muzzle: Node3D = mech.get_node("Visual/AimPivot/Muzzle")
	projectile.global_position = muzzle.global_position
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
	sphere.radius = Ballistics.EXPLOSION_RADIUS
	params.shape = sphere
	params.transform = Transform3D(Basis(), position)
	params.collide_with_bodies = true
	var hits := get_viewport().world_3d.direct_space_state.intersect_shape(params, 8)
	for hit in hits:
		var collider = hit.get("collider")
		if collider is Node and collider.is_in_group("mech"):
			var dist: float = (collider.global_position - position).length()
			var damage := Ballistics.damage_falloff(dist)
			if damage > 0.0:
				_apply_damage(collider, damage)

	turn_manager.finish_resolution()


## MatchState.mech_health is the source of truth; the mech node gets a mirror.
func _apply_damage(mech: Node, amount: float) -> void:
	var entity_name := String(mech.name)
	var new_health: float = turn_manager.state.apply_damage(entity_name, amount)
	mech.sync_health(new_health)


func status_line() -> String:
	if turn_manager == null or not turn_manager.state.started:
		return "match not started"
	var s = turn_manager.state
	if s.is_resolving():
		return "turn %d | %s | resolving" % [s.turn_number, s.active_entity_name()]
	return "turn %d | %s | move %.1fs | timer %.1fs" % [
		s.turn_number, s.active_entity_name(), s.movement_budget_left, s.turn_time_left,
	]
