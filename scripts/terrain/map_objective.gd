extends Resource
## A map objective (S31): where a mode's action happens, as map data.
## kinds: "control_zone" (hold to win), "checkpoint" (ordered race gates),
## "siege_target" (bound to a collapsible structure by name).

@export var objective_name := "objective"
@export_enum("control_zone", "checkpoint", "siege_target") var kind := "control_zone"
## World-space XY region the mech's body center must occupy.
@export var region := Rect2(0, 0, 2, 2)
## Checkpoint visit order (0 first). Ignored by other kinds.
@export var order := 0
## Siege: the collapsible structure this objective tracks.
@export var structure_name := ""
