## TASK-022 unit tests for the PURE chain target selector (no scene).
##
## DD-004 Electricity = chain: on each hit the bolt must redirect toward the
## NEAREST not-yet-hit enemy within a radius and continue, each enemy hit once,
## bounded by max_targets, never looping. The scene-free helper
## ProjectileChain.nearest_index(from, positions, radius) is the single source of
## truth the projectile reads; it returns the index of the closest position
## within radius, or -1 when there is none (empty / all out of range). The CALLER
## filters already-hit enemies (passes only live candidates), so this helper is
## pure geometry and trivially unit-testable.
extends GutTest


func test_returns_minus_one_for_empty() -> void:
	var idx := ProjectileChain.nearest_index(Vector2.ZERO, PackedVector2Array(), 160.0)
	assert_eq(idx, -1, "no candidates -> -1")


func test_returns_minus_one_when_all_out_of_radius() -> void:
	var positions := PackedVector2Array([Vector2(500, 0), Vector2(0, 400)])
	var idx := ProjectileChain.nearest_index(Vector2.ZERO, positions, 160.0)
	assert_eq(idx, -1, "all candidates beyond the radius -> -1")


func test_picks_the_nearest_within_radius() -> void:
	var positions := PackedVector2Array([
		Vector2(150, 0),   # 150 away
		Vector2(40, 0),    # 40 away (nearest)
		Vector2(90, 0),    # 90 away
	])
	var idx := ProjectileChain.nearest_index(Vector2.ZERO, positions, 160.0)
	assert_eq(idx, 1, "the closest in-range candidate is chosen")


func test_radius_is_inclusive_bound() -> void:
	var positions := PackedVector2Array([Vector2(160, 0)])
	var idx := ProjectileChain.nearest_index(Vector2.ZERO, positions, 160.0)
	assert_eq(idx, 0, "a candidate exactly at the radius is in range")


func test_picks_nearest_ignoring_far_ones() -> void:
	var positions := PackedVector2Array([
		Vector2(300, 0),   # out of range
		Vector2(120, 0),   # nearest in range
		Vector2(1000, 0),  # out of range
	])
	var idx := ProjectileChain.nearest_index(Vector2.ZERO, positions, 160.0)
	assert_eq(idx, 1, "out-of-range candidates never win")


# --- Combined with already-hit filtering (the caller's contract): the chain
# never repeats a target and is bounded by max_targets. We simulate the loop the
# projectile runs: pick nearest unhit, mark, hop, repeat.

func test_chain_walk_visits_each_once_bounded_by_max_targets() -> void:
	# Four enemies in a line; from origin, each within radius of the previous.
	var enemies := PackedVector2Array([
		Vector2(0, 0), Vector2(100, 0), Vector2(200, 0), Vector2(300, 0),
	])
	var radius := 160.0
	var max_targets := 3
	var hit_order: Array = []
	var hit := {}
	var pos := Vector2(-50, 0)   # start just left of the first enemy
	for _i in range(max_targets):
		# Build candidate list of UNHIT enemies (caller filters), tracking indices.
		var live := PackedVector2Array()
		var map: Array = []
		for j in range(enemies.size()):
			if not hit.has(j):
				live.append(enemies[j])
				map.append(j)
		var li := ProjectileChain.nearest_index(pos, live, radius)
		if li == -1:
			break
		var real: int = map[li]
		hit[real] = true
		hit_order.append(real)
		pos = enemies[real]
	assert_eq(hit_order.size(), 3, "bounded by max_targets (3)")
	assert_eq(hit_order, [0, 1, 2], "walks nearest-unhit each hop, no repeats")
	# Each index appears once.
	var seen := {}
	for r in hit_order:
		seen[r] = true
	assert_eq(seen.size(), hit_order.size(), "no enemy is hit twice")


func test_chain_stops_when_next_is_out_of_range() -> void:
	# Two close enemies then a big gap: the chain should stop after the 2nd.
	var enemies := PackedVector2Array([
		Vector2(0, 0), Vector2(100, 0), Vector2(500, 0),
	])
	var radius := 160.0
	var max_targets := 3
	var hit := {}
	var hit_order: Array = []
	var pos := Vector2(-50, 0)
	for _i in range(max_targets):
		var live := PackedVector2Array()
		var map: Array = []
		for j in range(enemies.size()):
			if not hit.has(j):
				live.append(enemies[j])
				map.append(j)
		var li := ProjectileChain.nearest_index(pos, live, radius)
		if li == -1:
			break
		var real: int = map[li]
		hit[real] = true
		hit_order.append(real)
		pos = enemies[real]
	assert_eq(hit_order, [0, 1], "chain stops when no unhit enemy is within radius")
