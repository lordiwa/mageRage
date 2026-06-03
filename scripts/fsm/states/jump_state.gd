## Airborne state after a leap (GDD: Fire => Leap + explosive air Dash).
##
## Applies the jump impulse on enter, then air control + gravity. Offers three
## exits, each gated on the matching unlocked ability:
##   - Ice  => hold glide while descending -> GlideState
##   - Electricity => press fly -> FlightState (the game-changer)
##   - touching floor -> MoveState
## Also provides a one-shot air dash (Fire's explosive dash) on the "dash" input.
class_name JumpState extends EstadoBase

const SPEED := 220.0
const JUMP_VELOCITY := -380.0
const DASH_SPEED := 460.0
const DASH_TIME := 0.12

var _dash_used := false
var _dash_timer := 0.0

func enter() -> void:
	_dash_timer = 0.0
	# When entering from a flight toggle (not a real jump), skip the launch
	# impulse and keep the air dash spent, so toggling flight off is not a free
	# upward leap that also re-grants the dash. The flag is one-shot.
	if player.suppress_jump_impulse:
		player.suppress_jump_impulse = false
	else:
		player.velocity.y = JUMP_VELOCITY  # the leap impulse
		_dash_used = false

func physics_update(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		player.facing = signf(dir)

	# One explosive air dash (Fire). During the dash we override horizontal
	# velocity and suppress gravity briefly for a snappy, deterministic burst.
	if _dash_timer > 0.0:
		_dash_timer -= delta
		player.velocity.x = player.facing * DASH_SPEED
		player.velocity.y = 0.0
		player.move_and_slide()
		if player.is_on_floor():
			transition_to("MoveState")
		return

	if player.abilities.has("fire") and not _dash_used \
			and Input.is_action_just_pressed("dash"):
		_dash_used = true
		_dash_timer = DASH_TIME
		player.velocity.x = player.facing * DASH_SPEED
		player.velocity.y = 0.0
		player.move_and_slide()
		return

	player.velocity += player.get_gravity() * delta
	player.velocity.x = dir * SPEED
	player.move_and_slide()

	# Exits are mutually exclusive: request at most one transition per frame so
	# two requests can't race in the same physics step.
	if player.is_on_floor():
		transition_to("MoveState")
		return

	# Electricity unlock: free flight. Gated here so without electricity the
	# fly input is a no-op (ability gating).
	if player.abilities.has("electricity") and Input.is_action_just_pressed("fly"):
		transition_to("FlightState")
		return

	# Ice unlock: hold glide while descending for hang-time.
	if player.abilities.has("ice") \
			and player.velocity.y > 0.0 and Input.is_action_pressed("glide"):
		transition_to("GlideState")
