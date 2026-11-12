extends Resource
## A terrain-shaping primitive for MapDefinitions (S21). One resource covers
## the three fill kinds the layouts need: rect, circle, and staircase (a
## walkable stepped ramp when paired with the mesher's diagonal smoothing).

const TerrainLayout := preload("res://scripts/terrain/terrain_layout.gd")

@export_enum("rect", "circle", "staircase") var kind := "rect"
## Rect fill/clear (world space).
@export var rect := Rect2(-30, -4, 60, 4)
## Circle fill/clear (world space).
@export var center := Vector2.ZERO
@export var radius := 0.0
## Staircase: step_count ramps each step_width wide, rising step_height per
## step from base_y upward.
@export var start_x := 0.0
@export var base_y := 0.0
@export var base_height := 0.0
@export var step_width := 0.5
@export var step_height := 0.25
@export var step_count := 1
## true = fill solid, false = carve.
@export var solid := true


func apply(grid) -> void:
	match kind:
		"rect":
			TerrainLayout.fill_world_rect(grid, rect, solid)
		"circle":
			grid.fill_circle(center, radius, solid)
		"staircase":
			for i in step_count:
				TerrainLayout.fill_world_rect(grid,
						Rect2(start_x + i * step_width, base_y, step_width,
								base_height + (i + 1) * step_height), solid)
