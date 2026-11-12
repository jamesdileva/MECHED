extends Resource
## A collapsible structure in a MapDefinition (S21): region + world-space
## anchors. build() converts anchors to grid cells for the collapse rule.
@export var structure_name := "structure"
@export var region := Rect2(0, 0, 1, 1)
## World-space cells; the structure drops when ALL of them are carved.
@export var anchors: Array = []


func build(grid) -> Dictionary:
	var cell_anchors: Array = []
	for anchor in anchors:
		cell_anchors.append(grid.world_to_cell(anchor))
	return {"name": structure_name, "region": region, "anchors": cell_anchors}
