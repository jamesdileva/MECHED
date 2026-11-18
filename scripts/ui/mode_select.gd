extends Control
## Mode select (S31): lists the game modes supported by the chosen map
## (data-driven filtering), writes the pick to MatchSession, BACK returns.

const BATTLE := "res://scenes/main/main.tscn"
const MAP_SELECT := "res://scenes/menus/map_select.tscn"


func _ready() -> void:
	var map: Resource = load(MatchSession.map_path)
	var first: Button = null
	for mode_name in map.supported_modes:
		var mode_path := "res://data/modes/%s.tres" % String(mode_name).to_lower().replace(" ", "_")
		if not ResourceLoader.exists(mode_path):
			continue
		var mode: Resource = load(mode_path)
		var button := Button.new()
		button.text = String(mode.display_name).to_upper()
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(_on_mode.bind(mode_path))
		%ModeButtons.add_child(button)
		if first == null:
			first = button
	if first != null:
		first.grab_focus()
	%BackButton.pressed.connect(_on_back)


func _on_mode(mode_path: String) -> void:
	MatchSession.mode_path = mode_path
	get_tree().change_scene_to_file(BATTLE)


func _on_back() -> void:
	get_tree().change_scene_to_file(MAP_SELECT)
