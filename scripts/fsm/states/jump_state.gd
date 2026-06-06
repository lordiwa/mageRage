## Airborne state after a leap (GDD: Fire => Leap + explosive air Dash).
##
## Applies the jump impulse on enter, then air control + gravity. Offers three
## exits, each gated on the matching unlocked ability:
##   - Ice  => hold glide while descending -> GlideState
##   - Electricity => DD-008 DOUBLE JUMP: a SECOND jump press in the air ->
##     FlightState (the game-changer). No dedicated `fly` action.
##   - touching floor -> MoveState
##
## TASK-054: one-shot air dash (Fire's explosive dash) on the "dash" input.
## TASK-055: dash is now cooldown-REPEATABLE (replaces the one-per-airtime _dash_used
## model) and shared via DashComponent (child of Player). The air dash is suppressed
## while player.is_flight_suppressed() per DD-011.
class_name JumpState extends EstadoBase

const SPEED := 220.0
const JUMP_VELOCITY := -380.0

## TASK-055: DASH_SPEED is now owned by DashComponent. This const is KEPT for backwards
## compatibility with existing tests that reference JumpState.DASH_SPEED. It mirrors
## DashComponent.DASH_SPEED — both must stay in sync.
const DASH_SPEED := 700.0

func enter() -> void:
	player.velocity.y = JUMP_VELOCITY  # the leap impulse
	# DD-008: register this leap so a subsequent air jump press is the genuine
	# SECOND jump (-> flight). reset_jumps() runs on landing.
	player.register_jump()
	# NOTE: we do NOT reset the DashComponent cooldown on enter. The cooldown
	# persists across state transitions (shared component on the Player) so a
	# just-used dash cannot be reset by entering JumpState.

func physics_update(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	# Twin-stick: aim owns facing while a device is aiming.
	if dir != 0.0 and not player.is_aiming():
		player.facing = signf(dir)

	# Resolve the shared DashComponent and tick its timers.
	var dash := player.get_node_or_null("DashComponent") as DashComponent
	if dash != null:
		dash.update(delta)

	# --- Active air dash burst ---
	# During the burst: override velocity (via apply_burst), suppress gravity.
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
	player.velocity.x = dir * SPEED
	player.move_and_slide()

	# Exits are mutually exclusive: request at most one transition per frame so
	# two requests can't race in the same physics step.
	if player.is_on_floor():
		transition_to("MoveState")
		return

	# DD-008 double-jump -> flight. A SECOND jump press in the air (the first
	# leap already registered jump_count >= 1) promotes to flight, gated on
	# electricity. Without electricity the double-jump does nothing.
	# TASK-028 (DD-011): an Empire anti-magic field also gates it out — while the hero
	# stands in an un-purged zone flight is suppressed; cleared on exit/purge so this
	# is behavior-preserving everywhere else.
	if player.abilities.has("electricity") and player.jump_count >= 1 \
			and not player.is_flight_suppressed() \
			and InputGate.just_pressed("jump"):
		transition_to("FlightState")
		return

	# Ice unlock: hold glide while descending for hang-time.
	if player.abilities.has("ice") \
			and player.velocity.y > 0.0 and Input.is_action_pressed("glide"):
		transition_to("GlideState")
