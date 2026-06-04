## DD-012 soft aim-assist (aim magnetism) — the pure, deterministic core.
##
## SOFT magnetism, NOT a hard lock-on. The player keeps FULL manual control; this
## only BIASES the cast aim toward an enemy the player is already roughly aiming
## at. There is no button, no persistent "fixed target" state, no takeover — just
## a bounded rotation of the raw aim each time a cast is computed.
##
## DD-001 demands fair / deterministic / legible difficulty with no hidden help:
## `assist()` is a PURE function of (raw_aim, player_pos, enemy_positions, cones,
## range) — no RNG, no node lookups, no accumulators, no hidden state. The same
## inputs always yield the same aim, so the player can always understand why a
## shot went where it did (and the reticle is fed the same result for legibility).
##
## The magnetism profile (DD-012, provisional values supplied by the caller):
##   - Find the NEAREST enemy that lies within the OUTER cone (+/-cone_deg) of the
##     raw aim AND within range_px.
##   - If its angular offset is within the INNER cone (+/-inner_cone_deg): FULL
##     snap onto the enemy.
##   - Between the inner and outer cone: a PARTIAL lerp — rotate toward the enemy
##     by a fraction that fades to zero at the outer edge (so the assist is
##     seamless, never a visible jerk at the boundary).
##   - Outside the outer cone, beyond range, or behind the player: NO assist; the
##     raw aim is returned unchanged (deliberate aim elsewhere is respected).
##
## Returns a NORMALIZED aim. When nothing qualifies it returns the raw aim
## (normalized); a degenerate (zero-length) raw aim returns a safe unit vector.
class_name AimAssist extends RefCounted


## Compute the assisted cast aim. See the class header for the full contract.
##   raw_aim          - the player's manual aim (need not be normalized).
##   player_pos       - the aim origin (muzzle / body) in world space.
##   enemy_positions  - candidate enemy world positions (the "enemies" group).
##   cone_deg         - OUTER cone half-angle in degrees (DD-012 ~20).
##   inner_cone_deg   - INNER full-snap cone half-angle in degrees (DD-012 ~8).
##   range_px         - maximum assist distance in pixels (DD-012 ~400).
static func assist(
	raw_aim: Vector2,
	player_pos: Vector2,
	enemy_positions: Array,
	cone_deg: float,
	inner_cone_deg: float,
	range_px: float
) -> Vector2:
	# A zero-length aim has no direction to bias; return a safe finite unit vector.
	if raw_aim.length() <= 0.0001:
		return Vector2.RIGHT
	var aim := raw_aim.normalized()

	var cone := deg_to_rad(cone_deg)
	var inner := deg_to_rad(inner_cone_deg)

	# Pick the NEAREST enemy that qualifies (inside the outer cone AND in range).
	# Distance, not angle, selects the target (DD-012: "nearest enemy ...").
	var best_dir := Vector2.ZERO
	var best_offset := 0.0          # signed angle from aim to the chosen enemy
	var best_dist_sq := INF
	var range_sq := range_px * range_px

	for pos in enemy_positions:
		var to_enemy: Vector2 = pos - player_pos
		var dist_sq := to_enemy.length_squared()
		if dist_sq <= 0.0001:
			# Enemy exactly on the player: no direction to pull toward — skip.
			continue
		if dist_sq > range_sq:
			continue                # beyond range
		var offset := aim.angle_to(to_enemy)   # signed; magnitude is the cone test
		if absf(offset) > cone:
			continue                # outside the outer cone (also rejects behind)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_offset = offset
			best_dir = to_enemy.normalized()

	if best_dir == Vector2.ZERO:
		return aim                  # nothing qualified: manual aim respected

	var mag := absf(best_offset)
	if mag <= inner:
		# Inside the inner cone: full snap onto the enemy.
		return best_dir

	# Between the cones: partial pull. The strength fades linearly from 1.0 at the
	# inner edge to 0.0 at the outer edge, so the assist is continuous (no jerk at
	# either boundary) and never over-rotates past the enemy.
	var t := (cone - mag) / (cone - inner)
	t = clampf(t, 0.0, 1.0)
	return aim.rotated(best_offset * t).normalized()
