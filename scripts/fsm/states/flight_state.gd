## Free flight state (GDD: Electricity => Levitation / true 8-directional flight).
##
## Gravity is ignored: the hero moves under pure directional input. This state is
## only reachable through the electricity-gated DOUBLE-JUMP transitions in
## JumpState / GlideState, so it needs no "am I unlocked?" flag of its own.
## DD-008: there is no toggle-out — flight ends only on landing.
class_name FlightState extends EstadoBase

const FLY_SPEED := 260.0

func enter() -> void:
	player.velocity = Vector2.ZERO

func physics_update(_delta: float) -> void:
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
	if player.is_on_floor():
		transition_to("MoveState")
		return
