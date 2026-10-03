extends "res://tests/test_base.gd"
## S08: mech identity is data (architecture.md §8, AGENTS rules). Definitions
## are plain Resources; a Strider and a Standard chassis exist as .tres data
## and their stats must differ in the ways that define the archetypes.

const STRIDER := "res://data/mechs/strider.tres"
const STANDARD := "res://data/mechs/standard_mech.tres"
const MECH_SCENE := "res://scenes/mechs/mech.tscn"
const CONTROLLER_SCRIPT := "res://scripts/movement/mech_movement_controller.gd"


func test_definition_resources_load() -> void:
	var strider: Resource = load(STRIDER)
	var standard: Resource = load(STANDARD)
	assert_true(strider != null and standard != null, "both chassis definitions load")
	assert_equal(strider.display_name, "Strider", "strider display name")
	assert_equal(standard.display_name, "Standard", "standard display name")


func test_archetypes_differ_as_designed() -> void:
	var strider: Resource = load(STRIDER)
	var standard: Resource = load(STANDARD)
	assert_true(strider.max_speed > standard.max_speed, "Strider is faster")
	assert_true(strider.mass < standard.mass, "Strider is lighter")
	assert_true(strider.max_health < standard.max_health, "Strider is low armor")
	assert_true(strider.dash_speed > 0.0, "Strider has a dash")
	assert_true(standard.dash_speed == 0.0, "Standard has no dash")


func test_apply_definition_pushes_stats_into_body() -> void:
	var scene: PackedScene = load(MECH_SCENE)
	assert_true(scene != null, "mech.tscn loads")
	if scene == null:
		return
	var mech: Node = scene.instantiate()
	var strider: Resource = load(STRIDER)
	mech.apply_definition(strider)
	assert_equal(mech.mass, strider.mass, "definition mass applied")
	# get_node_or_null resolves on detached instances, so the movement
	# controller receives its stats without a tree entry.
	var mv: Node = mech.get_node("Movement")
	assert_equal(mv.max_speed, strider.max_speed, "definition speed applied")
	assert_equal(mv.dash_speed, strider.dash_speed, "definition dash applied")
	assert_true(mech.can_dash(), "Strider chassis can dash")
	assert_equal(mech.display_name(), "Strider", "display name comes from the definition")
	var standard: Resource = load(STANDARD)
	mech.apply_definition(standard)
	assert_true(mech.can_dash() == false, "Standard chassis cannot dash")
	assert_equal(mech.display_name(), "Standard", "reapplication updates identity")
	mech.free()


func test_dash_velocity_is_a_facing_burst() -> void:
	var ctrl: Node = load(CONTROLLER_SCRIPT).new()
	_add_cleanup(ctrl)
	var right: Vector3 = ctrl.dash_velocity(1.0)
	assert_equal(right, Vector3(ctrl.dash_speed, 0.0, 0.0), "dash fires along +facing")
	var left: Vector3 = ctrl.dash_velocity(-1.0)
	assert_equal(left, Vector3(-ctrl.dash_speed, 0.0, 0.0), "dash mirrors with facing")
