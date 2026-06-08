## Free flight state (GDD: Electricity => Levitation / true 8-directional flight).
##
## Gravity is ignored: the hero moves under pure directional input. This state is
## only reachable through the electricity-gated DOUBLE-JUMP transitions in
## JumpState / GlideState, so it needs no "am I unlocked?" flag of its own.
## DD-008: flight ends on landing OR on a deliberate double-tap of JUMP
## (TASK-062 — see DOUBLE_TAP_WINDOW below); there is no single-press toggle-out.
##
## TASK-055: an air dash (Fire's horizontal burst) is now available in FlightState
## via the shared DashComponent on the Player. The burst overrides the free-flight
## velocity for DASH_TIME (velocity.y=0, horizontal only). Air dash is suppressed
## while is_flight_suppressed() — but note that FlightState itself already drops to
## MoveState when suppressed, so the dash-suppression guard in try_air_dash is a
## belt-and-suspenders safety. The two guards are independent; both must hold.
class_name FlightState extends EstadoBase

const FLY_SPEED := 260.0

## TASK-062 (extends DD-008): a double-tap of JUMP while flying is a deliberate
## "stop flying" control. Two CLEAN JUMP taps within this window drop the hero to
## MoveState (a pure fall — same target as the landing exit), so gravity returns
## and the hero lands into platformer movement. Tunable/unit-testable constant.
const DOUBLE_TAP_WINDOW := 0.30

## TASK-068 (regression fix): a brief grace right after entering flight during
## which JUMP edges are IGNORED for exit detection. The hero ENTERS flight via a
## double-jump (two rapid JUMP presses in JumpState), and Input.is_action_just_pressed
## can latch true across MULTIPLE physics frames within one render frame; without
## this grace those entry presses bled straight into the exit detector and dropped
## the hero back to MoveState the instant flight began ("ya no puede volar").
## Tunable/unit-testable constant.
const ENTRY_GRACE := 0.25

## True once a first CLEAN in-flight JUMP tap is seen and we are waiting for a
## second within DOUBLE_TAP_WINDOW. Reset in enter() so each flight starts clean.
var _jump_tap_pending := false
## Seconds elapsed since the pending first tap; when it exceeds the window the
## pending tap is dropped so a later lone press starts a fresh count.
var _tap_window_elapsed := 0.0
## TASK-068 entry grace countdown (seconds). While > 0 the exit detector is fully
## skipped. Seeded in enter() and ticked down every physics frame.
var _entry_grace := 0.0
## TASK-068 release-gating: jump-held state observed on the PREVIOUS physics frame
## (via InputGate.pressed). A tap only counts when this is false (a rising edge
## that follows a release), so a held/latched single press can never count twice.
var _jump_was_down := false
## TASK-068 release-gating: the detector is ARMED only after JUMP has been observed
## RELEASED at least once since entering flight (after grace), so the entry hold/
## latch fully clears before any tap can count toward the exit.
var _exit_armed := false

func enter() -> void:
	player.velocity = Vector2.ZERO
	# TASK-062: a fresh flight has no pending tap (e.g. the entry double-jump
	# press in JumpState must not be mistaken for the first half of an exit tap).
	_jump_tap_pending = false
	_tap_window_elapsed = 0.0
	# TASK-068: start the entry grace and reset release-gating so the entry
	# double-jump (and any multi-frame just_pressed latch) cannot drop the hero.
	_entry_grace = ENTRY_GRACE
	# Assume jump may still be held from the entry press; require an observed
	# release before the detector arms.
	_jump_was_down = true
	_exit_armed = false

func physics_update(delta: float) -> void:
	# TASK-028 (DD-011) — SUSTAIN gate. Gating only the entry edge let a hero who was
	# ALREADY FLYING on entry coast through an un-purged anti-magic field (skipping the
	# purge). Re-read the flag every physics frame: while suppressed, drop OUT of flight
	# so the hero FALLS and becomes grounded inside the field. We drop to MoveState — NOT
	# JumpState, whose enter() applies a fresh upward launch impulse (-380) that would
	# re-loft a high-altitude entrant over the barrier un-purged (review HIGH). MoveState
	# applies gravity when airborne (a pure fall, no impulse). Synchronous (plain bool, no
	# await). The flag defaults false, so flight outside a zone is unaffected — DD-008
	# preserved. (We exit here, not in enter(), to avoid mutating the machine
	# mid-activation; the drop fires on the first physics frame.)
	if player.is_flight_suppressed():
		transition_to("MoveState")
		return

	# TASK-065 (DD-014): per-level shmup scoping. In the auto-scroll shmup the hero is
	# ALWAYS flying — dropping out (double-tap OR landing) means falling off-screen = an
	# accidental death. So when player.shmup_mode is set we SKIP the ENTIRE stop-flight
	# detector below (and the landing exit further down) and keep the hero in FlightState.
	# The flag defaults FALSE, so for the sectors the TASK-068 grace + release-gated
	# double-tap detector runs exactly as on master (byte-identical). We still ran the
	# DD-011 suppression exit above (untouched): the shmup has no anti-magic zones, so that
	# guard is inert here, and leaving it alone keeps the sector contract intact. When
	# shmup_mode is true the detector never runs, so its grace/release state simply stays
	# at its enter()-seeded values — harmless, since nothing reads it while skipped.
	if not _is_shmup_mode():
		# TASK-062 (extends DD-008) + TASK-068 (regression fix): GRACE + RELEASE-GATED
		# double-tap JUMP to stop flying. A second CLEAN tap within DOUBLE_TAP_WINDOW
		# drops to MoveState — a PURE FALL, the same target as the landing exit, never
		# a re-launch (JumpState.enter would add a fresh upward impulse). This only ever
		# REMOVES flight: it cannot grant traversal, so it can never bypass a gate
		# (anti-magic zone / FIRE gate / boss flight gap).
		#
		# Read BOTH the rising edge (just_pressed) and the held state (pressed) through
		# the InputGate seam so tests are deterministic (TASK-024) and the entry latch
		# is defeated:
		#   1. ENTRY GRACE: while _entry_grace > 0 we tick it down and SKIP all exit
		#      detection. The entry double-jump (and Godot's multi-physics-frame
		#      just_pressed latch) therefore can NEVER drop the hero.
		#   2. RELEASE-GATING: a tap counts only when it is a rising edge that FOLLOWS
		#      a release (jump was up last frame), and only once the detector is ARMED
		#      — armed after JUMP has been observed released at least once post-grace.
		#      A single held/latched press can never register as two taps.
		# Track the previous-frame held state up front so every early-return below
		# leaves it consistent for the next frame.
		var jump_down := InputGate.pressed("jump")
		var jump_edge := InputGate.just_pressed("jump")
		var was_down := _jump_was_down
		_jump_was_down = jump_down

		if _entry_grace > 0.0:
			# During grace: ignore all jump input for exit, just tick the timer down.
			# Do NOT arm and do NOT count taps; the entry presses pass through harmless.
			_entry_grace -= delta
		else:
			# Arm only after observing a genuine release (jump up this frame) so the
			# entry hold/latch has fully cleared before any tap can count.
			if not jump_down:
				_exit_armed = true
			# Expire a stale pending first tap so a later lone tap starts fresh.
			if _jump_tap_pending:
				_tap_window_elapsed += delta
				if _tap_window_elapsed > DOUBLE_TAP_WINDOW:
					_jump_tap_pending = false
					_tap_window_elapsed = 0.0
			# A CLEAN tap = an armed rising edge that follows a release (was up last
			# frame). Held/latched presses (was_down true) never count.
			if _exit_armed and jump_edge and not was_down:
				if _jump_tap_pending:
					transition_to("MoveState")
					return
				_jump_tap_pending = true
				_tap_window_elapsed = 0.0

	# Resolve the shared DashComponent and tick its timers.
	var dash := player.get_node_or_null("DashComponent") as DashComponent
	if dash != null:
		dash.update(delta)

	# --- Active air dash burst (during the burst: override velocity, skip flight physics) ---
	if dash != null and dash.is_dashing():
		dash.apply_burst(player)
		player.move_and_slide()
		if player.is_on_floor():
			transition_to("MoveState")
		return

	# --- Trigger a new air dash ---
	# try_air_dash checks: cooldown + fire gate + input edge + suppression (DD-011).
	# Suppression is belt-and-suspenders here: the sustain gate above already drops
	# FlightState -> MoveState when suppressed, so try_air_dash's check is a
	# safeguard in case suppression is set mid-frame.
	if dash != null and dash.try_air_dash(player):
		player.move_and_slide()
		return

	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).limit_length(1.0)
	# TASK-067 (DD-014): per-level FLY-SPEED override. The shared FLY_SPEED const is NEVER
	# changed; instead the player carries a fly_speed_scale multiplier (default 1.0 = no-op,
	# so the sectors are byte-identical). The shmup controller sets it > 1.0 for a faster
	# air-lane pace. Read defensively so a minimal fake/player without the field defaults to 1.0.
	player.velocity = input * FLY_SPEED * _fly_speed_scale()
	# Twin-stick: aim owns facing while a device is aiming.
	if input.x != 0.0 and not player.is_aiming():
		player.facing = signf(input.x)
	player.move_and_slide()

	# DD-008: flight ends only on landing (no toggle-out). Landed while flying ->
	# grounded handling (no free re-launch through Jump).
	# TASK-065 (DD-014): suppressed in the shmup (player.shmup_mode) — the always-flying hero
	# must never drop to platformer movement (off-screen fall). Default FALSE keeps the sector
	# landing exit byte-identical.
	if player.is_on_floor() and not _is_shmup_mode():
		transition_to("MoveState")
		return


## TASK-065 (DD-014): true when the per-level shmup flag is set on the player, meaning the
## hero is in the always-flying auto-scroll mode and FlightState's exits (double-tap +
## landing) must NOT fire. Read defensively ("shmup_mode" in player) so a minimal fake/player
## without the field defaults to FALSE — the sectors are byte-identical.
func _is_shmup_mode() -> bool:
	return "shmup_mode" in player and player.shmup_mode


## TASK-067 (DD-014): the per-level FLY-SPEED multiplier. Read defensively so a minimal
## fake/player without the field defaults to 1.0 (a no-op) — the sectors stay byte-identical.
func _fly_speed_scale() -> float:
	return player.fly_speed_scale if "fly_speed_scale" in player else 1.0
