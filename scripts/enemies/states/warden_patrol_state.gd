## DD-010 Warden FSM — PATROL. With no player in aggro range the boss paces a short
## range around its arena anchor (a looming sentry — pillar 1, the jailer was the
## protector). In the arena the player is effectively always in range, so this is
## mostly a safe start state; it transitions to Chase the moment the player is in
## aggro range (DroneAi.in_aggro_range). Mirrors the drone FSM idiom.
##
## TASK-059: GROUNDED heavy tank — the pace is horizontal and gravity is applied each
## step so the boss settles on / stays on the floor while idle (it never floats).
extends EstadoBase

const HOVER_RANGE := 40.0
const HOVER_SPEED := 30.0

var _dir := 1.0

func physics_update(delta: float) -> void:
	var boss := player as Warden
	if boss == null:
		return
	if boss.is_defeated():
		boss.velocity = Vector2.ZERO
		return
	if boss.player_in_aggro_range():
		transition_to("WardenChaseState")
		return
	var offset := boss.global_position.x - boss.spawn_position.x
	if offset > HOVER_RANGE:
		_dir = -1.0
	elif offset < -HOVER_RANGE:
		_dir = 1.0
	# Horizontal pace + gravity (grounded): the boss stays on the floor while idle.
	boss.velocity.x = _dir * HOVER_SPEED * boss.speed_multiplier()
	boss.velocity += boss.gravity_vector() * delta
	boss.move_and_slide()
