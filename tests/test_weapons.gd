extends "res://tests/test_base.gd"
## S11 universal weapons: weapons are data, every mech equips every weapon,
## and no weapon needs mech-specific code (roadmap verification). Modifier
## scaling is the S12 hook, proven here end-to-end.

const ROCKET := "res://data/weapons/rocket.tres"
const GRENADE := "res://data/weapons/grenade.tres"
const ENERGY := "res://data/weapons/energy_shot.tres"
const SIEGE := "res://data/mechs/siege_modifier.tres"
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
	var siege: Resource = load(SIEGE)
	var stats: Dictionary = rocket.effective(siege)
	assert_almost_equal(stats["damage_max"], rocket.damage_max * siege.damage_mult, EPS,
			"modifier multiplies damage")
	assert_almost_equal(stats["speed_max"], rocket.speed_max * siege.speed_mult, EPS,
			"modifier multiplies speed")
	assert_almost_equal(stats["knockback_force"], rocket.knockback_force * siege.knockback_mult,
			EPS, "modifier multiplies knockback")
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
