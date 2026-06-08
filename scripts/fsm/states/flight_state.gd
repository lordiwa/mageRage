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
## "stop flying" control. Two JUMP edges within this window drop the hero to
## MoveState (a pure fall — same target as the landing exit), so gravity returns
## and the hero lands into platformer movement. Tunable/unit-testable constant.
const DOUBLE_TAP_WINDOW := 0.30

## True once a first in-flight JUMP edge is seen and we are waiting for a second
## within DOUBLE_TAP_WINDOW. Reset in enter() so each flight starts clean.
var _jump_tap_pending := false
## Seconds elapsed since the pending first tap; when it exceeds the window the
## pending tap is dropped so a later lone press starts a fresh count.
var _tap_window_elapsed := 0.0

func enter() -> void:
	player.velocity = Vector2.ZERO
	# TASK-062: a fresh flight has no pending tap (e.g. the entry double-jump
	# press in JumpState must not be mistaken for the first half of an exit tap).
	_jump_tap_pending = false
	_tap_window_elapsed = 0.0

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
	# accidental death. So when player.shmup_mode is set we SKIP both flight EXITS below and
	# keep the hero in FlightState. The flag defaults FALSE, so for the sectors the
	# double-tap + landing exits run exactly as before (byte-identical). We still ran the
	# DD-011 suppression exit above (untouched): the shmup has no anti-magic zones, so that
	# guard is inert here, and leaving it alone keeps the sector contract intact.
	if not _is_shmup_mode():
		# TASK-062 (extends DD-008): double-tap JUMP to stop flying. Count JUMP edges
		# through the InputGate seam (deterministic in tests, per TASK-024); a second
		# edge within DOUBLE_TAP_WINDOW of the first drops to MoveState — a PURE FALL,
		# the same target as the landing exit, never a re-launch (JumpState.enter would
		# add a fresh upward impulse). This only ever REMOVES flight: it cannot grant
		# traversal, so it can never bypass a gate (anti-magic zone / FIRE gate / boss
		# flight gap). If the window lapses with no second tap the pending tap is
		# dropped, so a later lone press starts a fresh count (no toggle-out on one tap).
		if _jump_tap_pending:
			_tap_window_elapsed += delta
			if _tap_window_elapsed > DOUBLE_TAP_WINDOW:
				_jump_tap_pending = false
				_tap_window_elapsed = 0.0
		if InputGate.just_pressed("jump"):
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
	player.velocity = input * FLY_SPEED
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
