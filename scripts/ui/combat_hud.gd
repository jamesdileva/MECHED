extends CanvasLayer
## Player-facing combat HUD (S19) — everything needed to read the fight
## without the debug HUD (F3 toggles that one). Presentation only: reads
## MatchState through the match-controller group plus the player mech node.
## Ability cooldowns arrive with S23's cooldown-bearing abilities; current
## abilities are shown as state (the ANCHORED badge).

@onready var _turn_label: Label = %TurnLabel
@onready var _timer_bar: ProgressBar = %TimerBar
@onready var _wind_label: Label = %WindLabel
@onready var _player_name: Label = %PlayerName
@onready var _hp_bar: ProgressBar = %HPBar
@onready var _energy_bar: ProgressBar = %EnergyBar
@onready var _fuel_bar: ProgressBar = %FuelBar
@onready var _weapon_label: Label = %WeaponLabel
@onready var _aim_label: Label = %AimLabel
@onready var _anchor_label: Label = %AnchorLabel
@onready var _enemy_name: Label = %EnemyName
@onready var _enemy_hp_bar: ProgressBar = %EnemyHPBar


func _process(_delta: float) -> void:
	var mc: Node = get_tree().get_first_node_in_group("match_controller")
	if mc == null or mc.turn_manager == null or not mc.turn_manager.state.started \
			or mc.entities.is_empty():
		visible = false
		return
	visible = true
	var s = mc.turn_manager.state
	var player: Node = mc.entities[mc.player_index]
	var enemy: Node = mc.entities[1 - mc.player_index] \
			if mc.entities.size() > 1 else null

	_turn_label.text = _turn_text(mc, s)
	_timer_bar.max_value = mc.turn_manager.TURN_TIME
	_timer_bar.value = maxf(s.turn_time_left, 0.0)
	_wind_label.text = "WIND %s %.1f" % [mc.wind_arrow(s.wind), s.wind.length()]

	var player_name := String(player.display_name())
	_player_name.text = "%s  %d/%d" % [player_name,
			int(s.entity_health(player_name)), int(s.entity_max_health(player_name))]
	_hp_bar.max_value = s.entity_max_health(player_name)
	_hp_bar.value = s.entity_health(player_name)
	_energy_bar.max_value = mc.turn_manager.ENERGY_PER_TURN
	_energy_bar.value = s.movement_energy_left
	var fuel_max: float = s.fuel_max.get(player_name, 0.0)
	_fuel_bar.visible = fuel_max > 0.0
	_fuel_bar.max_value = fuel_max
	_fuel_bar.value = s.entity_fuel(player_name)
	_weapon_label.text = "[%s]" % _weapon_label_text(player, s)
	_aim_label.text = "AIM %.0f°   POWER %.0f%%" % [player.aim_angle, player.charge * 100.0]
	_anchor_label.visible = player.anchored

	if enemy != null:
		var enemy_name := String(enemy.display_name())
		_enemy_name.text = "%s  %d/%d" % [enemy_name,
				int(s.entity_health(enemy_name)), int(s.entity_max_health(enemy_name))]
		_enemy_hp_bar.max_value = s.entity_max_health(enemy_name)
		_enemy_hp_bar.value = s.entity_health(enemy_name)


func _turn_text(mc, s) -> String:
	if s.match_result != &"":
		return String(s.match_result)
	if s.is_resolving():
		return "TURN %d — RESOLVING" % s.turn_number
	if s.is_active(mc.player_index):
		return "TURN %d — YOUR TURN (%s)" % [s.turn_number, s.active_entity_name()]
	return "TURN %d — ENEMY TURN (%s)" % [s.turn_number, s.active_entity_name()]


## Armed weapon with its transformation name (Rocket -> Siege/Split/Guided).
func _weapon_label_text(player: Node, s) -> String:
	var weapon = s.active_weapon(String(player.display_name()))
	if weapon == null:
		return "—"
	if player.definition != null and player.definition.weapon_modifier != null:
		var transformation = player.definition.weapon_modifier.transformation_for(
				weapon.display_name)
		if transformation != null:
			return transformation.display_name
	return weapon.display_name
