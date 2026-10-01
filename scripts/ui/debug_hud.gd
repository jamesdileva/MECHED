extends CanvasLayer
## S01 debug HUD (implementation-guide §17): engine status plus raw action
## state, so "input works" can be verified at a glance. Grows with later
## sprints; never part of the shipping UI.

@onready var _status: Label = %Status


func _process(_delta: float) -> void:
	var snap := InputLayer.snapshot()
	var lines := [
		"MECHED | %s | FPS %d" % [Engine.get_version_info()["string"], Engine.get_frames_per_second()],
		"camera %s" % _camera_text(),
		"mech   %s" % _mech_text(),
		"combat %s" % _combat_text(),
		"turn   %s" % _match_text(),
		"input  move %+.2f   aim %+.2f" % [snap["move"], snap["aim"]],
		"input  jump %s  dash %s  fire %s  ability %s" % [
			_flag(snap["jump"]), _flag(snap["dash"]), _flag(snap["fire"]), _flag(snap["ability"]),
		],
	]
	_status.text = "\n".join(lines)


func _camera_text() -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "<none>"
	var pos: Vector3 = cam.global_position.snapped(Vector3(0.1, 0.1, 0.1))
	return str(pos)


func _mech_text() -> String:
	var mech: Node = get_tree().get_first_node_in_group("mech")
	if mech == null:
		return "<none>"
	var pos: Vector3 = mech.global_position.snapped(Vector3(0.1, 0.1, 0.1))
	var vel: Vector3 = mech.velocity.snapped(Vector3(0.1, 0.1, 0.1))
	var state := "floor" if mech.is_on_floor() else "air"
	return "pos %s  vel %s  %s" % [pos, vel, state]


func _match_text() -> String:
	var match_ctrl: Node = get_tree().get_first_node_in_group("match_controller")
	if match_ctrl == null:
		return "<no match>"
	return match_ctrl.status_line()


func _combat_text() -> String:
	var mech: Node = get_tree().get_first_node_in_group("mech")
	if mech == null:
		return "<none>"
	return "hp %.0f  aim %.0f°  pow %.2f" % [mech.health, mech.aim_angle, mech.charge]


func _flag(value: bool) -> String:
	return "[x]" if value else "[ ]"
