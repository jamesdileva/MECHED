extends Control
## Map select (S20/S21): the buttons are data-driven from the map list —
## each entry is a MapDefinition resource; the same match system loads any
## of them without code changes (roadmap verification).

const BATTLE := "res://scenes/main/main.tscn"
const MECH_SELECT := "res://scenes/menus/mech_select.tscn"

const MAPS: Array = [
	"res://data/maps/canyon.tres",
	"res://data/maps/floating_islands.tres",
	"res://data/maps/industrial_ruins.tres",
]


func _ready() -> void:
	var first: Button = null
	for path in MAPS:
		var map: Resource = load(path)
		var button := Button.new()
		button.text = String(map.display_name).to_upper()
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(_on_map.bind(path))
		%MapButtons.add_child(button)
		if first == null:
			first = button
	first.grab_focus()
	%BackButton.pressed.connect(_on_back)


func _on_map(map_path: String) -> void:
	MatchSession.map_path = map_path
	get_tree().change_scene_to_file(BATTLE)


func _on_back() -> void:
	get_tree().change_scene_to_file(MECH_SELECT)

