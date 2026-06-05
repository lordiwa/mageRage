## TASK-037 (M2.1 combat-feel) unit tests: the shooting STUTTER fix.
##
## This is a PERFORMANCE/FEEL fix only — visuals and behavior stay identical. The
## fix removes per-shot allocation: projectiles (and their per-shot Line2D + Curve
## trail) and muzzle flashes are POOLED and reused instead of instantiate()/
## queue_free() on every shot.
##
## These tests pin the pooling contract:
##   - acquire/release reuses the SAME instances (no fresh allocation per shot);
##   - a reused projectile has FULLY RESET state (no stale carryover — the classic
##     pooling bug: leftover life/hit-set/velocity/trail points);
##   - the trail (Line2D + width Curve) is NOT reallocated across reuses (same
##     object identity), and a second setup() never builds a second Curve;
##   - the pool is BOUNDED — a burst of acquire+release does not grow it without
##     limit (no node leak / unbounded orphan growth).
extends GutTest

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")


func _make_spell(element: int, shot_type := SpellData.ShotType.SINGLE,
		max_targets := 1) -> SpellData:
	var s := SpellData.new()
	s.element = element
	s.damage = 10.0
	s.speed = 400.0
	s.shot_type = shot_type
	s.max_targets = max_targets
	return s


func _make_pool() -> ProjectilePool:
	var pool := ProjectilePool.new()
	pool.scene = PROJECTILE_SCENE
	add_child_autofree(pool)   # _ready runs in-tree
	return pool


# --- Reuse: acquiring after release returns the SAME instances, not new ones ----

func test_release_then_acquire_reuses_the_same_instance() -> void:
	var pool := _make_pool()
	var first := pool.acquire()
	var id := first.get_instance_id()
	pool.release(first)
	var second := pool.acquire()
	assert_eq(second.get_instance_id(), id,
		"a released projectile is reused on the next acquire (no fresh allocation)")


func test_acquire_n_release_n_reacquire_n_reuses_all() -> void:
	var pool := _make_pool()
	var ids := {}
	var batch: Array = []
	for _i in range(3):
		var p := pool.acquire()
		batch.append(p)
		ids[p.get_instance_id()] = true
	for p in batch:
		pool.release(p)
	# Re-acquiring the same count must hand back the same three instances.
	var reused := {}
	for _i in range(3):
		var p := pool.acquire()
		reused[p.get_instance_id()] = true
	assert_eq(reused, ids,
		"releasing N then acquiring N returns the SAME N instances (full reuse)")


# --- No stale carryover: a reused projectile is fully reset on setup() ----------

func test_reused_projectile_resets_all_state() -> void:
	var pool := _make_pool()
	var p := pool.acquire() as Projectile
	# Dirty EVERY piece of per-shot state, as a real flight would.
	p.setup(_make_spell(SpellData.Element.ICE, SpellData.ShotType.PIERCE, 3), Vector2.RIGHT)
	p._life = 1.9
	p._hit[12345] = true
	p._remaining_targets = 0
	for _i in range(5):
		p._update_trail()
	pool.release(p)

	# Reuse it for a brand new Fire shot aimed UP.
	var again := pool.acquire() as Projectile
	again.setup(_make_spell(SpellData.Element.FIRE, SpellData.ShotType.SINGLE, 1), Vector2.UP)
	assert_eq(again._life, 0.0, "life resets to 0 on reuse (no carried-over age)")
	assert_eq(again._hit.size(), 0, "prior hit-targets are cleared on reuse")
	assert_eq(again._remaining_targets, 1,
		"remaining_targets is re-derived from the new spell, not stale")
	assert_eq(again.element, SpellData.Element.FIRE,
		"the new element is applied on reuse")
	assert_almost_eq(again._velocity.length(), 400.0, 0.5,
		"velocity is re-aimed on reuse (re-set from the new cast)")
	assert_eq(again.trail_point_count(), 0,
		"the trail points are cleared on reuse (no stale tail from the prior shot)")


# --- Trail (the prime allocation suspect) is reused, not rebuilt per shot -------

func test_trail_line_and_curve_are_not_reallocated_across_reuse() -> void:
	var pool := _make_pool()
	var p := pool.acquire() as Projectile
	p.setup(_make_spell(SpellData.Element.FIRE), Vector2.RIGHT)
	var line_id := p.trail_node_id()
	var curve_id := p.trail_curve_id()
	assert_ne(line_id, 0, "the trail Line2D exists after setup")
	assert_ne(curve_id, 0, "the trail width Curve exists after setup")
	pool.release(p)

	var again := pool.acquire() as Projectile
	again.setup(_make_spell(SpellData.Element.ICE), Vector2.UP)
	assert_eq(again.trail_node_id(), line_id,
		"the SAME Line2D is reused across shots (no per-shot Line2D.new())")
	assert_eq(again.trail_curve_id(), curve_id,
		"the SAME width Curve is reused across shots (no per-shot Curve.new())")


func test_second_setup_does_not_build_a_second_curve() -> void:
	# Calling setup() twice on one instance (as pooling does) must NOT allocate a
	# fresh Curve the second time — the width_curve identity is stable.
	var p := PROJECTILE_SCENE.instantiate() as Projectile
	add_child_autofree(p)
	p.setup(_make_spell(SpellData.Element.FIRE), Vector2.RIGHT)
	var curve_id := p.trail_curve_id()
	p.setup(_make_spell(SpellData.Element.ICE), Vector2.UP)
	assert_eq(p.trail_curve_id(), curve_id,
		"a second setup() reuses the existing width Curve (no Curve.new() per shot)")


# --- Bounded: a burst of acquire+release does not grow the pool unboundedly -----

func test_pool_is_bounded_under_acquire_release_burst() -> void:
	var pool := _make_pool()
	# Acquire+release one at a time many times: only ever one in flight, so the
	# pool should settle to a single reused instance (size 1), never grow per shot.
	for _i in range(20):
		var p := pool.acquire()
		pool.release(p)
	assert_eq(pool.size(), 1,
		"serial acquire/release reuses one instance — the pool stays size 1")
	assert_eq(pool.free_count(), 1, "that single instance returns to the free list")


func test_pool_grows_only_to_concurrent_demand() -> void:
	var pool := _make_pool()
	# Hold three at once -> pool must have at least three. Release all -> still 3
	# total (reused), all free. A subsequent burst of 3 reuses, not grows.
	var held: Array = []
	for _i in range(3):
		held.append(pool.acquire())
	assert_eq(pool.size(), 3, "the pool grows to meet concurrent demand (3 in flight)")
	for p in held:
		pool.release(p)
	assert_eq(pool.size(), 3, "releasing does not free instances — they are pooled")
	assert_eq(pool.free_count(), 3, "all three return to the free list for reuse")
	for _i in range(3):
		pool.acquire()
	assert_eq(pool.size(), 3,
		"a follow-up burst of 3 reuses the pooled instances (no unbounded growth)")
