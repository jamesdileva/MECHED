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
	var v: Vector3 = ctrl.compute_velocity(Vector3.ZERO, 1.0, false, true, 1.0 / 60.0)
	assert_true(v.x > 0.0 and v.x <= ctrl.max_speed, "accelerates toward max speed, got %s" % v.x)
	assert_equal(v.y, 0.0, "no vertical velocity when resting on floor")


func test_acceleration_direction_follows_axis() -> void:
	var ctrl: Node = load(CONTROLLER_SCRIPT).new()
	_add_cleanup(ctrl)
	var v: Vector3 = ctrl.compute_velocity(Vector3.ZERO, -1.0, false, true, 1.0 / 60.0)
	assert_true(v.x < 0.0, "negative axis accelerates toward -x, got %s" % v.x)


func test_jump_sets_upward_velocity() -> void:
	var ctrl: Node = load(CONTROLLER_SCRIPT).new()
	_add_cleanup(ctrl)
	var v: Vector3 = ctrl.compute_velocity(Vector3.ZERO, 0.0, true, true, 1.0 / 60.0)
	assert_equal(v.y, ctrl.jump_velocity, "jump impulse applied")


func test_floor_preserves_vertical_residual() -> void:
	# Knockback contract (S06): the floor branch must never zero vertical
	# velocity — a mech launched by a blast keeps rising even while the floor
	# flag is still set for the tick. Jump only ever raises it.
	var ctrl: Node = load(CONTROLLER_SCRIPT).new()
	_add_cleanup(ctrl)
	var launched: Vector3 = ctrl.compute_velocity(Vector3(0, 8, 0), 0.0, false, true, 1.0 / 60.0)
	assert_equal(launched.y, 8.0, "upward residual survives the floor branch")
	var boosted: Vector3 = ctrl.compute_velocity(Vector3(0, 8, 0), 0.0, true, true, 1.0 / 60.0)
	assert_equal(boosted.y, ctrl.jump_velocity, "jump raises a weaker launch to jump speed")
	var preserved: Vector3 = ctrl.compute_velocity(Vector3(0, 12, 0), 0.0, true, true, 1.0 / 60.0)
	assert_equal(preserved.y, 12.0, "jump never cuts a stronger existing launch")
	var resting: Vector3 = ctrl.compute_velocity(Vector3.ZERO, 0.0, false, true, 1.0 / 60.0)
	assert_equal(resting.y, 0.0, "a resting mech still rests")


func test_gravity_applies_when_airborne() -> void:
	var ctrl: Node = load(CONTROLLER_SCRIPT).new()
	_add_cleanup(ctrl)
	var v: Vector3 = ctrl.compute_velocity(Vector3(0, 5, 0), 0.0, false, false, 1.0 / 60.0)
	assert_equal(v.y, 5.0 - ctrl.gravity * (1.0 / 60.0), "gravity reduces upward velocity")


func test_decelerates_to_stop() -> void:
	var ctrl: Node = load(CONTROLLER_SCRIPT).new()
	_add_cleanup(ctrl)
	var v: Vector3 = ctrl.compute_velocity(Vector3(5, 0, 0), 0.0, false, true, 1.0 / 60.0)
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
	assert_equal(mech.position, mech.respawn_point, "respawn restores spawn point")
	assert_equal(mech.velocity, Vector3.ZERO, "respawn clears velocity")
	mech.free()
