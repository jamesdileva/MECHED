extends RefCounted
## Battlefield layout builder (S13): shapes the destructible mask into
## tactical terrain and returns the collapsible structures.
##
## Pure functions over the grid — headless-testable. Coordinates are world
## space (the grid is 60m wide: x −30..30, cell 0.25m; ground top y=0).
##
## Features: a tiered hill with a walkable 2m tunnel through it, a low cover
## wall, a ravine cut through the ground, a flush bridge over the ravine
## whose pillar is a collapsible structure, and a plateau with a cliff face
## over the ravine. Destroying the bridge pillar strands ground mechs —
## destroying terrain as a weapon.

const TerrainGridScript := preload("res://scripts/terrain/terrain_grid.gd")

const SPAWN_X := 0.0
const TUNNEL_HEIGHT := 2.0


static func fill_world_rect(grid, rect: Rect2, solid: bool) -> void:
	var lo: Vector2i = grid.world_to_cell(rect.position)
	var hi: Vector2i = grid.world_to_cell(rect.end)
	for cy in range(mini(lo.y, hi.y), maxi(lo.y, hi.y) + 1):
		for cx in range(mini(lo.x, hi.x), maxi(lo.x, hi.x) + 1):
			grid.set_solid(Vector2i(cx, cy), solid)


## Shapes the grid and returns the structure list. Call after grid.create().
static func build_standard_layout(grid) -> Array:
	# Ground slab.
	fill_world_rect(grid, Rect2(-30, -4, 60, 4), true)

	# Tiered hill (west): 0.25m steps, 0.5m wide each — the mesher smooths
	# 1-cell staircase boundaries into walkable 45-degree diagonals.
	var x := -26.0
	var height := 0.25
	while height <= 4.0:
		fill_world_rect(grid, Rect2(x, 0, 0.5, height), true)
		x += 0.5
		height += 0.25
	fill_world_rect(grid, Rect2(-18, 0, 4, 4), true)  # hilltop plateau

	# Tunnel through the hill (walk-under route, ~2m clearance).
	fill_world_rect(grid, Rect2(-22.5, 0, 7, TUNNEL_HEIGHT), false)

	# Low cover wall on the flats (blocks low arcs, jumpable).
	fill_world_rect(grid, Rect2(7, 0, 0.5, 1.6), true)

	# Ravine through the ground (east).
	fill_world_rect(grid, Rect2(18, -4, 6, 4), false)

	# Plateau with a cliff face over the ravine (high ground, east end).
	fill_world_rect(grid, Rect2(24.5, 0, 4.5, 1.5), true)

	# Bridge over the ravine, flush with the ground; its pillar is a
	# collapsible structure (see anchors below).
	fill_world_rect(grid, Rect2(17, -0.5, 8, 0.5), true)
	fill_world_rect(grid, Rect2(20.75, -4, 0.5, 3.5), true)  # pillar

	return [{
		"name": "bridge",
		"region": Rect2(17, -0.5, 8, 0.5),
		# Top / middle / bottom of the pillar: a shell that shears the pillar
		# takes all three; precision hits may leave it standing.
		"anchors": [
			grid.world_to_cell(Vector2(21, -0.75)),
			grid.world_to_cell(Vector2(21, -2.5)),
			grid.world_to_cell(Vector2(21, -3.75)),
		],
	}]


## Pure collapse rule: a structure falls when ALL of its anchor cells have
## been carved. Returns the collapsed structures (removed by the caller).
static func check_collapses(grid, structures: Array) -> Array:
	var collapsed: Array = []
	for structure in structures:
		var all_gone := true
		for anchor in structure["anchors"]:
			if grid.is_solid(anchor):
				all_gone = false
				break
		if all_gone:
			collapsed.append(structure)
	return collapsed


## Convenience for tests and tools: the world-space center of a structure.
static func structure_center(structure: Dictionary) -> Vector2:
	var region: Rect2 = structure["region"]
	return region.get_center()
