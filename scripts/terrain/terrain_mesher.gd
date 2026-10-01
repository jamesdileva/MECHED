extends RefCounted
## Builds the visual + collision triangle geometry for one terrain chunk
## directly from the mask (pure, headless-testable).
##
## Only exposed faces are emitted (a face borders an empty cell or the grid
## edge): top/bottom/side quads span the full Z depth, plus a front cap at
## +Z per solid cell so the cross-section reads correctly from the camera.
## The same triangle list drives the ArrayMesh and the ConcavePolygonShape3D,
## so visuals and collision can never drift apart.

const TerrainGridScript := preload("res://scripts/terrain/terrain_grid.gd")


## Returns {positions: PackedVector3Array (triangles), colors: PackedColorArray}.
static func build_chunk(grid, chunk: Vector2i, chunk_cells: int) -> Dictionary:
	var positions: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var cs: float = grid.cell_size
	var half: float = grid.depth * 0.5

	var cx0 := chunk.x * chunk_cells
	var cy0 := chunk.y * chunk_cells
	for cy in range(cy0, mini(cy0 + chunk_cells, grid.rows)):
		for cx in range(cx0, mini(cx0 + chunk_cells, grid.width)):
			if not grid.is_solid(Vector2i(cx, cy)):
				continue
			var center: Vector2 = grid.cell_center(cx, cy)
			var x0 := center.x - cs * 0.5
			var x1 := center.x + cs * 0.5
			var y_top := center.y + cs * 0.5
			var y_bot := center.y - cs * 0.5
			var top_open: bool = not grid.is_solid(Vector2i(cx, cy - 1))
			var bottom_open: bool = not grid.is_solid(Vector2i(cx, cy + 1))
			var left_open: bool = not grid.is_solid(Vector2i(cx - 1, cy))
			var right_open: bool = not grid.is_solid(Vector2i(cx + 1, cy))
			var grass: Color = TerrainGridScript.GRASS
			var dirt: Color = TerrainGridScript.DIRT

			# Front cap (cross-section face toward the camera).
			_quad(positions, colors,
					Vector3(x0, y_top, half), Vector3(x1, y_top, half),
					Vector3(x1, y_bot, half), Vector3(x0, y_bot, half),
					dirt)
			if top_open:
				_quad(positions, colors,
						Vector3(x0, y_top, half), Vector3(x1, y_top, half),
						Vector3(x1, y_top, -half), Vector3(x0, y_top, -half),
						grass)
			if bottom_open:
				_quad(positions, colors,
						Vector3(x0, y_bot, -half), Vector3(x1, y_bot, -half),
						Vector3(x1, y_bot, half), Vector3(x0, y_bot, half),
						dirt)
			if left_open:
				_quad(positions, colors,
						Vector3(x0, y_top, -half), Vector3(x0, y_bot, -half),
						Vector3(x0, y_bot, half), Vector3(x0, y_top, half),
						dirt)
			if right_open:
				_quad(positions, colors,
						Vector3(x1, y_top, half), Vector3(x1, y_bot, half),
						Vector3(x1, y_bot, -half), Vector3(x1, y_top, -half),
						dirt)
	return {"positions": positions, "colors": colors}


static func _quad(positions: PackedVector3Array, colors: PackedColorArray,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	# Two triangles: (a, b, c) and (a, c, d).
	positions.append_array(PackedVector3Array([a, b, c, a, c, d]))
	for i in 6:
		colors.append(color)
