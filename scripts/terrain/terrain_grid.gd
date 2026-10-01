extends RefCounted
## Pure destructible-terrain mask (architecture.md §5 "Destruction Mask").
##
## A 2D grid in the X–Y gameplay plane, extruded into a fixed-depth Z slab by
## the mesher/visual layers. Row 0 is the TOP row (highest y). Knows nothing
## about scenes, meshes, or physics — fully headless-testable, and the byte
## mask serializes deterministically for future replay/multiplayer sync.
## The rest of the game must never need to know this internal representation
## (implementation-guide §9); it talks to TerrainSystem.

## Sentinel from query_surface_y when a column has no solid cell at all
## (dug clean through).
const NO_SURFACE := NAN

const GRASS := Color(0.32, 0.48, 0.26)
const DIRT := Color(0.43, 0.34, 0.26)

var width := 0
var rows := 0
var cell_size := 0.25
var x_min := -30.0
var y_max := 8.0
## Slab thickness along Z (visual/collision extrusion).
var depth := 2.0
## 1 = solid, 0 = empty; index = row * width + col.
var cells: PackedByteArray = PackedByteArray()


func create(p_width: int, p_rows: int, p_cell_size: float, p_x_min: float,
		p_y_max: float, p_depth := 2.0) -> void:
	width = p_width
	rows = p_rows
	cell_size = p_cell_size
	x_min = p_x_min
	y_max = p_y_max
	depth = p_depth
	cells.resize(width * rows)
	cells.fill(0)


## Fills solid cells whose centers lie between top_y and bottom_y.
func fill_ground(top_y: float, bottom_y: float) -> void:
	for cy in rows:
		for cx in width:
			var y := center_y(cy)
			cells[cy * width + cx] = 1 if (y <= top_y and y >= bottom_y) else 0


func cell_center(cx: int, cy: int) -> Vector2:
	return Vector2(x_min + (cx + 0.5) * cell_size, y_max - (cy + 0.5) * cell_size)


func center_y(cy: int) -> float:
	return y_max - (cy + 0.5) * cell_size


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - x_min) / cell_size)), int(floor((y_max - p.y) / cell_size)))


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < width and c.y >= 0 and c.y < rows


func is_solid(c: Vector2i) -> bool:
	return in_bounds(c) and cells[c.y * width + c.x] == 1


func is_solid_world(p: Vector2) -> bool:
	return is_solid(world_to_cell(p))


func set_solid(c: Vector2i, solid: bool) -> void:
	if in_bounds(c):
		cells[c.y * width + c.x] = 1 if solid else 0


## Carves a circular crater. Returns the number of cells removed.
func destroy_circle(center: Vector2, radius: float) -> int:
	var removed := 0
	# Row indices run top-to-bottom (inverted vs world y), so min/max the
	# bounding box per axis — a plain lo..hi range is empty for any box that
	# descends in world space.
	var lo := world_to_cell(center - Vector2(radius, radius))
	var hi := world_to_cell(center + Vector2(radius, radius))
	var cy0 := maxi(mini(lo.y, hi.y), 0)
	var cy1 := mini(maxi(lo.y, hi.y) + 1, rows)
	var cx0 := maxi(mini(lo.x, hi.x), 0)
	var cx1 := mini(maxi(lo.x, hi.x) + 1, width)
	for cy in range(cy0, cy1):
		for cx in range(cx0, cx1):
			var c := Vector2i(cx, cy)
			if is_solid(c) and cell_center(cx, cy).distance_to(center) <= radius:
				cells[cy * width + cx] = 0
				removed += 1
	return removed


## Topmost solid cell center's y in the column under world x, or NO_SURFACE.
func query_surface_y(x: float) -> float:
	var cx := int(floor((x - x_min) / cell_size))
	if cx < 0 or cx >= width:
		return NO_SURFACE
	for cy in rows:
		if cells[cy * width + cx] == 1:
			return center_y(cy)
	return NO_SURFACE


func serialize() -> Dictionary:
	return {
		"width": width, "rows": rows, "cell_size": cell_size,
		"x_min": x_min, "y_max": y_max, "depth": depth,
		"cells": cells.duplicate(),
	}


func deserialize(data: Dictionary) -> void:
	width = int(data["width"])
	rows = int(data["rows"])
	cell_size = float(data["cell_size"])
	x_min = float(data["x_min"])
	y_max = float(data["y_max"])
	depth = float(data["depth"])
	cells = data["cells"].duplicate()
