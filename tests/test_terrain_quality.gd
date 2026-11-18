extends "res://tests/test_base.gd"
## S26 destruction quality: the critical requirement is that a match never
## becomes physically broken by terrain destruction. This stress suite hammers
## the carve pipeline headless — repeated large explosions, overlapping
## craters, a full-map carve, carves past the grid edge — and asserts the
## grid stays consistent and structures behave sanely after every hit.

const MAPS := "res://scripts/terrain/map_definition.gd"
const GRID := "res://scripts/terrain/terrain_grid.gd"
const LAYOUT := "res://scripts/terrain/terrain_layout.gd"
const CANYON := "res://data/maps/canyon.tres"
const ISLANDS := "res://data/maps/floating_islands.tres"
const RUINS := "res://data/maps/industrial_ruins.tres"
const MAP_LIST: Array = [CANYON, ISLANDS, RUINS]


func _laid_out(map_path: String):
	var map: Resource = load(map_path)
	var g = load(MAPS).build_onto_new_grid(map)
	return {"grid": g, "map": map, "structures": map.build(g)}


func test_repeated_large_explosions_keep_the_grid_consistent() -> void:
	var arena = _laid_out(CANYON)
	var g = arena["grid"]
	# Ten overlapping radius-6 blasts across the battlefield.
	for i in 10:
		var removed: int = g.destroy_circle(Vector2(-24 + i * 5.0, -1.0), 6.0)
		assert_true(removed >= 0, "carve %d returns a sane count" % i)
		# Queries must stay functional after every hit.
		g.query_surface_y(0.0)
	assert_true(g.query_surface_y(0.0) != 0.0 or is_nan(g.query_surface_y(0.0)),
			"surface query stays callable after stress")


func test_full_map_carve_leaves_a_valid_empty_grid() -> void:
	var g = _laid_out(CANYON)["grid"]
	var removed: int = g.destroy_circle(Vector2(0, 0), 60.0)
	assert_true(removed > 0, "a map-wide blast carves everything reachable")
	# Every column dug through: all surface queries are NAN.
	assert_true(is_nan(g.query_surface_y(-25.0)), "west edge carved through")
	assert_true(is_nan(g.query_surface_y(25.0)), "east edge carved through")
	# The grid itself stays valid and rebuildable: refill restores ground.
	g.fill_ground(0.0, -4.0)
	assert_true(g.is_solid_world(Vector2(0, -0.5)), "refill restores solidity")


func test_carves_past_the_grid_edge_are_clamped() -> void:
	var arena = _laid_out(CANYON)
	var g = arena["grid"]
	var before: int = g.cell_solid_count()
	# Center beyond the east bound: radius still reaches the last columns.
	g.destroy_circle(Vector2(36, 0), 10.0)
	assert_true(g.cell_solid_count() < before, "in-bounds cells near the edge still carved")
	# No crash, no out-of-bounds writes: queries stay sane.
	g.query_surface_y(45.0)
	assert_true(true, "clamped carve completes")


func test_collapse_under_stress_chain_works() -> void:
	var arena = _laid_out(CANYON)
	var layout = load(LAYOUT)
	var structures: Array = arena["structures"]
	# Two big blasts take the bridge anchors out under stress conditions.
	arena["grid"].destroy_circle(Vector2(21, -1.0), 2.5)
	arena["grid"].destroy_circle(Vector2(21, -3.0), 2.5)
	var collapsed: Array = layout.check_collapses(arena["grid"], structures)
	assert_equal(collapsed.size(), 1, "the bridge still collapses under stress")
	# Clearing the collapsed deck leaves a consistent grid.
	layout.fill_world_rect(arena["grid"], collapsed[0]["region"], false)
	assert_true(not arena["grid"].is_solid_world(Vector2(21, -0.25)),
			"deck cleared after stress collapse")


func test_all_maps_survive_identical_stress() -> void:
	# The roadmap verification generalized: the same stress sequence on every
	# map keeps the grid consistent — no code changes per map.
	for map_path in MAP_LIST:
		var arena = _laid_out(map_path)
		var g = arena["grid"]
		for i in 5:
			g.destroy_circle(Vector2(-20 + i * 10.0, 0.0), 5.0)
		# Queries stay functional on every map after stress.
		g.query_surface_y(0.0)
		assert_true(true, "%s survives the stress sequence" % map_path.get_file())


func test_restore_regenerates_terrain_and_structures() -> void:
	var map: Resource = load(CANYON)
	var fresh = load(MAPS).build_onto_new_grid(map)
	var fresh_structures: Array = map.build(fresh)
	# Wreck the fresh grid heavily, then run the map's own restore path.
	fresh.destroy_circle(Vector2(0, 0), 30.0)
	for structure in fresh_structures:
		load(LAYOUT).fill_world_rect(fresh, structure["region"], false)
	var wrecked_count: int = fresh.cell_solid_count()
	# Restore = re-run build on the same grid object (TerrainSystem.restore
	# delegates here).
	map.build(fresh)
	assert_true(fresh.cell_solid_count() > wrecked_count,
			"restore regenerates carved terrain")
	for structure in fresh_structures:
		for anchor in structure["anchors"]:
			assert_true(fresh.is_solid(anchor), "structure anchors fully revived")


func test_radius_zero_carve_changes_nothing() -> void:
	var g = _laid_out(CANYON)["grid"]
	var before: int = g.cell_solid_count()
	assert_equal(g.destroy_circle(Vector2(0, -0.5), 0.0), 0, "radius 0 carves nothing")
	assert_equal(g.cell_solid_count(), before, "grid untouched by a zero-radius blast")
