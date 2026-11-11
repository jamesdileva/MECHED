extends Control
## Map select (S20): the flow step exists today with one battlefield; the
## map list grows in S21 (Map System) without touching this scene's wiring.

const BATTLE := "res://scenes/main/main.tscn"
const MECH_SELECT := "res://scenes/menus/mech_select.tscn"

const MAPS: Array = [{"name": "CANYON", "id": "standard"}]


func _ready() -> void:
	var first: Button = %MapButtons.get_child(0)
	first.pressed.connect(_on_map.bind(MAPS[0]["id"]))
	first.grab_focus()
	%BackButton.pressed.connect(_on_back)


func _on_map(map_id: String) -> void:
	MatchSession.map_name = map_id
	get_tree().change_scene_to_file(BATTLE)


func _on_back() -> void:
	get_tree().change_scene_to_file(MECH_SELECT)
