extends "res://tests/test_base.gd"
## S27 camera system: the goal-priority state machine (overview > fresh
## impact > focus > hold), the match layer's focus selection (live shell
## first, else the active mech), and the overview toggle. All pure — headless.

const CAMERA := "res://scripts/core/game_camera.gd"
const MATCH_CONTROLLER := "res://scripts/match/match_controller.gd"
const MECH := "res://scenes/mechs/mech.tscn"
const OFFSET := Vector3(0, 4, 18)
const OVERVIEW := Vector3(0, 10, 42)
const EPS := 0.0001


func _camera():
	var camera: Node = load(CAMERA).new()
	_add_cleanup(camera)
	return camera


func test_pick_goal_overview_wins() -> void:
	var goal: Vector3 = load(CAMERA).pick_goal(
			true, true, Vector3(5, 1, 0), true, Vector3(10, 1, 0),
			OFFSET, OVERVIEW, Vector3.ZERO)
	assert_equal(goal, OVERVIEW, "overview outranks everything")


func test_fresh_impact_outranks_focus() -> void:
	var camera = _camera()
	var goal: Vector3 = camera.pick_goal(
			false, true, Vector3(5, 1, 0), true, Vector3(10, 1, 0),
			OFFSET, OVERVIEW, Vector3.ZERO)
	assert_equal(goal, Vector3(5, 1, 0) + OFFSET,
			"fresh impact holds the camera on the blast")


func test_focus_is_third_priority() -> void:
	var camera = _camera()
	var goal: Vector3 = camera.pick_goal(
			false, false, Vector3(5, 1, 0), true, Vector3(10, 1, 0),
			OFFSET, OVERVIEW, Vector3.ZERO)
	assert_equal(goal, Vector3(10, 1, 0) + OFFSET, "focus + offset is the goal")


func test_no_focus_holds_position() -> void:
	var camera = _camera()
	var fallback := Vector3(3, 2, 18)
	var goal: Vector3 = camera.pick_goal(
			false, false, Vector3(5, 1, 0), false, Vector3(10, 1, 0),
			OFFSET, OVERVIEW, fallback)
	assert_equal(goal, fallback, "no focus: hold the current position")


func test_camera_focus_prefers_live_shell() -> void:
	var controller: Node = load(MATCH_CONTROLLER).new()
	_add_cleanup(controller)
	var mech1: Node = load(MECH).instantiate()
	_add_cleanup(mech1)
	var mech2: Node = load(MECH).instantiate()
	_add_cleanup(mech2)
	controller.setup([mech1, mech2])
	# No shells: focus is the active mech.
	assert_equal(controller.camera_focus_node(), mech1, "focus defaults to the active mech")
	# A live shell takes priority.
	var shell: Node3D = Node3D.new()
	_add_cleanup(shell)
	controller._live_shells.append(shell)
	assert_equal(controller.camera_focus_node(), shell, "live shell outranks the mech")


func test_toggle_overview_flips() -> void:
	var camera = _camera()
	assert_true(not camera.overview, "starts at combat framing")
	camera.toggle_overview()
	assert_true(camera.overview, "overview toggles on")
	camera.toggle_overview()
	assert_true(not camera.overview, "overview toggles back off")
