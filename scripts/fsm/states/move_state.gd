## Grounded state: run, fall off ledges, initiate a jump (GDD: Fire => Leap).
##
## Carries coyote time so a jump pressed shortly after walking off a ledge still
## fires, and consumes the Player's jump buffer so a jump pressed just before
## landing fires on touchdown. Jump is gated on the "fire" ability per the
## movement = mastery progression, but in the demo all abilities are pre-unlocked.
class_name MoveState extends EstadoBase

const SPEED := 220.0
const COYOTE_TIME := 0.10

var _coyote := 0.0

func enter() -> void:
	# Fresh grace window each time we (re)enter the grounded state.
	_coyote = COYOTE_TIME

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity += player.get_gravity() * delta
		_coyote -= delta
	else:
		_coyote = COYOTE_TIME

	var dir := Input.get_axis("move_left", "move_right")
	player.velocity.x = dir * SPEED
	if dir != 0.0:
		player.facing = signf(dir)
	player.move_and_slide()

	# Buffered jump: Player records "jump pressed" for a short window; we fire it
	# as soon as we are within coyote grace. Fire unlock gates the leap.
	if player.abilities.has("fire") and player.consume_jump_buffer() and _coyote > 0.0:
		transition_to("JumpState")
