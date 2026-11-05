extends RigidBody3D
## Artillery projectile (S04/S11/S12). The physics engine owns the flight
## (implementation-guide §10): gravity, collision, CCD. Gameplay rules hang
## off the `exploded` signal, consumed by the match layer — damage and turn
## transitions never happen inside this node.
##
## S11: per-weapon flight physics (gravity mult, bounces, restitution).
## S12: per-mech transformations — shells carry their own impact stats (the
## match layer computes them from the fired weapon at spawn) and may home on
## a locked target with a capped turn rate.

signal exploded(position: Vector3, stats: Dictionary)

## Grace window during which the shell ignores its shooter — muzzle grazes
## (steep aim angles) must not detonate on the barrel that fired them.
const SHOOTER_GRACE := 0.15

@export var match_gravity := 30.0
@export var max_lifetime := 8.0

## Per-weapon flight behavior, set before add_child.
var gravity_mult := 1.0
var bounces_left := 0
var bounciness := 0.0
## Stats of the fired weapon (already modifier- and transformation-scaled);
## the match layer reads them back at impact.
var impact_stats: Dictionary = {}

var _age := 0.0
var _done := false
var _shooter: Node = null
var _homing_target: Node = null
var _homing_strength := 0.0


func _ready() -> void:
	var engine_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	gravity_scale = match_gravity * gravity_mult / engine_gravity
	if bounciness > 0.0:
		var mat := PhysicsMaterial.new()
		mat.bounce = bounciness
		physics_material_override = mat
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _homing_strength > 0.0 and _homing_target != null \
			and is_instance_valid(_homing_target):
		var to_target: Vector3 = _homing_target.global_position - global_position
		if to_target.length() > 0.01:
			# Guidance changes direction only — speed (and the base arc's
			# identity) is preserved.
			var speed := linear_velocity.length()
			linear_velocity = steer_direction(linear_velocity, to_target,
					_homing_strength, delta) * speed
	_age += delta
	if _age >= max_lifetime:
		_explode()
	elif _is_out_of_bounds():
		# A shell that leaves the battlefield must not hold the turn in
		# resolution for its whole lifetime.
		_explode()


func launch(velocity: Vector3) -> void:
	linear_velocity = velocity


func set_shooter(shooter: Node) -> void:
	_shooter = shooter


func set_homing(target: Node, strength: float) -> void:
	_homing_target = target
	_homing_strength = strength


func _on_body_entered(body: Node) -> void:
	if body == _shooter and _age < SHOOTER_GRACE:
		return
	# Direct mech hits always detonate; otherwise bounces absorb contacts
	# (the physics material does the actual rebounding) until they run out.
	if not body.is_in_group("mech") and bounces_left > 0:
		bounces_left -= 1
		return
	_explode()


func _is_out_of_bounds() -> bool:
	return absf(global_position.x) > 45.0 or global_position.y > 30.0 \
			or global_position.y < -15.0


func _explode() -> void:
	if _done:
		return
	_done = true
	exploded.emit(global_position, impact_stats.duplicate())


## Capped-rate steering: slerp toward the desired direction without
## overshoot; a zero rate leaves the direction unchanged. Pure — testable
## headless.
static func steer_direction(current: Vector3, desired: Vector3, turn_rate: float,
		delta: float) -> Vector3:
	if current.length() < 0.001:
		return desired.normalized()
	var blended: Vector3 = current.normalized().slerp(desired.normalized(),
			clampf(turn_rate * delta, 0.0, 1.0))
	if blended.length() < 0.001:
		return current.normalized()
	return blended.normalized()


## Angular offset (degrees) for shell `index` of a `count`-shell spread.
static func spread_offset(index: int, count: int, spread_degrees: float) -> float:
	if count <= 1:
		return 0.0
	return (float(index) - float(count - 1) * 0.5) * spread_degrees
