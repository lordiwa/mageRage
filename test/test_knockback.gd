## TASK-010 unit tests for Knockback.knockback_vector (pure, no scene).
##
## The drone is shoved ALONG the projectile's travel direction (away from where
## the shot came from). Sign correctness is the load-bearing assertion.
extends GutTest


func test_knockback_points_along_hit_direction() -> void:
	# Shot traveling right -> drone pushed right (positive x).
	var kb := Knockback.knockback_vector(Vector2.RIGHT, 100.0)
	assert_gt(kb.x, 0.0, "knockback x is positive when the shot travels right")
	assert_eq(kb.y, 0.0, "no vertical component for a purely horizontal shot")


func test_knockback_reverses_with_direction() -> void:
	# Shot traveling left -> drone pushed left (negative x).
	var kb := Knockback.knockback_vector(Vector2.LEFT, 100.0)
	assert_lt(kb.x, 0.0, "knockback x is negative when the shot travels left")


func test_knockback_magnitude_scales_with_strength() -> void:
	var kb := Knockback.knockback_vector(Vector2.RIGHT, 250.0)
	assert_almost_eq(kb.length(), 250.0, 0.001,
		"knockback magnitude equals strength for a unit hit direction")


func test_zero_direction_yields_zero_knockback() -> void:
	var kb := Knockback.knockback_vector(Vector2.ZERO, 100.0)
	assert_eq(kb, Vector2.ZERO,
		"a zero hit direction produces no knockback (no NaN)")


func test_diagonal_direction_is_normalized() -> void:
	# Non-unit input must not inflate the magnitude beyond strength.
	var kb := Knockback.knockback_vector(Vector2(3, 4), 50.0)  # length 5
	assert_almost_eq(kb.length(), 50.0, 0.001,
		"hit direction is normalized before scaling by strength")
