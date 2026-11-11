extends Control
## Main menu (S20 match flow): FIGHT opens mech select; QUIT exits.
## Controller-navigable: the first button grabs focus and the default ui_*
## joypad bindings walk the buttons.

const MECH_SELECT := "res://scenes/menus/mech_select.tscn"


func _ready() -> void:
	%FightButton.pressed.connect(_on_fight)
	%QuitButton.pressed.connect(func(): get_tree().quit())
	%FightButton.grab_focus()


func _on_fight() -> void:
	get_tree().change_scene_to_file(MECH_SELECT)
