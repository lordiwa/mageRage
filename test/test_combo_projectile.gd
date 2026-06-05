## TASK-040 (DD-013) the COMBO projectile spawns via the SAME pooled path and
## carries the combo element / shot_type / effect + the combo color (ProjectileStyle).
## Pooled reuse must reset cleanly so a combo never leaks into a later single shot.
extends GutTest

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")


func _make_projectile() -> Projectile:
	var p := PROJECTILE_SCENE.instantiate()
	add_child_autofree(p)
	return p


func _combo(path: String) -> SpellData:
	return load(path) as SpellData


# --- each combo projectile carries its element + combo color/shape -----------

func test_steam_projectile_carries_steam_element_and_color() -> void:
	var p := _make_projectile()
	p.setup(_combo("res://resources/spells/combo_steam.tres"), Vector2.RIGHT)
	assert_eq(p.element, SpellData.Element.STEAM, "the spawned projectile is a STEAM combo")
	assert_eq(p.visual_color(), ProjectileStyle.STEAM_COLOR, "it wears the white-hot tint")
	assert_eq(p.visual_shape(), ProjectileStyle.SHAPE_STEAM, "it wears the STEAM silhouette")


func test_plasma_projectile_carries_plasma_element_and_color() -> void:
	var p := _make_projectile()
	p.setup(_combo("res://resources/spells/combo_plasma.tres"), Vector2.RIGHT)
	assert_eq(p.element, SpellData.Element.PLASMA, "the spawned projectile is a PLASMA combo")
	assert_eq(p.visual_color(), ProjectileStyle.PLASMA_COLOR, "it wears the violet/magenta tint")


func test_frostarc_projectile_chains_and_slows() -> void:
	var p := _make_projectile()
	p.setup(_combo("res://resources/spells/combo_frostarc.tres"), Vector2.RIGHT)
	assert_eq(p.element, SpellData.Element.FROSTARC, "the spawned projectile is a FROSTARC combo")
	assert_eq(p.shot_type, SpellData.ShotType.CHAIN, "FROSTARC chains like Electricity")
	assert_true(p.applies_slow, "FROSTARC carries the Ice slow (Superconductor)")
	assert_eq(p.visual_color(), ProjectileStyle.FROSTARC_COLOR, "it wears the cyan-white tint")


# --- pooled reuse: a combo must not bleed into a later single shot -----------

func test_reusing_a_combo_projectile_as_a_single_resets_cleanly() -> void:
	var p := _make_projectile()
	p.setup(_combo("res://resources/spells/combo_frostarc.tres"), Vector2.RIGHT)
	assert_true(p.applies_slow, "first life: FROSTARC slows")
	# Reuse the SAME instance as a plain Fire single (no slow, SINGLE shot).
	var fire := SpellData.new()
	fire.element = SpellData.Element.FIRE
	fire.applies_slow = false
	fire.max_targets = 1
	fire.shot_type = SpellData.ShotType.SINGLE
	p.setup(fire, Vector2.RIGHT)
	assert_eq(p.element, SpellData.Element.FIRE, "reused instance becomes a Fire single")
	assert_false(p.applies_slow, "no stale FROSTARC slow leaks into the reused single")
	assert_eq(p.visual_color(), ProjectileStyle.FIRE_COLOR, "reused instance restyles to Fire")
