## DD-009 drone FSM — PATROL. With no player in aggro range the drone hovers
## back and forth in a short range around its spawn (a desperate sentry on its
## beat — pillar 1, the jailer was the protector). Transitions to Chase the moment
## the player enters aggro range (DroneAi.in_aggro_range).
##
## Mirrors the hero's node-based FSM (EstadoBase child of a StateMachine) so the
## drone follows the same idiom. The drone is a FLYING CharacterBody2D: gravity is
## off; movement is pure horizontal hover.
extends EstadoBase

## Hover half-width around spawn (px) and hover speed (px/s, pre-slow).
const HOVER_RANGE := 48.0
const HOVER_SPEED := 40.0

var _dir := 1.0   # +1 right, -1 left

func physics_update(_delta: float) -> void:
	# TASK-020: duck-typed (Variant) so this state drives BOTH the EmpireDrone and
	# the ShieldDrone (same floating-drone interface), not just EmpireDrone.
	var drone = player
	if drone == null:
		return
	# Chase as soon as the player is in aggro range.
	if drone.player_in_aggro_range():
		transition_to("DroneChaseState")
		return
	# TASK-069: in the shmup the SPAWNER owns this enemy's position per its motion pattern, so
	# the patrol hover YIELDS position control (no velocity / move_and_slide) — the transition
	# logic above still runs so the drone can still reach Chase/Attack and fire. Sector drones
	# (shmup_motion false) fall through to the unchanged hover below (byte-identical).
	if "shmup_motion" in drone and drone.shmup_motion:
		return
	# Hover: flip direction at the patrol bounds around spawn.
	var offset: float = drone.global_position.x - drone.spawn_position.x
	if offset > HOVER_RANGE:
		_dir = -1.0
	elif offset < -HOVER_RANGE:
		_dir = 1.0
	drone.velocity = Vector2(_dir * HOVER_SPEED * drone.speed_multiplier(), 0.0)
	drone.move_and_slide()
