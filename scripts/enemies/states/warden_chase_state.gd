## DD-010 Warden FSM — CHASE. The player is engaged, so the boss steers toward them
## (slowly — it's a heavy construct) keeping pressure. When the cooldown is ready it
## goes to Attack to telegraph + fire the current phase pattern. Chase speed honors
## the DD-009 Ice SLOW (a frozen Warden lumbers — the control window the design wants).
extends EstadoBase

const CHASE_SPEED := 60.0   # px/s, pre-slow (heavier/slower than the drone)

func physics_update(_delta: float) -> void:
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
	var dir := boss.steer_toward_player()
	boss.velocity = dir * CHASE_SPEED * boss.speed_multiplier()
	boss.move_and_slide()
