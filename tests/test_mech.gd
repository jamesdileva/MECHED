extends "res://tests/test_base.gd"
## S02 movement rules: controller kinematics are pure functions, so velocity
## integration, jumping, gravity, deceleration, clamps, and respawn are all
## verified headless without stepping the physics simulation.

const CONTROLLER_SCRIPT := "res://scripts/movement/mech_movement_controller.gd"
const MECH_SCENE := "res://scenes/mechs/mech.tscn"


func test_mech_scene_structure() -> void:
	var scene: PackedScene = load(MECH_SCENE)
	assert_true(scene != null, "mech.tscn loads")
	if scene == null:
		return
	var mech: Node = scene.instantiate()
	assert_true(mech is CharacterBody3D, "mech root is a CharacterBody3D")
	assert_true(mech.get_node_or_null("Movement") != null, "mech has a Movement controller")
	assert_true(mech.get_node_or_null("Collision") is CollisionShape3D, "mech has a collision shape")
	assert_true(mech.get_node_or_null("Visual") is Node3D, "mech has a Visual rig for facing")
	mech.free()


func test_accelerates_toward_axis_on_floor() -> void:
	var ctrl: Node = load(CONTROLLER_SCRIPT).new()
	_add_cleanup(ctrl)
	ctrl.move_axis = 1.0
	ctrl.want_jump = false
	var v: Vector3 = ctrl.compute_velocity(Vector3.ZERO, true, 1.0 / 60.0)
	assert_true(v.x > 0.0 and v.x <= ctrl.max_speed, "accelerates toward max speed, got %s" % v.x)
	assert_equal(v.y, 0.0, "no vertical velocity when resting on floor")


func test_jump_sets_upward_velocity() -> void:
	var ctrl: Node = load(CONTROLLER_SCRIPT).new()
	_add_cleanup(ctrl)
	ctrl.move_axis = 0.0
	ctrl.want_jump = true
	var v: Vector3 = ctrl.compute_velocity(Vector3.ZERO, true, 1.0 / 60.0)
	assert_equal(v.y, ctrl.jump_velocity, "jump impulse applied")


func test_gravity_applies_when_airborne() -> void:
	var ctrl: Node = load(CONTROLLER_SCRIPT).new()
	_add_cleanup(ctrl)
	ctrl.move_axis = 0.0
	ctrl.want_jump = false
	var v: Vector3 = ctrl.compute_velocity(Vector3(0, 5, 0), false, 1.0 / 60.0)
	assert_equal(v.y, 5.0 - ctrl.gravity * (1.0 / 60.0), "gravity reduces upward velocity")


func test_decelerates_to_stop() -> void:
	var ctrl: Node = load(CONTROLLER_SCRIPT).new()
	_add_cleanup(ctrl)
	ctrl.move_axis = 0.0
	ctrl.want_jump = false
	var v: Vector3 = ctrl.compute_velocity(Vector3(5, 0, 0), true, 1.0 / 60.0)
	assert_true(v.x < 5.0, "decelerates toward zero, got %s" % v.x)
	assert_equal(v.z, 0.0, "side-plane depth stays locked")


func test_position_clamped_to_battlefield() -> void:
	var ctrl: Node = load(CONTROLLER_SCRIPT).new()
	_add_cleanup(ctrl)
	var clamped: Vector3 = ctrl.clamp_position(Vector3(100, 5, 3))
	assert_true(clamped.x <= ctrl.bounds_max_x, "x clamped to max bound")
	assert_equal(clamped.z, 0.0, "z clamped to gameplay plane")


func test_mech_respawns_below_kill_plane() -> void:
	var scene: PackedScene = load(MECH_SCENE)
	assert_true(scene != null, "mech.tscn loads")
	if scene == null:
		return
	# Respawn rules are battlefield-local (mech.gd), so a detached instance
	# exercises them without a tree entry.
	var mech: Node = scene.instantiate()
	mech.position = Vector3(0, -11, 0)
	assert_true(mech.should_respawn(), "below kill plane triggers respawn")
	mech.respawn()
	assert_equal(mech.position, mech.RESPAWN_POINT, "respawn restores spawn point")
	assert_equal(mech.velocity, Vector3.ZERO, "respawn clears velocity")
	mech.free()
