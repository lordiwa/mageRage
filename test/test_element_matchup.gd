## Unit tests for the DD-006 element-vs-armor matchup table (pure logic, no scene).
##
## Binding rule (docs/DECISIONES-DISENO.md DD-006): a drone armored in element X
## RESISTS X (x0.5) and is WEAK to its counter (x1.5); the third element is
## NEUTRAL (x1.0). Counter cycle: Electricity -> Fire -> Ice -> Electricity, i.e.
## the element listed beats the armor whose counter it is.
##   - Fire armor : Fire x0.5, Electricity x1.5, Ice x1.0
##   - Ice armor  : Ice x0.5,  Fire x1.5,        Electricity x1.0
##   - Elec armor : Elec x0.5, Ice x1.5,         Fire x1.0
## All 9 (spell element x armor) pairs are asserted so the table can never silently
## drift. ElementMatchup.multiplier() is a pure function; damage = base * multiplier.
extends GutTest

const FIRE := SpellData.Element.FIRE
const ICE := SpellData.Element.ICE
const ELEC := SpellData.Element.ELECTRICITY


# --- Resist (x0.5): same element as the armor ------------------------------

func test_fire_vs_fire_armor_resisted() -> void:
	assert_eq(ElementMatchup.multiplier(FIRE, FIRE), 0.5,
		"Fire armor resists Fire")


func test_ice_vs_ice_armor_resisted() -> void:
	assert_eq(ElementMatchup.multiplier(ICE, ICE), 0.5,
		"Ice armor resists Ice")


func test_elec_vs_elec_armor_resisted() -> void:
	assert_eq(ElementMatchup.multiplier(ELEC, ELEC), 0.5,
		"Electric armor resists Electricity")


# --- Weak (x1.5): the armor's counter --------------------------------------

func test_elec_vs_fire_armor_weak() -> void:
	assert_eq(ElementMatchup.multiplier(ELEC, FIRE), 1.5,
		"Fire armor is weak to Electricity")


func test_fire_vs_ice_armor_weak() -> void:
	assert_eq(ElementMatchup.multiplier(FIRE, ICE), 1.5,
		"Ice armor is weak to Fire")


func test_ice_vs_elec_armor_weak() -> void:
	assert_eq(ElementMatchup.multiplier(ICE, ELEC), 1.5,
		"Electric armor is weak to Ice")


# --- Neutral (x1.0): the third element -------------------------------------

func test_ice_vs_fire_armor_neutral() -> void:
	assert_eq(ElementMatchup.multiplier(ICE, FIRE), 1.0,
		"Ice is neutral against Fire armor")


func test_elec_vs_ice_armor_neutral() -> void:
	assert_eq(ElementMatchup.multiplier(ELEC, ICE), 1.0,
		"Electricity is neutral against Ice armor")


func test_fire_vs_elec_armor_neutral() -> void:
	assert_eq(ElementMatchup.multiplier(FIRE, ELEC), 1.0,
		"Fire is neutral against Electric armor")


# --- Applied damage helper -------------------------------------------------

func test_damage_after_matchup_scales_base() -> void:
	# 20 base, Fire vs Ice armor (weak) -> 30.
	assert_eq(ElementMatchup.apply(20.0, FIRE, ICE), 30.0,
		"apply() should scale base damage by the matchup multiplier")
	# 20 base, Fire vs Fire armor (resist) -> 10.
	assert_eq(ElementMatchup.apply(20.0, FIRE, FIRE), 10.0,
		"resisted hit halves base damage")
