extends "res://tests/test_base.gd"
## S11 universal weapons: weapons are data, every mech equips every weapon,
## and no weapon needs mech-specific code (roadmap verification). Modifier
## scaling is the S12 hook, proven here end-to-end.

const ROCKET := "res://data/weapons/rocket.tres"
const GRENADE := "res://data/weapons/grenade.tres"
const ENERGY := "res://data/weapons/energy_shot.tres"
const SIEGE_ROCKET := "res://data/weapons/transformations/siege_rocket.tres"
const SPLIT_ROCKET := "res://data/weapons/transformations/split_rocket.tres"
const GUIDED_ROCKET := "res://data/weapons/transformations/guided_rocket.tres"
const MODIFIER_SCRIPT := "res://scripts/weapons/weapon_modifier.gd"
const PROJECTILE_SCRIPT := "res://scripts/projectiles/projectile.gd"
const BALLISTICS := "res://scripts/combat/ballistics.gd"
const MATCH_STATE := "res://scripts/match/match_state.gd"
const EPS := 0.0001


func _load(path: String) -> Resource:
	return load(path)


func test_weapon_definitions_load() -> void:
	for path in [ROCKET, GRENADE, ENERGY]:
		var weapon: Resource = load(path)
		assert_true(weapon != null, "%s loads" % path.get_file())


func test_archetypes_differ_as_designed() -> void:
	var rocket: Resource = load(ROCKET)
	var grenade: Resource = load(GRENADE)
	var energy: Resource = load(ENERGY)
	assert_true(grenade.bounces > 0, "Grenade bounces before detonating")
	assert_true(grenade.terrain_damage_mult > rocket.terrain_damage_mult,
			"Grenade disrupts terrain more than the Rocket")
	assert_true(energy.speed_max > rocket.speed_max, "Energy Shot is the fastest")
	assert_true(energy.terrain_damage_mult < rocket.terrain_damage_mult,
			"Energy Shot is light on terrain (architecture.md §10)")
	assert_true(energy.gravity_mult < 1.0, "Energy Shot flies flatter")


func test_effective_without_modifier_is_identity() -> void:
	var rocket: Resource = load(ROCKET)
	var stats: Dictionary = rocket.effective(null)
	assert_equal(stats["damage_max"], rocket.damage_max, "no modifier = raw stats")
	assert_equal(stats["speed_max"], rocket.speed_max, "no modifier = raw speed")


func test_modifier_scales_the_weapon() -> void:
	var rocket: Resource = load(ROCKET)
	var modifier = load(MODIFIER_SCRIPT).new()
	modifier.speed_mult = 0.8
	modifier.damage_mult = 1.3
	var stats: Dictionary = rocket.effective(modifier)
	assert_almost_equal(stats["damage_max"], rocket.damage_max * 1.3, EPS,
			"modifier multiplies damage")
	assert_almost_equal(stats["speed_max"], rocket.speed_max * 0.8, EPS,
			"modifier multiplies speed")
	assert_equal(stats["bounces"], rocket.bounces, "multipliers never touch weapon behavior")


func test_ballistics_accepts_weapon_speed_range() -> void:
	var b = load(BALLISTICS)
	var custom_max := 44.0
	var v: Vector3 = b.launch_velocity(45.0, 1.0, 1.0, 20.0, custom_max)
	assert_almost_equal(v.length(), custom_max, EPS, "full power reaches the weapon's max speed")
	var slow: Vector3 = b.launch_velocity(45.0, 1.0, 0.0, 20.0, custom_max)
	assert_almost_equal(slow.length(), 20.0, EPS, "zero power starts at the weapon's min speed")


func test_loadout_cycles_and_wraps() -> void:
	var s = load(MATCH_STATE).new()
	s.set_loadout("Strider", [load(ROCKET), load(GRENADE), load(ENERGY)])
	assert_equal(s.active_weapon("Strider").display_name, "Rocket", "slot 0 armed first")
	s.cycle_weapon("Strider")
	assert_equal(s.active_weapon("Strider").display_name, "Grenade", "cycling arms slot 1")
	s.cycle_weapon("Strider")
	assert_equal(s.active_weapon("Strider").display_name, "Energy Shot", "cycling arms slot 2")
	s.cycle_weapon("Strider")
	assert_equal(s.active_weapon("Strider").display_name, "Rocket", "loadout wraps around")


func test_every_chassis_can_equip_every_weapon() -> void:
	# The roadmap verification, made executable: any weapon goes into any
	# chassis's loadout and arms cleanly.
	var weapons: Array = [load(ROCKET), load(GRENADE), load(ENERGY)]
	for chassis_path in ["res://data/mechs/standard_mech.tres",
			"res://data/mechs/strider.tres", "res://data/mechs/wraith.tres",
			"res://data/mechs/bastion.tres"]:
		var chassis: Resource = load(chassis_path)
		assert_true(chassis != null, "%s loads" % chassis_path.get_file())
		var s = load(MATCH_STATE).new()
		s.set_loadout(chassis.display_name, weapons)
		for slot in weapons.size():
			s.active_weapon_index[chassis.display_name] = slot
			var weapon: Resource = s.active_weapon(chassis.display_name)
			assert_true(weapon != null, "%s arms %s" %
					[chassis.display_name, weapon.display_name])


func test_transformations_rename_and_rescale_the_rocket() -> void:
	var rocket: Resource = load(ROCKET)
	var base: Dictionary = rocket.effective(null)
	var siege: Resource = load(SIEGE_ROCKET)
	var stats: Dictionary = siege.apply(base)
	assert_equal(stats["transformation_name"], "Siege Rocket", "transformation names the shell")
	assert_almost_equal(stats["damage_max"], base["damage_max"] * 1.4, EPS,
			"Siege hits harder")
	assert_almost_equal(stats["explosion_radius"], base["explosion_radius"] * 1.3, EPS,
			"Siege blasts bigger")
	assert_true(stats["speed_max"] < base["speed_max"], "Siege flies slower")
	assert_equal(stats["projectile_count"], 1, "Siege stays a single shell")


func test_split_rocket_spreads_three_submunitions() -> void:
	var rocket: Resource = load(ROCKET)
	var base: Dictionary = rocket.effective(null)
	var split: Resource = load(SPLIT_ROCKET)
	var stats: Dictionary = split.apply(base)
	assert_equal(stats["projectile_count"], 3, "Split fires three shells")
	assert_almost_equal(stats["damage_max"], base["damage_max"] * 0.5, EPS,
			"each submunition is half strength")
	var spread: float = stats["spread_degrees"]
	var offsets: Array = [
		load(PROJECTILE_SCRIPT).spread_offset(0, 3, spread),
		load(PROJECTILE_SCRIPT).spread_offset(1, 3, spread),
		load(PROJECTILE_SCRIPT).spread_offset(2, 3, spread),
	]
	assert_almost_equal(offsets[0], -spread, EPS, "first shell angles left by the full spread")
	assert_almost_equal(offsets[1], 0.0, EPS, "middle shell flies straight")
	assert_almost_equal(offsets[2], spread, EPS, "last shell angles right")


func test_guided_rocket_homes() -> void:
	var rocket: Resource = load(ROCKET)
	var base: Dictionary = rocket.effective(null)
	var guided: Resource = load(GUIDED_ROCKET)
	var stats: Dictionary = guided.apply(base)
	assert_true(stats["homing_strength"] > 0.0, "Guided Rocket tracks its target")
	assert_true(stats["damage_max"] < base["damage_max"],
			"guidance trades raw damage for accuracy")
	assert_equal(stats["projectile_count"], 1, "Guided stays a single shell")


func test_weapon_without_transformation_keeps_its_identity() -> void:
	var rocket: Resource = load(ROCKET)
	var base: Dictionary = rocket.effective(null)
	var modifier = load(MODIFIER_SCRIPT).new()
	var stats: Dictionary = rocket.effective(modifier)
	assert_equal(stats.get("projectile_count", 1), 1, "untransformed weapons stay single-shot")
	assert_equal(stats.get("homing_strength", 0.0), 0.0, "untransformed weapons stay dumb-fired")


func test_chassis_modifiers_carry_their_transformations() -> void:
	# The S12 wiring made executable: Bastion transforms the Rocket into Siege,
	# Strider into Split, Wraith into Guided; Standard transforms nothing.
	var expected := {
		"res://data/mechs/bastion_modifier.tres": "Siege Rocket",
		"res://data/mechs/strider_modifier.tres": "Split Rocket",
		"res://data/mechs/wraith_modifier.tres": "Guided Rocket",
	}
	for modifier_path in expected:
		var modifier: Resource = load(modifier_path)
		assert_true(modifier != null, "%s loads" % modifier_path.get_file())
		var transformation = modifier.transformation_for("Rocket")
		assert_true(transformation != null, "%s transforms the Rocket" % modifier_path.get_file())
		assert_equal(transformation.display_name, expected[modifier_path],
				"%s Rocket transformation" % modifier_path.get_file())
	assert_equal(load("res://data/mechs/standard_mech.tres").weapon_modifier, null,
			"Standard chassis transforms nothing")
	assert_equal(load("res://data/mechs/bastion.tres").weapon_modifier.display_name,
			"Bastion Weapons", "Bastion chassis wires its modifier")
	assert_equal(load("res://data/mechs/strider.tres").weapon_modifier.display_name,
			"Strider Weapons", "Strider chassis wires its modifier")
	assert_equal(load("res://data/mechs/wraith.tres").weapon_modifier.display_name,
			"Wraith Weapons", "Wraith chassis wires its modifier")


func test_steering_caps_turn_rate_and_preserves_speed_direction() -> void:
	var current := Vector3(1, 0, 0)
	var desired := Vector3(0, 1, 0)
	var unchanged: Vector3 = load(PROJECTILE_SCRIPT).steer_direction(
			current, desired, 0.0, 1.0 / 60.0)
	assert_almost_equal(unchanged.x, 1.0, EPS, "zero turn rate leaves direction unchanged")
	var slight: Vector3 = load(PROJECTILE_SCRIPT).steer_direction(
			current, desired, 3.5, 1.0 / 60.0)
	assert_true(slight.y > 0.0 and slight.x > 0.0,
			"a capped rate turns partway toward the target")
	assert_almost_equal(slight.length(), 1.0, EPS, "steered direction stays normalized")
	var aligned: Vector3 = load(PROJECTILE_SCRIPT).steer_direction(
			current, desired, 1000.0, 1.0 / 60.0)
	assert_almost_equal(aligned.y, 1.0, EPS, "a huge rate aligns with the target this tick")
