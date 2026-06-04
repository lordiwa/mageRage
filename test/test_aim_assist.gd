## Unit tests for the DD-012 soft aim-assist (aim magnetism) pure function.
##
## SOFT magnetism, NOT a hard lock-on: AimAssist.assist() only BIASES the cast
## aim toward an enemy the player is already roughly aiming at. It is a pure,
## deterministic function of (raw_aim, player_pos, enemy_positions, cones, range)
## — no RNG, no node lookups, no hidden state — so it is trivially testable
## headless with zero scene setup (DD-001: fair / deterministic / legible).
##
## Behaviour contract under test (DD-012):
##   - Enemy inside the OUTER cone (~+/-20deg) AND within RANGE (~400px): the aim
##     rotates toward that enemy by a BOUNDED amount. Full snap inside the INNER
##     cone (~8deg); partial lerp between inner and outer cone.
##   - Enemy OUTSIDE the outer cone, or BEYOND range, or BEHIND the player: NO
##     assist — raw_aim is returned unchanged (manual aim is respected).
##   - No enemy / empty list: raw_aim returned unchanged.
##   - Nearest qualifying enemy of several is the one chosen.
##   - An enemy exactly on the aim is a no-op (already aligned).
##   - The returned vector is always normalized.
extends GutTest

# Provisional DD-012 tunables, mirrored from AimAssist for readable test intent.
const CONE := 20.0          # outer cone half-angle (deg)
const INNER := 8.0          # inner (full-snap) cone half-angle (deg)
const RANGE := 400.0        # max assist range (px)

# Most tests aim along +X from the origin; helpers keep the cases terse.
const ORIGIN := Vector2.ZERO
const RIGHT := Vector2.RIGHT


# Build a unit vector at `deg` degrees off +X (CCW positive in Godot screen
# space is +Y down, but for these planar-angle assertions the convention is
# internally consistent: we only ever compare against angles we constructed).
func _at_deg(deg: float, dist: float) -> Vector2:
	return RIGHT.rotated(deg_to_rad(deg)) * dist


# --- No qualifying enemy => unchanged ---------------------------------------

func test_no_enemies_returns_raw_aim() -> void:
	var out := AimAssist.assist(RIGHT, ORIGIN, [], CONE, INNER, RANGE)
	assert_almost_eq(out.x, 1.0, 0.001, "no enemies: aim unchanged (x)")
	assert_almost_eq(out.y, 0.0, 0.001, "no enemies: aim unchanged (y)")


func test_enemy_outside_cone_not_assisted() -> void:
	# Enemy at 45deg off the aim, well outside the 20deg outer cone, in range.
	var enemy := _at_deg(45.0, 200.0)
	var out := AimAssist.assist(RIGHT, ORIGIN, [enemy], CONE, INNER, RANGE)
	assert_almost_eq(out.angle(), RIGHT.angle(), 0.001,
		"enemy outside the outer cone must NOT pull the aim (manual aim respected)")


func test_enemy_beyond_range_not_assisted() -> void:
	# Enemy dead-ahead but 500px away, beyond the 400px range.
	var enemy := _at_deg(0.0, 500.0)
	var out := AimAssist.assist(RIGHT, ORIGIN, [enemy], CONE, INNER, RANGE)
	assert_almost_eq(out.angle(), RIGHT.angle(), 0.001,
		"enemy beyond range must NOT pull the aim")


func test_enemy_behind_player_not_assisted() -> void:
	# Enemy directly BEHIND the aim (180deg), in range. Must not pull.
	var enemy := _at_deg(180.0, 200.0)
	var out := AimAssist.assist(RIGHT, ORIGIN, [enemy], CONE, INNER, RANGE)
	assert_almost_eq(out.angle(), RIGHT.angle(), 0.001,
		"enemy behind the player must NOT pull the aim")


# --- Inner cone: full snap ---------------------------------------------------

func test_enemy_inside_inner_cone_full_snap() -> void:
	# Enemy at 5deg off the aim (inside the 8deg inner cone): full snap onto it.
	var enemy := _at_deg(5.0, 200.0)
	var out := AimAssist.assist(RIGHT, ORIGIN, [enemy], CONE, INNER, RANGE)
	var to_enemy := (enemy - ORIGIN).normalized()
	assert_almost_eq(out.angle(), to_enemy.angle(), 0.001,
		"enemy inside the inner cone: aim snaps fully onto the enemy")


# --- Outer/partial cone: bounded lerp ---------------------------------------

func test_enemy_between_cones_partial_pull() -> void:
	# Enemy at 14deg off the aim: between inner (8) and outer (20) cone, so the
	# aim is pulled PARTWAY — past the raw aim but not all the way to the enemy.
	var enemy := _at_deg(14.0, 200.0)
	var out := AimAssist.assist(RIGHT, ORIGIN, [enemy], CONE, INNER, RANGE)
	var raw_a := 0.0
	var enemy_a := deg_to_rad(14.0)
	var out_a := out.angle()
	assert_gt(out_a, raw_a + 0.0001,
		"partial assist must move the aim off the raw direction toward the enemy")
	assert_lt(out_a, enemy_a - 0.0001,
		"partial assist must NOT fully snap onto a between-cones enemy")


# --- Exactly-on-aim => no-op -------------------------------------------------

func test_enemy_exactly_on_aim_is_noop() -> void:
	# Enemy dead-ahead in range: already aligned, the result equals the raw aim.
	var enemy := _at_deg(0.0, 200.0)
	var out := AimAssist.assist(RIGHT, ORIGIN, [enemy], CONE, INNER, RANGE)
	assert_almost_eq(out.angle(), RIGHT.angle(), 0.001,
		"enemy exactly on the aim: no rotation (no-op)")


# --- Nearest-of-several is chosen -------------------------------------------

func test_nearest_of_several_chosen() -> void:
	# Two qualifying enemies inside the cone+range: one near at +5deg / 100px,
	# one far at -6deg / 350px. The NEAR one (inside inner cone) wins -> full snap
	# onto it, proving distance (not angle) picks the target.
	var near := _at_deg(5.0, 100.0)
	var far := _at_deg(-6.0, 350.0)
	var out := AimAssist.assist(RIGHT, ORIGIN, [far, near], CONE, INNER, RANGE)
	var to_near := (near - ORIGIN).normalized()
	assert_almost_eq(out.angle(), to_near.angle(), 0.001,
		"the NEAREST qualifying enemy is chosen (full snap onto the near one)")


# --- Degenerate inputs are safe ---------------------------------------------

func test_zero_length_raw_aim_returns_safe_unit_vector() -> void:
	# A degenerate (zero) raw aim must not crash or produce NaN; the result is a
	# finite unit vector (assist cannot define a cone around a zero vector).
	var enemy := _at_deg(0.0, 200.0)
	var out := AimAssist.assist(Vector2.ZERO, ORIGIN, [enemy], CONE, INNER, RANGE)
	assert_true(is_finite(out.x) and is_finite(out.y),
		"zero-length raw aim returns a finite vector (no NaN)")


func test_result_is_normalized() -> void:
	var enemy := _at_deg(10.0, 200.0)
	var out := AimAssist.assist(RIGHT, ORIGIN, [enemy], CONE, INNER, RANGE)
	assert_almost_eq(out.length(), 1.0, 0.001, "assisted aim is normalized")
