extends Node
## Generic movement rules for a mech body (implementation-guide §6: movement
## rules are separate from mech identity).
##
## Knows nothing about input devices or mech identity: a driver (player input
## via InputLayer today, an AI planner later) sets move_axis / want_jump each
## tick, then the owning CharacterBody3D calls compute_velocity() followed by
## move_and_slide(). Stats are exported so future MechDefinition resources can
## populate them (S08+: data-driven mechs).

@export var max_speed := 8.0
@export var acceleration := 40.0
@export var jump_velocity := 10.0
@export var gravity := 30.0

@export var bounds_min_x := -27.0
@export var bounds_max_x := 27.0
@export var plane_z := 0.0

## Driver intent, set every physics tick: -1..1 horizontal.
var move_axis := 0.0
## Driver intent, edge-triggered: the driver decides what "pressed" means.
var want_jump := false


## Pure kinematics — no physics-server access — so movement rules are
## testable headless without stepping the physics simulation.
func compute_velocity(current: Vector3, on_floor: bool, delta: float) -> Vector3:
	var v := current
	if on_floor:
		v.y = jump_velocity if want_jump else 0.0
	else:
		v.y -= gravity * delta
	v.x = move_toward(v.x, move_axis * max_speed, acceleration * delta)
	v.z = 0.0
	return v


## Movement limits: keep the mech inside the battlefield and locked to the
## gameplay plane (side-on with limited depth, architecture.md §3).
func clamp_position(pos: Vector3) -> Vector3:
	return Vector3(clampf(pos.x, bounds_min_x, bounds_max_x), pos.y, plane_z)
