extends Camera3D
## S27 camera system: side-on tactical readability. Goal priority
## (pick_goal): map overview > fresh impact hold > focus node > hold
## position, with exponential smoothing toward the goal. Pure presentation —
## it reads match state, never writes it.

@export var follow_offset := Vector3(0, 4, 18)
@export var follow_smoothing := 5.0
## Zoomed-out framing for the map overview (frames the full battlefield).
@export var overview_offset := Vector3(0, 10, 42)
## How long the camera holds on a fresh blast before swinging back.
@export var impact_hold_ms := 600
@export var impact_smoothing := 8.0

## Set by the battle scene every frame from the match layer (live shell
## first, else the active mech).
var focus_node: Node3D = null
## {pos: Vector3, at: int} — the latest blast, pushed by the match layer.
var impact: Dictionary = {}
var overview := false

static func pick_goal(overview: bool, impact_fresh: bool, impact_pos: Vector3,
		has_focus: bool, focus_pos: Vector3, follow_offset: Vector3,
		overview_offset: Vector3, fallback: Vector3) -> Vector3:
	if overview:
		return overview_offset
	if impact_fresh:
		return impact_pos + follow_offset
	if has_focus:
		return focus_pos + follow_offset
	return fallback


func toggle_overview() -> void:
	overview = not overview


func _impact_fresh() -> bool:
	return impact.has("at") \
			and Time.get_ticks_msec() - int(impact["at"]) <= impact_hold_ms


func _process(delta: float) -> void:
	var has_focus := focus_node != null and is_instance_valid(focus_node)
	var impact_fresh := _impact_fresh()
	var goal := pick_goal(overview, impact_fresh,
			impact.get("pos", global_position), has_focus,
			focus_node.global_position if has_focus else global_position,
			follow_offset, overview_offset, global_position)
	var rate := impact_smoothing if impact_fresh and not overview \
			else follow_smoothing
	global_position = global_position.lerp(goal, 1.0 - exp(-rate * delta))
