extends "res://tests/test_base.gd"
## S19 combat UI: the player-facing HUD exists, carries every combat-state
## element the roadmap lists, and is wired into the main scene. The F3 toggle
## makes the roadmap verification testable by hand: hide the debug HUD and
## read the fight from this UI alone.

const COMBAT_HUD := "res://scenes/ui/combat_hud.tscn"
const MAIN := "res://scenes/main/main.tscn"


func test_combat_hud_scene_structure() -> void:
	var scene: PackedScene = load(COMBAT_HUD)
	assert_true(scene != null, "combat_hud.tscn loads")
	if scene == null:
		return
	var hud: Node = scene.instantiate()
	# Every element the roadmap S19 list requires (ability cooldowns arrive
	# with S23's cooldown-bearing abilities; state badges cover them now).
	for required in ["TurnLabel", "TimerBar", "WindLabel", "PlayerName", "HPBar",
			"EnergyBar", "FuelBar", "WeaponLabel", "AimLabel", "AnchorLabel",
			"EnemyName", "EnemyHPBar"]:
		assert_true(hud.get_node_or_null("%" + required) != null,
				"HUD has %s" % required)
	hud.free()


func test_main_scene_includes_combat_hud() -> void:
	var scene: PackedScene = load(MAIN)
	assert_true(scene != null, "main.tscn loads")
	if scene == null:
		return
	var main: Node = scene.instantiate()
	assert_true(main.get_node_or_null("CombatHUD") != null,
			"main instances the CombatHUD")
	main.free()


func test_match_state_tracks_max_health_for_bars() -> void:
	var s = load("res://scripts/match/match_state.gd").new()
	s.set_entity_max_health("Bastion", 150.0)
	s.set_entity_health("Bastion", 90.0)
	assert_equal(s.entity_max_health("Bastion"), 150.0, "max health recorded")
	# Bars read scale: 90/150.
	assert_almost_equal(float(s.entity_health("Bastion")) / s.entity_max_health("Bastion"),
			0.6, 0.0001, "bar fraction computes")
