## Twin-stick aiming: the right-stick `aim_*` actions are a JOYPAD-ONLY input
## layer (mouse aim is handled in code by cursor position, not an action). We
## assert against the live InputMap (project.godot `[input]`, loaded by the
## engine) so a missing/renamed binding is caught automatically.
##
## These are intentionally NOT in test_gamepad_bindings.gd::GAMEPAD_ACTIONS:
## that suite requires a keyboard event on every action, and these are
## joypad-only by design. Right stick in Godot 4 maps to axis 2 (X) / axis 3 (Y).
extends GutTest

## action -> [expected joypad axis, expected sign of axis_value].
const AIM_ACTIONS := {
	"aim_left": [2, -1.0],
	"aim_right": [2, 1.0],
	"aim_up": [3, -1.0],
	"aim_down": [3, 1.0],
}


func _motion_event(action: String) -> InputEventJoypadMotion:
	if not InputMap.has_action(action):
		return null
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion:
			return ev
	return null


func test_aim_actions_exist() -> void:
	for action in AIM_ACTIONS:
		assert_true(InputMap.has_action(action),
			"aim action '%s' must exist in the InputMap" % action)


func test_aim_actions_bind_correct_axis_and_sign() -> void:
	for action in AIM_ACTIONS:
		var motion := _motion_event(action)
		assert_not_null(motion,
			"aim action '%s' must have an InputEventJoypadMotion" % action)
		if motion == null:
			continue
		var expected_axis: int = AIM_ACTIONS[action][0]
		var expected_sign: float = AIM_ACTIONS[action][1]
		assert_eq(motion.axis, expected_axis,
			"aim action '%s' must bind joypad axis %d (right stick)" % [action, expected_axis])
		assert_eq(signf(motion.axis_value), expected_sign,
			"aim action '%s' must have axis_value sign %s" % [action, expected_sign])


func test_aim_actions_have_a_reasonable_deadzone() -> void:
	# Right-stick aim wants a deadzone around 0.3 (matches the move sticks).
	for action in AIM_ACTIONS:
		var dz := InputMap.action_get_deadzone(action)
		assert_almost_eq(dz, 0.3, 0.01,
			"aim action '%s' should use a ~0.3 deadzone" % action)


func test_aim_actions_are_joypad_only() -> void:
	# Mouse aim is handled in code (cursor position), so these actions must NOT
	# carry keyboard/mouse events — they are joypad-only by design.
	for action in AIM_ACTIONS:
		for ev in InputMap.action_get_events(action):
			assert_false(ev is InputEventKey or ev is InputEventMouseButton,
				"aim action '%s' must be joypad-only (no keyboard/mouse event)" % action)
