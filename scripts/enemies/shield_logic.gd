## TASK-020 ShieldLogic — PURE, scene-free directional-shield math for the Shield
## Drone (Drone con escudo direccional). Kept static/RefCounted so every fairness
## rule is trivially unit-testable and can never silently drift (game-design SKILL:
## fair/deterministic, DD-001 — the player can always read the shield).
##
## The Shield Drone carries a DIRECTIONAL frontal shield. A player projectile
## travels along `hit_dir`, so it APPROACHES the drone from `-hit_dir`. The shot is
## BLOCKED only when the shield is UP and the approach direction lies within the
## shield's frontal half-arc of the facing — i.e. the shield is turned INTO the
## incoming shot. Flank/behind shots (outside the arc) and ANY shot while the
## shield is down (the attack wind-up window) land full damage.
class_name ShieldLogic extends RefCounted

## True only when the shield is UP and the shot strikes the frontal arc.
##
## `hit_dir`            — the projectile's TRAVEL direction (it approaches from `-hit_dir`).
## `shield_facing`      — unit-ish direction the shield faces (toward the player).
## `arc_halfwidth_rad`  — half the frontal cone width, in radians (e.g. ~80deg).
## `shield_up`          — false during the attack wind-up (shield dropped) -> never blocks.
##
## Zero-vector safe: a zero `hit_dir` or `shield_facing` is never blocked (no NaN
## from angle_to on a zero vector).
static func is_blocked(hit_dir: Vector2, shield_facing: Vector2,
		arc_halfwidth_rad: float, shield_up: bool) -> bool:
	if not shield_up:
		return false
	if hit_dir == Vector2.ZERO or shield_facing == Vector2.ZERO:
		return false
	# The shot approaches FROM the opposite of its travel direction.
	var approach := -hit_dir
	# Blocked when the shield faces into the incoming shot within the half-arc.
	var angle := absf(shield_facing.angle_to(approach))
	return angle <= arc_halfwidth_rad

## Unit direction the shield should face: from the drone toward the player. Zero
## in (coincident positions) -> zero out (safe, no NaN).
static func shield_facing_toward(drone_pos: Vector2, target_pos: Vector2) -> Vector2:
	var to_target := target_pos - drone_pos
	if to_target == Vector2.ZERO:
		return Vector2.ZERO
	return to_target.normalized()
