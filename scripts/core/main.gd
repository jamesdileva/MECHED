extends Node3D
## Battle scene (S01–S21).
##
## Assembles battlefield, mechs, the match layer, side-on camera, and HUDs.
## The flow (S20/S21) parameterizes it through MatchSession: the player's
## chassis, AI difficulty, and map are chosen in the menus and applied at
## setup. Gameplay systems attach under Main as sprints add them; this node
## never implements game rules itself.

@onready var _camera: Camera3D = $Camera3D
@onready var _match: Node = $MatchController
@onready var _victory: Control = %VictoryOverlay
@onready var _result_label: Label = %ResultLabel
@onready var _rematch_button: Button = %RematchButton


func _ready() -> void:
	# Match flow (S20/S21): the menus chose the player's chassis, difficulty,
	# and battlefield.
	$Mech.definition = load(MatchSession.player_chassis)
	_match.ai_difficulty = MatchSession.ai_difficulty
	var map_definition: Resource = load(MatchSession.map_path)
	_match.map_definition = map_definition
	$Battlefield/TerrainSystem.map_definition = map_definition
	_apply_map_spawns(map_definition)
	_camera.follow_target = $Mech
	_match.setup([$Mech, $DummyMech])
	_match.terrain = $Battlefield/TerrainSystem
	_rematch_button.pressed.connect(_on_rematch)
	%MenuButton.pressed.connect(_on_menu)


## Spawns come from the map (S21): positions and respawn points for both
## mechs, plus map-driven movement bounds.
func _apply_map_spawns(map_definition: Resource) -> void:
	if map_definition.spawn_points.size() >= 2:
		$Mech.position = map_definition.spawn_points[0]
		$Mech.respawn_point = map_definition.spawn_points[0]
		$DummyMech.position = map_definition.spawn_points[1]
		$DummyMech.respawn_point = map_definition.spawn_points[1]
	for mech in [$Mech, $DummyMech]:
		mech.apply_map_bounds(map_definition)


func _process(_delta: float) -> void:
	if _match == null or _match.turn_manager == null:
		return
	# Victory/defeat overlay (S20): shows once when the match ends, then
	# grabs focus so REMATCH / MAIN MENU are controller-navigable.
	if _match.turn_manager.state.match_result != &"" and not _victory.visible:
		var winner: String = _match.turn_manager.state.winner
		_result_label.text = "VICTORY" \
				if winner == String($Mech.display_name()) else "DEFEAT"
		_victory.visible = true
		_rematch_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	# Debug tooling (implementation-guide §17) uses raw keys on purpose —
	# it is developer-only and outside the device-agnostic action contract.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1:
			for mech in get_tree().get_nodes_in_group("mech"):
				mech.respawn()
		elif event.physical_keycode == KEY_F3:
			# Hide the debug HUD to read the fight from the combat UI alone.
			$DebugHUD.visible = not $DebugHUD.visible


func _on_rematch() -> void:
	# MatchSession persists: the reload keeps the chosen chassis/difficulty/map.
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
