## TASK-044 REAL-PHYSICS regression for the TASK-037 pooling stutter fix.
##
## The headless pool unit tests (test_projectile_pool.gd) drive _try_hit() directly,
## so they never enter Godot's body_entered/area_entered PHYSICS CALLBACK context —
## and thus missed a live-playtest error: parking a pooled projectile SYNCHRONOUSLY
## inside that callback disabled the Area2D CollisionObject mid-callback, which Godot
## forbids ("Disabling a CollisionObject node during a physics callback is not
## allowed ... Disable with call_deferred() instead.").
##
## The fix DEFERS the CollisionObject disabling (process_mode / monitoring /
## monitorable) while keeping the LOGICAL spent/parked state SYNCHRONOUS so the
## _is_spent() guard still blocks a double-hit during the one-frame deferred gap.
##
## These tests pin that contract:
##   - a hit parks the projectile back in its pool with the enemy hit exactly ONCE
##     (no double-hit) even though the disable is now deferred;
##   - the CollisionObject disable is DEFERRED: synchronously right after the hit the
##     Area2D is still monitoring / not process-disabled, yet _is_spent() is already
##     true; after a physics frame the CollisionObject IS disabled;
##   - a real collision through body_entered (the forbidden callback context) parks
##     the projectile and hits once, reproducing the playtest path the unit suite
##     could not.
extends GutTest

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")


# A drone-like body on the Enemies physics layer (3) so the projectile's mask (3)
# detects it and body_entered fires from real physics. Records its elemental hits.
class FakeBody:
	extends StaticBody2D
	var hits: Array = []

	func _init() -> void:
		collision_layer = 0
		collision_mask = 0
		set_collision_layer_value(3, true)   # IS an Enemy (layer 3)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 16.0
		shape.shape = circle
		add_child(shape)

	func apply_elemental_hit(element: int, base_damage: float, slow: bool,
			hit_dir: Vector2 = Vector2.ZERO) -> void:
		hits.append({"element": element, "damage": base_damage,
			"slow": slow, "dir": hit_dir})


func _make_spell(element: int) -> SpellData:
	var s := SpellData.new()
	s.element = element
	s.damage = 10.0
	s.speed = 400.0
	s.shot_type = SpellData.ShotType.SINGLE
	s.max_targets = 1
	return s


func _make_pool() -> ProjectilePool:
	var pool := ProjectilePool.new()
	pool.scene = PROJECTILE_SCENE
	add_child_autofree(pool)
	return pool


# --- Deferred disable: logical park is SYNCHRONOUS, CollisionObject disable is not -

func test_hit_parks_synchronously_but_defers_collision_disable() -> void:
	# Acquire a pooled projectile (so _despawn returns it to the pool) and hit it.
	var pool := _make_pool()
	var p := pool.acquire() as Projectile
	p.setup(_make_spell(SpellData.Element.FIRE), Vector2.RIGHT)
	var enemy := FakeBody.new()
	add_child_autofree(enemy)

	# Drive the hit the way the physics callback does (single hit path).
	p._try_hit(enemy)

	# SYNCHRONOUS, same frame as the "callback": the projectile is logically spent
	# (so a second hit this frame is blocked) AND already returned to the pool...
	assert_true(p._is_spent(),
		"the shot is logically spent SYNCHRONOUSLY (guards a same-frame double-hit)")
	assert_eq(pool.free_count(), 1,
		"the projectile is returned to the pool synchronously (bookkeeping is not deferred)")
	# ...but the CollisionObject disable is DEFERRED, so it is NOT yet disabled.
	assert_true(p.monitoring,
		"monitoring is STILL true synchronously after the hit (disable is deferred, not in-callback)")
	assert_ne(p.process_mode, Node.PROCESS_MODE_DISABLED,
		"process_mode is NOT disabled synchronously (deferred to avoid the in-callback disable)")

	# After the deferred call flushes (next physics step), the CollisionObject IS off.
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(p.monitoring,
		"monitoring is disabled after the deferred frame (the park fully applies)")
	assert_eq(p.process_mode, Node.PROCESS_MODE_DISABLED,
		"process_mode is disabled after the deferred frame")


func test_no_double_hit_during_the_deferred_gap() -> void:
	# A second hit arriving in the SAME frame (before the deferred disable flushes)
	# must be blocked by the synchronous _is_spent() guard — the classic risk of
	# deferring the disable. The enemy is hit exactly once.
	var pool := _make_pool()
	var p := pool.acquire() as Projectile
	p.setup(_make_spell(SpellData.Element.FIRE), Vector2.RIGHT)
	var enemy := FakeBody.new()
	add_child_autofree(enemy)

	p._try_hit(enemy)             # hop 1: hits + parks logically
	p._try_hit(enemy)             # same frame, before deferred flush: must be a no-op
	assert_eq(enemy.hits.size(), 1,
		"the enemy is hit exactly once — the deferred disable did not reopen a double-hit")


# --- Real collision through the body_entered PHYSICS CALLBACK (the missed path) ---

func test_real_collision_callback_parks_without_error_and_hits_once() -> void:
	# Reproduce the live-playtest context: a genuine physics overlap fires
	# body_entered (a physics callback), which parks the pooled projectile. With the
	# fix this must NOT disable the CollisionObject in-callback, must hit once, and
	# must return the projectile to its pool.
	var pool := _make_pool()
	var p := pool.acquire() as Projectile
	p.setup(_make_spell(SpellData.Element.ICE), Vector2.RIGHT)
	p.global_position = Vector2.ZERO

	var enemy := FakeBody.new()
	add_child_autofree(enemy)
	enemy.global_position = Vector2.ZERO   # overlap the projectile -> body_entered

	# Let physics register the overlap and fire body_entered, then flush deferred.
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_eq(enemy.hits.size(), 1,
		"a real body_entered collision hits the enemy exactly once")
	assert_eq(pool.free_count(), 1,
		"the projectile is parked back in its pool after the real collision")
	assert_true(p._is_spent(),
		"the projectile is spent after the real-collision hit")
