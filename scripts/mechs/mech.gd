extends CharacterBody3D
## A mech body (S02–S04): physics, facing, aiming, health, respawn.
##
## Movement rules live in the Movement child (mech_movement_controller.gd).
## move_axis / want_jump / aim_axis / charge are driver intent, set externally
## every physics tick by the MatchController (player input today, an AI driver
## later — the same interface). The body never reads input devices itself.
## Health is a synced mirror: MatchState.mech_health is the source of truth
## and the match layer pushes values in via sync_health().

@export var respawn_point := Vector3(0, 3, 0)

const KILL_PLANE_Y := -10.0
const FACING_DEADZONE := 0.1
const AIM_SPEED_DEG := 70.0
const AIM_MIN_DEG := 0.0
const AIM_MAX_DEG := 90.0

## Driver intent, set externally each physics tick by the match layer.
var move_axis := 0.0
var want_jump := false
var aim_axis := 0.0
var charge := 0.0

## Barrel elevation in degrees above the horizon (0–90); persists between
## turns like GunBound's angle memory.
var aim_angle := 45.0

## Health mirror — authoritative value lives in MatchState.mech_health.
var health := 100.0

# Typed via get_node rather than a global class reference so headless script
# mode never depends on global class registration.
@onready var _movement: Node = $Movement
@onready var _visual: Node3D = $Visual
@onready var _aim_pivot: Node3D = $Visual/AimPivot


func _ready() -> void:
	add_to_group("mech")


func _physics_process(delta: float) -> void:
	aim_angle = clampf(aim_angle - aim_axis * AIM_SPEED_DEG * delta, AIM_MIN_DEG, AIM_MAX_DEG)
	_aim_pivot.rotation.z = deg_to_rad(aim_angle)
	velocity = _movement.compute_velocity(velocity, move_axis, want_jump, is_on_floor(), delta)
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


## +1 when facing right (+X), -1 when facing left. Used to sign the launch
## vector; aim_angle itself is always 0–90 above the horizon.
func facing() -> float:
	return -1.0 if _visual.rotation.y > PI * 0.5 else 1.0


func sync_health(value: float) -> void:
	health = value


func should_respawn() -> bool:
	return position.y < KILL_PLANE_Y


func respawn() -> void:
	position = respawn_point
	velocity = Vector3.ZERO
