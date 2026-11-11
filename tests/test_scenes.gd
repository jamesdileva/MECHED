extends "res://tests/test_base.gd"
## S01 structural checks: the project's scenes load headless and contain the
## nodes the roadmap's verification depends on.


func test_project_main_scene_is_the_menu() -> void:
	assert_equal(ProjectSettings.get_setting("application/run/main_scene", ""),
			"res://scenes/menus/main_menu.tscn", "match flow boots at the main menu")
	assert_equal(ProjectSettings.get_setting("autoload/MatchSession", ""),
			"*res://scripts/core/match_session.gd", "MatchSession autoload registered")


func test_main_scene_loads_and_is_assembled() -> void:
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	assert_true(scene != null, "main.tscn loads")
	if scene == null:
		return
	var main: Node = scene.instantiate()
	assert_true(main.get_node_or_null("Camera3D") is Camera3D, "main has a Camera3D")
	assert_true(main.get_node_or_null("Battlefield") != null, "main instances the battlefield")
	assert_true(main.get_node_or_null("MatchController") != null, "main has the MatchController")
	assert_true(main.get_node_or_null("Mech") != null, "main has the player mech")
	assert_true(main.get_node_or_null("DummyMech") != null, "main has the dummy opponent")
	assert_true(main.get_node_or_null("DebugHUD") != null, "main has the debug HUD")
	assert_true(main.get_node_or_null("CombatHUD") != null, "main instances the CombatHUD")
	# Match flow (S20): the victory/defeat overlay with rematch + menu buttons.
	var overlay: Node = main.get_node_or_null("VictoryOverlay")
	assert_true(overlay != null, "main has the victory/defeat overlay")
	if overlay != null:
		assert_true(overlay.get_node_or_null("%RematchButton") is Button,
				"overlay has a REMATCH button")
		assert_true(overlay.get_node_or_null("%MenuButton") is Button,
				"overlay has a MAIN MENU button")
	main.free()


func test_battlefield_has_destructible_terrain() -> void:
	var scene: PackedScene = load("res://scenes/battlefield/battlefield.tscn")
	assert_true(scene != null, "battlefield.tscn loads")
	if scene == null:
		return
	var battlefield: Node = scene.instantiate()
	var terrain: Node = battlefield.get_node_or_null("TerrainSystem")
	assert_true(terrain != null, "battlefield instances the TerrainSystem")
	if terrain != null:
		assert_true(terrain.get_node_or_null("Collision") is StaticBody3D,
				"terrain has a collision body")
		assert_true(terrain.get_node_or_null("Surface") != null,
				"terrain has a surface holder for chunk meshes")
	battlefield.free()


func test_projectile_scene_is_physics_ready() -> void:
	var scene: PackedScene = load("res://scenes/projectiles/projectile.tscn")
	assert_true(scene != null, "projectile.tscn loads")
	if scene == null:
		return
	var projectile: Node = scene.instantiate()
	assert_true(projectile is RigidBody3D, "projectile root is a RigidBody3D")
	assert_true(projectile.get_node_or_null("Collision") is CollisionShape3D,
			"projectile has a collision shape")
	# Fast shells tunnel without CCD, and body_entered needs contact monitoring.
	assert_true(projectile.continuous_cd, "projectile uses continuous collision detection")
	assert_true(projectile.contact_monitor, "projectile reports contacts")
	projectile.free()


func test_explosion_effect_scene_structure() -> void:
	var scene: PackedScene = load("res://scenes/projectiles/explosion_effect.tscn")
	assert_true(scene != null, "explosion_effect.tscn loads")
	if scene == null:
		return
	var fx: Node = scene.instantiate()
	assert_true(fx.get_node_or_null("Blast") is MeshInstance3D, "explosion has a blast mesh")
	fx.free()
