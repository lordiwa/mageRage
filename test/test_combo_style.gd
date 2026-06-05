## TASK-040 (DD-013) combo readability: ProjectileStyle EXTENDED for the 3 combo
## readouts. Each combo projectile must telegraph as its OWN blended thing — a
## distinct color (and shape) — so a combo never reads as a plain single element.
##
## Color language for combos (kept legible, distinct from the 3 base elements):
##   STEAM    = white-hot (the Ice-then-Fire shatter)
##   PLASMA   = violet/magenta (Fire+Electricity overload)
##   FROSTARC = cyan-white (Ice+Electricity superconductor)
extends GutTest


func test_steam_style_is_white_hot_and_distinct_shape() -> void:
	var style := ProjectileStyle.for_element(SpellData.Element.STEAM)
	assert_eq(style["color"], ProjectileStyle.STEAM_COLOR,
		"STEAM uses the white-hot combo tint")
	assert_eq(style["shape"], ProjectileStyle.SHAPE_STEAM, "STEAM has its own silhouette")


func test_plasma_style_is_violet_magenta_and_distinct_shape() -> void:
	var style := ProjectileStyle.for_element(SpellData.Element.PLASMA)
	assert_eq(style["color"], ProjectileStyle.PLASMA_COLOR,
		"PLASMA uses the violet/magenta combo tint")
	assert_eq(style["shape"], ProjectileStyle.SHAPE_PLASMA, "PLASMA has its own silhouette")


func test_frostarc_style_is_cyan_white_and_distinct_shape() -> void:
	var style := ProjectileStyle.for_element(SpellData.Element.FROSTARC)
	assert_eq(style["color"], ProjectileStyle.FROSTARC_COLOR,
		"FROSTARC uses the cyan-white combo tint")
	assert_eq(style["shape"], ProjectileStyle.SHAPE_FROSTARC,
		"FROSTARC has its own silhouette")


func test_combo_colors_are_distinct_from_the_three_base_elements() -> void:
	var base := [
		ProjectileStyle.FIRE_COLOR, ProjectileStyle.ICE_COLOR,
		ProjectileStyle.ELECTRICITY_COLOR,
	]
	for combo in [ProjectileStyle.STEAM_COLOR, ProjectileStyle.PLASMA_COLOR,
			ProjectileStyle.FROSTARC_COLOR]:
		for b in base:
			assert_ne(combo, b,
				"each combo tint is distinct from the base element tints (legibility)")


func test_all_three_combos_have_distinct_shapes() -> void:
	var steam: int = ProjectileStyle.for_element(SpellData.Element.STEAM)["shape"]
	var plasma: int = ProjectileStyle.for_element(SpellData.Element.PLASMA)["shape"]
	var frost: int = ProjectileStyle.for_element(SpellData.Element.FROSTARC)["shape"]
	var seen := {}
	for s in [steam, plasma, frost]:
		seen[s] = true
	assert_eq(seen.size(), 3, "each combo silhouette is distinct (no two share a shape)")


func test_each_combo_polygon_has_at_least_three_points() -> void:
	for el in [SpellData.Element.STEAM, SpellData.Element.PLASMA,
			SpellData.Element.FROSTARC]:
		var poly := ProjectileStyle.polygon_for(ProjectileStyle.for_element(el)["shape"])
		assert_gte(poly.size(), 3, "combo shape %d yields a renderable polygon" % el)
