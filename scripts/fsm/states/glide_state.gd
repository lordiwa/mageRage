## Glide state (GDD: Ice => Glide / hang-time).
##
## Clamps descent speed so the hero floats across long horizontal chasms while
## the glide input is held. Releasing glide drops back to JumpState (normal
## fall); DD-008 double-jump (a second jump press, with Electricity) promotes to
## FlightState; landing returns to MoveState.
##
## TASK-055: an air dash (Fire's explosive horizontal burst) is now available in
## GlideState via the shared DashComponent on the Player. The burst suppresses the
## glide descent momentarily (velocity.y=0 for DASH_TIME), then normal glide resumes.
## Air dash is suppressed while is_flight_suppressed() per DD-011.
class_name GlideState extends EstadoBase

const SPEED := 240.0
const MAX_FALL := 60.0      # clamp descent for the floaty glide feel

func physics_update(delta: float) -> void:
	# Resolve the shared DashComponent and tick its timers.
	var dash := player.get_node_or_null("DashComponent") as DashComponent
	if dash != null:
		dash.update(delta)

	# --- Active air dash burst (during the burst: override velocity, skip glide physics) ---
	if dash != null and dash.is_dashing():
		dash.apply_burst(player)
		player.move_and_slide()
		if player.is_on_floor():
			transition_to("MoveState")
		return

	# --- Trigger a new air dash ---
	# try_air_dash checks: cooldown + fire gate + input edge + suppression (DD-011).
	if dash != null and dash.try_air_dash(player):
		player.move_and_slide()
		return

	player.velocity += player.get_gravity() * delta
	player.velocity.y = minf(player.velocity.y, MAX_FALL)

	var dir := Input.get_axis("move_left", "move_right")
	player.velocity.x = dir * SPEED
	# Twin-stick: aim owns facing while a device is aiming.
	if dir != 0.0 and not player.is_aiming():
		player.facing = signf(dir)
	player.move_and_slide()

	# Exits are mutually exclusive: at most one transition request per frame.
	if player.is_on_floor():
		transition_to("MoveState")
		return
	# DD-008 double-jump -> flight (electricity-gated). A second jump press while
	# gliding promotes to flight; without electricity it does nothing. TASK-028
	# (DD-011): also gated out while inside an un-purged anti-magic field.
	if player.abilities.has("electricity") and player.jump_count >= 1 \
			and not player.is_flight_suppressed() \
			and InputGate.just_pressed("jump"):
		transition_to("FlightState")
		return
	if not Input.is_action_pressed("glide"):
		transition_to("JumpState")
