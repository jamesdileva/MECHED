extends RigidBody3D
## Artillery projectile (S04). The physics engine owns the flight
## (implementation-guide §10): gravity, collision, CCD. Gameplay rules hang
## off the `exploded` signal, consumed by the match layer — damage and turn
## transitions never happen inside this node.

signal exploded(position: Vector3)

@export var match_gravity := 30.0
@export var max_lifetime := 8.0

var _age := 0.0
var _done := false


func _ready() -> void:
	var engine_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	gravity_scale = match_gravity / engine_gravity
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= max_lifetime:
		_explode()


func launch(velocity: Vector3) -> void:
	linear_velocity = velocity


func _on_body_entered(_body: Node) -> void:
	_explode()


func _explode() -> void:
	if _done:
		return
	_done = true
	exploded.emit(global_position)
	queue_free()
