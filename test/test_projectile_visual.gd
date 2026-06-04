## TASK-014 unit tests: a player projectile styles itself from the cast spell's
## element so the shot is readable at a glance (color + silhouette).
##
## projectile.setup(spell, dir) already copies element/damage/speed/aim; this adds
## that it also drives the visual from ProjectileStyle.for_element(spell.element).
## We assert the body's Polygon2D reflects the element's color and silhouette, and
## that existing behavior (rotation, velocity, element copy) is untouched.
extends GutTest

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")


func _make_spell(element: int) -> SpellData:
	var s := SpellData.new()
	s.element = element
	s.damage = 10.0
	s.speed = 400.0
	return s


func _make_projectile() -> Projectile:
	var p := PROJECTILE_SCENE.instantiate()
	add_child_autofree(p)   # _ready runs: collision setup + visual node resolve
	return p


func test_setup_applies_fire_color_and_shape() -> void:
	var p := _make_projectile()
	p.setup(_make_spell(SpellData.Element.FIRE), Vector2.RIGHT)
	var style := ProjectileStyle.for_element(SpellData.Element.FIRE)
	assert_eq(p.visual_color(), style["color"],
		"a Fire shot is tinted with the Fire color")
	assert_eq(p.visual_shape(), style["shape"],
		"a Fire shot uses the Fire silhouette")


func test_setup_applies_ice_color_and_shape() -> void:
	var p := _make_projectile()
	p.setup(_make_spell(SpellData.Element.ICE), Vector2.RIGHT)
	var style := ProjectileStyle.for_element(SpellData.Element.ICE)
	assert_eq(p.visual_color(), style["color"],
		"an Ice shot is tinted with the Ice color")
	assert_eq(p.visual_shape(), style["shape"],
		"an Ice shot uses the Ice silhouette")


func test_setup_applies_electricity_color_and_shape() -> void:
	var p := _make_projectile()
	p.setup(_make_spell(SpellData.Element.ELECTRICITY), Vector2.RIGHT)
	var style := ProjectileStyle.for_element(SpellData.Element.ELECTRICITY)
	assert_eq(p.visual_color(), style["color"],
		"an Electricity shot is tinted with the Electricity color")
	assert_eq(p.visual_shape(), style["shape"],
		"an Electricity shot uses the Electricity silhouette")


func test_setup_applies_antimatter_color_and_shape() -> void:
	var p := _make_projectile()
	p.setup(_make_spell(SpellData.Element.ANTIMATTER), Vector2.RIGHT)
	var style := ProjectileStyle.for_element(SpellData.Element.ANTIMATTER)
	assert_eq(p.visual_color(), style["color"],
		"an Antimatter shot is tinted with the Antimatter color")
	assert_eq(p.visual_shape(), style["shape"],
		"an Antimatter shot uses the Antimatter silhouette")


func test_different_elements_yield_different_visuals() -> void:
	var fire := _make_projectile()
	fire.setup(_make_spell(SpellData.Element.FIRE), Vector2.RIGHT)
	var ice := _make_projectile()
	ice.setup(_make_spell(SpellData.Element.ICE), Vector2.RIGHT)
	assert_ne(fire.visual_color(), ice.visual_color(),
		"Fire and Ice shots are different colors")
	assert_ne(fire.visual_shape(), ice.visual_shape(),
		"Fire and Ice shots are different silhouettes")


# --- Regression: styling must not disturb the existing setup() contract -------

func test_setup_still_copies_element_and_aims() -> void:
	var p := _make_projectile()
	p.setup(_make_spell(SpellData.Element.ICE), Vector2.RIGHT)
	assert_eq(p.element, SpellData.Element.ICE, "element is still copied")
	assert_almost_eq(p.rotation, 0.0, 0.0001,
		"rotation still faces the aim (RIGHT -> 0 rad)")
