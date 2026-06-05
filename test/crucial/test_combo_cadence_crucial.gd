## CRUCIAL CORE (TASK-049) — group J: dual-cast combo cadence/cost/window (TASK-040).
##
## The 7 reviewer-curated combo-cadence invariants lifted verbatim from
## test/test_combo_cadence.gd with its full before_each setup (real combo .tres so the
## spawn path / element / costs match production). Deterministic (time = delta fed in),
## no physics-frame await -> no Input-edge flake surface. The full nightly suite still
## runs all 17 methods under res://test.
extends GutTest

var mgr: MagicManager
var mana: Mana
var fire: SpellData
var ice: SpellData
var steam: SpellData
var plasma: SpellData
var frostarc: SpellData
var origin: Node2D

const FIRE_COST := 4.0
const ICE_COST := 3.0


func before_each() -> void:
	fire = SpellData.new()
	fire.display_name = "Firebolt"
	fire.element = SpellData.Element.FIRE
	fire.mana_cost = FIRE_COST
	fire.fire_interval = 0.18

	ice = SpellData.new()
	ice.display_name = "Ice Shard"
	ice.element = SpellData.Element.ICE
	ice.mana_cost = ICE_COST
	ice.fire_interval = 0.40

	# Real combo .tres so the spawn path / element / costs match production.
	steam = load("res://resources/spells/combo_steam.tres") as SpellData
	plasma = load("res://resources/spells/combo_plasma.tres") as SpellData
	frostarc = load("res://resources/spells/combo_frostarc.tres") as SpellData

	mana = Mana.new()
	mana.max_mana = 1000.0
	mana.regen_per_second = 0.0
	add_child_autofree(mana)
	mana.current_mana = 1000.0

	mgr = MagicManager.new()
	mgr.spells = [fire, ice]   # primary=fire, secondary=ice
	mgr.mana = mana
	add_child_autofree(mgr)

	origin = Node2D.new()
	add_child_autofree(origin)


func test_combo_fired_carries_the_blended_combo_spell() -> void:
	# primary=fire, secondary=ice -> STEAM combo.
	var captured := [null]
	mgr.combo_fired.connect(func(spell: SpellData) -> void: captured[0] = spell)
	mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, 0.001)
	assert_not_null(captured[0], "combo_fired carried a spell")
	assert_eq(captured[0].element, SpellData.Element.STEAM,
		"Fire+Ice fires the STEAM combo spell, not a single element")


func test_combo_spends_both_elements_mana() -> void:
	mana.current_mana = 100.0
	mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, 0.001)
	# A combo costs AT LEAST the sum of both element costs (a premium is allowed).
	var spent := 100.0 - mana.current_mana
	assert_gte(spent, FIRE_COST + ICE_COST,
		"a combo spends at least both elements' mana (sum or a premium)")
	assert_gt(spent, FIRE_COST,
		"a combo costs strictly more than a single primary shot (anti-dominance)")


func test_combo_does_not_fire_with_insufficient_combined_mana() -> void:
	# Enough for one single (fire=4) but NOT for the combo (>= 7). It must not fire.
	mana.current_mana = FIRE_COST + 0.5   # 4.5 < 7
	var r := mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, 0.001)
	assert_false(r["shot"], "a combo does NOT fire when combined mana can't pay for it")
	assert_eq(mana.current_mana, FIRE_COST + 0.5,
		"a blocked combo spends NO mana (all-or-nothing)")


func test_combo_cadence_is_slower_than_either_single_interval() -> void:
	assert_gt(mgr.combo_interval(fire, ice), fire.fire_interval,
		"the combo cadence is slower than the fast (Fire) single interval")
	assert_gt(mgr.combo_interval(fire, ice), ice.fire_interval,
		"the combo cadence is slower than the slow (Ice) single interval")


func test_second_trigger_after_window_does_not_combo() -> void:
	# Primary held alone for LONGER than the window, THEN secondary arrives: the
	# window lapsed, so this frame is treated as singles, not a combo.
	mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, false, mgr.combo_window() * 2.0)
	var r := mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, 0.001)
	assert_false(r["shot"],
		"a secondary that arrives AFTER the window lapsed does not retro-combo this frame")


func test_same_element_both_slots_fires_exactly_one_empowered_shot() -> void:
	# HIGH-2 fix: same element + both triggers must FIRE one empowered shot (and
	# suppress the second single) — NOT a no-op that lets two full singles through.
	mgr.secondary = fire
	watch_signals(mgr)
	var r := mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, 0.001)
	assert_true(r["shot"], "an empowered same-element dual-trigger actually fires")
	assert_eq(r["kind"], ComboTable.KIND_EMPOWERED, "and it reports the EMPOWERED kind")
	assert_signal_emitted(mgr, "combo_fired",
		"the empowered shot fires through the combo path (one shot, suppresses singles)")


func test_empowered_shot_is_scaled_by_the_empowered_multiplier() -> void:
	# The single empowered shot carries ~1.5x the element's damage — one BIGGER shot,
	# never two identical projectiles.
	mgr.secondary = fire
	var captured := [null]
	mgr.combo_fired.connect(func(spell: SpellData) -> void: captured[0] = spell)
	mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, 0.001)
	assert_not_null(captured[0], "combo_fired carried the empowered spell")
	assert_eq(captured[0].element, SpellData.Element.FIRE,
		"the empowered shot keeps the element (it is a bigger Fire shot)")
	assert_almost_eq(captured[0].damage, fire.damage * ComboTable.EMPOWERED_MULTIPLIER, 0.001,
		"the empowered shot deals ~1.5x the single's damage")
