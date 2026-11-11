extends Control
## Mech select (S20): the four chassis as focusable buttons with a data-driven
## detail panel, plus the AI difficulty cycle. Controller-navigable (vertical
## button list, first button focused on entry).

const MECH_SELECT_ENTRIES: Array = [
	"res://data/mechs/standard_mech.tres",
	"res://data/mechs/strider.tres",
	"res://data/mechs/wraith.tres",
	"res://data/mechs/bastion.tres",
]
const DIFFICULTIES: Array = ["Easy", "Normal", "Hard", "Expert"]
const MAIN_MENU := "res://scenes/menus/main_menu.tscn"
const MAP_SELECT := "res://scenes/menus/map_select.tscn"

var _difficulty_slot := 1  # Normal


func _ready() -> void:
	for path in MECH_SELECT_ENTRIES:
		var def: Resource = load(path)
		var button := Button.new()
		button.text = String(def.display_name).to_upper()
		button.custom_minimum_size = Vector2(0, 40)
		button.focus_entered.connect(_show_detail.bind(def))
		button.pressed.connect(_on_chosen.bind(path))
		%ChassisButtons.add_child(button)
	_difficulty_slot = DIFFICULTIES.find(MatchSession.ai_difficulty)
	if _difficulty_slot < 0:
		_difficulty_slot = 1
	%DifficultyButton.text = "AI DIFFICULTY: %s" % DIFFICULTIES[_difficulty_slot].to_upper()
	%DifficultyButton.pressed.connect(_on_difficulty)
	%BackButton.pressed.connect(_on_back)
	var first: Button = %ChassisButtons.get_child(0)
	_show_detail(load(MECH_SELECT_ENTRIES[0]))
	first.grab_focus()


func _show_detail(def: Resource) -> void:
	var lines: Array = [
		"HP %d    MASS %.1f    SPEED %.0f m/s" % [def.max_health, def.mass, def.max_speed],
	]
	var gadgets: Array = []
	if def.dash_speed > 0.0:
		gadgets.append("DASH")
	if def.jetpack_fuel > 0.0:
		gadgets.append("JETPACK")
	if def.weapon_modifier != null:
		for transformation in def.weapon_modifier.transformations:
			gadgets.append("%s -> %s" % [transformation.base_weapon, transformation.display_name])
	if gadgets.is_empty():
		lines.append("No special equipment")
	else:
		lines.append(" · ".join(gadgets))
	%DetailLabel.text = "\n".join(lines)


func _on_chosen(path: String) -> void:
	MatchSession.player_chassis = path
	get_tree().change_scene_to_file(MAP_SELECT)


func _on_difficulty() -> void:
	_difficulty_slot = (_difficulty_slot + 1) % DIFFICULTIES.size()
	MatchSession.ai_difficulty = DIFFICULTIES[_difficulty_slot]
	%DifficultyButton.text = "AI DIFFICULTY: %s" % DIFFICULTIES[_difficulty_slot].to_upper()


func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
