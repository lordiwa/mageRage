## TASK-018 Charger FSM — WIND-UP. The mandatory telegraph before the lunge (DD-001
## fair play: the player always gets the full wind-up to leap/dash away). On enter the
## Charger holds still, flashes the telegraph color, and LOCKS the lunge direction
## toward the player's CURRENT position — so the charge commits to one direction and
## never re-homes mid-lunge (fair, dodgeable). Once ChargerAi.windup_elapsed is true it
## transitions to Charge. A slowed Charger (DD-004 Ice) winds up MORE slowly, giving
## the player even more reaction time.
extends EstadoBase

const WINDUP := 0.5   # seconds of telegraph before the lunge (pre-slow)

var _telegraph := 0.0

func enter() -> void:
	_telegraph = 0.0
	var charger := player as Charger
	if charger == null:
		return
	charger.velocity = Vector2.ZERO
	# Lock the lunge toward the player NOW; this is the only homing the charge gets.
	charger.lock_lunge_at_target()
	charger.begin_telegraph()

func physics_update(delta: float) -> void:
	var charger := player as Charger
	if charger == null:
		return
	# Hold position during the wind-up; gravity still settles it on the ground. A
	# slowed Charger advances the telegraph more slowly (longer tell).
	charger.velocity.x = 0.0
	charger.velocity += charger.gravity_vector() * delta
	charger.move_and_slide()
	_telegraph += delta * charger.speed_multiplier()
	if ChargerAi.windup_elapsed(_telegraph, WINDUP):
		transition_to("ChargerChargeState")

func exit() -> void:
	var charger := player as Charger
	if charger != null:
		charger.end_telegraph()
