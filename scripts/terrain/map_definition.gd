extends Resource
## A data-driven battlefield (S21, architecture.md §3/§5): terrain ops,
## collapsible structures, spawn points, wind rules, and mech boundaries —
## all Resource data. The same match system loads any map without code
## changes (roadmap S21 verification).
##
## build(grid) executes the terrain ops in order and converts structures;
## spawn_points[0] is the player's, [1] the AI's.

const TerrainGridScript := preload("res://scripts/terrain/terrain_grid.gd")

const CELL := 0.25
const GRID_TOP_Y := 8.0
const GRID_ROWS := 48
## The mask always spans the full 60m world; bounds are mech movement limits,
## not the grid extent.
const GRID_WIDTH := 240
const GRID_X_MIN := -30.0

@export var display_name := "Canyon"
@export var terrain_ops: Array = []
@export var structures: Array = []
## [player_spawn: Vector3, ai_spawn: Vector3] — drop-in positions.
@export var spawn_points: PackedVector3Array = PackedVector3Array([
	Vector3(0, 3, 0), Vector3(12, 7, 0),
])
## Wind strength cap for this battlefield (m/s², S14).
@export var wind_max := 5.0
## Mech movement bounds (S02 movement clamps are map-driven now).
@export var bounds_min_x := -27.0
@export var bounds_max_x := 27.0


## Executes terrain ops and converts structures; returns the structure list
## for the terrain system's collapse checks.
func build(grid) -> Array:
	for op in terrain_ops:
		if op != null:
			op.apply(grid)
	var out: Array = []
	for structure in structures:
		if structure != null:
			out.append(structure.build(grid))
	return out


## Convenience for tests/tools: a fresh grid with this map built on it.
static func build_onto_new_grid(map_definition: Resource) -> Object:
	var grid = TerrainGridScript.new()
	grid.create(GRID_WIDTH, GRID_ROWS, CELL, GRID_X_MIN, GRID_TOP_Y)
	map_definition.build(grid)
	return grid
