## TASK-007: gamepad/controller support is an INPUT-BINDING layer (additive over
## keyboard/mouse). This suite is the load-bearing guard for it: every gameplay
## action must carry at least one joypad event (button OR motion) so a controller
## can drive it. We assert against the live InputMap (the project.godot `[input]`
## section, loaded by the engine), via InputMap.action_get_events(action), rather
## than parsing the file — so it catches a missing/renamed binding automatically.
##
## Per docs/DECISIONES-DISENO.md DD-008 the gamepad is the primary control scheme;
## this does NOT touch movement/FSM/combat behavior, only that the bindings exist.
## DD-008 dropped `fly`/`element_cycle`/`cast` and added `cast_primary`/`cast_secondary`.
extends GutTest

## Every gameplay action that must be controller-drivable (DD-008 scheme).
const GAMEPAD_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "dash", "glide", "cast_primary", "cast_secondary",
	"element_1", "element_2", "element_3",
]

## Actions removed by DD-008 that must NOT linger in the InputMap.
const REMOVED_ACTIONS := ["fly", "element_cycle", "cast"]


func _has_joypad_event(action: String) -> bool:
	if not InputMap.has_action(action):
		return false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			return true
	return false


# --- Per-action checks (one failing assert names the missing binding) -------

func test_each_gameplay_action_has_a_joypad_binding() -> void:
	for action in GAMEPAD_ACTIONS:
		assert_true(InputMap.has_action(action),
			"action '%s' must exist in the InputMap" % action)
		assert_true(_has_joypad_event(action),
			"action '%s' must have a joypad event (button or motion) for gamepad support" % action)


# --- Keyboard parity: gamepad support is ADDITIVE, not a replacement --------

func test_keyboard_events_are_preserved() -> void:
	# Sanity that we did not drop keyboard bindings while adding joypad ones.
	for action in GAMEPAD_ACTIONS:
		var has_key := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey or ev is InputEventMouseButton:
				has_key = true
				break
		assert_true(has_key,
			"action '%s' must keep its keyboard/mouse event (additive support)" % action)


# --- DD-008 removed the old actions --------------------------------------

func test_superseded_actions_are_removed() -> void:
	for action in REMOVED_ACTIONS:
		assert_false(InputMap.has_action(action),
			"DD-008 removed action '%s'; it must not remain in the InputMap" % action)
