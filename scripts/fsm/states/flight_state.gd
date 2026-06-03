## Free flight state (GDD: Electricity => Levitation / true 8-directional flight).
##
## Gravity is ignored: the hero moves under pure directional input. This state is
## only reachable through the electricity-gated transitions in JumpState /
## GlideState, so it needs no "am I unlocked?" flag of its own. Pressing fly
## again drops out of flight back into normal airborne handling.
class_name FlightState extends EstadoBase

const FLY_SPEED := 260.0

func enter() -> void:
	player.velocity = Vector2.ZERO

func physics_update(_delta: float) -> void:
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).limit_length(1.0)
	player.velocity = input * FLY_SPEED
	if input.x != 0.0:
		player.facing = signf(input.x)
	player.move_and_slide()

	# Landed while flying -> grounded handling (no free re-launch through Jump).
	if player.is_on_floor():
		transition_to("MoveState")
		return

	# Toggle out of flight -> resume gravity-bound airborne handling. Flag the
	# next JumpState entry to skip the launch impulse / dash reset, so leaving
	# flight is not a free upward leap that also re-grants the air dash.
	if Input.is_action_just_pressed("fly"):
		player.suppress_jump_impulse = true
		transition_to("JumpState")
