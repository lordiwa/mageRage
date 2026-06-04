## TASK-012 unit tests for the enemy projectile's i-frame pass-through (no scene).
##
## Fairness fix (DD-001): while the hero is invulnerable (i-frames), the enemy
## projectile must pass THROUGH — deal no damage AND not be consumed — so i-frames
## truly mean untouchable. Against a vulnerable hero it damages and is consumed as
## before. The Area2D signal can't be driven headlessly, so the hit decision is
## factored into the pure helper `should_land_hit()` which the resolver uses.
extends GutTest


# A scene-free stand-in for the hero's damage handler. Records damage taken and
# exposes the i-frame gate the projectile checks. TASK-016: also captures the
# hit direction the projectile threads through take_player_damage.
class FakeHero:
	extends Node
	var invulnerable := false
	var damage_taken := 0.0
	var last_hit_dir := Vector2.ZERO
	var hit_count := 0

	func is_invulnerable() -> bool:
		return invulnerable

	func take_player_damage(amount: float, hit_dir: Vector2 = Vector2.ZERO) -> void:
		damage_taken += amount
		last_hit_dir = hit_dir
		hit_count += 1


func _make_projectile() -> EnemyProjectile:
	var proj := EnemyProjectile.new()
	proj.damage = 12.0
	add_child_autofree(proj)   # _ready runs: collision setup
	return proj


# --- Pure hit decision -------------------------------------------------------

func test_should_land_hit_true_for_vulnerable_hero() -> void:
	var proj := _make_projectile()
	var hero := FakeHero.new()
	hero.invulnerable = false
	assert_true(proj.should_land_hit(hero),
		"a vulnerable hero takes the hit")


func test_should_land_hit_false_for_invulnerable_hero() -> void:
	var proj := _make_projectile()
	var hero := FakeHero.new()
	hero.invulnerable = true
	assert_false(proj.should_land_hit(hero),
		"an invulnerable hero is passed through (no hit)")


# --- Resolution: vulnerable hero -> damage AND consumed ----------------------

func test_vulnerable_hero_takes_damage_and_consumes_projectile() -> void:
	var proj := _make_projectile()
	var hero := FakeHero.new()
	add_child_autofree(hero)
	hero.invulnerable = false

	proj.resolve_hit(hero)

	assert_eq(hero.damage_taken, 12.0,
		"a vulnerable hero takes the projectile's damage")
	assert_true(proj.is_queued_for_deletion(),
		"the projectile is consumed (freed) on a landed hit")


# --- Resolution: invulnerable hero -> no damage AND not consumed -------------

func test_invulnerable_hero_takes_no_damage_and_projectile_passes_through() -> void:
	var proj := _make_projectile()
	var hero := FakeHero.new()
	add_child_autofree(hero)
	hero.invulnerable = true

	proj.resolve_hit(hero)

	assert_eq(hero.damage_taken, 0.0,
		"an invulnerable hero takes no damage")
	assert_false(proj.is_queued_for_deletion(),
		"the projectile passes through (not consumed) during i-frames")


# --- TASK-016: hit direction is threaded into take_player_damage -------------

func test_resolve_hit_threads_travel_direction_into_damage() -> void:
	var proj := _make_projectile()
	# setup() normalizes the aim into _velocity; the travel direction is RIGHT.
	proj.setup(Vector2.RIGHT, 12.0)
	var hero := FakeHero.new()
	add_child_autofree(hero)
	hero.invulnerable = false

	proj.resolve_hit(hero)

	assert_eq(hero.hit_count, 1, "the hero is hit exactly once")
	assert_almost_eq(hero.last_hit_dir.x, 1.0, 0.0001,
		"the projectile threads its travel direction (RIGHT) into the hit")
	assert_almost_eq(hero.last_hit_dir.y, 0.0, 0.0001,
		"the threaded direction is the normalized travel vector")
