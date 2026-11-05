extends "res://tests/test_base.gd"
## S13 terrain-as-tactical-tool: the layout creates the situations and the
## collapse rule makes terrain destruction a weapon. All pure — headless.

const GRID := "res://scripts/terrain/terrain_grid.gd"
const LAYOUT := "res://scripts/terrain/terrain_layout.gd"
const MESHER := "res://scripts/terrain/terrain_mesher.gd"
const CHUNK_CELLS := 32


func _laid_out_grid():
	var g = load(GRID).new()
	g.create(240, 48, 0.25, -30.0, 8.0)
	load(LAYOUT).build_standard_layout(g)
	return g


func test_hill_and_tunnel_exist() -> void:
	var g = _laid_out_grid()
	# Hilltop is high ground above the spawn level.
	assert_true(g.is_solid_world(Vector2(-16, 3.5)), "hilltop is solid high ground")
	# The tunnel cuts a walkable channel through the hill.
	assert_true(not g.is_solid_world(Vector2(-19, 1.0)), "tunnel interior is open")
	assert_true(g.is_solid_world(Vector2(-19, 3.0)), "hill mass above the tunnel")
	assert_true(g.query_surface_y(-19) > 2.0, "the tunnel roof reads as the surface")


func test_ravine_and_bridge_exist() -> void:
	var g = _laid_out_grid()
	# The ravine opens the floor between x 18..24 (clear of the pillar at ~21).
	assert_true(not g.is_solid_world(Vector2(19, -1.0)), "ravine interior is open")
	# The bridge deck crosses it flush with the ground, held by the pillar.
	assert_true(g.is_solid_world(Vector2(21, -0.25)), "bridge deck crosses the ravine")
	assert_true(g.is_solid_world(Vector2(21, -3.5)), "bridge pillar reaches the bottom")
	assert_true(g.is_solid_world(Vector2(26, 1.0)), "plateau stands east of the ravine")


func test_cover_wall_stands_on_the_flats() -> void:
	var g = _laid_out_grid()
	assert_true(g.is_solid_world(Vector2(7.25, 1.0)), "cover wall blocks low arcs")
	assert_true(not g.is_solid_world(Vector2(7.25, 2.5)), "cover wall is jumpable")


func test_bridge_collapses_when_its_pillar_is_carved() -> void:
	var g = _laid_out_grid()
	var layout = load(LAYOUT)
	var structures: Array = layout.build_standard_layout(g)
	assert_equal(structures.size(), 1, "the layout ships one collapsible structure")
	assert_equal(layout.check_collapses(g, structures).size(), 0,
			"an intact pillar holds the bridge")
	# A couple of shells shear the pillar (radius 2 reaches all three anchors).
	g.destroy_circle(Vector2(21, -2.5), 2.0)
	var collapsed: Array = layout.check_collapses(g, structures)
	assert_equal(collapsed.size(), 1, "destroying the anchors drops the structure")
	assert_equal(collapsed[0]["name"], "bridge", "the bridge is what collapsed")
	# Applying the collapse clears the deck: the crossing is gone.
	layout.fill_world_rect(g, collapsed[0]["region"], false)
	assert_true(not g.is_solid_world(Vector2(21, -0.25)), "deck cells are gone")
	assert_true(not g.is_solid_world(Vector2(19, -0.25)), "the whole span dropped")


func test_partial_pillar_damage_leaves_the_bridge_standing() -> void:
	var g = _laid_out_grid()
	var layout = load(LAYOUT)
	var structures: Array = layout.build_standard_layout(g)
	# Precision hit near the top: lower anchors survive.
	g.destroy_circle(Vector2(21, -0.75), 0.9)
	assert_equal(layout.check_collapses(g, structures).size(), 0,
			"precision damage does not drop the bridge (weapon choice matters)")


func test_ramp_staircases_smooth_into_diagonals() -> void:
	var g = load(GRID).new()
	g.create(40, 20, 0.25, -5.0, 4.0)
	# A four-step staircase (x -2..0): each step is exactly one cell tall.
	for i in 4:
		load(LAYOUT).fill_world_rect(g, Rect2(-2 + i * 0.5, -1, 0.5, 0.25 * (i + 1)), true)
	var chunk: Dictionary = load(MESHER).build_chunk(g, Vector2i(0, 0), CHUNK_CELLS)
	var positions: PackedVector3Array = chunk["positions"]
	var riser_xs := {}
	var diagonal_count := 0
	for i in range(0, positions.size(), 6):
		var a: Vector3 = positions[i]
		var b: Vector3 = positions[i + 1]
		if absf(a.x - b.x) < 0.0001 and absf(absf(a.y - b.y) - 0.25) < 0.0001:
			riser_xs[a.x] = true
		elif absf(a.x - b.x) > 0.0001 and absf(a.y - b.y) > 0.0001:
			diagonal_count += 1
	# No vertical riser may remain at the three smoothed step boundaries.
	for boundary in [-1.5, -1.0, -0.5]:
		assert_true(not riser_xs.has(boundary),
				"no riser at smoothed boundary %s" % boundary)
	assert_true(diagonal_count > 0, "smoothing emitted diagonal ramp faces")


func test_cliffs_keep_their_risers() -> void:
	var g = load(GRID).new()
	g.create(40, 20, 0.25, -5.0, 4.0)
	# A 1m-tall block: its walls are genuine cliffs, NOT smoothed (nothing
	# solid sits one cell below-right of the edge, so no diagonal applies).
	load(LAYOUT).fill_world_rect(g, Rect2(-1, 0, 1, 1), true)
	var chunk: Dictionary = load(MESHER).build_chunk(g, Vector2i(0, 0), CHUNK_CELLS)
	var positions: PackedVector3Array = chunk["positions"]
	var riser_xs := {}
	var diagonal_count := 0
	for i in range(0, positions.size(), 6):
		var a: Vector3 = positions[i]
		var b: Vector3 = positions[i + 1]
		if absf(a.x - b.x) < 0.0001 and absf(absf(a.y - b.y) - 0.25) < 0.0001:
			riser_xs[a.x] = true
		elif absf(a.x - b.x) > 0.0001 and absf(a.y - b.y) > 0.0001:
			diagonal_count += 1
	# fill_world_rect includes the end cell: the block spans x -1..0.25, so
	# its cliff walls are at x = -1 (left) and x = 0.25 (right).
	assert_true(riser_xs.has(0.25), "cliff walls keep vertical risers")
	assert_true(riser_xs.has(-1.0), "both block walls are full risers")
	assert_equal(diagonal_count, 0, "a lone block emits no smoothing diagonals")
