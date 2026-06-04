## TASK-010 unit tests for ScreenShake pure feel math (no rendered camera).
##
## Acceptance criteria covered:
##  - trauma decays toward 0 over time and CLAMPS at 0 (never negative);
##  - trauma is clamped at the top (never above 1);
##  - offset magnitude scales with trauma^2 (squared response), is non-negative,
##    and is 0 when trauma is 0.
extends GutTest


func test_decay_reduces_trauma() -> void:
	# 1.0 trauma, rate 2.0, dt 0.1 -> 0.8.
	assert_almost_eq(ScreenShake.decay(1.0, 2.0, 0.1), 0.8, 0.0001,
		"decay subtracts rate*delta from trauma")


func test_decay_clamps_at_zero_never_negative() -> void:
	# Over-decay must floor at 0, not go negative.
	assert_eq(ScreenShake.decay(0.1, 5.0, 1.0), 0.0,
		"decay never returns a negative trauma")


func test_decay_clamps_at_one() -> void:
	assert_eq(ScreenShake.decay(2.0, 0.0, 0.0), 1.0,
		"trauma is clamped to a max of 1")


func test_offset_magnitude_is_trauma_squared() -> void:
	# max_offset 8, trauma 0.5 -> 8 * 0.25 = 2.0.
	assert_almost_eq(ScreenShake.offset_magnitude(0.5, 8.0), 2.0, 0.0001,
		"offset magnitude = max_offset * trauma^2")


func test_offset_magnitude_squared_response() -> void:
	# Halving trauma should QUARTER the offset (squared, not linear).
	var full := ScreenShake.offset_magnitude(1.0, 10.0)
	var half := ScreenShake.offset_magnitude(0.5, 10.0)
	assert_almost_eq(half, full * 0.25, 0.0001,
		"halving trauma quarters the offset (squared response)")


func test_offset_magnitude_zero_at_zero_trauma() -> void:
	assert_eq(ScreenShake.offset_magnitude(0.0, 10.0), 0.0,
		"no trauma -> no offset")


func test_offset_magnitude_never_negative() -> void:
	assert_gte(ScreenShake.offset_magnitude(0.3, 6.0), 0.0,
		"offset magnitude is non-negative")
