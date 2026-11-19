extends "res://tests/test_base.gd"
## S21 map system: three battlefields as pure data, loaded by the same match
## system without code changes (roadmap verification). Canyon must reproduce
## the S13 layout exactly — it is the playtest baseline.

const MAPS := "res://scripts/terrain/map_definition.gd"
const GRID := "res://scripts/terrain/terrain_grid.gd"
const LAYOUT := "res://scripts/terrain/terrain_layout.gd"

const CANYON := "res://data/maps/canyon.tres"
const ISLANDS := "res://data/maps/floating_islands.tres"
const RUINS := "res://data/maps/industrial_ruins.tres"
const MAP_LIST: Array = [CANYON, ISLANDS, RUINS]
const EPS := 0.0001


func _built(map_path: String):
	var g = load(MAPS).build_onto_new_grid(load(map_path))
	return g


func test_all_three_maps_load_and_build() -> void:
	for path in MAP_LIST:
		var map: Resource = load(path)
		assert_true(map != null, "%s loads" % path.get_file())
		var g = load(MAPS).build_onto_new_grid(map)
		assert_true(g != null, "%s builds onto a grid" % path.get_file())


func test_canyon_retains_key_s13_features() -> void:
	# The S13 baseline test served its purpose (proving the ops matched the
	# hardcoded layout). S33 deliberately extends the battlefield, so the
	# test now asserts the key tactical features instead of byte-equality.
	var g = _built(CANYON)
	assert_true(g.is_solid_world(Vector2(0, -0.5)), "ground slab stands")
	assert_true(g.is_solid_world(Vector2(-19, 3.5)), "hilltop stands")
	assert_true(not g.is_solid_world(Vector2(-19, 1.0)), "tunnel is open")
	assert_true(g.is_solid_world(Vector2(21, -0.25)), "bridge deck crosses the ravine")
	assert_true(not g.is_solid_world(Vector2(19, -1.0)), "ravine is open")
	assert_true(g.is_solid_world(Vector2(26, 3.5)), "watchtower stands on the plateau")


func test_canyon_has_the_bridge_structure() -> void:
	var structures: Array = load(CANYON).build(_built(CANYON)).duplicate()
	assert_equal(structures.size(), 2, "Canyon ships two collapsible structures")
	var names: Array = []
	for s in structures:
		names.append(s["name"])
	assert_true("bridge" in names, "the bridge is present")
	assert_true("watchtower" in names, "the watchtower is present")


func test_floating_islands_have_no_ground() -> void:
	var g = _built(ISLANDS)
	# Islands exist at height...
	assert_true(g.is_solid_world(Vector2(-16, 1.25)), "island A is solid")
	assert_true(g.is_solid_world(Vector2(16, 1.5)), "island C is solid")
	# ...and there is NO ground beneath — the void is real.
	assert_true(not g.is_solid_world(Vector2(0, -1.0)), "no ground below the islands")
	assert_true(is_nan(g.query_surface_y(-9.0)), "mid-gap columns have no surface")
	assert_true(g.query_surface_y(-16) >= 0.5, "island A has a surface to stand on")


func test_industrial_ruins_have_the_scaffold() -> void:
	var g = _built(RUINS)
	# The tower and its walk-up steps.
	assert_true(g.is_solid_world(Vector2(11, 3.5)), "tower stands")
	assert_true(g.is_solid_world(Vector2(14.5, 1.5)), "steps stand")
	# The broken floor is a real pit.
	assert_true(not g.is_solid_world(Vector2(1.5, -1.0)), "broken floor opens a pit")
	# The scaffold deck spans tower to wall, 4m up.
	assert_true(g.is_solid_world(Vector2(18, 4.0)), "scaffold deck stands")
	var structures: Array = load(RUINS).build(g)
	assert_equal(structures.size(), 2, "Ruins ships two collapsible structures")
	var names: Array = []
	for s in structures:
		names.append(s["name"])
	assert_true("scaffold" in names, "the scaffold is present")
	assert_true("building_roof" in names, "the building roof is present")


func test_maps_define_two_spawns_above_their_terrain() -> void:
	for path in MAP_LIST:
		var map: Resource = load(path)
		var spawns: PackedVector3Array = map.spawn_points
		assert_equal(spawns.size(), 2, "%s defines player + AI spawns" % path.get_file())
		var g = _built(path)
		for i in 2:
			var spawn: Vector3 = spawns[i]
			assert_true(spawn.y > -4.0, "%s spawn %d is above the kill plane"
					% [path.get_file(), i])
			# Spawns must be over solid-enough terrain or open air — never
			# buried inside the mask.
			assert_true(not g.is_solid_world(Vector2(spawn.x, spawn.y)),
					"%s spawn %d is not buried in terrain"
							% [path.get_file(), i])


func test_wind_caps_are_map_defined() -> void:
	var canyon: Resource = load(CANYON)
	var islands: Resource = load(ISLANDS)
	assert_almost_equal(canyon.wind_max, 5.0, EPS, "Canyon: standard wind")
	assert_true(islands.wind_max > canyon.wind_max,
			"Floating Islands blows harder (islands + wind is the identity)")
	assert_true(islands.wind_max <= 8.0, "wind stays within the sane band")


func test_structures_build_to_cell_anchors() -> void:
	for path in [CANYON, RUINS]:
		var map: Resource = load(path)
		var g = _built(path)
		var structures: Array = map.build(g)
		assert_true(structures.size() >= 1, "%s ships structures" % path.get_file())
		for structure in structures:
			for anchor in structure["anchors"]:
				assert_true(anchor is Vector2i, "anchors converted to cell coords")
