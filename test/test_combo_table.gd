## TASK-040 (M2.1) DUAL-CAST ELEMENT MIXING / COMBO (DD-013) — pure mapping tests.
##
## Pressing BOTH triggers fires ONE blended COMBO projectile that combines the two
## equipped elements. The element->element->combo mapping is a PURE, deterministic
## (DD-001) static helper (ComboTable), mirroring how AimAssist is a pure helper:
## no RNG, no node lookups, no hidden state — same inputs, same combo.
##
## Combo table (ANTIMATTER excluded — it is the separate DD-002 ultimate):
##   Fire + Ice         = STEAM   (white-hot thermal-shock burst)
##   Fire + Electricity = PLASMA  (violet explosive arc + small AoE)
##   Ice  + Electricity = FROSTARC (cyan-white chilled chain that slows)
##   same element both slots = NO combo -> empowered single shot (~1.5x)
##   ANTIMATTER in either slot = NO combo -> falls back to single
##
## ComboTable.combo_for(a, b) returns a ComboResult:
##   .kind == ComboTable.KIND_COMBO     -> .spell is the blended combo SpellData
##   .kind == ComboTable.KIND_EMPOWERED -> same-element: empower the single shot
##   .kind == ComboTable.KIND_NONE      -> no blend (Antimatter): plain single
## Commutative: combo_for(a, b) == combo_for(b, a) for every pair.
extends GutTest

const FIRE := SpellData.Element.FIRE
const ICE := SpellData.Element.ICE
const ELEC := SpellData.Element.ELECTRICITY
const ANTI := SpellData.Element.ANTIMATTER


# --- the three combos exist as loadable SpellData .tres ----------------------

func test_steam_combo_tres_loads_as_spelldata() -> void:
	var s := load("res://resources/spells/combo_steam.tres") as SpellData
	assert_not_null(s, "combo_steam.tres loads as SpellData")
	assert_eq(s.element, SpellData.Element.STEAM, "STEAM combo carries the STEAM element")


func test_plasma_combo_tres_loads_as_spelldata() -> void:
	var s := load("res://resources/spells/combo_plasma.tres") as SpellData
	assert_not_null(s, "combo_plasma.tres loads as SpellData")
	assert_eq(s.element, SpellData.Element.PLASMA, "PLASMA combo carries the PLASMA element")


func test_frostarc_combo_tres_loads_as_spelldata() -> void:
	var s := load("res://resources/spells/combo_frostarc.tres") as SpellData
	assert_not_null(s, "combo_frostarc.tres loads as SpellData")
	assert_eq(s.element, SpellData.Element.FROSTARC,
		"FROSTARC combo carries the FROSTARC element")


# --- mapping: each pair yields its combo (and is COMMUTATIVE) ----------------

func test_fire_plus_ice_is_steam_both_orders() -> void:
	var ab := ComboTable.combo_for(FIRE, ICE)
	var ba := ComboTable.combo_for(ICE, FIRE)
	assert_eq(ab.kind, ComboTable.KIND_COMBO, "Fire+Ice blends to a combo")
	assert_eq(ab.spell.element, SpellData.Element.STEAM, "Fire+Ice -> STEAM")
	assert_eq(ba.spell.element, SpellData.Element.STEAM, "Ice+Fire -> STEAM (commutative)")
	assert_eq(ab.spell, ba.spell, "Fire+Ice and Ice+Fire return the SAME combo SpellData")


func test_fire_plus_electricity_is_plasma_both_orders() -> void:
	var ab := ComboTable.combo_for(FIRE, ELEC)
	var ba := ComboTable.combo_for(ELEC, FIRE)
	assert_eq(ab.kind, ComboTable.KIND_COMBO, "Fire+Electricity blends to a combo")
	assert_eq(ab.spell.element, SpellData.Element.PLASMA, "Fire+Electricity -> PLASMA")
	assert_eq(ba.spell.element, SpellData.Element.PLASMA,
		"Electricity+Fire -> PLASMA (commutative)")
	assert_eq(ab.spell, ba.spell, "both orders return the SAME combo SpellData")


func test_ice_plus_electricity_is_frostarc_both_orders() -> void:
	var ab := ComboTable.combo_for(ICE, ELEC)
	var ba := ComboTable.combo_for(ELEC, ICE)
	assert_eq(ab.kind, ComboTable.KIND_COMBO, "Ice+Electricity blends to a combo")
	assert_eq(ab.spell.element, SpellData.Element.FROSTARC, "Ice+Electricity -> FROSTARC")
	assert_eq(ba.spell.element, SpellData.Element.FROSTARC,
		"Electricity+Ice -> FROSTARC (commutative)")
	assert_eq(ab.spell, ba.spell, "both orders return the SAME combo SpellData")


# --- same element both slots -> empowered single, NOT a combo projectile -----

func test_same_element_is_empowered_single_not_a_combo() -> void:
	for el in [FIRE, ICE, ELEC]:
		var r := ComboTable.combo_for(el, el)
		assert_eq(r.kind, ComboTable.KIND_EMPOWERED,
			"same element both slots -> EMPOWERED single, not a combo (element %d)" % el)
		assert_null(r.spell, "an empowered single carries no separate combo SpellData")


func test_empowered_multiplier_is_above_one_and_tunable() -> void:
	# The empowered single is stronger than one shot but is NOT two shots.
	assert_gt(ComboTable.EMPOWERED_MULTIPLIER, 1.0,
		"empowered single hits harder than a plain single (~1.5x)")
	assert_lt(ComboTable.EMPOWERED_MULTIPLIER, 2.0,
		"empowered single is LESS than two full shots (it is one bigger shot)")


# --- ANTIMATTER excluded: never blends ---------------------------------------

func test_antimatter_in_either_slot_never_combos() -> void:
	for other in [FIRE, ICE, ELEC, ANTI]:
		var r1 := ComboTable.combo_for(ANTI, other)
		var r2 := ComboTable.combo_for(other, ANTI)
		assert_ne(r1.kind, ComboTable.KIND_COMBO,
			"Antimatter never blends into a combo (Anti+%d)" % other)
		assert_ne(r2.kind, ComboTable.KIND_COMBO,
			"Antimatter never blends into a combo (%d+Anti)" % other)


func test_antimatter_pairs_fall_back_to_a_single_shot() -> void:
	# Antimatter + a real element -> plain single (NONE), never a combo or empower.
	var r := ComboTable.combo_for(ANTI, FIRE)
	assert_eq(r.kind, ComboTable.KIND_NONE,
		"Antimatter + element -> no blend (plain single shot)")
	assert_null(r.spell, "the fallback single carries no combo SpellData")


# --- determinism (DD-001): same inputs, same result, repeatedly -------------

func test_mapping_is_deterministic_across_repeated_calls() -> void:
	var first := ComboTable.combo_for(FIRE, ELEC).spell
	for _i in range(20):
		assert_eq(ComboTable.combo_for(FIRE, ELEC).spell, first,
			"the pure mapping returns the identical combo SpellData every call")


# --- each combo carries the right ShotType / effect identity -----------------

func test_steam_is_single_target_burst() -> void:
	# Fire+Ice = STEAM / Thermal Shock: heavy SINGLE-target burst.
	var steam := ComboTable.combo_for(FIRE, ICE).spell
	assert_eq(steam.shot_type, SpellData.ShotType.SINGLE,
		"STEAM is a heavy single-target burst (SINGLE shot type)")


func test_frostarc_chains_and_applies_slow() -> void:
	# Ice+Electricity = FROST-ARC: a chilled CHAIN that slows multiple targets.
	var frost := ComboTable.combo_for(ICE, ELEC).spell
	assert_eq(frost.shot_type, SpellData.ShotType.CHAIN,
		"FROSTARC chains like Electricity")
	assert_true(frost.applies_slow, "FROSTARC carries the Ice slow (Superconductor)")
	assert_gt(frost.max_targets, 1, "FROSTARC chains to multiple targets")


func test_plasma_carries_fire_aggression() -> void:
	# Fire+Electricity = PLASMA / Overload: explosive arc with a small AoE.
	var plasma := ComboTable.combo_for(FIRE, ELEC).spell
	assert_gt(plasma.damage, 0.0, "PLASMA deals damage")
	assert_gt(plasma.max_targets, 1, "PLASMA has a small AoE (more than one target)")
