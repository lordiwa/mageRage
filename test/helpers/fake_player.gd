## A headless stand-in for the Player used in FSM transition tests.
##
## The movement states only touch a small surface of the player: velocity,
## facing, abilities, gravity, floor query, the jump buffer, and move_and_slide.
## This fake implements exactly that surface with no physics server / rendering,
## so transition logic is unit-testable without a scene. Tests set `on_floor`
## and `abilities` directly and read back `velocity`.
class_name FakePlayer extends Node

var velocity := Vector2.ZERO
var facing := 1.0
var abilities: Dictionary = {}
## TASK-065 (DD-014): mirrors Player.shmup_mode. DEFAULTS FALSE so every existing FSM
## transition test is byte-identical; FlightState reads it to suppress its flight EXITS
## (double-tap + landing) when the shmup level sets it TRUE.
var shmup_mode := false
## TASK-067 (DD-014): mirrors Player.fly_speed_scale. DEFAULTS 1.0 (no-op) so every
## existing flight-velocity test is byte-identical; FlightState multiplies FLY_SPEED by it.
var fly_speed_scale := 1.0
var on_floor := false
var gravity := Vector2(0, 980)
## DD-008: tracks how many jumps have fired since leaving the ground. The first
## jump (Move -> Jump) sets this to 1; a second jump press in the air (with
## electricity) promotes to flight. Reset to 0 on landing.
var jump_count := 0
var _jump_buffered := false

## TASK-028 anti-magic zone: while true the hero is inside an un-purged Empire
## dampening field and the FSM must NOT enter FlightState (DD-008 double-jump is
## gated out). Defaults false so flight works exactly as before everywhere else.
var _flight_suppressed := false

func is_on_floor() -> bool:
	return on_floor

## TASK-028: the anti-magic zone toggles this on body enter/exit; the FSM reads it.
func set_flight_suppressed(value: bool) -> void:
	_flight_suppressed = value

func is_flight_suppressed() -> bool:
	return _flight_suppressed

## DD-008 double-jump support: count fired jumps and reset on landing.
func register_jump() -> void:
	jump_count += 1

func reset_jumps() -> void:
	jump_count = 0

func get_gravity() -> Vector2:
	return gravity

func move_and_slide() -> bool:
	# No physics server in unit tests; floor state is whatever the test set.
	return false

## Peek: is a jump currently buffered? Does NOT clear the buffer.
func has_buffered_jump() -> bool:
	return _jump_buffered

## Clears and returns the buffered-jump flag (call only when firing the jump).
func consume_jump_buffer() -> bool:
	if _jump_buffered:
		_jump_buffered = false
		return true
	return false

func buffer_jump() -> void:
	_jump_buffered = true
