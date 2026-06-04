## TASK-018 Charger FSM — CHARGE. The fast HORIZONTAL ground lunge in the LOCKED
## direction (captured at wind-up start, so it never re-homes — fair, the player can
## leap/dash over or step out of it). The lunge runs for a fixed duration; its contact
## hitbox is active so touching the player deals contact damage (respecting i-frames).
## Gravity still applies so the Charger stays grounded. A slowed Charger (DD-004 Ice)
## lunges SLOWER (less distance / more reaction time). Once ChargerAi.charge_elapsed is
## true it transitions to Recovery (the exposed stagger window).
extends EstadoBase

const CHARGE_SPEED := 420.0   # px/s, pre-slow (fast lunge — clearly faster than chase)
const CHARGE_DURATION := 0.35 # seconds of lunge before the stagger (pre-slow timing)

var _elapsed := 0.0

func enter() -> void:
	_elapsed = 0.0
	var charger := player as Charger
	if charger != null:
		charger.activate_lunge_hitbox(true)

func physics_update(delta: float) -> void:
	var charger := player as Charger
	if charger == null:
		return
	# Lunge along the locked horizontal sign; speed honors the Ice slow.
	charger.velocity.x = charger.lunge_direction_sign() * CHARGE_SPEED * charger.speed_multiplier()
	charger.velocity += charger.gravity_vector() * delta
	charger.move_and_slide()
	# A slowed Charger spends LONGER lunging in real time (effective duration scales
	# up), matching the slower speed — both halves of the Ice tell stay coherent.
	_elapsed += delta * charger.speed_multiplier()
	if ChargerAi.charge_elapsed(_elapsed, CHARGE_DURATION):
		transition_to("ChargerRecoveryState")

func exit() -> void:
	var charger := player as Charger
	if charger != null:
		charger.activate_lunge_hitbox(false)
		charger.velocity.x = 0.0
