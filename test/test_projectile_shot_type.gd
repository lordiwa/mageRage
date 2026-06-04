## TASK-022 unit tests: the Projectile honors the cast spell's SHOT TYPE
## (DD-004 element identities), driven by SpellData.shot_type copied in setup():
##   SINGLE = stop/queue_free after the first hit (Fire).
##   PIERCE = pass straight THROUGH, hitting up to max_targets distinct enemies,
##            applying slow on each, WITHOUT redirecting (Ice).
##   CHAIN  = on each hit redirect velocity toward the nearest not-yet-hit enemy
##            within chain_radius and keep flying, each enemy once, bounded by
##            max_targets, stopping when none in range (Electricity).
##
## We use a lightweight fake enemy (Area2D in the "enemies" group exposing
## apply_elemental_hit) so the chain target discovery + hit path run headlessly.
extends GutTest

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")


# --- Fake enemy: records the elemental hits it received. Lives in the "enemies"
# group so CHAIN target discovery can find it; exposes apply_elemental_hit with
# the real (element, base_damage, slow, hit_dir) signature.
class FakeEnemy:
	extends Area2D
	var hits: Array = []
	func _init() -> void:
		add_to_group("enemies")
	func apply_elemental_hit(element: int, base_damage: float, slow: bool,
			hit_dir: Vector2 = Vector2.ZERO) -> void:
		hits.append({"element": element, "damage": base_damage,
			"slow": slow, "dir": hit_dir})


func _make_spell(element: int, shot_type: int, max_targets := 1,
		applies_slow := false, chain_radius := 160.0) -> SpellData:
	var s := SpellData.new()
	s.element = element
	s.damage = 10.0
	s.speed = 400.0
	s.shot_type = shot_type
	s.max_targets = max_targets
	s.applies_slow = applies_slow
	s.chain_radius = chain_radius
	return s


func _make_projectile() -> Projectile:
	var p := PROJECTILE_SCENE.instantiate()
	add_child_autofree(p)
	return p


func _make_enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	add_child_autofree(e)
	e.global_position = pos
	return e


# --- SINGLE (Fire): stops after the first hit -------------------------------

func test_single_frees_after_first_hit() -> void:
	var p := _make_projectile()
	p.setup(_make_spell(SpellData.Element.FIRE, SpellData.ShotType.SINGLE), Vector2.RIGHT)
	var e1 := _make_enemy(Vector2(50, 0))
	var e2 := _make_enemy(Vector2(100, 0))
	p._try_hit(e1)
	assert_eq(e1.hits.size(), 1, "the first enemy is hit once")
	assert_true(p.is_queued_for_deletion(),
		"a SINGLE shot is freed after its first hit (Fire stops)")
	# A second hit after free does nothing more.
	p._try_hit(e2)
	assert_eq(e2.hits.size(), 0, "a freed SINGLE shot deals no further hits")


# --- PIERCE (Ice): passes through up to max_targets, no redirect, slow each ---

func test_pierce_hits_up_to_max_targets_distinct_enemies() -> void:
	var p := _make_projectile()
	p.setup(_make_spell(SpellData.Element.ICE, SpellData.ShotType.PIERCE, 3, true),
		Vector2.RIGHT)
	var e1 := _make_enemy(Vector2(50, 0))
	var e2 := _make_enemy(Vector2(100, 0))
	var e3 := _make_enemy(Vector2(150, 0))
	var e4 := _make_enemy(Vector2(200, 0))
	p._try_hit(e1)
	assert_false(p.is_queued_for_deletion(), "still flying after 1 pierce")
	p._try_hit(e2)
	assert_false(p.is_queued_for_deletion(), "still flying after 2 pierces")
	p._try_hit(e3)
	assert_eq(e1.hits.size(), 1)
	assert_eq(e2.hits.size(), 1)
	assert_eq(e3.hits.size(), 1)
	assert_true(p.is_queued_for_deletion(),
		"a PIERCE shot frees once it has hit max_targets distinct enemies")
	p._try_hit(e4)
	assert_eq(e4.hits.size(), 0, "no hits beyond max_targets")


func test_pierce_does_not_redirect_velocity() -> void:
	var p := _make_projectile()
	p.setup(_make_spell(SpellData.Element.ICE, SpellData.ShotType.PIERCE, 3, true),
		Vector2.RIGHT)
	var before := p._velocity
	# Put another enemy off-axis; PIERCE must NOT steer toward it.
	_make_enemy(Vector2(60, 200))
	p._try_hit(_make_enemy(Vector2(50, 0)))
	assert_eq(p._velocity, before,
		"PIERCE flies straight through; velocity is unchanged on hit")


func test_pierce_applies_slow_on_each_hit() -> void:
	var p := _make_projectile()
	p.setup(_make_spell(SpellData.Element.ICE, SpellData.ShotType.PIERCE, 3, true),
		Vector2.RIGHT)
	var e1 := _make_enemy(Vector2(50, 0))
	var e2 := _make_enemy(Vector2(100, 0))
	p._try_hit(e1)
	p._try_hit(e2)
	assert_true(e1.hits[0]["slow"], "Ice pierce applies slow to the 1st enemy")
	assert_true(e2.hits[0]["slow"], "Ice pierce applies slow to the 2nd enemy")


func test_pierce_does_not_double_hit_same_enemy() -> void:
	var p := _make_projectile()
	p.setup(_make_spell(SpellData.Element.ICE, SpellData.ShotType.PIERCE, 3, true),
		Vector2.RIGHT)
	var e1 := _make_enemy(Vector2(50, 0))
	p._try_hit(e1)
	p._try_hit(e1)
	assert_eq(e1.hits.size(), 1, "one enemy is never pierced twice")


# --- CHAIN (Electricity): redirect toward nearest unhit, stop when none -------

func test_chain_redirects_toward_nearest_unhit_enemy() -> void:
	var p := _make_projectile()
	p.setup(_make_spell(SpellData.Element.ELECTRICITY, SpellData.ShotType.CHAIN,
		3, false, 160.0), Vector2.RIGHT)
	var e1 := _make_enemy(Vector2(50, 0))
	# Next enemy is straight UP from e1, within radius -> velocity must turn upward.
	var e2 := _make_enemy(Vector2(50, 120))
	p.global_position = Vector2(50, 0)
	p._try_hit(e1)
	assert_false(p.is_queued_for_deletion(), "chain keeps flying after a hit")
	assert_gt(p._velocity.y, 0.0,
		"velocity redirects toward the next enemy (upward to e2)")
	# Speed magnitude preserved on the redirect.
	assert_almost_eq(p._velocity.length(), 400.0, 1.0,
		"chain keeps its speed when it redirects")


func test_chain_stops_when_no_unhit_enemy_in_radius() -> void:
	var p := _make_projectile()
	p.setup(_make_spell(SpellData.Element.ELECTRICITY, SpellData.ShotType.CHAIN,
		3, false, 160.0), Vector2.RIGHT)
	var e1 := _make_enemy(Vector2(50, 0))
	# The only other enemy is far away (beyond chain_radius).
	_make_enemy(Vector2(50, 600))
	p.global_position = Vector2(50, 0)
	p._try_hit(e1)
	assert_true(p.is_queued_for_deletion(),
		"a chain with no unhit enemy in radius frees after its hit")


func test_chain_each_enemy_hit_once_bounded_by_max_targets() -> void:
	var p := _make_projectile()
	p.setup(_make_spell(SpellData.Element.ELECTRICITY, SpellData.ShotType.CHAIN,
		2, false, 160.0), Vector2.RIGHT)
	# Three enemies in chaining range, but max_targets is 2.
	var e1 := _make_enemy(Vector2(0, 0))
	var e2 := _make_enemy(Vector2(100, 0))
	var e3 := _make_enemy(Vector2(200, 0))
	p.global_position = Vector2(0, 0)
	p._try_hit(e1)        # hop 1
	# Simulate arrival at e2 and the chain hop there.
	p.global_position = e2.global_position
	p._try_hit(e2)        # hop 2 -> reaches max_targets
	assert_eq(e1.hits.size(), 1)
	assert_eq(e2.hits.size(), 1)
	assert_true(p.is_queued_for_deletion(),
		"chain frees once it has hit max_targets enemies")
	p._try_hit(e3)
	assert_eq(e3.hits.size(), 0, "no chain hit beyond max_targets")


# --- Regression: setup still copies data + aims, default shot type is SINGLE --

func test_setup_copies_shot_type_and_chain_radius() -> void:
	var p := _make_projectile()
	p.setup(_make_spell(SpellData.Element.ELECTRICITY, SpellData.ShotType.CHAIN,
		3, false, 200.0), Vector2.RIGHT)
	assert_eq(p.shot_type, SpellData.ShotType.CHAIN, "shot_type is copied in setup")
	assert_almost_eq(p.chain_radius, 200.0, 0.001, "chain_radius is copied in setup")


func test_setup_still_copies_core_fields_and_aims() -> void:
	var p := _make_projectile()
	p.setup(_make_spell(SpellData.Element.FIRE, SpellData.ShotType.SINGLE), Vector2.RIGHT)
	assert_eq(p.element, SpellData.Element.FIRE, "element still copied")
	assert_almost_eq(p.base_damage, 10.0, 0.001, "damage still copied")
	assert_almost_eq(p.speed, 400.0, 0.001, "speed still copied")
	assert_almost_eq(p.rotation, 0.0, 0.0001, "rotation still aims (RIGHT -> 0)")
