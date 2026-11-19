extends "res://tests/test_base.gd"
## S34 advanced weapon transformations: each chassis transforms all three
## base weapons (Rocket + Grenade + Energy Shot = 9 distinct behaviors).

const AI_DRIVER := "res://scripts/ai/ai_driver.gd"
const CANYON := "res://data/maps/canyon.tres"
const EPS := 0.0001


func _modifier(chassis_name: String) -> Resource:
	return load("res://data/mechs/%s_modifier.tres" % chassis_name.to_lower())


func test_all_nine_transformations_resolve() -> void:
	# Each chassis modifier transforms all three base weapons.
	var chassis_mods := {
		"bastion": ["Siege Rocket", "Bunker Buster", "Heavy Lance"],
		"strider": ["Split Rocket", "Cluster Grenade", "Split Beam"],
		"wraith": ["Guided Rocket", "Aerial Mine", "Piercing Shot"],
	}
	var base_weapons := ["Rocket", "Grenade", "Energy Shot"]
	for chassis_name in chassis_mods:
		var modifier: Resource = load("res://data/mechs/%s_modifier.tres" % chassis_name)
		assert_true(modifier != null, "%s modifier loads" % chassis_name)
		for base in base_weapons:
			var transformation = modifier.transformation_for(base)
			assert_true(transformation != null,
					"%s transforms %s" % [chassis_name, base])
			assert_equal(transformation.display_name,
					chassis_mods[chassis_name][base_weapons.find(base)],
					"%s %s transformation name" % [chassis_name, base])


func test_bunker_buster_is_a_demolition_shell() -> void:
	var tf: Resource = load("res://data/weapons/transformations/bunker_buster.tres")
	assert_true(tf.terrain_mult > 1.0, "bunker buster digs deeper than base grenade")
	assert_true(tf.damage_mult > 1.0, "bunker buster hits harder")
	assert_true(tf.speed_mult < 1.0, "bunker buster is slower")


func test_cluster_grenade_spreads_three_ways() -> void:
	var tf: Resource = load("res://data/weapons/transformations/cluster_grenade.tres")
	assert_equal(tf.projectile_count, 3, "cluster fires three submunitions")
	assert_true(tf.damage_mult < 1.0, "each submunition is weaker")
	assert_true(tf.spread_degrees > 0.0, "submunitions spread")


func test_piercing_shot_is_fast_and_flat() -> void:
	var tf: Resource = load("res://data/weapons/transformations/piercing_shot.tres")
	assert_true(tf.speed_mult > 1.0, "piercing shot is faster than base energy")
	assert_true(tf.terrain_mult < 0.5, "piercing shot barely scratches terrain")


func test_heavy_lance_is_slow_and_hard_hitting() -> void:
	var tf: Resource = load("res://data/weapons/transformations/heavy_lance.tres")
	assert_true(tf.damage_mult > 1.0, "heavy lance hits harder")
	assert_true(tf.speed_mult < 1.0, "heavy lance is slower")
	assert_true(tf.knockback_mult > 1.0, "heavy lance pushes harder")


func test_aerial_mine_is_a_grenade_variant() -> void:
	var tf: Resource = load("res://data/weapons/transformations/aerial_mine.tres")
	assert_true(tf.damage_mult < 1.0, "aerial mine is a lighter grenade")
	assert_true(tf.terrain_mult < 1.0, "aerial mine barely digs")


func test_split_beam_is_a_light_double_shot() -> void:
	var tf: Resource = load("res://data/weapons/transformations/split_beam.tres")
	assert_equal(tf.projectile_count, 2, "split beam fires two submunitions")
	assert_true(tf.damage_mult < 1.0, "each beam is weaker")


func test_chassis_modifiers_resolve_all_three_weapons() -> void:
	# End-to-end: each modifier transforms each base weapon (S34 goal).
	var base_weapons := {
		"Rocket": load("res://data/weapons/rocket.tres"),
		"Grenade": load("res://data/weapons/grenade.tres"),
		"Energy Shot": load("res://data/weapons/energy_shot.tres"),
	}
	var modifiers := {
		"bastion": load("res://data/mechs/bastion_modifier.tres"),
		"strider": load("res://data/mechs/strider_modifier.tres"),
		"wraith": load("res://data/mechs/wraith_modifier.tres"),
	}
	for chassis_name in modifiers:
		var modifier: Resource = modifiers[chassis_name]
		for base_name in base_weapons:
			var stats: Dictionary = base_weapons[base_name].effective(modifier)
			var transformation = modifier.transformation_for(base_name)
			if transformation != null:
				stats = transformation.apply(stats)
				assert_true(stats["damage_max"] > 0.0,
						"%s + %s = %s (%.0f dmg)" % [
							chassis_name, base_name,
							transformation.display_name, stats["damage_max"]])
			else:
				assert_true(stats["damage_max"] > 0.0,
						"%s + %s (untransformed) still deals damage" %
								[chassis_name, base_name])


func test_solver_works_with_transformed_weapons() -> void:
	# The AI solver consumes transformed stats without code changes —
	# prove it picks a valid transformation for a target.
	var weapon_stats: Array = []
	var modifier: Resource = load("res://data/mechs/bastion_modifier.tres")
	var rocket: Resource = load("res://data/weapons/rocket.tres")
	var stats: Dictionary = rocket.effective(modifier)
	var transformation = modifier.transformation_for("Rocket")
	if transformation != null:
		stats = transformation.apply(stats)
	weapon_stats.append({"slot": 0, "stats": stats})
	var plan: Dictionary = load(AI_DRIVER).solve_shot(
			Vector3(0, 1, 0), Vector3(10, 1, 0), 1.0, Vector2.ZERO, weapon_stats,
			NAN, null, [], [45.0], [0.75])
	assert_true(plan["miss"] < 5.0,
			"solver lands a transformed weapon (miss %.2f)" % plan["miss"])
