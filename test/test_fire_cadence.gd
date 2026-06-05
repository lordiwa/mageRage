## TASK-038 (M2.1 combat-feel) hold-to-fire + per-element fire rate.
##
## The MagicManager gains per-SLOT cadence accumulators so a HELD trigger fires
## continuously at the slot element's data-driven `fire_interval` (Fire fastest,
## Ice slowest), gated by mana. The player calls try_cast_primary_held() /
## try_cast_secondary_held(origin, aim, held, delta) every frame: the accumulator
## ticks by delta and a shot fires only when held AND accumulator >= interval AND
## mana affords — then the accumulator resets. A real fire emits `cast_fired` so
## headless tests can count shots without spawning a projectile scene.
##
## Pure/deterministic (DD-001): no randomness, no wall-clock — time is the `delta`
## fed in, so the same inputs always yield the same shot count.
extends GutTest

var mgr: MagicManager
var mana: Mana
var fire: SpellData
var ice: SpellData
var lightning: SpellData
var origin: Node2D

const FIRE_INTERVAL := 0.18
const ELEC_INTERVAL := 0.28
const ICE_INTERVAL := 0.40


func before_each() -> void:
	fire = SpellData.new()
	fire.display_name = "Firebolt"
	fire.element = SpellData.Element.FIRE
	fire.mana_cost = 1.0
	fire.fire_interval = FIRE_INTERVAL

	ice = SpellData.new()
	ice.display_name = "Ice Shard"
	ice.element = SpellData.Element.ICE
	ice.mana_cost = 1.0
	ice.fire_interval = ICE_INTERVAL

	lightning = SpellData.new()
	lightning.display_name = "Lightning"
	lightning.element = SpellData.Element.ELECTRICITY
	lightning.mana_cost = 1.0
	lightning.fire_interval = ELEC_INTERVAL

	mana = Mana.new()
	mana.max_mana = 1000.0
	mana.regen_per_second = 0.0
	add_child_autofree(mana)
	mana.current_mana = 1000.0   # plenty unless a test lowers it

	mgr = MagicManager.new()
	mgr.spells = [fire, ice, lightning]   # primary=fire, secondary=ice
	mgr.mana = mana
	add_child_autofree(mgr)

	origin = Node2D.new()
	add_child_autofree(origin)


## Drive a HELD primary trigger over `seconds` in fixed `step`-second ticks and
## return how many shots actually fired (counting the cast_fired signal).
func _hold_primary(seconds: float, step: float) -> int:
	var shots := 0
	var t := 0.0
	while t < seconds - 0.000001:
		if mgr.try_cast_primary_held(origin, Vector2.RIGHT, true, step):
			shots += 1
		t += step
	return shots


func _hold_secondary(seconds: float, step: float) -> int:
	var shots := 0
	var t := 0.0
	while t < seconds - 0.000001:
		if mgr.try_cast_secondary_held(origin, Vector2.RIGHT, true, step):
			shots += 1
		t += step
	return shots


# --- the held cast actually fires (cast_fired) ------------------------------

func test_held_primary_fires_on_the_first_ready_tick() -> void:
	watch_signals(mgr)
	var fired := mgr.try_cast_primary_held(origin, Vector2.RIGHT, true, 0.001)
	assert_true(fired, "a held primary with mana fires on the first ready tick")
	assert_signal_emitted(mgr, "cast_fired", "a real held cast emits cast_fired")


# --- cadence gates per-frame spam -------------------------------------------

func test_many_small_ticks_within_one_interval_fire_exactly_once() -> void:
	# 10 ticks of 0.01s = 0.10s total, BELOW the 0.18s fire interval. The first
	# (ready) tick fires; the rest are gated. Exactly one shot.
	var shots := _hold_primary(0.10, 0.01)
	assert_eq(shots, 1,
		"many sub-interval ticks fire exactly once (cadence gates per-frame spam)")


func test_not_held_never_fires_even_when_ready() -> void:
	# Accumulator is ready, but the trigger is not held -> no shot, no drain.
	var fired := mgr.try_cast_primary_held(origin, Vector2.RIGHT, false, 1.0)
	assert_false(fired, "a released trigger never fires even when the accumulator is ready")
	assert_eq(mana.current_mana, 1000.0, "no mana is spent while the trigger is released")


# --- cadence count: Fire out-rates Ice over the same window -----------------

func test_held_fire_out_rates_held_ice_over_same_window() -> void:
	# Over 1.0s of small ticks: Fire (0.18) fires more shots than Ice (0.40).
	var fire_shots := _hold_primary(1.0, 0.005)
	# Swap so the primary slot holds ICE, then hold the same window.
	mgr.select(1)   # ice -> primary
	var ice_shots := _hold_primary(1.0, 0.005)
	assert_gt(fire_shots, ice_shots,
		"Fire fires MORE shots than Ice in the same hold window")
	# ~floor(T / I): 1.0/0.18 ~ 5..6 ; 1.0/0.40 ~ 2..3 (first tick is a free shot).
	assert_between(fire_shots, 5, 7, "Fire shot count tracks 1s / 0.18s interval")
	assert_between(ice_shots, 2, 4, "Ice shot count tracks 1s / 0.40s interval")


# --- both slots fire independently ------------------------------------------

func test_both_slots_fire_independently_primary_out_rates_secondary() -> void:
	# primary=fire (0.18), secondary=ice (0.40). Hold BOTH over the same window
	# (interleaved per tick) and confirm primary out-rates secondary.
	var p_shots := 0
	var s_shots := 0
	var t := 0.0
	while t < 1.0 - 0.000001:
		if mgr.try_cast_primary_held(origin, Vector2.RIGHT, true, 0.005):
			p_shots += 1
		if mgr.try_cast_secondary_held(origin, Vector2.RIGHT, true, 0.005):
			s_shots += 1
		t += 0.005
	assert_gt(p_shots, s_shots,
		"holding both, the Fire primary out-rates the Ice secondary (independent slots)")
	assert_gt(p_shots, 0, "the primary slot fired")
	assert_gt(s_shots, 0, "the secondary slot fired")


# --- mana gates the cadence -------------------------------------------------

func test_mana_gates_a_cadence_ready_shot_then_regen_resumes() -> void:
	mana.current_mana = 0.0   # cannot afford fire (cost 1.0)
	var fired := mgr.try_cast_primary_held(origin, Vector2.RIGHT, true, 1.0)
	assert_false(fired, "a cadence-ready shot does NOT fire when mana can't afford it")
	# Refill mana; the very next held tick (still ready) now fires.
	mana.current_mana = 1000.0
	var fired_after := mgr.try_cast_primary_held(origin, Vector2.RIGHT, true, 0.001)
	assert_true(fired_after, "once mana is restored the held cadence resumes firing")


func test_mana_not_spent_when_blocked_by_low_mana() -> void:
	mana.current_mana = 0.0
	mgr.try_cast_primary_held(origin, Vector2.RIGHT, true, 1.0)
	assert_eq(mana.current_mana, 0.0, "a mana-blocked held cast spends nothing")


# --- element swap changes the subsequent cadence ----------------------------

func test_switching_element_changes_cadence_to_slower() -> void:
	# Hold Fire (0.18) for a window, then select Ice and hold the same window:
	# Ice (0.40) must produce strictly fewer shots.
	var fire_shots := _hold_primary(1.0, 0.005)
	mgr.select(1)   # ice -> primary (slower)
	var ice_shots := _hold_primary(1.0, 0.005)
	assert_lt(ice_shots, fire_shots,
		"selecting the slower Ice element lowers the subsequent shot rate")


func test_selecting_an_element_allows_an_immediate_first_shot() -> void:
	# After a select the promoted slot is cadence-ready so the next held tick fires
	# immediately (deterministic, no surprise dead frame).
	mgr.select(2)   # electricity -> primary
	var fired := mgr.try_cast_primary_held(origin, Vector2.RIGHT, true, 0.001)
	assert_true(fired, "a freshly selected primary fires immediately on the next held tick")


# --- secondary cadence honors its own element interval ----------------------

func test_secondary_uses_its_own_element_interval() -> void:
	# secondary = ice (0.40). Over 1.0s it fires the Ice-rate count, independent of
	# the (idle) primary slot.
	var ice_shots := _hold_secondary(1.0, 0.005)
	assert_between(ice_shots, 2, 4, "the secondary slot fires at its own Ice interval")
