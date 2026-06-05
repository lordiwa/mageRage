## TASK-040 (DD-013) FIX HIGH-1: combo projectiles must respect the DD-006 armor RPS.
##
## STEAM/PLASMA/FROSTARC are NOT separate matchup entries — a combo resolves its armor
## multiplier THROUGH its two BASE elements (the constituents that formed it), using
## the MEAN of the two base multipliers. So combos are still resisted / bonused like
## any element (NEVER above the RPS — that is reserved for Antimatter). The derivation
## is a PURE, deterministic, commutative function on ElementMatchup.
##
## STEAM   = Fire+Ice   ; PLASMA = Fire+Elec ; FROSTARC = Ice+Elec
extends GutTest

const FIRE := SpellData.Element.FIRE
const ICE := SpellData.Element.ICE
const ELEC := SpellData.Element.ELECTRICITY
const STEAM := SpellData.Element.STEAM
const PLASMA := SpellData.Element.PLASMA
const FROSTARC := SpellData.Element.FROSTARC


# --- combo_components: the pure, commutative base-element decomposition -------

func test_combo_components_decomposes_each_combo_to_its_two_base_elements() -> void:
	assert_eq(ElementMatchup.combo_components(STEAM), [FIRE, ICE], "STEAM = Fire+Ice")
	assert_eq(ElementMatchup.combo_components(PLASMA), [FIRE, ELEC], "PLASMA = Fire+Elec")
	assert_eq(ElementMatchup.combo_components(FROSTARC), [ICE, ELEC], "FROSTARC = Ice+Elec")


func test_combo_components_of_a_base_element_is_itself() -> void:
	for el in [FIRE, ICE, ELEC]:
		assert_eq(ElementMatchup.combo_components(el), [el],
			"a base element decomposes to just itself (single matchup)")


# --- a combo's multiplier = MEAN of its two base-element multipliers ----------

func test_steam_multiplier_is_mean_of_fire_and_ice() -> void:
	for armor in [FIRE, ICE, ELEC]:
		var expected := (ElementMatchup.multiplier(FIRE, armor)
			+ ElementMatchup.multiplier(ICE, armor)) / 2.0
		assert_almost_eq(ElementMatchup.multiplier(STEAM, armor), expected, 0.0001,
			"STEAM multiplier vs armor %d is the mean of Fire+Ice" % armor)


func test_plasma_multiplier_is_mean_of_fire_and_elec() -> void:
	for armor in [FIRE, ICE, ELEC]:
		var expected := (ElementMatchup.multiplier(FIRE, armor)
			+ ElementMatchup.multiplier(ELEC, armor)) / 2.0
		assert_almost_eq(ElementMatchup.multiplier(PLASMA, armor), expected, 0.0001,
			"PLASMA multiplier vs armor %d is the mean of Fire+Elec" % armor)


func test_frostarc_multiplier_is_mean_of_ice_and_elec() -> void:
	for armor in [FIRE, ICE, ELEC]:
		var expected := (ElementMatchup.multiplier(ICE, armor)
			+ ElementMatchup.multiplier(ELEC, armor)) / 2.0
		assert_almost_eq(ElementMatchup.multiplier(FROSTARC, armor), expected, 0.0001,
			"FROSTARC multiplier vs armor %d is the mean of Ice+Elec" % armor)


# --- combos are NEVER above the RPS (no free pass) ---------------------------

func test_no_combo_ever_exceeds_the_weak_bonus() -> void:
	# A combo can never beat a perfectly-correct single's x1.5 weakness bonus: the
	# mean of two base mults is capped by the larger, and at most one base is x1.5.
	for combo in [STEAM, PLASMA, FROSTARC]:
		for armor in [FIRE, ICE, ELEC]:
			assert_lte(ElementMatchup.multiplier(combo, armor), ElementMatchup.WEAK,
				"combo %d vs armor %d never exceeds the x1.5 weak bonus" % [combo, armor])


func test_each_combo_is_resisted_by_one_armor_and_bonused_by_another() -> void:
	# A combo built from one resisted + one neutral/weak base reads as a real matchup:
	# it has a WORST armor (mean < neutral) and a BEST armor (mean > neutral), so the
	# RPS still matters for combos (they are not flat-neutral everywhere).
	for combo in [STEAM, PLASMA, FROSTARC]:
		var muls := []
		for armor in [FIRE, ICE, ELEC]:
			muls.append(ElementMatchup.multiplier(combo, armor))
		muls.sort()
		assert_lt(muls[0], ElementMatchup.NEUTRAL,
			"combo %d has an armor it is worse than neutral against" % combo)
		assert_gt(muls[2], ElementMatchup.NEUTRAL,
			"combo %d has an armor it is better than neutral against" % combo)


# --- determinism + commutativity of the derivation ---------------------------

func test_combo_multiplier_is_deterministic() -> void:
	var first := ElementMatchup.multiplier(STEAM, ICE)
	for _i in range(20):
		assert_eq(ElementMatchup.multiplier(STEAM, ICE), first,
			"the combo multiplier is a pure, repeatable function")


func test_apply_scales_base_through_the_combo_matchup() -> void:
	# apply() must route combo damage through the derived multiplier (impact path).
	var base := 40.0
	var expected := base * ElementMatchup.multiplier(STEAM, ICE)
	assert_almost_eq(ElementMatchup.apply(base, STEAM, ICE), expected, 0.0001,
		"apply() scales combo base damage by the derived (mean) matchup")
