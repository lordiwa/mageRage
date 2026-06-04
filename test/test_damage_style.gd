## TASK-010 unit tests for DamageStyle.for_effectiveness (pure, no scene).
##
## DD-006 multipliers 0.5 / 1.0 / 1.5 must map to THREE DISTINCT styles so the
## floating damage number reinforces the armor read:
##  - resisted (<= 0.75): dim + smaller;
##  - neutral  (~ 1.0)  : white + normal;
##  - super    (>= 1.25): bright + larger.
extends GutTest


func test_resisted_tier_is_dim_and_smaller() -> void:
	var style := DamageStyle.for_effectiveness(0.5)   # DD-006 resist
	assert_eq(style["color"], DamageStyle.RESISTED_COLOR,
		"resisted hit uses the dim grey color")
	assert_lt(style["scale"], DamageStyle.NEUTRAL_SCALE,
		"resisted hit is smaller than neutral")


func test_neutral_tier_is_white_and_normal() -> void:
	var style := DamageStyle.for_effectiveness(1.0)   # DD-006 neutral
	assert_eq(style["color"], DamageStyle.NEUTRAL_COLOR,
		"neutral hit uses white")
	assert_eq(style["scale"], DamageStyle.NEUTRAL_SCALE,
		"neutral hit uses the normal scale")


func test_super_effective_tier_is_bright_and_larger() -> void:
	var style := DamageStyle.for_effectiveness(1.5)   # DD-006 weak / super
	assert_eq(style["color"], DamageStyle.SUPER_COLOR,
		"super-effective hit uses the bright color")
	assert_gt(style["scale"], DamageStyle.NEUTRAL_SCALE,
		"super-effective hit is larger than neutral")


func test_three_tiers_are_distinct() -> void:
	var resisted := DamageStyle.for_effectiveness(0.5)
	var neutral := DamageStyle.for_effectiveness(1.0)
	var sup := DamageStyle.for_effectiveness(1.5)
	# Distinct colors.
	assert_ne(resisted["color"], neutral["color"], "resisted vs neutral color differ")
	assert_ne(neutral["color"], sup["color"], "neutral vs super color differ")
	assert_ne(resisted["color"], sup["color"], "resisted vs super color differ")
	# Monotonic scale: resisted < neutral < super.
	assert_lt(resisted["scale"], neutral["scale"], "scale grows resisted->neutral")
	assert_lt(neutral["scale"], sup["scale"], "scale grows neutral->super")
