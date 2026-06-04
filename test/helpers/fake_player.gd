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
var on_floor := false
var gravity := Vector2(0, 980)
## DD-008: tracks how many jumps have fired since leaving the ground. The first
## jump (Move -> Jump) sets this to 1; a second jump press in the air (with
## electricity) promotes to flight. Reset to 0 on landing.
var jump_count := 0
var _jump_buffered := false

func is_on_floor() -> bool:
	return on_floor

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
