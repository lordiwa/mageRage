## DD-010 unit tests for the Warden boss node behavior (instanced, no full arena).
##
## Pure phase/armor/pattern/fan math is covered in test_warden_phases.gd; here we
## exercise the BOSS wiring that needs a live node + Health child:
##   - attack gating: can't fire before the wind-up elapsed; cooldown respected;
##   - the Ice SLOW (DD-009) divides the effective cooldown (slower attacks) and
##     slows the telegraph wind-up;
##   - the live-armor matchup (damage scales by the CURRENT phase armor, DD-006);
##   - phase transitions on crossing a threshold (armor swaps, phase_changed fires);
##   - victory: at <= 0 HP the boss is defeated exactly once and emits `defeated`.
extends GutTest

const FIRE := SpellData.Element.FIRE
const ICE := SpellData.Element.ICE
const ELEC := SpellData.Element.ELECTRICITY


# Build a Warden with a Health child in code (no .tscn) so behavior is testable
# headlessly. A far-off fake target keeps it engaged (huge aggro/attack ranges).
func _make_warden(maxhp := 300.0) -> Warden:
	var boss := Warden.new()
	boss.max_health = maxhp
	var health := Health.new()
	health.name = "Health"
	health.max_health = maxhp
	boss.add_child(health)
	add_child_autofree(boss)        # _ready runs: wires Health, seeds phase 1
	var target := Node2D.new()
	target.global_position = Vector2(100, 0)
	add_child_autofree(target)
	boss.target = target
	return boss


# --- Phase derivation from live HP ------------------------------------------

func test_starts_in_phase_one_with_fire_armor() -> void:
	var boss := _make_warden()
	assert_eq(boss.phase(), 1, "a full-HP Warden starts in Phase 1")
	assert_eq(boss.armor_type(), FIRE, "Phase 1 armor is Fire")
	assert_eq(boss.pattern(), WardenPhases.Pattern.AIMED, "Phase 1 fires the aimed shot")


# --- Live-armor matchup: damage scales by the CURRENT phase armor ------------

func test_electricity_hit_in_phase1_is_super_effective() -> void:
	var boss := _make_warden(300.0)
	# P1 Fire armor weak to Electricity (x1.5): 20 base -> 30 damage.
	boss.apply_elemental_hit(ELEC, 20.0, false)
	var health := boss.get_node("Health") as Health
	var hp := health.current_health
	assert_almost_eq(hp, 270.0, 0.001,
		"Electricity into P1 Fire armor deals x1.5 (300 - 30 = 270)")


func test_fire_hit_in_phase1_is_resisted() -> void:
	var boss := _make_warden(300.0)
	# P1 Fire armor resists Fire (x0.5): 20 base -> 10 damage.
	boss.apply_elemental_hit(FIRE, 20.0, false)
	var health := boss.get_node("Health") as Health
	var hp := health.current_health
	assert_almost_eq(hp, 290.0, 0.001,
		"Fire into P1 Fire armor is resisted x0.5 (300 - 10 = 290)")


# --- Phase transitions: crossing a threshold swaps armor + emits the signal ---

func test_crossing_66_percent_advances_to_phase_two() -> void:
	var boss := _make_warden(300.0)
	watch_signals(boss)
	# Drop just below 66% (198 HP). Use a neutral element to control the number:
	# Ice into Fire armor is neutral x1.0, so 110 base -> 110 damage -> 190 HP (<66%).
	boss.apply_elemental_hit(ICE, 110.0, false)
	assert_eq(boss.phase(), 2, "below 66% HP the Warden is in Phase 2")
	assert_eq(boss.armor_type(), ICE, "Phase 2 armor swaps to Ice")
	assert_eq(boss.pattern(), WardenPhases.Pattern.FAN, "Phase 2 fires the fan")
	assert_signal_emitted(boss, "phase_changed", "a phase change emits phase_changed")


func test_crossing_33_percent_advances_to_phase_three() -> void:
	var boss := _make_warden(300.0)
	# Neutral hits to avoid armor-multiplier surprises across the swap. Drop to ~90 HP.
	boss.apply_elemental_hit(ICE, 110.0, false)    # -> 190 HP, now P2 (Ice armor)
	# In P2 the armor is Ice; Electricity is neutral vs Ice (x1.0). 110 -> 80 HP.
	boss.apply_elemental_hit(ELEC, 110.0, false)   # -> 80 HP (<33% of 300 = 99)
	assert_eq(boss.phase(), 3, "below 33% HP the Warden is in Phase 3")
	assert_eq(boss.armor_type(), ELEC, "Phase 3 armor swaps to Electricity")
	assert_eq(boss.pattern(), WardenPhases.Pattern.SWEEP, "Phase 3 fires the sweep")


# --- Attack gating: cooldown respected (can't spam) --------------------------

func test_cannot_attack_immediately_after_firing() -> void:
	var boss := _make_warden()
	boss.mark_attacked()             # just fired -> _time_since_attack = 0
	assert_false(boss.can_attack(),
		"the boss cannot fire again with zero time since its last shot")


func test_can_attack_after_full_cooldown() -> void:
	var boss := _make_warden()
	boss.mark_attacked()
	# Advance the cooldown timer past the phase-1 cadence.
	boss._physics_process(boss.cooldown_p1 + 0.01)
	assert_true(boss.can_attack(),
		"the boss can fire once the full phase cooldown has elapsed")


func test_defeated_boss_cannot_attack() -> void:
	var boss := _make_warden(50.0)
	boss.apply_elemental_hit(ICE, 100.0, false)   # lethal (neutral vs Fire) -> 0 HP
	boss._physics_process(10.0)                   # plenty of cooldown
	assert_false(boss.can_attack(),
		"a defeated Warden never attacks again")


# --- Telegraph gating: the wind-up must elapse before the shot ---------------

func test_telegraph_not_elapsed_before_windup() -> void:
	var boss := _make_warden()
	# Phase 1 wind-up is windup_p1; partway through it the shot must not be ready.
	assert_false(DroneAi.telegraph_elapsed(boss.windup_p1 * 0.5, boss.phase_windup()),
		"the boss cannot fire halfway through its wind-up")


func test_telegraph_elapsed_at_windup_end() -> void:
	var boss := _make_warden()
	assert_true(DroneAi.telegraph_elapsed(boss.phase_windup(), boss.phase_windup()),
		"the boss fires once the full wind-up has elapsed")


# --- Ice SLOW (DD-009): slows movement AND attack rate -----------------------

func test_slow_multiplier_default_is_full() -> void:
	var boss := _make_warden()
	assert_almost_eq(boss.speed_multiplier(), 1.0, 0.001,
		"an un-slowed boss has a 1.0 speed/attack multiplier")


func test_ice_hit_applies_slow() -> void:
	var boss := _make_warden()
	boss.apply_elemental_hit(ICE, 5.0, true)   # slow flag set
	assert_true(boss.is_slowed(), "an Ice hit with the slow flag slows the boss")
	assert_almost_eq(boss.speed_multiplier(), 0.5, 0.001,
		"a slowed boss runs at the 0.5 control multiplier (DD-009)")


func test_slow_lengthens_effective_cooldown() -> void:
	# A slowed boss attacks slower: its effective cooldown is cadence / 0.5 = 2x.
	# After exactly one cadence-worth of time it must NOT yet be able to attack.
	var boss := _make_warden()
	boss.apply_elemental_hit(ICE, 1.0, true)   # slow on (does not reset cooldown by itself)
	boss.mark_attacked()
	boss._slow.apply()                         # keep slow fresh across the tick
	boss._time_since_attack = boss.cooldown_p1 + 0.01   # one normal cadence elapsed
	assert_false(boss.can_attack(),
		"while slowed, one normal cadence is not enough — the boss attacks slower")


# --- Victory: at <= 0 HP the boss is defeated once and emits `defeated` -------

func test_lethal_hit_triggers_defeat_and_signal() -> void:
	var boss := _make_warden(40.0)
	watch_signals(boss)
	# Ice is neutral vs Fire armor (x1.0): 100 base overkills 40 HP -> 0.
	boss.apply_elemental_hit(ICE, 100.0, false)
	assert_true(boss.is_defeated(), "a lethal hit defeats the Warden")
	assert_signal_emitted(boss, "defeated", "defeat emits the `defeated` signal")


func test_defeat_fires_only_once() -> void:
	var boss := _make_warden(40.0)
	watch_signals(boss)
	boss.apply_elemental_hit(ICE, 100.0, false)   # lethal
	# Any further hits are ignored once won (and can't re-emit defeated).
	boss.apply_elemental_hit(ICE, 100.0, false)
	assert_signal_emit_count(boss, "defeated", 1,
		"defeat is latched: `defeated` emits exactly once")
