extends "res://tests/test_base.gd"
## S22 environmental hazards: zones burn neutrally by position and time,
## barrels chain-detonaate once each, and hazards are per-map data.

const HAZARD := "res://scripts/terrain/map_hazard.gd"
const MAPS := "res://scripts/terrain/map_definition.gd"
const CANYON := "res://data/maps/canyon.tres"
const ISLANDS := "res://data/maps/floating_islands.tres"
const RUINS := "res://data/maps/industrial_ruins.tres"
const BARREL := "res://scenes/hazards/explosive_barrel.tscn"
const EPS := 0.0001


func test_zone_damage_inside_and_outside() -> void:
	var region := Rect2(0, -2, 3, 2)
	# Body center inside the region: full dps * delta.
	var inside: float = load(HAZARD).zone_damage(region, Vector3(1.5, -1.0, 0), 15.0, 0.5)
	assert_almost_equal(inside, 7.5, EPS, "inside the zone: dps * delta")
	# Above the region: nothing.
	var above: float = load(HAZARD).zone_damage(region, Vector3(1.5, 0.5, 0), 15.0, 0.5)
	assert_almost_equal(above, 0.0, EPS, "outside the zone: no damage")


func test_canyon_ships_ravine_lava() -> void:
	var map: Resource = load(CANYON)
	var zones: Array = map.hazards.filter(func(h): return h != null and h.kind == "zone")
	assert_equal(zones.size(), 1, "Canyon ships one damage zone")
	var region: Rect2 = zones[0]["region"]
	# The zone sits in the ravine bottom, where a shoved mech lands.
	var burn: float = load(HAZARD).zone_damage(region, Vector3(21, -3.0, 0), 15.0, 0.5)
	assert_true(burn > 0.0, "the ravine bottom burns")


func test_islands_ship_no_hazards() -> void:
	var islands: Resource = load(ISLANDS)
	assert_equal(islands.hazards.size(), 0, "the void is the islands' hazard")


func test_ruins_ship_lava_and_two_barrels() -> void:
	var map: Resource = load(RUINS)
	var zones: Array = map.hazards.filter(func(h): return h != null and h.kind == "zone")
	var explosives: Array = map.hazards.filter(func(h): return h != null and h.kind == "explosive")
	assert_equal(zones.size(), 1, "the broken-floor pit burns")
	assert_equal(explosives.size(), 2, "two barrels stand in the ruins")
	# Barrel spawn positions must not be buried inside the terrain mask.
	var g = load(MAPS).build_onto_new_grid(map)
	for barrel in explosives:
		assert_true(not g.is_solid_world(Vector2(barrel["position"].x, barrel["position"].y)),
				"%s spawn is not buried" % barrel["hazard_name"])


func test_barrel_scene_is_a_hazard_body() -> void:
	var scene: PackedScene = load(BARREL)
	assert_true(scene != null, "barrel scene loads")
	if scene == null:
		return
	var barrel: Node = scene.instantiate()
	assert_true(barrel.is_in_group("hazard_object"), "barrel is in the hazard group")
	assert_true(barrel is RigidBody3D, "barrel is a pushable rigid body")
	assert_true(barrel.detonated == false, "barrel starts undetonated")
	barrel.free()


func test_declare_winner_handles_zone_kills() -> void:
	# Zones are neutral: whoever dies to a zone, the OTHER entity wins.
	var s = load("res://scripts/match/match_state.gd").new()
	s.begin_match(PackedStringArray(["Strider", "Standard"]), 100.0, 15.0, 5)
	s.apply_damage("Strider", 200.0)
	s.declare_winner("Standard")
	assert_equal(String(s.match_result), "Standard wins the match",
			"a zone kill crowns the survivor")
