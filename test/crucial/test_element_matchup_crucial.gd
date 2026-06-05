## CRUCIAL CORE (TASK-049) — group H: element-vs-armor RPS (DD-006).
##
## The 4 reviewer-curated matchup guards (resist / weak / neutral + applied scaling)
## lifted verbatim from test/test_element_matchup.gd. Pure function, no scene.
## The full nightly suite still runs ALL 9-pair coverage under res://test.
extends GutTest

const FIRE := SpellData.Element.FIRE
const ICE := SpellData.Element.ICE
const ELEC := SpellData.Element.ELECTRICITY


func test_fire_vs_fire_armor_resisted() -> void:
	assert_eq(ElementMatchup.multiplier(FIRE, FIRE), 0.5,
		"Fire armor resists Fire")


func test_elec_vs_fire_armor_weak() -> void:
	assert_eq(ElementMatchup.multiplier(ELEC, FIRE), 1.5,
		"Fire armor is weak to Electricity")


func test_ice_vs_fire_armor_neutral() -> void:
	assert_eq(ElementMatchup.multiplier(ICE, FIRE), 1.0,
		"Ice is neutral against Fire armor")


func test_damage_after_matchup_scales_base() -> void:
	# 20 base, Fire vs Ice armor (weak) -> 30.
	assert_eq(ElementMatchup.apply(20.0, FIRE, ICE), 30.0,
		"apply() should scale base damage by the matchup multiplier")
	# 20 base, Fire vs Fire armor (resist) -> 10.
	assert_eq(ElementMatchup.apply(20.0, FIRE, FIRE), 10.0,
		"resisted hit halves base damage")
