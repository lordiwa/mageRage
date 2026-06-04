## TASK-010 hit-feedback: knockback math. A hit shoves the drone ALONG the
## projectile's travel direction — i.e. away from the shooter, the way the shot
## was going (a short positional punch) — pairs with the hit flash so a solid hit
## reads as solid (game-design SKILL Game Feel).
##
## Pure & static so the direction sign is unit-testable with no scene: the result
## points along `hit_dir` (the projectile's travel direction), i.e. the drone is
## pushed the way the shot was already going.
class_name Knockback extends RefCounted


## Pure: knockback velocity/offset for a hit. `hit_dir` is the projectile's travel
## direction; the drone is pushed along it, scaled by `strength`. A zero hit_dir
## yields zero knockback (no NaN from normalizing a zero vector).
static func knockback_vector(hit_dir: Vector2, strength: float) -> Vector2:
	var dir := hit_dir.normalized()
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	return dir * strength
