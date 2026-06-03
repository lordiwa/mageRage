## Glide state (GDD: Ice => Glide / hang-time).
##
## Clamps descent speed so the hero floats across long horizontal chasms while
## the glide input is held. Releasing glide drops back to JumpState (normal
## fall); pressing fly (with Electricity) promotes to FlightState; landing
## returns to MoveState.
class_name GlideState extends EstadoBase

const SPEED := 240.0
const MAX_FALL := 60.0      # clamp descent for the floaty glide feel

func physics_update(delta: float) -> void:
	player.velocity += player.get_gravity() * delta
	player.velocity.y = minf(player.velocity.y, MAX_FALL)

	var dir := Input.get_axis("move_left", "move_right")
	player.velocity.x = dir * SPEED
	if dir != 0.0:
		player.facing = signf(dir)
	player.move_and_slide()

	if not Input.is_action_pressed("glide"):
		transition_to("JumpState")
	if player.abilities.has("electricity") and Input.is_action_just_pressed("fly"):
		transition_to("FlightState")
	if player.is_on_floor():
		transition_to("MoveState")
