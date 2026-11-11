extends Node3D
## Battle scene (S01–S20).
##
## Assembles battlefield, mechs, the match layer, side-on camera, and HUDs.
## The flow (S20) parameterizes it through MatchSession: the player's chassis
## and the AI difficulty are chosen in the menus and applied at setup.
## Gameplay systems attach under Main as sprints add them; this node never
## implements game rules itself.

@onready var _camera: Camera3D = $Camera3D
@onready var _match: Node = $MatchController
@onready var _victory: Control = %VictoryOverlay
@onready var _result_label: Label = %ResultLabel
@onready var _rematch_button: Button = %RematchButton


func _ready() -> void:
	# Match flow (S20): the menus chose the player's chassis and difficulty.
	$Mech.definition = load(MatchSession.player_chassis)
	_match.ai_difficulty = MatchSession.ai_difficulty
	_camera.follow_target = $Mech
	_match.setup([$Mech, $DummyMech])
	_match.terrain = $Battlefield/TerrainSystem
	_rematch_button.pressed.connect(_on_rematch)
	%MenuButton.pressed.connect(_on_menu)


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
	# MatchSession persists: the reload keeps the chosen chassis/difficulty.
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
