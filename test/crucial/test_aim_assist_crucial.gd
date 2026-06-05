## CRUCIAL CORE (TASK-049) — group L: aim-assist purity (DD-012).
##
## The 5 reviewer-curated aim-assist guards (cone in/out, partial pull, nearest-of,
## degenerate-safe), lifted verbatim from test/test_aim_assist.gd with the shared
## consts + `_at_deg` helper. Pure function; no scene, no input, no flake surface.
## The full nightly suite still runs ALL of test_aim_assist.gd under res://test.
extends GutTest

const CONE := 20.0          # outer cone half-angle (deg)
const INNER := 8.0          # inner (full-snap) cone half-angle (deg)
const RANGE := 400.0        # max assist range (px)

const ORIGIN := Vector2.ZERO
const RIGHT := Vector2.RIGHT


func _at_deg(deg: float, dist: float) -> Vector2:
	return RIGHT.rotated(deg_to_rad(deg)) * dist


func test_enemy_outside_cone_not_assisted() -> void:
	var enemy := _at_deg(45.0, 200.0)
	var out := AimAssist.assist(RIGHT, ORIGIN, [enemy], CONE, INNER, RANGE)
	assert_almost_eq(out.angle(), RIGHT.angle(), 0.001,
		"enemy outside the outer cone must NOT pull the aim (manual aim respected)")


func test_enemy_inside_inner_cone_full_snap() -> void:
	var enemy := _at_deg(5.0, 200.0)
	var out := AimAssist.assist(RIGHT, ORIGIN, [enemy], CONE, INNER, RANGE)
	var to_enemy := (enemy - ORIGIN).normalized()
	assert_almost_eq(out.angle(), to_enemy.angle(), 0.001,
		"enemy inside the inner cone: aim snaps fully onto the enemy")


func test_enemy_between_cones_partial_pull() -> void:
	var enemy := _at_deg(14.0, 200.0)
	var out := AimAssist.assist(RIGHT, ORIGIN, [enemy], CONE, INNER, RANGE)
	var raw_a := 0.0
	var enemy_a := deg_to_rad(14.0)
	var out_a := out.angle()
	assert_gt(out_a, raw_a + 0.0001,
		"partial assist must move the aim off the raw direction toward the enemy")
	assert_lt(out_a, enemy_a - 0.0001,
		"partial assist must NOT fully snap onto a between-cones enemy")


func test_nearest_of_several_chosen() -> void:
	var near := _at_deg(5.0, 100.0)
	var far := _at_deg(-6.0, 350.0)
	var out := AimAssist.assist(RIGHT, ORIGIN, [far, near], CONE, INNER, RANGE)
	var to_near := (near - ORIGIN).normalized()
	assert_almost_eq(out.angle(), to_near.angle(), 0.001,
		"the NEAREST qualifying enemy is chosen (full snap onto the near one)")


func test_zero_length_raw_aim_returns_safe_unit_vector() -> void:
	var enemy := _at_deg(0.0, 200.0)
	var out := AimAssist.assist(Vector2.ZERO, ORIGIN, [enemy], CONE, INNER, RANGE)
	assert_true(is_finite(out.x) and is_finite(out.y),
		"zero-length raw aim returns a finite vector (no NaN)")
