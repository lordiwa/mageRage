## CRUCIAL CORE (TASK-049) — group I (combo RPS): TASK-040 / DD-013.
##
## The 3 reviewer-curated combo-matchup guards (mean derivation, no-combo-exceeds-weak,
## each combo resisted/bonused) lifted verbatim from test/test_combo_matchup.gd. Pure
## function, no scene. The full nightly suite still runs the rest under res://test.
extends GutTest

const FIRE := SpellData.Element.FIRE
const ICE := SpellData.Element.ICE
const ELEC := SpellData.Element.ELECTRICITY
const STEAM := SpellData.Element.STEAM
const PLASMA := SpellData.Element.PLASMA
const FROSTARC := SpellData.Element.FROSTARC


func test_steam_multiplier_is_mean_of_fire_and_ice() -> void:
	for armor in [FIRE, ICE, ELEC]:
		var expected := (ElementMatchup.multiplier(FIRE, armor)
			+ ElementMatchup.multiplier(ICE, armor)) / 2.0
		assert_almost_eq(ElementMatchup.multiplier(STEAM, armor), expected, 0.0001,
			"STEAM multiplier vs armor %d is the mean of Fire+Ice" % armor)


func test_no_combo_ever_exceeds_the_weak_bonus() -> void:
	for combo in [STEAM, PLASMA, FROSTARC]:
		for armor in [FIRE, ICE, ELEC]:
			assert_lte(ElementMatchup.multiplier(combo, armor), ElementMatchup.WEAK,
				"combo %d vs armor %d never exceeds the x1.5 weak bonus" % [combo, armor])


func test_each_combo_is_resisted_by_one_armor_and_bonused_by_another() -> void:
	for combo in [STEAM, PLASMA, FROSTARC]:
		var muls := []
		for armor in [FIRE, ICE, ELEC]:
			muls.append(ElementMatchup.multiplier(combo, armor))
		muls.sort()
		assert_lt(muls[0], ElementMatchup.NEUTRAL,
			"combo %d has an armor it is worse than neutral against" % combo)
		assert_gt(muls[2], ElementMatchup.NEUTRAL,
			"combo %d has an armor it is better than neutral against" % combo)
