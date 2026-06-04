## DD-009 drone FSM — ATTACK. Mandatory telegraph then fire (DD-001 fair play: the
## player always gets the full wind-up to react). On enter the drone holds still
## and flashes a wind-up color; once DroneAi.telegraph_elapsed is true it fires one
## enemy projectile at the player, resets its cooldown, and returns to Chase. The
## wind-up duration honors the Ice SLOW multiplier (a slowed drone telegraphs
## longer — Ice's control identity, DD-004).
extends EstadoBase

const WINDUP := 0.4   # seconds of telegraph before the shot (pre-slow)

var _telegraph := 0.0

func enter() -> void:
	# TASK-020: duck-typed (Variant) so this state drives BOTH the EmpireDrone and
	# the ShieldDrone. begin_telegraph() on the ShieldDrone also DROPS its shield.
	_telegraph = 0.0
	var drone = player
	if drone != null:
		drone.velocity = Vector2.ZERO
		drone.begin_telegraph()

func physics_update(delta: float) -> void:
	var drone = player
	if drone == null:
		return
	# Hold position during the wind-up; a slowed drone winds up more slowly.
	_telegraph += delta * drone.speed_multiplier()
	if DroneAi.telegraph_elapsed(_telegraph, WINDUP):
		drone.fire_at_player()
		drone.mark_attacked()
		transition_to("DroneChaseState")

func exit() -> void:
	var drone = player
	if drone != null:
		drone.end_telegraph()
