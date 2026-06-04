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
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).limit_length(1.0)
	player.velocity = input * FLY_SPEED
	if input.x != 0.0:
		player.facing = signf(input.x)
	player.move_and_slide()

	# DD-008: flight ends only on landing (no toggle-out). Landed while flying ->
	# grounded handling (no free re-launch through Jump).
	if player.is_on_floor():
		transition_to("MoveState")
		return
