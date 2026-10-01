extends Node3D
## Combat sandbox entry point (S01–S03).
##
## Assembles battlefield, mechs, the match layer, side-on camera, and debug
## HUD. Gameplay systems attach under Main as sprints add them; this node
## never implements game rules itself.

@onready var _camera: Camera3D = $Camera3D
@onready var _match: Node = $MatchController


func _ready() -> void:
	_camera.follow_target = $Mech
	_match.setup([$Mech, $DummyMech])


func _unhandled_input(event: InputEvent) -> void:
	# Debug tooling (implementation-guide §17) uses raw keys on purpose —
	# it is developer-only and outside the device-agnostic action contract.
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F1:
		for mech in get_tree().get_nodes_in_group("mech"):
			mech.respawn()
