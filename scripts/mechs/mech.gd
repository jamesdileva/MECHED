extends CharacterBody3D
## A mech body (S02/S03): physics, facing, respawn.
##
## Movement rules live in the Movement child (mech_movement_controller.gd).
## move_axis / want_jump are driver intent, set externally every physics tick
## by the MatchController (player input today, an AI driver later — the same
## interface). The body never reads input devices itself.

@export var respawn_point := Vector3(0, 3, 0)

const KILL_PLANE_Y := -10.0
const FACING_DEADZONE := 0.1

## Driver intent, set externally each physics tick by the match layer.
var move_axis := 0.0
var want_jump := false

# Typed via get_node rather than a global class reference so headless script
# mode never depends on global class registration.
@onready var _movement: Node = $Movement
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group("mech")


func _physics_process(delta: float) -> void:
	velocity = _movement.compute_velocity(velocity, is_on_floor(), delta)
	move_and_slide()
	position = _movement.clamp_position(position)
	_update_facing(move_axis, delta)
	if should_respawn():
		respawn()
	want_jump = false


func _update_facing(axis: float, delta: float) -> void:
	if absf(axis) < FACING_DEADZONE:
		return
	var target_yaw := 0.0 if axis > 0.0 else PI
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))


func should_respawn() -> bool:
	return position.y < KILL_PLANE_Y


func respawn() -> void:
	position = respawn_point
	velocity = Vector3.ZERO
