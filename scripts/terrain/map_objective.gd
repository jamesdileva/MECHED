extends Resource
## A map objective (S31/S32): where a mode's action happens, as map data.
## kinds: "control_zone" (hold to win = Capture), "checkpoint" (ordered race
## gates = Reach), "siege_target" (bound to a collapsible structure by name
## = Destroy). SURVIVE is a mode-level win condition (no map region needed).
## ESCORT is reserved for S43 (needs NPC entities).

## The objective kind vocabulary (roadmap S32's five kinds).
const KIND_CAPTURE := "control_zone"
const KIND_DESTROY := "siege_target"
const KIND_REACH := "checkpoint"

@export var objective_name := "objective"
@export_enum("control_zone", "checkpoint", "siege_target") var kind := "control_zone"
## World-space XY region the mech's body center must occupy.
@export var region := Rect2(0, 0, 2, 2)
## Checkpoint visit order (0 first). Ignored by other kinds.
@export var order := 0
## Siege: the collapsible structure this objective tracks.
@export var structure_name := ""
