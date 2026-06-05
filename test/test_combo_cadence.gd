## TASK-040 (DD-013) DUAL-CAST COMBO cadence + mana cost on the MagicManager.
##
## Pressing BOTH triggers (within a short window) fires ONE blended COMBO projectile
## via the SAME pooled path — NOT two singles. Anti-dominance cost (so combos can't
## become the only thing the player does, killing the single-element swap RPS):
##   - it fires only when BOTH triggers are held within a short window (~0.12s);
##   - it consumes BOTH elements' mana (a sum/premium) per combo shot;
##   - it fires on a SLOWER combo cadence than either single element's interval.
##
## Pure/deterministic (DD-001): time is the `delta` fed in, no wall-clock/RNG, so
## the same inputs always yield the same combo count.
##
## try_cast_combo_held(origin, dir, primary_held, secondary_held, delta) ->
##   {"shot": bool, "kind": int}. It ticks a COMBO accumulator and, when both
##   triggers are held within the window AND the combo cadence is ready AND both
##   manas afford it, spawns ONE combo projectile, spends BOTH manas, resets the
##   combo cadence and emits combo_fired. Returns shot=true so the player suppresses
##   the two single shots that frame.
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


## Hold BOTH triggers over `seconds` in `step` ticks; return combo shots fired.
func _hold_both(seconds: float, step: float) -> int:
	var shots := 0
	var t := 0.0
	while t < seconds - 0.000001:
		var r := mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, step)
		if r["shot"]:
			shots += 1
		t += step
	return shots


# --- ONE combo, not two singles ---------------------------------------------

func test_both_triggers_fire_one_combo_on_the_first_ready_tick() -> void:
	watch_signals(mgr)
	var r := mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, 0.001)
	assert_true(r["shot"], "both triggers held + ready fires a combo")
	assert_eq(r["kind"], ComboTable.KIND_COMBO, "the blended shot is a real combo")
	assert_signal_emitted(mgr, "combo_fired", "a real combo emits combo_fired")


func test_combo_fired_carries_the_blended_combo_spell() -> void:
	# primary=fire, secondary=ice -> STEAM combo.
	var captured := [null]
	mgr.combo_fired.connect(func(spell: SpellData) -> void: captured[0] = spell)
	mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, 0.001)
	assert_not_null(captured[0], "combo_fired carried a spell")
	assert_eq(captured[0].element, SpellData.Element.STEAM,
		"Fire+Ice fires the STEAM combo spell, not a single element")


# --- combo consumes BOTH manas (more than a single shot) --------------------

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


# --- combo cadence is SLOWER than the single-shot cadence -------------------

func test_combo_cadence_is_slower_than_either_single_interval() -> void:
	assert_gt(mgr.combo_interval(fire, ice), fire.fire_interval,
		"the combo cadence is slower than the fast (Fire) single interval")
	assert_gt(mgr.combo_interval(fire, ice), ice.fire_interval,
		"the combo cadence is slower than the slow (Ice) single interval")


func test_holding_both_fires_fewer_combos_than_holding_one_fires_singles() -> void:
	# Over the same window, combos (slower cadence) must be strictly RARER than the
	# fast single — so spamming combos is time-expensive, not a win button.
	var combo_shots := _hold_both(1.0, 0.005)
	# Reset cadence for an apples-to-apples single-hold count.
	mgr._ready()
	var single_shots := 0
	var t := 0.0
	while t < 1.0 - 0.000001:
		if mgr.try_cast_primary_held(origin, Vector2.RIGHT, true, 0.005):
			single_shots += 1
		t += 0.005
	assert_lt(combo_shots, single_shots,
		"holding both fires FEWER combos than holding one fires singles (slower cadence)")
	assert_gt(combo_shots, 0, "but combos do fire while both are held")


func test_many_sub_interval_combo_ticks_fire_exactly_once() -> void:
	# Ticks summing below the combo interval fire exactly one combo (cadence gates).
	var interval := mgr.combo_interval(fire, ice)
	var shots := _hold_both(interval * 0.5, interval * 0.05)
	assert_eq(shots, 1, "sub-interval combo ticks fire exactly once (cadence gating)")


# --- the dual-trigger WINDOW: both must be held close together --------------

func test_only_one_trigger_held_fires_no_combo() -> void:
	# Primary held, secondary released -> NOT a dual-trigger -> no combo.
	var r := mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, false, 0.001)
	assert_false(r["shot"], "one trigger alone never fires a combo")
	assert_eq(r["kind"], ComboTable.KIND_NONE, "a single trigger is not a combo")


func test_second_trigger_within_window_completes_the_combo() -> void:
	# Press primary first; then the secondary arrives a hair later (within the window)
	# -> the combo fires.
	mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, false, 0.001)
	var r := mgr.try_cast_combo_held(
		origin, Vector2.RIGHT, true, true, mgr.combo_window() * 0.5)
	assert_true(r["shot"], "the second trigger arriving within the window completes the combo")


func test_second_trigger_after_window_does_not_combo() -> void:
	# Primary held alone for LONGER than the window, THEN secondary arrives: the
	# window lapsed, so this frame is treated as singles, not a combo.
	mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, false, mgr.combo_window() * 2.0)
	var r := mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, 0.001)
	assert_false(r["shot"],
		"a secondary that arrives AFTER the window lapsed does not retro-combo this frame")


# --- HIGH-2: same element both slots -> ONE empowered single (NOT two) -------

func test_same_element_both_slots_is_empowered_not_a_blended_combo() -> void:
	# Make both slots Fire: the kind is EMPOWERED (not a STEAM/PLASMA/FROSTARC blend).
	mgr.secondary = fire
	var r := mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, 0.001)
	assert_eq(r["kind"], ComboTable.KIND_EMPOWERED,
		"same element both slots is an EMPOWERED single, not a blended combo")


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


func test_empowered_costs_both_manas_not_free() -> void:
	# An empowered shot is taxed (both manas) so it is NOT a free DPS doubler.
	mgr.secondary = fire
	mana.current_mana = 100.0
	mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, 0.001)
	var spent := 100.0 - mana.current_mana
	assert_gt(spent, FIRE_COST,
		"the empowered shot costs strictly more than one single (taxed, not free)")


func test_empowered_is_on_the_slower_combo_cadence() -> void:
	# Same anti-dominance cadence as a combo: a just-fired empowered is on cooldown,
	# so same-element mashing can't out-rate normal single fire.
	mgr.secondary = fire
	mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, 0.001)   # fires
	var r := mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, 0.001)
	assert_false(r["shot"], "a just-fired empowered shot is on the slower combo cadence")


# --- MEDIUM: holding both is a TRADE, not pure addition ----------------------

func test_holding_both_does_not_out_produce_dedicated_single_play() -> void:
	# Sustained output check: over a window, the combos fired while holding BOTH must
	# be FEWER than the singles fired by dedicated single-trigger play. Holding both
	# trades fast single fire for the slow combo rhythm (you don't get both).
	var combo_shots := _hold_both(1.0, 0.005)
	mgr._ready()
	var single_shots := 0
	var t := 0.0
	while t < 1.0 - 0.000001:
		if mgr.try_cast_primary_held(origin, Vector2.RIGHT, true, 0.005):
			single_shots += 1
		t += 0.005
	assert_lt(combo_shots, single_shots,
		"holding both yields FEWER combos than dedicated single play yields singles")


# --- a real fire resets the combo cadence -----------------------------------

func test_combo_resets_its_cadence_after_firing() -> void:
	mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, 0.001)   # fires
	# Immediately after, a tiny tick is below the combo interval -> no second combo.
	var r := mgr.try_cast_combo_held(origin, Vector2.RIGHT, true, true, 0.001)
	assert_false(r["shot"], "a just-fired combo is on cooldown (cadence reset)")
