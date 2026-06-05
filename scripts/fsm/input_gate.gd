## Thin, behavior-preserving indirection for the FSM's edge-triggered input reads.
##
## In game this delegates 1:1 to Input.is_action_just_pressed(action) — the
## runtime behavior is byte-identical to calling Input directly. Its ONLY reason
## to exist is test determinism: headless GUT cannot make Input.is_action_just_pressed()
## deterministic once any upstream test awaits a physics frame (the engine's
## physics-frame counter advances past where a programmatic Input.action_press()
## stamps its "just pressed" edge, so the read always returns false for the rest
## of the run). The movement-FSM transition tests gate jump->flight / air-dash on
## that edge, which made them green locally but RED on the slower CI runner with
## "Signals emitted: []". Tests set a deterministic override via set_test_override()
## (cleared in after_each); production never touches it.
class_name InputGate extends RefCounted

## Per-action override of the "just pressed" edge, keyed by action name. Null entries
## fall through to the real Input. Only tests populate this.
static var _overrides: Dictionary = {}


## True when `action` fired its just-pressed edge this frame. Returns the test
## override when one is set for the action; otherwise the real engine reading.
static func just_pressed(action: String) -> bool:
	if _overrides.has(action):
		return _overrides[action]
	return Input.is_action_just_pressed(action)


## True while `action` is HELD this frame (hold-to-fire reads cadence triggers
## through here). Returns the test override when set; otherwise the real engine
## reading. TASK-038: same seam as just_pressed so held-input tests stay deterministic
## under cross-script physics-frame poisoning.
static func pressed(action: String) -> bool:
	if _overrides.has(action):
		return _overrides[action]
	return Input.is_action_pressed(action)


## TEST ONLY: force `just_pressed(action)` / `pressed(action)` to return `value`
## deterministically.
static func set_test_override(action: String, value: bool) -> void:
	_overrides[action] = value


## TEST ONLY: drop all overrides so reads fall back to the real Input. Call from
## a test's after_each so overrides never leak across tests or into the game.
static func clear_test_overrides() -> void:
	_overrides.clear()
