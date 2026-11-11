extends "res://tests/test_base.gd"
## S20 match flow: the menu scenes exist with the required nodes, MatchSession
## carries the picks, and duplicate chassis choices get unique display names.

const MAIN_MENU := "res://scenes/menus/main_menu.tscn"
const MECH_SELECT := "res://scenes/menus/mech_select.tscn"
const MAP_SELECT := "res://scenes/menus/map_select.tscn"
const BATTLE := "res://scenes/main/main.tscn"
const MATCH_CONTROLLER := "res://scripts/match/match_controller.gd"
const MECH := "res://scenes/mechs/mech.tscn"


func test_menu_scenes_load_with_required_nodes() -> void:
	var menu: Node = load(MAIN_MENU).instantiate()
	assert_true(menu.get_node_or_null("%FightButton") is Button, "menu has FIGHT")
	assert_true(menu.get_node_or_null("%QuitButton") is Button, "menu has QUIT")
	menu.free()

	var select: Node = load(MECH_SELECT).instantiate()
	assert_true(select.get_node_or_null("%ChassisButtons") != null, "mech select has chassis buttons")
	assert_true(select.get_node_or_null("%DetailLabel") != null, "mech select has the detail panel")
	assert_true(select.get_node_or_null("%DifficultyButton") is Button, "mech select has the difficulty cycle")
	assert_true(select.get_node_or_null("%BackButton") is Button, "mech select has BACK")
	select.free()

	var map_select: Node = load(MAP_SELECT).instantiate()
	assert_true(map_select.get_node_or_null("%MapButtons") != null, "map select has map buttons")
	assert_true(map_select.get_node_or_null("%BackButton") is Button, "map select has BACK")
	map_select.free()


func test_chassis_entries_all_load() -> void:
	# The mech select list is data-driven: every entry must resolve.
	for path in ["res://data/mechs/standard_mech.tres", "res://data/mechs/strider.tres",
			"res://data/mechs/wraith.tres", "res://data/mechs/bastion.tres"]:
		var def: Resource = load(path)
		assert_true(def != null, "%s loads" % path.get_file())


func test_duplicate_chassis_names_are_uniqued() -> void:
	# S20: both sides may pick Standard — MatchState keys must not collide.
	var controller: Node = load(MATCH_CONTROLLER).new()
	_add_cleanup(controller)
	var mech1: Node = load(MECH).instantiate()
	_add_cleanup(mech1)
	var mech2: Node = load(MECH).instantiate()
	_add_cleanup(mech2)
	mech1.definition = load("res://data/mechs/standard_mech.tres")
	mech2.definition = load("res://data/mechs/standard_mech.tres")
	controller.setup([mech1, mech2])
	var name1 := String(mech1.display_name())
	var name2 := String(mech2.display_name())
	assert_true(name1 != name2, "duplicate chassis names get uniqued (%s / %s)" % [name1, name2])
	# Independent health: damaging one leaves the other untouched.
	var s = controller.turn_manager.state
	s.apply_damage(name1, 40.0)
	assert_true(s.entity_health(name2) == s.STARTING_HEALTH,
			"health keys are independent after uniquing")


func test_session_defaults() -> void:
	# MatchSession is an autoload; in script mode its values are read straight
	# from the default state of a fresh instance of its script.
	var session = load("res://scripts/core/match_session.gd").new()
	_add_cleanup(session)
	assert_true(session.player_chassis == "res://data/mechs/standard_mech.tres",
			"session defaults to the Standard chassis")
	assert_equal(session.ai_difficulty, "Normal", "session defaults to Normal AI")
