extends "res://tests/test_base.gd"
## S01 structural checks: the project's scenes load headless and contain the
## nodes the roadmap's verification depends on.


func test_project_main_scene_is_configured() -> void:
	assert_equal(ProjectSettings.get_setting("application/run/main_scene", ""),
			"res://scenes/main/main.tscn", "main scene setting")


func test_main_scene_loads_and_is_assembled() -> void:
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	assert_true(scene != null, "main.tscn loads")
	if scene == null:
		return
	var main: Node = scene.instantiate()
	assert_true(main.get_node_or_null("Camera3D") is Camera3D, "main has a Camera3D")
	assert_true(main.get_node_or_null("Battlefield") != null, "main instances the battlefield")
	assert_true(main.get_node_or_null("DebugHUD") != null, "main has the debug HUD")
	main.free()


func test_battlefield_has_playable_ground() -> void:
	var scene: PackedScene = load("res://scenes/battlefield/battlefield.tscn")
	assert_true(scene != null, "battlefield.tscn loads")
	if scene == null:
		return
	var battlefield: Node = scene.instantiate()
	var ground: Node = battlefield.get_node_or_null("Ground")
	assert_true(ground is StaticBody3D, "battlefield has a StaticBody3D ground")
	if ground is StaticBody3D:
		assert_true(ground.get_node_or_null("Collision") is CollisionShape3D,
				"ground has a collision shape")
	battlefield.free()
