## DD-004 / DD-009 unit tests for SlowEffect (pure time bookkeeping, no scene).
##
## An Ice hit applies SLOWED: multiplier 0.5 while active, ~2.5s duration,
## refreshed on re-hit, decaying back to 1.0 when it expires. This is Ice's
## "control" identity made real.
extends GutTest

var slow: SlowEffect


func before_each() -> void:
	slow = SlowEffect.new()


func test_inactive_by_default_is_full_speed() -> void:
	assert_false(slow.is_active(), "a fresh SlowEffect is inactive")
	assert_eq(slow.multiplier(), 1.0, "inactive -> full-speed multiplier 1.0")


func test_apply_activates_and_halves_multiplier() -> void:
	slow.apply()
	assert_true(slow.is_active(), "apply() activates the slow")
	assert_eq(slow.multiplier(), SlowEffect.SLOW_MULTIPLIER,
		"active slow halves the multiplier to 0.5")
	assert_almost_eq(slow.remaining(), SlowEffect.DURATION, 0.001,
		"apply() seeds the full duration")


func test_decays_over_time_then_recovers_to_full() -> void:
	slow.apply()
	# Tick most of the duration: still active, still 0.5.
	slow.update(2.0)
	assert_true(slow.is_active(), "still active partway through the duration")
	assert_eq(slow.multiplier(), SlowEffect.SLOW_MULTIPLIER,
		"multiplier stays 0.5 while active")
	# Tick past the end: recovers to full.
	slow.update(1.0)
	assert_false(slow.is_active(), "slow expires after its duration")
	assert_eq(slow.multiplier(), 1.0, "recovers to full multiplier 1.0 on expiry")


func test_rehit_refreshes_the_timer() -> void:
	slow.apply()
	slow.update(2.0)            # 0.5s remaining
	assert_lt(slow.remaining(), SlowEffect.DURATION,
		"timer has decayed before the re-hit")
	slow.apply()               # re-hit refreshes to full duration
	assert_almost_eq(slow.remaining(), SlowEffect.DURATION, 0.001,
		"re-hit refreshes the slow back to full duration")
	assert_true(slow.is_active(), "still active after refresh")


func test_remaining_clamps_at_zero() -> void:
	slow.apply()
	slow.update(10.0)
	assert_eq(slow.remaining(), 0.0, "remaining never goes negative")
	assert_eq(slow.multiplier(), 1.0, "fully decayed -> 1.0")
