## TASK-020 unit tests for ShieldLogic — the PURE, scene-free directional-shield
## predicates that drive the Shield Drone (no rendered scene needed).
##
## The Shield Drone carries a DIRECTIONAL frontal shield. A player projectile is
## BLOCKED only when the shield is UP and the shot strikes the shield's frontal
## arc. The shot travels along `hit_dir` and therefore APPROACHES from `-hit_dir`;
## it is blocked when the angle between `shield_facing` and `-hit_dir` is within
## the shield's half-arc. The shield DROPS (is down) during the drone's own attack
## wind-up — the telegraphed punish window. These helpers encode both rules so
## they are fair/deterministic (DD-001) and can never silently drift.
extends GutTest

const DEG := PI / 180.0


# --- is_blocked: shield UP, frontal hit -> blocked ---------------------------

func test_blocked_when_shield_up_and_hit_dead_on_front() -> void:
	# Shield faces RIGHT (+x). The shot travels LEFT (-x), so it approaches FROM
	# the right (+x) — dead-on into the shield face. With a generous arc -> blocked.
	var blocked := ShieldLogic.is_blocked(Vector2.LEFT, Vector2.RIGHT, 80.0 * DEG, true)
	assert_true(blocked, "a head-on shot into the raised shield's face is blocked")


func test_blocked_within_arc_just_inside_boundary() -> void:
	# Shield faces RIGHT. A shot approaching from 70deg off the facing (inside an
	# 80deg half-arc) is still blocked. The shot APPROACHES from `-hit_dir`; pick a
	# travel dir whose negation sits 70deg off +x.
	var approach := Vector2.RIGHT.rotated(70.0 * DEG)   # where it comes FROM
	var hit_dir := -approach                            # how it travels
	assert_true(ShieldLogic.is_blocked(hit_dir, Vector2.RIGHT, 80.0 * DEG, true),
		"a shot inside the half-arc (70deg < 80deg) is blocked")


# --- is_blocked: outside the arc (flank / behind) -> NOT blocked --------------

func test_not_blocked_just_outside_arc_boundary() -> void:
	# Same shield, a shot approaching from 85deg off the facing is OUTSIDE an 80deg
	# half-arc -> it slips past the shield (a flank hit).
	var approach := Vector2.RIGHT.rotated(85.0 * DEG)
	var hit_dir := -approach
	assert_false(ShieldLogic.is_blocked(hit_dir, Vector2.RIGHT, 80.0 * DEG, true),
		"a shot just outside the half-arc (85deg > 80deg) is NOT blocked (flank)")


func test_not_blocked_from_directly_behind() -> void:
	# Shield faces RIGHT; a shot that approaches from the LEFT (180deg off) hits the
	# unshielded back. Travel dir is +x (it came from -x).
	assert_false(ShieldLogic.is_blocked(Vector2.RIGHT, Vector2.RIGHT, 80.0 * DEG, true),
		"a shot into the drone's BACK (opposite the facing) is never blocked")


func test_not_blocked_from_flank_90deg() -> void:
	# A shot approaching from straight above (90deg off a RIGHT-facing shield) is a
	# pure flank hit, outside any sane frontal arc (<90deg half-arc).
	var approach := Vector2.UP                # comes from above
	var hit_dir := -approach                  # travels down
	assert_false(ShieldLogic.is_blocked(hit_dir, Vector2.RIGHT, 80.0 * DEG, true),
		"a 90deg flank shot is outside an 80deg half-arc -> not blocked")


# --- is_blocked: shield DOWN -> never blocked (the punish window) -------------

func test_not_blocked_when_shield_down_even_dead_on() -> void:
	# The SAME dead-on frontal shot that was blocked above is NOT blocked when the
	# shield is down (wind-up): full damage lands. This is the telegraphed punish.
	assert_false(ShieldLogic.is_blocked(Vector2.LEFT, Vector2.RIGHT, 80.0 * DEG, false),
		"with the shield DOWN, even a head-on frontal shot is NOT blocked")


# --- is_blocked: zero-vector safety ------------------------------------------

func test_zero_hit_dir_is_not_blocked() -> void:
	assert_false(ShieldLogic.is_blocked(Vector2.ZERO, Vector2.RIGHT, 80.0 * DEG, true),
		"a zero hit direction is handled safely (not blocked, no NaN)")


func test_zero_shield_facing_is_not_blocked() -> void:
	assert_false(ShieldLogic.is_blocked(Vector2.LEFT, Vector2.ZERO, 80.0 * DEG, true),
		"a zero shield facing is handled safely (not blocked, no NaN)")


# --- is_blocked: arc width is honored ----------------------------------------

func test_wider_arc_blocks_a_shot_a_narrow_arc_lets_through() -> void:
	# A shot approaching from 75deg off the facing.
	var approach := Vector2.RIGHT.rotated(75.0 * DEG)
	var hit_dir := -approach
	assert_false(ShieldLogic.is_blocked(hit_dir, Vector2.RIGHT, 60.0 * DEG, true),
		"a 60deg half-arc does NOT cover a 75deg shot")
	assert_true(ShieldLogic.is_blocked(hit_dir, Vector2.RIGHT, 80.0 * DEG, true),
		"an 80deg half-arc DOES cover the same 75deg shot")


# --- shield_facing_toward: tracks the player ---------------------------------

func test_shield_facing_points_from_drone_toward_player() -> void:
	var facing := ShieldLogic.shield_facing_toward(Vector2(100, 0), Vector2(300, 0))
	assert_gt(facing.x, 0.0, "the shield faces toward a player on the right (+x)")
	assert_almost_eq(facing.length(), 1.0, 0.001, "the facing is a unit vector")


func test_shield_facing_zero_safe_when_coincident() -> void:
	var facing := ShieldLogic.shield_facing_toward(Vector2(50, 50), Vector2(50, 50))
	assert_eq(facing, Vector2.ZERO,
		"a coincident drone/player yields a safe zero facing (no NaN)")
