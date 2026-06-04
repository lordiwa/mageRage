## DD-010 Warden FSM — ATTACK. Mandatory telegraph then fire the CURRENT phase's
## pattern (DD-001 fair play: the player always gets the full wind-up to react, and
## the wind-up flashes a readable tell). On enter the boss holds still and begins
## the telegraph; once DroneAi.telegraph_elapsed is true (against the phase's
## wind-up) it fires the phase pattern (aimed / fan / sweep), resets its cooldown,
## and returns to Chase. The wind-up honors the DD-009 Ice SLOW (a slowed boss winds
## up more slowly), so freezing it truly buys the player time.
extends EstadoBase

var _telegraph := 0.0

func enter() -> void:
	_telegraph = 0.0
	var boss := player as Warden
	if boss != null:
		boss.velocity = Vector2.ZERO
		boss.begin_telegraph()

func physics_update(delta: float) -> void:
	var boss := player as Warden
	if boss == null:
		return
	if boss.is_defeated():
		boss.end_telegraph()
		transition_to("WardenPatrolState")
		return
	# A slowed boss winds up more slowly (Ice control identity, DD-009).
	_telegraph += delta * boss.speed_multiplier()
	if DroneAi.telegraph_elapsed(_telegraph, boss.phase_windup()):
		boss.fire_pattern()
		boss.mark_attacked()
		transition_to("WardenChaseState")

func exit() -> void:
	var boss := player as Warden
	if boss != null:
		boss.end_telegraph()
