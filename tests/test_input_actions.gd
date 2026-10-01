extends "res://tests/test_base.gd"
## Enforces the architecture.md §18 contract: every gameplay action exists in
## the InputMap and is bound to BOTH a keyboard event and a gamepad event.
## Adding an action with only one device's binding must fail CI.

const REQUIRED_ACTIONS := [
	"move_left", "move_right", "jump", "dash", "aim_up",
	"aim_down", "fire", "cycle_weapon", "use_ability", "end_turn", "pause",
]


func test_all_required_actions_exist() -> void:
	for action in REQUIRED_ACTIONS:
		assert_true(InputMap.has_action(action), "action '%s' is registered" % action)


func test_every_action_has_keyboard_and_gamepad_binding() -> void:
	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var has_key := false
		var has_pad := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				has_key = true
			elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_pad = true
		assert_true(has_key, "'%s' has a keyboard binding" % action)
		assert_true(has_pad, "'%s' has a gamepad binding" % action)


func test_actions_have_configured_deadzone() -> void:
	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			continue
		assert_true(InputMap.action_get_deadzone(action) > 0.0,
				"'%s' has a nonzero deadzone" % action)
