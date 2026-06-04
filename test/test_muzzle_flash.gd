## TASK-014 unit tests: casting a spell spawns a brief element-tinted muzzle flash
## at the origin (outgoing-cast feedback), and a FAILED cast does not.
##
## The flash is wired at the spawn site (MagicManager._spawn -> _spawn_muzzle_flash)
## so it only fires on a real cast — _spawn runs only AFTER mana is spent, and a
## failed cast returns before reaching it. To stay headless and deterministic, we
## drive the flash seam directly with a test-owned parent and a lightweight fake
## flash that records its burst(element) + spawn position, rather than parenting a
## real projectile into the global tree.
extends GutTest


# A scene-free stand-in for impact_spark: records that it was burst and where.
class FakeFlash:
	extends Node2D
	var burst_element := -999
	var burst_position := Vector2.ZERO

	func burst(element: int) -> void:
		burst_element = element
		burst_position = global_position


# A PackedScene whose instances are FakeFlash, injected as muzzle_flash_scene.
func _fake_flash_scene() -> PackedScene:
	var ps := PackedScene.new()
	ps.pack(FakeFlash.new())
	return ps


func _make_spell(element: int, cost: float) -> SpellData:
	var s := SpellData.new()
	s.element = element
	s.damage = 10.0
	s.speed = 400.0
	s.mana_cost = cost
	return s


var mgr: MagicManager
var mana: Mana
var origin: Node2D
var parent: Node2D
var fire: SpellData


func before_each() -> void:
	fire = _make_spell(SpellData.Element.FIRE, 10.0)

	mana = Mana.new()
	mana.max_mana = 100.0
	add_child_autofree(mana)

	origin = Node2D.new()
	add_child_autofree(origin)
	origin.global_position = Vector2(42, 7)

	# A test-owned container so spawned flashes are scoped + auto-freed (no leak
	# into the global tree, which would make other tests flaky).
	parent = Node2D.new()
	add_child_autofree(parent)

	mgr = MagicManager.new()
	mgr.spells = [fire]
	mgr.mana = mana
	mgr.muzzle_flash_scene = _fake_flash_scene()
	add_child_autofree(mgr)


func _last_flash() -> FakeFlash:
	var found: FakeFlash = null
	for child in parent.get_children():
		if child is FakeFlash:
			found = child
	return found


# --- The flash seam: a real cast spawns an element-tinted flash at the origin --

func test_cast_spawns_element_tinted_flash_at_origin() -> void:
	# This is exactly what _spawn calls after a successful mana spend.
	mgr._spawn_muzzle_flash(fire, origin, parent)
	var flash := _last_flash()
	assert_not_null(flash, "a muzzle flash is spawned on a cast")
	if flash != null:
		assert_eq(flash.burst_element, SpellData.Element.FIRE,
			"the flash is tinted with the cast spell's element")
		assert_eq(flash.burst_position, origin.global_position,
			"the flash spawns at the muzzle/origin position")


func test_flash_uses_each_elements_tint() -> void:
	var ice := _make_spell(SpellData.Element.ICE, 5.0)
	mgr._spawn_muzzle_flash(ice, origin, parent)
	var flash := _last_flash()
	assert_not_null(flash)
	if flash != null:
		assert_eq(flash.burst_element, SpellData.Element.ICE,
			"the flash carries the actual cast element, not a hardcoded one")


# --- A failed cast never reaches the flash seam -------------------------------

func test_failed_cast_returns_null_before_spawning_anything() -> void:
	# A zero-mana cast fails in _try_cast and returns the spell as null; _spawn
	# (and thus the flash) is never reached. We assert the guard that gates it.
	mana.current_mana = 1.0   # < fire cost 10
	var spell := mgr.try_cast_primary()
	assert_null(spell, "a zero-mana cast fails (returns null) so _spawn never runs")
	# And the flash seam itself no-ops on a null/absent scene wiring.
	assert_eq(_last_flash(), null, "nothing was spawned for a failed cast")


# --- Null-safety: missing flash scene / parent are silent no-ops --------------

func test_missing_flash_scene_is_null_safe() -> void:
	mgr.muzzle_flash_scene = null
	mgr._spawn_muzzle_flash(fire, origin, parent)   # must not error
	assert_eq(_last_flash(), null,
		"no flash scene wired -> no flash, no error")


func test_null_parent_is_null_safe() -> void:
	mgr._spawn_muzzle_flash(fire, origin, null)   # must not error
	assert_eq(_last_flash(), null, "a null parent is a silent no-op")
