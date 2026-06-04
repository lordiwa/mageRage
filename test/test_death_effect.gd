## TASK-017 unit tests for the PURE death-effect tuning selector (no scene).
##
## A higher importance (e.g. boss max_hp) yields a LOUDER death beat than a low one
## (drone): more particles, bigger shake, longer hit-stop, longer dissolve. Per the
## game-design SKILL juice budget the loudest death is reserved for the boss; routine
## drone deaths are modest. The selector clamps to sane floors/caps and never returns
## degenerate (zero/negative) values for a valid enemy.
extends GutTest


# A modest enemy (drone ~60 HP) and a loud one (boss ~300 HP).
const DRONE_HP := 60.0
const BOSS_HP := 300.0


func test_returns_all_expected_keys() -> void:
	var t := DeathEffect.tuning_for(DRONE_HP)
	assert_has(t, "burst_amount", "tuning carries a particle burst_amount")
	assert_has(t, "shake", "tuning carries a screen-shake trauma")
	assert_has(t, "hit_stop", "tuning carries a hit-stop effectiveness")
	assert_has(t, "dissolve_time", "tuning carries a dissolve_time")


func test_boss_is_louder_than_drone_on_every_axis() -> void:
	var drone := DeathEffect.tuning_for(DRONE_HP)
	var boss := DeathEffect.tuning_for(BOSS_HP)
	assert_gt(boss.burst_amount, drone.burst_amount,
		"the boss death bursts more particles than a drone")
	assert_gt(boss.shake, drone.shake,
		"the boss death shakes the camera harder than a drone")
	assert_gt(boss.hit_stop, drone.hit_stop,
		"the boss death freezes longer than a drone")
	assert_gt(boss.dissolve_time, drone.dissolve_time,
		"the boss dissolve lingers longer than a drone")


func test_higher_importance_is_monotonic() -> void:
	# A bigger enemy is never quieter than a smaller one on the loudest axis.
	var small := DeathEffect.tuning_for(40.0)
	var big := DeathEffect.tuning_for(120.0)
	assert_gte(big.shake, small.shake,
		"shake is non-decreasing as importance grows")
	assert_gte(big.burst_amount, small.burst_amount,
		"burst_amount is non-decreasing as importance grows")


func test_drone_death_is_modest() -> void:
	# Routine drone death stays small per the juice budget: its shake must not reach
	# the loud boss-blow territory (warden transition_shake is ~0.8).
	var drone := DeathEffect.tuning_for(DRONE_HP)
	assert_lt(drone.shake, 0.8,
		"a routine drone death does not spend the boss-blow shake budget")


func test_boss_shake_is_clamped_to_a_sane_cap() -> void:
	# Even an absurd importance must not exceed the trauma ceiling (ScreenShake
	# clamps trauma to [0,1], so a >1 request is wasted/unsafe).
	var huge := DeathEffect.tuning_for(100000.0)
	assert_lte(huge.shake, 1.0, "death shake never exceeds the trauma ceiling of 1.0")


func test_defaults_and_floor_for_zero_or_negative_importance() -> void:
	# A degenerate importance (0 / negative) still yields a usable, positive beat.
	var zero := DeathEffect.tuning_for(0.0)
	assert_gt(zero.burst_amount, 0, "even a zero-importance death bursts at least some particles")
	assert_gt(zero.dissolve_time, 0.0, "dissolve_time is always positive")
	assert_gte(zero.shake, 0.0, "shake is never negative")
	assert_gte(zero.hit_stop, 0.0, "hit_stop is never negative")


func test_burst_amount_is_an_int_count() -> void:
	var t := DeathEffect.tuning_for(BOSS_HP)
	assert_typeof(t.burst_amount, TYPE_INT, "burst_amount is a particle count (int)")
