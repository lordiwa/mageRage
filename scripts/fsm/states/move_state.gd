## Grounded state: run, fall off ledges, initiate a jump, ground dash (GDD: Fire => Leap + Dash).
##
## Carries coyote time so a jump pressed shortly after walking off a ledge still
## fires, and consumes the Player's jump buffer so a jump pressed just before
## landing fires on touchdown. Jump is gated on the "fire" ability per the
## movement = mastery progression, but in the demo all abilities are pre-unlocked.
##
## TASK-054: ground dash — while grounded + Fire unlocked, InputGate.just_pressed("dash")
## starts a burst at DASH_SPEED in the facing direction for DASH_TIME. Gravity is
## suppressed during the burst. A cooldown (DASH_COOLDOWN) prevents spamming; it is
## repeatable after the cooldown elapses.
##
## NOTE: DASH_SPEED and DASH_TIME mirror JumpState's constants — keep both in sync.
## If the air-dash tuning changes, update both files.
class_name MoveState extends EstadoBase

const SPEED := 220.0
const COYOTE_TIME := 0.10

## Ground dash — mirrors JumpState (keep in sync with JumpState.DASH_SPEED / DASH_TIME).
const DASH_SPEED := 460.0
const DASH_TIME := 0.12
## Anti-spam cooldown for the ground dash (MoveState is persistent on the ground,
## so one-per-airtime cannot apply). Provisional; tunable in playtest (DD-001).
const DASH_COOLDOWN := 0.35

var _coyote := 0.0
var _dash_timer := 0.0      # > 0 while the burst is active
var _dash_cooldown := 0.0   # > 0 while the re-dash is blocked

func enter() -> void:
	# Fresh grace window each time we (re)enter the grounded state.
	_coyote = COYOTE_TIME
	# Note: we do NOT reset _dash_cooldown on enter — the cooldown persists through
	# brief airtime (e.g. coyote frames) so a player cannot reset it by brushing a ledge.

func physics_update(delta: float) -> void:
	# Tick cooldown timers every frame regardless of floor state.
	if _dash_timer > 0.0:
		_dash_timer -= delta
	if _dash_cooldown > 0.0:
		_dash_cooldown -= delta

	if not player.is_on_floor():
		player.velocity += player.get_gravity() * delta
		_coyote -= delta
	else:
		_coyote = COYOTE_TIME
		# DD-008: grounded -> reset the double-jump counter for the next airtime.
		player.reset_jumps()

	# --- Ground dash burst (TASK-054) ---
	# During the active burst: override horizontal velocity, suppress gravity,
	# then fall through to the jump-buffer check so a jump still cancels the dash.
	if _dash_timer > 0.0:
		player.velocity.x = player.facing * DASH_SPEED
		player.velocity.y = 0.0
		player.move_and_slide()
		# Jump-cancel check below handles JumpState transition; return here to skip
		# the normal run logic but still allow the jump buffer to fire.
		# Fall through to buffered-jump guard at the bottom.
		if player.abilities.has("fire") and _coyote > 0.0 and player.has_buffered_jump():
			player.consume_jump_buffer()
			transition_to("JumpState")
		return

	# --- Trigger a new ground dash ---
	if player.abilities.has("fire") and _dash_cooldown <= 0.0 \
			and InputGate.just_pressed("dash"):
		_dash_timer = DASH_TIME
		_dash_cooldown = DASH_COOLDOWN
		player.velocity.x = player.facing * DASH_SPEED
		player.velocity.y = 0.0
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
