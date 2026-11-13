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


func test_canyon_matches_the_s13_baseline_exactly() -> void:
	# The S13 hardcoded layout authored as map data: the two masks must be
	# identical so the playtest baseline is unchanged.
	var from_layout = load(GRID).new()
	from_layout.create(240, 48, 0.25, -30.0, 8.0)
	load(LAYOUT).build_standard_layout(from_layout)
	var from_data = _built(CANYON)
	assert_equal(from_data.cells, from_layout.cells,
			"Canyon ops reproduce the S13 layout byte-for-byte")
	assert_equal(from_data.width, from_layout.width, "grid width matches")


func test_canyon_has_the_bridge_structure() -> void:
	var structures: Array = load(CANYON).build(_built(CANYON)).duplicate()
	assert_equal(structures.size(), 1, "Canyon ships the collapsible bridge")
	assert_equal(structures[0]["name"], "bridge", "the structure is the bridge")


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
	assert_true(structures.size() == 1 and structures[0]["name"] == "scaffold",
			"the scaffold is a collapsible structure")


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
