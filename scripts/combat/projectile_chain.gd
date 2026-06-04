## TASK-022 / DD-004 Electricity chain: the PURE, scene-free target selector the
## chaining projectile reads. Given a point and a list of candidate positions,
## return the INDEX of the nearest one within `radius`, or -1 when none qualifies
## (empty list or all out of range). Keeping it static + free of scene/node refs
## makes the chain math trivially unit-testable and impossible to drift.
##
## The CALLER filters out already-hit enemies (passes only live candidates), so
## this helper is pure geometry: nearest-within-radius. Combined with the caller's
## already-hit set + a max_targets bound, the chain visits each enemy once and
## never loops.
class_name ProjectileChain extends RefCounted


## Pure: index of the closest position to `from` whose distance is <= `radius`,
## or -1 if the array is empty or every candidate is beyond the radius. The
## radius bound is inclusive (a candidate exactly at `radius` qualifies).
static func nearest_index(from: Vector2, positions: PackedVector2Array,
		radius: float) -> int:
	var best := -1
	var radius_sq := radius * radius
	var best_dist_sq := INF
	for i in range(positions.size()):
		var d_sq := from.distance_squared_to(positions[i])
		# Inclusive radius bound; strict-less keeps ties on the first (lowest) index.
		if d_sq <= radius_sq and d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = i
	return best
