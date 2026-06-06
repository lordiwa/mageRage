## Grounded state: run, fall off ledges, initiate a jump, ground dash (GDD: Fire => Leap + Dash).
##
## Carries coyote time so a jump pressed shortly after walking off a ledge still
## fires, and consumes the Player's jump buffer so a jump pressed just before
## landing fires on touchdown. Jump is gated on the "fire" ability per the
## movement = mastery progression, but in the demo all abilities are pre-unlocked.
##
## TASK-054: ground dash — while grounded + Fire unlocked + dash just_pressed ->
## a burst at DashComponent.DASH_SPEED in the facing direction for DashComponent.DASH_TIME.
## Gravity is suppressed during the burst. A cooldown (DashComponent.DASH_COOLDOWN)
## prevents spamming; it is repeatable after the cooldown elapses.
##
## TASK-055: dash logic is now owned by DashComponent (child of Player). This removes
## the per-state constant duplication and makes the cooldown SHARED across all states.
## The ground dash is NOT suppressed by is_flight_suppressed() (only air dashes are).
class_name MoveState extends EstadoBase

const SPEED := 220.0
const COYOTE_TIME := 0.10

var _coyote := 0.0

func enter() -> void:
	# Fresh grace window each time we (re)enter the grounded state.
	_coyote = COYOTE_TIME
	# Note: we do NOT reset the DashComponent cooldown on enter — the cooldown persists
	# through brief airtime (e.g. coyote frames) so a player cannot reset it by brushing
	# a ledge. The component owns its own timer state.

func physics_update(delta: float) -> void:
	# Resolve the shared DashComponent (single source of dash truth).
	var dash := player.get_node_or_null("DashComponent") as DashComponent

	# Tick the dash timers this frame.
	if dash != null:
		dash.update(delta)

	if not player.is_on_floor():
		player.velocity += player.get_gravity() * delta
		_coyote -= delta
	else:
		_coyote = COYOTE_TIME
		# DD-008: grounded -> reset the double-jump counter for the next airtime.
		player.reset_jumps()

	# --- Active dash burst ---
	# During the burst: override horizontal velocity, suppress gravity, then fall
	# through to the jump-buffer check so a jump can still cancel the dash.
	if dash != null and dash.is_dashing():
		dash.apply_burst(player)
		player.move_and_slide()
		# Jump-cancel: a buffered jump during the ground dash still transitions.
		if player.abilities.has("fire") and _coyote > 0.0 and player.has_buffered_jump():
			player.consume_jump_buffer()
			transition_to("JumpState")
		return

	# --- Trigger a new ground dash ---
	# try_ground_dash handles: cooldown check + fire gate + input edge + sets velocity.
	# The ground dash is NOT suppressed by is_flight_suppressed() (only air dashes are,
	# per DD-011 safety reasoning — the barrier is aerial, not ground-level).
	if dash != null and dash.try_ground_dash(player):
		player.move_and_slide()
		# Still allow jump-cancel on the dash trigger frame.
		if player.abilities.has("fire") and _coyote > 0.0 and player.has_buffered_jump():
			player.consume_jump_buffer()
			transition_to("JumpState")
		return

	var dir := Input.get_axis("move_left", "move_right")
	player.velocity.x = dir * SPEED
	# Twin-stick: while aiming, the aim owns facing — don't let movement override it.
	if dir != 0.0 and not player.is_aiming():
		player.facing = signf(dir)
	player.move_and_slide()

	# Buffered jump: the Player records "jump pressed" for a short window. We must
	# only CONSUME the buffer on the frame the jump actually fires, otherwise a
	# press made while falling (coyote already 0) would be cleared every frame and
	# the buffered jump would be lost before landing. So: check the floor/coyote
	# condition FIRST (peek, don't clear), then consume when we commit. On the
	# landing frame is_on_floor() re-seeds _coyote above, so a jump buffered in
	# mid-air fires on touchdown. Fire unlock gates the leap.
	if player.abilities.has("fire") and _coyote > 0.0 and player.has_buffered_jump():
		player.consume_jump_buffer()
		transition_to("JumpState")
