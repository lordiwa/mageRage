## TASK-018 Charger FSM — CHASE. The player is in aggro range, so the Charger walks
## toward them horizontally (gravity keeps it grounded). When the player leaves aggro
## range it drops back to Patrol; once the player is in attack range it commits to the
## WindUp (the mandatory telegraph before the lunge). Walk speed honors the Ice SLOW
## multiplier (DD-004 control identity).
extends EstadoBase

const CHASE_SPEED := 110.0   # px/s, pre-slow (horizontal approach)

func physics_update(delta: float) -> void:
	var charger := player as Charger
	if charger == null:
		return
	if not charger.player_in_aggro_range():
		transition_to("ChargerPatrolState")
		return
	if charger.player_in_attack_range():
		transition_to("ChargerWindUpState")
		return
	# Horizontal approach: take only the x sign of the steer (grounded melee).
	var steer := charger.steer_toward_player()
	charger.velocity.x = signf(steer.x) * CHASE_SPEED * charger.speed_multiplier()
	charger.velocity += charger.gravity_vector() * delta
	charger.move_and_slide()
