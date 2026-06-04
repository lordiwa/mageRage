## DD-009 drone FSM — CHASE. The player is in aggro range, so the drone steers
## toward them (DroneAi.steer_direction: horizontal + a little vertical), gravity
## off. When the player leaves aggro range it drops back to Patrol; when in
## attack range AND the cooldown is ready it goes to Attack to telegraph + fire.
## Chase speed honors the Ice SLOW multiplier (DD-004 control identity).
extends EstadoBase

const CHASE_SPEED := 90.0      # px/s, pre-slow

func physics_update(_delta: float) -> void:
	# TASK-020: duck-typed (Variant) so this state drives BOTH the EmpireDrone and
	# the ShieldDrone (same floating-drone interface), not just EmpireDrone.
	var drone = player
	if drone == null:
		return
	if not drone.player_in_aggro_range():
		transition_to("DronePatrolState")
		return
	if drone.can_attack():
		transition_to("DroneAttackState")
		return
	var dir: Vector2 = drone.steer_toward_player()
	drone.velocity = dir * CHASE_SPEED * drone.speed_multiplier()
	drone.move_and_slide()
