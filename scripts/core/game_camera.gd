extends Camera3D
## Side-on sandbox camera (S01): static framing of the battlefield.
##
## Framing rules and projectile/impact tracking arrive with the camera system
## (S27). Camera movement must never alter gameplay state; the optional follow
## target is pure presentation.

@export var follow_target: Node3D
@export var follow_offset: Vector3 = Vector3(0, 4, 18)
@export var follow_smoothing := 5.0


func _process(delta: float) -> void:
	if follow_target == null:
		return
	var goal := follow_target.global_position + follow_offset
	global_position = global_position.lerp(goal, 1.0 - exp(-follow_smoothing * delta))
