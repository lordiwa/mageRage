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
var _jump_buffered := false

func is_on_floor() -> bool:
	return on_floor

func get_gravity() -> Vector2:
	return gravity

func move_and_slide() -> bool:
	# No physics server in unit tests; floor state is whatever the test set.
	return false

func consume_jump_buffer() -> bool:
	if _jump_buffered:
		_jump_buffered = false
		return true
	return false

func buffer_jump() -> void:
	_jump_buffered = true
