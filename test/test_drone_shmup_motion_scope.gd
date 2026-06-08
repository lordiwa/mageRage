## TASK-069 unit tests for the SHMUP-SCOPED drone movement seam: the per-enemy
## `shmup_motion` flag the drone's MOVEMENT states honor.
##
## The shmup spawner OWNS a streamed enemy's position (per its pattern). The shared drone
## FSM movement (Patrol/Chase steering + move_and_slide) would FIGHT a spawner-driven
## position, so when `shmup_motion` is true the MOVEMENT states yield position control
## (skip their steering / move_and_slide) while the Attack telegraph+fire path still runs.
##
## SCOPING contract (acceptance criterion (c)): with `shmup_motion` OFF (the sector default)
## the states are BYTE-IDENTICAL — they still drive velocity + move_and_slide exactly as
## before. We prove BOTH directions with a fake drone that records move_and_slide() calls
## (no rendered scene, no real physics, deterministic).
extends GutTest

const PatrolState := preload("res://scripts/enemies/states/drone_patrol_state.gd")
const ChaseState := preload("res://scripts/enemies/states/drone_chase_state.gd")
const AttackState := preload("res://scripts/enemies/states/drone_attack_state.gd")


## A scene-free fake drone exposing the duck-typed interface the drone states call, plus a
## `shmup_motion` flag and a move_and_slide() spy. A plain Node2D (NOT CharacterBody2D) so
## the spy method does not clash with the native CharacterBody2D.move_and_slide(); the states
## drive the drone duck-typed (their `player` is typed as Node), so this works headlessly.
class FakeDrone:
	extends Node2D
	var velocity := Vector2.ZERO
	var shmup_motion := false
	var spawn_position := Vector2.ZERO
	var move_calls := 0
	var fired := false
	var attacked := false
	var telegraphing := false
	# Tunable test knobs for the gating queries.
	var aggro := true
	var attack_ready := false
	var steer := Vector2(-1.0, 0.0)
	var slow_mult := 1.0

	func player_in_aggro_range() -> bool:
		return aggro

	func can_attack() -> bool:
		return attack_ready

	func steer_toward_player() -> Vector2:
		return steer

	func speed_multiplier() -> float:
		return slow_mult

	func begin_telegraph() -> void:
		telegraphing = true

	func end_telegraph() -> void:
		telegraphing = false

	func fire_at_player() -> void:
		fired = true

	func mark_attacked() -> void:
		attacked = true

	# Spy: record the call (and that velocity drove it) instead of moving real physics.
	func move_and_slide() -> void:
		move_calls += 1


func _wire(state: EstadoBase, drone: FakeDrone) -> EstadoBase:
	add_child_autofree(drone)
	add_child_autofree(state)
	state.player = drone
	return state


# --- (c) SCOPING: flag OFF (sector default) is byte-identical -----------------

func test_patrol_drives_move_and_slide_when_flag_off() -> void:
	# Sector default: shmup_motion false. Patrol (player out of aggro) hovers via velocity +
	# move_and_slide EXACTLY as before — unchanged sector behavior.
	var drone := FakeDrone.new()
	drone.shmup_motion = false
	drone.aggro = false   # stay in patrol
	var state := _wire(PatrolState.new(), drone)
	state.physics_update(0.05)
	assert_eq(drone.move_calls, 1,
		"with shmup_motion OFF, Patrol still drives move_and_slide (sector behavior unchanged)")
	assert_ne(drone.velocity, Vector2.ZERO,
		"with shmup_motion OFF, Patrol still sets a hover velocity")


func test_chase_drives_move_and_slide_when_flag_off() -> void:
	# Sector default: Chase steers toward the player via velocity + move_and_slide as before.
	var drone := FakeDrone.new()
	drone.shmup_motion = false
	drone.aggro = true
	drone.attack_ready = false
	drone.steer = Vector2(-1.0, 0.0)
	var state := _wire(ChaseState.new(), drone)
	state.physics_update(0.05)
	assert_eq(drone.move_calls, 1,
		"with shmup_motion OFF, Chase still drives move_and_slide (sector behavior unchanged)")
	assert_ne(drone.velocity, Vector2.ZERO,
		"with shmup_motion OFF, Chase still sets a steering velocity")


# --- (c) SCOPING: flag ON yields position control -----------------------------

func test_patrol_skips_move_and_slide_when_flag_on() -> void:
	# Shmup: the spawner owns position, so Patrol must NOT move_and_slide (no fight).
	var drone := FakeDrone.new()
	drone.shmup_motion = true
	drone.aggro = false
	var state := _wire(PatrolState.new(), drone)
	state.physics_update(0.05)
	assert_eq(drone.move_calls, 0,
		"with shmup_motion ON, Patrol yields position control (no move_and_slide)")


func test_chase_skips_move_and_slide_when_flag_on() -> void:
	# Shmup: Chase yields position control too (the spawner pattern drives the body).
	var drone := FakeDrone.new()
	drone.shmup_motion = true
	drone.aggro = true
	drone.attack_ready = false
	var state := _wire(ChaseState.new(), drone)
	state.physics_update(0.05)
	assert_eq(drone.move_calls, 0,
		"with shmup_motion ON, Chase yields position control (no move_and_slide)")


# --- (d) STILL FIRES in shmup (combat read preserved) ------------------------

func test_attack_still_telegraphs_and_fires_when_flag_on() -> void:
	# The whole point: MOVEMENT changes, COMBAT does not. With shmup_motion ON the Attack
	# state must still telegraph then fire_at_player + mark_attacked (the element-swap read).
	var drone := FakeDrone.new()
	drone.shmup_motion = true
	var attack := _wire(AttackState.new(), drone) as EstadoBase
	attack.enter()
	assert_true(drone.telegraphing,
		"Attack telegraphs (wind-up) even in shmup motion mode")
	# Drive past the wind-up so the shot fires.
	for _i in range(20):
		attack.physics_update(0.05)
	assert_true(drone.fired,
		"with shmup_motion ON the drone STILL fires (combat read preserved)")
	assert_true(drone.attacked,
		"with shmup_motion ON the drone STILL resets its attack cooldown after firing")


func test_attack_fires_identically_when_flag_off() -> void:
	# Byte-identical the other way: with the flag OFF (sector) Attack fires the same way.
	var drone := FakeDrone.new()
	drone.shmup_motion = false
	var attack := _wire(AttackState.new(), drone) as EstadoBase
	attack.enter()
	for _i in range(20):
		attack.physics_update(0.05)
	assert_true(drone.fired,
		"with shmup_motion OFF the drone fires (sector combat unchanged)")


# --- real drones default the flag OFF (sector byte-identical) -----------------

func test_real_drones_default_shmup_motion_off() -> void:
	# The flag must default FALSE on the REAL drones so sector_01/02 are byte-identical;
	# only the shmup spawner flips it on streamed enemies.
	var empire := EmpireDrone.new()
	add_child_autofree(empire)
	var shield := ShieldDrone.new()
	add_child_autofree(shield)
	assert_false(empire.shmup_motion,
		"EmpireDrone defaults shmup_motion OFF (sector behavior byte-identical)")
	assert_false(shield.shmup_motion,
		"ShieldDrone defaults shmup_motion OFF (sector behavior byte-identical)")
