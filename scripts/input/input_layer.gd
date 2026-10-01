extends Node
## Device-agnostic input facade (architecture.md §18).
##
## Gameplay code reads actions ONLY through InputLayer, never through Input
## directly. Every action has keyboard and gamepad bindings declared together
## in project.godot; this facade is what keeps gameplay code device-agnostic.
##
## Analog sources (sticks, triggers) are exposed as normalized strength, so
## the keyboard path (0/1) and the analog path (0..1) converge on the same
## values.

const ALL_ACTIONS: PackedStringArray = [
	"move_left",
	"move_right",
	"jump",
	"dash",
	"aim_up",
	"aim_down",
	"fire",
	"cycle_weapon",
	"use_ability",
	"end_turn",
	"pause",
]


func get_move_axis() -> float:
	return Input.get_action_strength("move_right") - Input.get_action_strength("move_left")


func get_aim_axis() -> float:
	return Input.get_action_strength("aim_down") - Input.get_action_strength("aim_up")


func is_action_pressed(action: StringName) -> bool:
	return Input.is_action_pressed(action)


func is_action_just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action)


func is_action_just_released(action: StringName) -> bool:
	return Input.is_action_just_released(action)


## Diagnostic snapshot for the debug HUD and tooling. Not for gameplay logic.
func snapshot() -> Dictionary:
	return {
		"move": get_move_axis(),
		"aim": get_aim_axis(),
		"jump": is_action_pressed("jump"),
		"dash": is_action_pressed("dash"),
		"fire": is_action_pressed("fire"),
		"ability": is_action_pressed("use_ability"),
	}
