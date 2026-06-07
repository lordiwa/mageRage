## DD-010 Warden FSM — CHASE. The player is engaged, so the boss lumbers toward them
## (slowly — it's a heavy construct) keeping pressure. When the cooldown is ready it
## goes to Attack to telegraph + fire the current phase pattern. Chase speed honors
## the DD-009 Ice SLOW (a frozen Warden lumbers — the control window the design wants).
##
## TASK-059: GROUNDED heavy tank. Pursuit is HORIZONTAL ONLY — take only the x sign of
## the steer (the boss no longer flies diagonally/vertically toward the hero); gravity
## owns velocity.y. Mirrors the Charger chase idiom (signf(steer.x) + gravity_vector).
extends EstadoBase

const CHASE_SPEED := 60.0   # px/s, pre-slow (heavier/slower than the drone)

func physics_update(delta: float) -> void:
	var boss := player as Warden
	if boss == null:
		return
	if boss.is_defeated():
		boss.velocity = Vector2.ZERO
		return
	if not boss.player_in_aggro_range():
		transition_to("WardenPatrolState")
		return
	if boss.can_attack():
		transition_to("WardenAttackState")
		return
	# Horizontal-only pursuit (grounded tank): never add a vertical/upward component.
	boss.velocity.x = boss.horizontal_steer_sign() * CHASE_SPEED * boss.speed_multiplier()
	boss.velocity += boss.gravity_vector() * delta
	boss.move_and_slide()
