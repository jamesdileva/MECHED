extends "res://tests/test_base.gd"
## S05 terrain rules. The grid and the chunk mesher are pure objects, so the
## roadmap's S05 verification — crater forms, terrain keeps changing under
## repeated explosions, surface state is queryable/serializable — is proven
## headless. Physical interaction (mech falling into craters, shells hitting
## the new collision) is engine-driven and verified in-game.

const GRID := "res://scripts/terrain/terrain_grid.gd"
const MESHER := "res://scripts/terrain/terrain_mesher.gd"
const CHUNK_CELLS := 32


func _grid():
	var g = load(GRID).new()
	g.create(240, 48, 0.25, -30.0, 8.0)
	g.fill_ground(0.0, -4.0)
	return g


func test_ground_fills_between_top_and_bottom() -> void:
	var g = _grid()
	assert_true(g.is_solid_world(Vector2(0, -0.5)), "below ground_top is solid")
	assert_true(g.is_solid_world(Vector2(0, -3.5)), "ground extends to bottom")
	assert_true(not g.is_solid_world(Vector2(0, 0.5)), "above ground_top is empty")
	assert_true(not g.is_solid_world(Vector2(500, -0.5)), "outside the grid is empty")


func test_destroy_circle_carves_the_mask() -> void:
	var g = _grid()
	var removed: int = g.destroy_circle(Vector2(0, -0.5), 1.0)
	assert_true(removed > 0, "carving removes cells")
	assert_true(not g.is_solid_world(Vector2(0, -0.5)), "crater center is empty")
	assert_true(g.is_solid_world(Vector2(20, -0.5)), "far ground is untouched")


func test_destroy_count_matches_circle_area() -> void:
	var g = _grid()
	# Fully submerged circle: radius 1.5 at depth 2.0 spans -3.5..-0.5, inside
	# the solid slab, so the removed count should be ~π * (1.5/0.25)² ≈ 113.
	var removed: int = g.destroy_circle(Vector2(0, -2.0), 1.5)
	assert_true(removed > 90 and removed < 135, "removed ~πr² cells, got %d" % removed)


func test_repeated_explosions_keep_carving() -> void:
	var g = _grid()
	var first: int = g.destroy_circle(Vector2(0, -0.5), 2.5)
	var second: int = g.destroy_circle(Vector2(1.0, -0.5), 2.5)
	assert_true(first > 0 and second > 0, "overlapping explosions keep removing cells")
	assert_true(g.query_surface_y(0.0) < -2.0, "surface at crater is much lower")


func test_surface_query_tracks_terrain() -> void:
	var g = _grid()
	var intact: float = g.query_surface_y(20.0)
	assert_almost_equal(intact, -0.125, 0.001, "intact column surfaces at the top cell")
	# Shallow carve: r1.5 at depth -1.0 hollows the top 2.5m but leaves the
	# slab's bottom row intact.
	g.destroy_circle(Vector2(20, -1.0), 1.5)
	var carved: float = g.query_surface_y(20.0)
	assert_true(carved < intact, "carved column surfaces lower")


func test_digging_through_the_floor_opens_a_pit() -> void:
	var g = _grid()
	# r2.5 at mid-slab depth spans the full 4m slab → the column goes clean
	# through and the surface query finds nothing.
	g.destroy_circle(Vector2(0, -2.0), 2.5)
	assert_true(is_nan(g.query_surface_y(0.0)), "column dug through has no surface")
	assert_true(not g.is_solid_world(Vector2(0, -3.9)), "bottom cell is gone")


func test_serialize_roundtrip_preserves_mask() -> void:
	var g = _grid()
	g.destroy_circle(Vector2(3.0, -0.5), 2.0)
	var data: Dictionary = g.serialize()
	var g2 = load(GRID).new()
	g2.create(240, 48, 0.25, -30.0, 8.0)
	g2.fill_ground(0.0, -4.0)
	g2.deserialize(data)
	assert_equal(g2.width, g.width, "width survives roundtrip")
	assert_equal(g2.cells, g.cells, "mask bytes survive roundtrip")
	assert_true(not g2.is_solid_world(Vector2(3.0, -0.5)), "carved cell still empty")
	assert_true(g2.is_solid_world(Vector2(20, -0.5)), "solid cell still solid")


func test_mesher_reflects_destruction() -> void:
	var g = _grid()
	var mesher = load(MESHER).new()
	var chunk := Vector2i(7, 1)
	var before: Dictionary = mesher.build_chunk(g, chunk, CHUNK_CELLS)
	assert_true(before["positions"].size() > 0, "intact ground chunk has geometry")
	g.destroy_circle(Vector2(29.0, 0.0), 6.0)
	var after: Dictionary = mesher.build_chunk(g, chunk, CHUNK_CELLS)
	assert_true(after["positions"].size() < before["positions"].size(),
			"carving removes chunk geometry (%d -> %d)" % [before["positions"].size(), after["positions"].size()])
	assert_equal(before["positions"].size() % 6, 0, "geometry is whole triangles")


func test_mesher_skips_empty_chunks() -> void:
	var g = _grid()
	var mesher = load(MESHER).new()
	var sky_chunk: Dictionary = mesher.build_chunk(g, Vector2i(0, 0), CHUNK_CELLS)
	assert_equal(sky_chunk["positions"].size(), 0, "chunk with no solid cells has no geometry")
