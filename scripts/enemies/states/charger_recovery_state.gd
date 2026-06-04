## TASK-018 Charger FSM — RECOVERY. The stagger window AFTER the lunge: the Charger
## can't act and its core is EXPOSED (extra-vulnerable). This is the read-and-punish
## payoff — a player who read the telegraph, dodged the lunge, and counter-attacks now
## lands BONUS damage (ChargerAi.exposed_multiplier, applied in apply_elemental_hit).
## On enter it flags the exposed window; once ChargerAi.recovery_elapsed is true it
## clears the flag and returns to Chase. Gravity still settles it on the ground.
extends EstadoBase

const RECOVERY := 0.7   # seconds of exposed stagger before recovering to Chase

var _elapsed := 0.0

func enter() -> void:
	_elapsed = 0.0
	var charger := player as Charger
	if charger != null:
		charger.velocity.x = 0.0
		charger.set_exposed(true)

func physics_update(delta: float) -> void:
	var charger := player as Charger
	if charger == null:
		return
	# Staggered: no horizontal action, gravity keeps it grounded.
	charger.velocity.x = 0.0
	charger.velocity += charger.gravity_vector() * delta
	charger.move_and_slide()
	_elapsed += delta
	if ChargerAi.recovery_elapsed(_elapsed, RECOVERY):
		transition_to("ChargerChaseState")

func exit() -> void:
	var charger := player as Charger
	if charger != null:
		charger.set_exposed(false)
