## TASK-018 Charger FSM — PATROL. With no player in aggro range the Charger walks
## back and forth on the ground around its spawn (a heavy sentry on its beat — pillar
## 1, the jailer was the protector). Transitions to Chase the moment the player enters
## aggro range (DroneAi.in_aggro_range). GROUNDED: gravity is applied every step so the
## Charger stays on the floor (unlike the floating drone).
extends EstadoBase

## Walk half-width around spawn (px) and walk speed (px/s, pre-slow).
const WALK_RANGE := 64.0
const WALK_SPEED := 36.0

var _dir := 1.0   # +1 right, -1 left

func physics_update(delta: float) -> void:
	var charger := player as Charger
	if charger == null:
		return
	if charger.player_in_aggro_range():
		transition_to("ChargerChaseState")
		return
	# Walk: flip direction at the patrol bounds around spawn.
	var offset := charger.global_position.x - charger.spawn_position.x
	if offset > WALK_RANGE:
		_dir = -1.0
	elif offset < -WALK_RANGE:
		_dir = 1.0
	charger.velocity.x = _dir * WALK_SPEED * charger.speed_multiplier()
	# Gravity keeps the grounded Charger on the floor.
	charger.velocity += charger.gravity_vector() * delta
	charger.move_and_slide()
