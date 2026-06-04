## DD-009 unit tests for DroneAi pure decision helpers (no rendered scene).
##
## The drone FSM (Patrol -> Chase -> Attack) routes every transition through these
## static helpers so the thresholds are fair/deterministic (DD-001) and can never
## drift. Covered: aggro in-range gating, attack-cooldown gating, telegraph
## (wind-up) elapsed timing, and the chase steering direction sign (toward player).
extends GutTest


# --- Aggro range -------------------------------------------------------------

func test_in_aggro_range_true_when_within() -> void:
	assert_true(DroneAi.in_aggro_range(200.0, 280.0),
		"distance below aggro range -> in range")


func test_in_aggro_range_true_at_exact_boundary() -> void:
	# Inclusive: distance == range counts as in range (<=).
	assert_true(DroneAi.in_aggro_range(280.0, 280.0),
		"distance equal to aggro range -> in range (inclusive)")


func test_in_aggro_range_false_when_beyond() -> void:
	assert_false(DroneAi.in_aggro_range(400.0, 280.0),
		"distance beyond aggro range -> not in range")


# --- Attack cooldown gating --------------------------------------------------

func test_cooldown_ready_after_full_cooldown() -> void:
	assert_true(DroneAi.cooldown_ready(1.5, 1.5),
		"cooldown is ready once the full interval has elapsed (>=)")


func test_cooldown_not_ready_before_cooldown() -> void:
	assert_false(DroneAi.cooldown_ready(0.5, 1.5),
		"cooldown is not ready before the interval elapses")


func test_cooldown_ready_well_past() -> void:
	assert_true(DroneAi.cooldown_ready(5.0, 1.5),
		"cooldown stays ready after the interval")


# --- Telegraph (wind-up) elapsed ---------------------------------------------

func test_telegraph_not_elapsed_mid_windup() -> void:
	assert_false(DroneAi.telegraph_elapsed(0.2, 0.4),
		"telegraph not finished partway through the wind-up")


func test_telegraph_elapsed_at_windup_end() -> void:
	assert_true(DroneAi.telegraph_elapsed(0.4, 0.4),
		"telegraph is complete once wind-up time is reached (>=)")


func test_telegraph_elapsed_past_windup() -> void:
	assert_true(DroneAi.telegraph_elapsed(0.6, 0.4),
		"telegraph stays complete past the wind-up")


# --- Chase steering direction (sign toward player) ---------------------------

func test_steer_points_right_when_player_is_right() -> void:
	var dir := DroneAi.steer_direction(Vector2(100, 0), Vector2(300, 0))
	assert_gt(dir.x, 0.0, "drone left of player steers right (+x)")


func test_steer_points_left_when_player_is_left() -> void:
	var dir := DroneAi.steer_direction(Vector2(300, 0), Vector2(100, 0))
	assert_lt(dir.x, 0.0, "drone right of player steers left (-x)")


func test_steer_is_normalized() -> void:
	var dir := DroneAi.steer_direction(Vector2(0, 0), Vector2(30, 40))  # length 50
	assert_almost_eq(dir.length(), 1.0, 0.001,
		"steering direction is a unit vector")


func test_steer_has_vertical_component_toward_player() -> void:
	# Player below the drone -> positive y steering (drone steers a little down).
	var dir := DroneAi.steer_direction(Vector2(0, 0), Vector2(0, 100))
	assert_gt(dir.y, 0.0, "drone steers vertically toward the player too")
