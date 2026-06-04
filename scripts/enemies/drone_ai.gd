## DD-009 drone AI — pure decision helpers for the node-based FSM.
##
## The drone FSM (Patrol -> Chase -> Attack) keeps ALL transition logic in these
## static, scene-free helpers so every threshold is trivially unit-testable and
## can never silently drift (game-design SKILL: fair/deterministic, DD-001 — the
## player can always understand the drone's behavior). The FSM states are thin:
## they read input/state and ask these helpers what to do.
class_name DroneAi extends RefCounted

## True when the player is within aggro range (inclusive) — Patrol -> Chase gate.
static func in_aggro_range(distance: float, aggro_range: float) -> bool:
	return distance <= aggro_range

## True once the attack cooldown has fully elapsed — gates Chase -> Attack so the
## drone cannot spam shots (fair, DD-001).
static func cooldown_ready(time_since_last_attack: float, cooldown: float) -> bool:
	return time_since_last_attack >= cooldown

## True once the telegraph wind-up has fully elapsed — the drone fires only AFTER
## the player has had the full wind-up to react (mandatory telegraph, DD-009).
static func telegraph_elapsed(telegraph_time: float, windup: float) -> bool:
	return telegraph_time >= windup

## Unit steering vector from the drone toward the player (horizontal + a little
## vertical). Zero in/zero out is safe (no NaN from normalizing a zero vector).
static func steer_direction(drone_pos: Vector2, target_pos: Vector2) -> Vector2:
	var to_target := target_pos - drone_pos
	if to_target == Vector2.ZERO:
		return Vector2.ZERO
	return to_target.normalized()
