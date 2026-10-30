extends RigidBody3D
## Artillery projectile (S04/S11). The physics engine owns the flight
## (implementation-guide §10): gravity, collision, CCD. Gameplay rules hang
## off the `exploded` signal, consumed by the match layer — damage and turn
## transitions never happen inside this node.
##
## S11: flight physics are per-weapon — gravity multiplier, bounce count and
## restitution are pushed in by the match layer at spawn (before the body
## enters the physics space).

signal exploded(position: Vector3)

## Grace window during which the shell ignores its shooter — muzzle grazes
## (steep aim angles) must not detonate on the barrel that fired them.
const SHOOTER_GRACE := 0.15

@export var match_gravity := 30.0
@export var max_lifetime := 8.0

## Per-weapon flight behavior (S11), set before add_child.
var gravity_mult := 1.0
var bounces_left := 0
var bounciness := 0.0

var _age := 0.0
var _done := false
var _shooter: Node = null


func _ready() -> void:
	var engine_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	gravity_scale = match_gravity * gravity_mult / engine_gravity
	if bounciness > 0.0:
		var mat := PhysicsMaterial.new()
		mat.bounce = bounciness
		physics_material_override = mat
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
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
	exploded.emit(global_position)
	queue_free()
