## CRUCIAL CORE (TASK-049) — group N: SlowEffect decay/recover (DD-004/DD-009).
##
## The one reviewer-curated slow-effect lifecycle guard lifted verbatim from
## test/test_slow_effect.gd with its before_each. Pure time bookkeeping, no scene.
extends GutTest

var slow: SlowEffect


func before_each() -> void:
	slow = SlowEffect.new()


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
