## The hero CharacterBody2D. Owns shared movement state (abilities, facing, jump
## buffer); the per-state movement logic lives in the FSM children. Collision is
## set up per GDD 5.C: the hero IS on the Player layer and detects Environment +
## Enemies.
##
## In this movement demo all traversal abilities are pre-unlocked so every verb
## (run / leap / dash / glide / flight) is immediately usable.
class_name Player extends CharacterBody2D

const JUMP_BUFFER := 0.10      # grace window before landing for a buffered jump

## Unlocked elements. Each gates a movement verb in the FSM:
## fire -> leap+dash, ice -> glide, electricity -> flight.
@export var abilities: Dictionary = {"fire": true, "ice": true, "electricity": true}

## -1 = facing left, +1 = facing right. Used by air dash for its burst direction.
var facing := 1.0

## One-shot: when true, the next JumpState entry skips the launch impulse + dash
## reset. Set by FlightState when toggling flight off so leaving flight does not
## grant a free upward leap (and re-grant the air dash).
var suppress_jump_impulse := false

var _jump_buffer := 0.0

func _ready() -> void:
	# GDD 5.C: I am Player; I collide with Environment and Enemies.
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(3, true)

func _process(delta: float) -> void:
	# Record a jump press into the buffer regardless of which state is active,
	# so a press just before landing still fires (consumed by MoveState).
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)

## Peek: is a jump currently buffered? Does NOT clear the buffer, so a state can
## check the floor/coyote condition before committing to fire.
func has_buffered_jump() -> bool:
	return _jump_buffer > 0.0

## Returns true once if a jump was buffered, clearing it. Call only when the jump
## actually fires.
func consume_jump_buffer() -> bool:
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		return true
	return false
