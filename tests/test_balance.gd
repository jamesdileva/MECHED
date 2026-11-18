extends "res://tests/test_base.gd"
## S24 balance sandbox: the tuning table drives the match — turn time, energy
## economy, gravity, wind, multipliers — all from data, no code changes.

const BALANCE := "res://scripts/core/balance.gd"
const CONFIG := "res://scripts/core/balance_config.gd"
const MATCH_CONTROLLER := "res://scripts/match/match_controller.gd"
const MECH := "res://scenes/mechs/mech.tscn"
const STANDARD := "res://data/mechs/standard_mech.tres"
const TURN_MANAGER := "res://scripts/match/turn_manager.gd"
const EPS := 0.0001


func _configured_controller(overrides: Dictionary) -> Array:
	var cfg = load(CONFIG).new()
	for key in overrides:
		cfg.set(key, overrides[key])
	var controller: Node = load(MATCH_CONTROLLER).new()
	controller.map_definition = null
	_add_cleanup(controller)
	var mech1: Node = load(MECH).instantiate()
	_add_cleanup(mech1)
	var mech2: Node = load(MECH).instantiate()
	_add_cleanup(mech2)
	mech1.definition = load(STANDARD)
	mech2.definition = load(STANDARD)
	controller._balance_test_cfg = cfg
	controller.setup([mech1, mech2])
	return [controller, mech1, mech2]


func test_config_defaults_match_shipped_tuning() -> void:
	var cfg: Resource = load(CONFIG).new()
	assert_almost_equal(cfg.turn_time, 15.0, EPS, "turn time default")
	assert_almost_equal(cfg.energy_per_turn, 100.0, EPS, "energy default")
	assert_almost_equal(cfg.jump_cost, 10.0, EPS, "jump cost default")
	assert_almost_equal(cfg.gravity, 30.0, EPS, "gravity default")
	assert_almost_equal(cfg.damage_mult, 1.0, EPS, "damage mult neutral by default")


func test_setup_applies_turn_and_economy_tuning() -> void:
	var pair := _configured_controller({
		"turn_time": 9.0, "energy_per_turn": 60.0, "jump_cost": 20.0,
	})
	var controller: Node = pair[0]
	assert_almost_equal(controller.turn_manager.turn_time, 9.0, EPS, "turn time applied")
	assert_almost_equal(controller.turn_manager.energy_per_turn, 60.0, EPS,
			"energy applied")
	assert_almost_equal(controller.turn_manager.jump_cost, 20.0, EPS, "jump cost applied")
	var s = controller.turn_manager.state
	assert_almost_equal(s.turn_time_left, 9.0, EPS, "opening turn uses tuned time")
	assert_almost_equal(s.movement_energy_left, 60.0, EPS, "opening turn uses tuned energy")
	assert_almost_equal(s.wind_cap, 5.0, EPS, "wind cap default unchanged")


func test_setup_applies_starting_health() -> void:
	# Starting health = chassis definition max health x health_mult (no
	# separate knob: the defs are the per-chassis balance surface).
	var pair := _configured_controller({"health_mult": 0.8})
	var s = pair[0].turn_manager.state
	assert_almost_equal(s.entity_health("Standard"), 80.0, EPS,
			"health mult scales starting health (100 x 0.8)")


func test_setup_applies_gravity_to_state_and_mechs() -> void:
	var pair := _configured_controller({"gravity": 45.0})
	var controller: Node = pair[0]
	assert_almost_equal(controller.turn_manager.state.gravity, 45.0, EPS,
			"state gravity applied (AI solver reads it)")
	assert_almost_equal(pair[1].get_node("Movement").gravity, 45.0, EPS,
			"mech movement gravity applied")


func test_setup_applies_move_speed_mult() -> void:
	var pair := _configured_controller({"move_speed_mult": 1.5})
	var mech: Node = pair[1]
	# Standard chassis: 8 m/s x 1.5 = 12.
	assert_almost_equal(mech.get_node("Movement").max_speed, 12.0, EPS,
			"move speed mult scales chassis speed")


func test_setup_applies_health_mult() -> void:
	var pair := _configured_controller({"health_mult": 2.0})
	var s = pair[0].turn_manager.state
	# Standard chassis: 100 x 2 = 200.
	assert_almost_equal(s.entity_max_health("Standard"), 200.0, EPS,
			"health mult scales chassis health")


func test_damage_and_knockback_mults_are_exposed() -> void:
	var cfg: Resource = load(CONFIG).new()
	cfg.damage_mult = 2.0
	cfg.knockback_mult = 3.0
	assert_almost_equal(cfg.damage_mult, 2.0, EPS, "damage mult settable")
	assert_almost_equal(cfg.knockback_mult, 3.0, EPS, "knockback mult settable")
