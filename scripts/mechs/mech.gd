extends CharacterBody3D
## The player mech (S02): physics body + input wiring.
##
## Movement rules live in the Movement child (mech_movement_controller.gd);
## this script only translates InputLayer state into driver intent, applies
## the controller's kinematics, handles facing (presentation), and respawn.
## Mech identity/stats become data-driven MechDefinition resources in S08+.

const RESPAWN_POINT := Vector3(0, 3, 0)
const KILL_PLANE_Y := -10.0
const FACING_DEADZONE := 0.1

# Position is battlefield-local: Main is the unmoved match root, so local ==
# global in-game. Keeping rules in local frame also keeps them testable
# headless without a tree entry (and matches the MatchState direction: state
# as data, not scene-graph transforms).
@onready var _movement: Node = $Movement
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group("mech")


func _physics_process(delta: float) -> void:
	_movement.move_axis = InputLayer.get_move_axis()
	_movement.want_jump = InputLayer.is_action_just_pressed("jump")
	velocity = _movement.compute_velocity(velocity, is_on_floor(), delta)
	move_and_slide()
	position = _movement.clamp_position(position)
	_update_facing(_movement.move_axis, delta)
	if should_respawn():
		respawn()


func _update_facing(axis: float, delta: float) -> void:
	if absf(axis) < FACING_DEADZONE:
		return
	var target_yaw := 0.0 if axis > 0.0 else PI
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))


func should_respawn() -> bool:
	return position.y < KILL_PLANE_Y


func respawn() -> void:
	position = RESPAWN_POINT
	velocity = Vector3.ZERO
