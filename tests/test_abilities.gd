extends "res://tests/test_base.gd"
## S23 mech ability pass: abilities are data on definitions, mechanics are
## interpreted by the mech, and defensive windows scale damage taken. All
## pure — headless.

const MECH := "res://scenes/mechs/mech.tscn"
const ABILITY := "res://scripts/mechs/mech_ability.gd"
const CANYON := "res://data/maps/canyon.tres"
const EPS := 0.0001

func _bastion():
	# The battle scene wires definitions; tests load the chassis directly.
	var mech: Node = load(MECH).instantiate()
	_add_cleanup(mech)
	mech.definition = load("res://data/mechs/bastion.tres")
	mech.apply_definition(mech.definition)
	return mech


func _strider():
	var mech: Node = load(MECH).instantiate()
	_add_cleanup(mech)
	mech.definition = load("res://data/mechs/strider.tres")
	mech.apply_definition(mech.definition)
	return mech


func test_definitions_carry_ability_sets() -> void:
	var bastion: Node = _bastion()
	assert_true(bastion.abilities().size() == 2, "Bastion ships two abilities")
	assert_equal(bastion.abilities()[0]["ability_name"], "anchor", "anchor first")
	assert_equal(bastion.abilities()[1]["ability_name"], "armor_brace", "brace second")
	var strider: Node = _strider()
	var names: Array = []
	for ability in strider.abilities():
		names.append(ability["ability_name"])
	assert_true("dash" in names and "wall_climb" in names,
			"Strider ships dash + wall climb")
	assert_true(load("res://data/mechs/wraith.tres").abilities.size() == 2,
			"Wraith ships hover + air dash")


func test_cooldowns_tick_and_ready() -> void:
	var mech: Node = _bastion()
	mech.start_cooldown("armor_brace", 1.0)
	assert_true(not mech.is_cooldown_ready("armor_brace"), "on cooldown")
	mech._tick_ability_timers(1.0)
	assert_true(mech.is_cooldown_ready("armor_brace"), "cooldown expired")


func test_anchor_toggles_via_apply_ability() -> void:
	var mech: Node = _bastion()
	var anchor: Resource = mech.abilities()[0]
	assert_true(not mech.anchored, "starts unanchored")
	mech.apply_ability(anchor)
	assert_true(mech.anchored, "anchor toggles on")
	mech.apply_ability(anchor)
	assert_true(not mech.anchored, "anchor toggles off")


func test_armor_brace_halves_damage_and_expires() -> void:
	var mech: Node = _bastion()
	var brace: Resource = mech.abilities()[1]
	mech.apply_ability(brace)
	assert_almost_equal(mech.damage_taken_mult(), brace.param, EPS,
			"braced mech takes half damage")
	mech._tick_ability_timers(brace.duration)
	assert_almost_equal(mech.damage_taken_mult(), 1.0, EPS, "brace expires")


func test_evasive_window_after_dash() -> void:
	var mech: Node = _strider()
	var dash: Resource = mech.abilities()[0]
	mech.apply_ability(dash)
	assert_almost_equal(mech.damage_taken_mult(), dash.param, EPS,
			"evasive window after dash: quarter damage")
	mech._tick_ability_timers(dash.duration)
	assert_almost_equal(mech.damage_taken_mult(), 1.0, EPS, "evasive window expires")


func test_hover_arrests_falls() -> void:
	# Hover damps vertical velocity toward zero — a falling Wraith arrests its
	# fall instead of accelerating; without hover gravity keeps pulling.
	var ctrl = load("res://scripts/movement/mech_movement_controller.gd").new()
	_add_cleanup(ctrl)
	var falling: Vector3 = ctrl.compute_velocity(Vector3(0, -3, 0), 0.0, false, false, true,
			false, 1.0 / 60.0)
	assert_almost_equal(falling.y, -2.5, EPS,
			"hover damps the fall toward zero (gravity would give -3.5)")
	var coasting: Vector3 = ctrl.compute_velocity(Vector3(0, -3, 0), 0.0, false, false, false,
			false, 1.0 / 60.0)
	assert_almost_equal(coasting.y, -3.0 - ctrl.gravity / 60.0, EPS,
			"without hover the fall accelerates")


func test_air_dash_carries_its_own_speed() -> void:
	var mech: Node = load(MECH).instantiate()
	_add_cleanup(mech)
	mech.definition = load("res://data/mechs/wraith.tres")
	mech.apply_definition(mech.definition)
	var air_dash: Resource = mech.abilities()[1]
	assert_equal(air_dash.ability_name, "air_dash", "second Wraith ability is air dash")
	# The air dash's speed is the ability's own param, applied by apply_ability.
	mech.apply_ability(air_dash)
	assert_almost_equal(mech.velocity.x, air_dash.param, EPS,
			"air dash bursts along the facing at its own speed")


func test_wall_climb_hold_sets_climbing() -> void:
	var mech: Node = _strider()
	var climb: Resource = mech.abilities()[1]
	assert_equal(climb.ability_name, "wall_climb", "second Strider ability is wall climb")
	mech.hold_ability(climb)
	assert_true(mech.climbing, "hold sets the climbing state")
	mech.release_ability(climb)
	assert_true(not mech.climbing, "release ends the climb")
