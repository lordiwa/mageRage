## TASK-014 unit tests for ProjectileStyle.for_element (pure, no scene).
##
## Combat readability doctrine ("Readable VFX over noise"): a player projectile
## must telegraph its element at a glance in BOTH color and silhouette. The pure
## mapping ProjectileStyle.for_element(element) -> {color, shape} is the single
## source of truth the projectile reads in setup(). Tests pin:
##  - each element maps to its color-language tint (Fire warm, Ice cold cyan,
##    Electricity arc yellow, Antimatter violet);
##  - each element maps to a DISTINCT shape id (color alone is not enough);
##  - an out-of-range element falls back to a safe default style.
extends GutTest


func test_fire_style_is_warm_and_distinct_shape() -> void:
	var style := ProjectileStyle.for_element(SpellData.Element.FIRE)
	assert_eq(style["color"], ProjectileStyle.FIRE_COLOR,
		"Fire uses the warm orange tint of the element color language")
	assert_eq(style["shape"], ProjectileStyle.SHAPE_FIRE,
		"Fire uses the rounded/teardrop bolt silhouette")


func test_ice_style_is_cold_and_distinct_shape() -> void:
	var style := ProjectileStyle.for_element(SpellData.Element.ICE)
	assert_eq(style["color"], ProjectileStyle.ICE_COLOR,
		"Ice uses the cold cyan tint of the element color language")
	assert_eq(style["shape"], ProjectileStyle.SHAPE_ICE,
		"Ice uses the angular shard silhouette")


func test_electricity_style_is_arc_yellow_and_distinct_shape() -> void:
	var style := ProjectileStyle.for_element(SpellData.Element.ELECTRICITY)
	assert_eq(style["color"], ProjectileStyle.ELECTRICITY_COLOR,
		"Electricity uses the arc-yellow tint of the element color language")
	assert_eq(style["shape"], ProjectileStyle.SHAPE_ELECTRICITY,
		"Electricity uses the jagged/arc silhouette")


func test_antimatter_style_is_violet_and_distinct_shape() -> void:
	var style := ProjectileStyle.for_element(SpellData.Element.ANTIMATTER)
	assert_eq(style["color"], ProjectileStyle.ANTIMATTER_COLOR,
		"Antimatter uses the violet tint of the element color language")
	assert_eq(style["shape"], ProjectileStyle.SHAPE_ANTIMATTER,
		"Antimatter uses its own silhouette")


func test_out_of_range_element_falls_back_to_safe_default() -> void:
	var style := ProjectileStyle.for_element(-1)
	assert_eq(style["color"], ProjectileStyle.DEFAULT_COLOR,
		"an unknown element uses the safe default color")
	assert_eq(style["shape"], ProjectileStyle.DEFAULT_SHAPE,
		"an unknown element uses the safe default shape")


func test_color_language_matches_impact_spark_source_of_truth() -> void:
	# The cast/impact juice and the projectile body must speak the SAME element
	# color language, so a shot and its hit read as one element.
	assert_eq(ProjectileStyle.FIRE_COLOR, Color(1.0, 0.55, 0.20, 1.0),
		"Fire tint matches the established color language")
	assert_eq(ProjectileStyle.ICE_COLOR, Color(0.45, 0.80, 1.0, 1.0),
		"Ice tint matches the established color language")
	assert_eq(ProjectileStyle.ELECTRICITY_COLOR, Color(1.0, 0.95, 0.35, 1.0),
		"Electricity tint matches the established color language")
	assert_eq(ProjectileStyle.ANTIMATTER_COLOR, Color(0.75, 0.35, 1.0, 1.0),
		"Antimatter tint matches the established color language")


func test_all_four_elements_have_distinct_shapes() -> void:
	var fire: int = ProjectileStyle.for_element(SpellData.Element.FIRE)["shape"]
	var ice: int = ProjectileStyle.for_element(SpellData.Element.ICE)["shape"]
	var elec: int = ProjectileStyle.for_element(SpellData.Element.ELECTRICITY)["shape"]
	var anti: int = ProjectileStyle.for_element(SpellData.Element.ANTIMATTER)["shape"]
	var shapes := [fire, ice, elec, anti]
	# A set built from the four shape ids must still have four members.
	var seen := {}
	for s in shapes:
		seen[s] = true
	assert_eq(seen.size(), 4, "each element silhouette is distinct (no two share a shape)")


func test_each_element_polygon_has_at_least_three_points() -> void:
	# The silhouette must be a real polygon (a renderable triangle+), not a stub.
	for el in [SpellData.Element.FIRE, SpellData.Element.ICE,
			SpellData.Element.ELECTRICITY, SpellData.Element.ANTIMATTER]:
		var poly := ProjectileStyle.polygon_for(ProjectileStyle.for_element(el)["shape"])
		assert_gte(poly.size(), 3,
			"shape %d yields a polygon with >= 3 vertices" % el)
