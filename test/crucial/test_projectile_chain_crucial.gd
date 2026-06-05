## CRUCIAL CORE (TASK-049) — group N: projectile chain walk (DD-004, TASK-022).
##
## The one reviewer-curated chain-walk guard (visits each once, bounded by
## max_targets, no repeats) lifted verbatim from test/test_projectile_chain.gd.
## Pure geometry, no scene.
extends GutTest


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
