## TASK-016 unit tests: PlayerHUD damage-feedback PURE math (no rendered scene).
##
## The red edge vignette + hit-direction indicator are driven by static helpers so
## the curves/mappings test headless without instancing the CanvasLayer:
##  - vignette_alpha(t, duration, peak): peak at t=0, monotonic fade to 0 at the
##    duration, clamped, zero/negative-duration safe;
##  - intensity_for(amount, max_hp): the vignette PEAK alpha scaled by the damage
##    fraction, clamped into the [MIN..MAX] readable band, zero-max safe;
##  - indicator_angle(hit_dir): the screen-edge arrow angle (radians) pointing back
##    toward the SOURCE of the hit, i.e. along -hit_dir;
##  - should_show_indicator(hit_dir): false for a ZERO direction (vignette only).
extends GutTest

const Hud := preload("res://scripts/ui/player_hud.gd")


# --- vignette_alpha: peak-then-fade curve ------------------------------------

func test_vignette_alpha_starts_at_peak() -> void:
	assert_almost_eq(Hud.vignette_alpha(0.0, 0.4, 0.6), 0.6, 0.0001,
		"the vignette is at its peak alpha at t=0")


func test_vignette_alpha_fades_to_zero_at_duration() -> void:
	assert_almost_eq(Hud.vignette_alpha(0.4, 0.4, 0.6), 0.0, 0.0001,
		"the vignette has fully faded (alpha 0) by the end of the duration")


func test_vignette_alpha_is_monotonic_decreasing() -> void:
	var early := Hud.vignette_alpha(0.1, 0.4, 0.6)
	var late := Hud.vignette_alpha(0.3, 0.4, 0.6)
	assert_lt(late, early,
		"the vignette alpha decreases over time (a quick fade)")


func test_vignette_alpha_clamps_past_duration() -> void:
	assert_almost_eq(Hud.vignette_alpha(1.0, 0.4, 0.6), 0.0, 0.0001,
		"past the duration the alpha clamps to 0, never negative")


func test_vignette_alpha_zero_duration_is_safe() -> void:
	assert_eq(Hud.vignette_alpha(0.0, 0.0, 0.6), 0.0,
		"a zero/degenerate duration must not divide-by-zero; alpha is 0")


# --- intensity_for: peak alpha scaled by damage, clamped band ----------------

func test_intensity_for_bigger_hit_is_at_least_as_strong() -> void:
	var small := Hud.intensity_for(10.0, 100.0)
	var big := Hud.intensity_for(40.0, 100.0)
	assert_gte(big, small,
		"a bigger hit yields an equal-or-stronger vignette peak")


func test_intensity_for_clamped_into_band() -> void:
	var i := Hud.intensity_for(10.0, 100.0)
	assert_gte(i, Hud.VIGNETTE_MIN_PEAK,
		"even a tiny hit reads at least at the minimum peak")
	assert_lte(i, Hud.VIGNETTE_MAX_PEAK,
		"even a lethal hit never exceeds the max peak (playfield stays readable)")


func test_intensity_for_huge_hit_clamps_to_max() -> void:
	assert_almost_eq(Hud.intensity_for(500.0, 100.0), Hud.VIGNETTE_MAX_PEAK, 0.0001,
		"an overkill hit clamps to the max peak, not beyond")


func test_intensity_for_zero_max_is_safe() -> void:
	var i := Hud.intensity_for(25.0, 0.0)
	assert_gte(i, Hud.VIGNETTE_MIN_PEAK,
		"a zero max HP must not divide-by-zero; falls back to the min peak")
	assert_lte(i, Hud.VIGNETTE_MAX_PEAK,
		"the zero-max fallback still respects the max-peak cap")


# --- indicator_angle: points back toward the source of the hit ---------------

func test_indicator_angle_points_toward_source() -> void:
	# A hit travelling RIGHT came FROM the left; the indicator points LEFT (PI rad).
	var angle := Hud.indicator_angle(Vector2.RIGHT)
	assert_almost_eq(absf(angle), PI, 0.0001,
		"a rightward hit's indicator points left (toward the source)")


func test_indicator_angle_is_negated_direction() -> void:
	# A hit travelling DOWN came from ABOVE; the arrow points UP (-Y).
	var angle := Hud.indicator_angle(Vector2.DOWN)
	var expected := Vector2.UP.angle()
	assert_almost_eq(angle, expected, 0.0001,
		"the indicator angle is the angle of -hit_dir (toward the source)")


func test_indicator_angle_normalizes_unnormalized_input() -> void:
	var angle := Hud.indicator_angle(Vector2(5.0, 0.0))
	assert_almost_eq(absf(angle), PI, 0.0001,
		"an unnormalized travel direction still maps to the correct source angle")


# --- should_show_indicator: skip the arrow for a ZERO direction --------------

func test_should_show_indicator_true_for_real_direction() -> void:
	assert_true(Hud.should_show_indicator(Vector2.RIGHT),
		"a real hit direction shows the directional arrow")


func test_should_show_indicator_false_for_zero() -> void:
	assert_false(Hud.should_show_indicator(Vector2.ZERO),
		"a ZERO hit direction skips the arrow (vignette-only)")


# --- indicator_edge_position: anchor toward the screen edge (source dir) ------
# The indicator sits on the screen-edge rectangle in the SOURCE direction
# (-hit_dir): a hit travelling RIGHT came from the LEFT edge, etc. Mapping is
# from a centered origin out to the (size - margin) rectangle, ZERO-safe.

const VP := Vector2(1280.0, 720.0)
const MARGIN := 48.0


func test_indicator_edge_position_right_hit_lands_on_left_edge() -> void:
	# A hit travelling RIGHT came FROM the left: the indicator hugs the LEFT edge.
	var p: Vector2 = Hud.indicator_edge_position(Vector2.RIGHT, VP, MARGIN)
	assert_almost_eq(p.x, MARGIN, 0.5,
		"a rightward hit anchors the indicator near the LEFT screen edge")
	assert_almost_eq(p.y, VP.y * 0.5, 0.5,
		"a purely horizontal hit stays vertically centered")


func test_indicator_edge_position_left_hit_lands_on_right_edge() -> void:
	var p: Vector2 = Hud.indicator_edge_position(Vector2.LEFT, VP, MARGIN)
	assert_almost_eq(p.x, VP.x - MARGIN, 0.5,
		"a leftward hit anchors the indicator near the RIGHT screen edge")
	assert_almost_eq(p.y, VP.y * 0.5, 0.5,
		"a purely horizontal hit stays vertically centered")


func test_indicator_edge_position_down_hit_lands_on_top_edge() -> void:
	# A hit travelling DOWN came FROM above: the indicator hugs the TOP edge.
	var p: Vector2 = Hud.indicator_edge_position(Vector2.DOWN, VP, MARGIN)
	assert_almost_eq(p.y, MARGIN, 0.5,
		"a downward hit anchors the indicator near the TOP screen edge")
	assert_almost_eq(p.x, VP.x * 0.5, 0.5,
		"a purely vertical hit stays horizontally centered")


func test_indicator_edge_position_up_hit_lands_on_bottom_edge() -> void:
	var p: Vector2 = Hud.indicator_edge_position(Vector2.UP, VP, MARGIN)
	assert_almost_eq(p.y, VP.y - MARGIN, 0.5,
		"an upward hit anchors the indicator near the BOTTOM screen edge")
	assert_almost_eq(p.x, VP.x * 0.5, 0.5,
		"a purely vertical hit stays horizontally centered")


func test_indicator_edge_position_diagonal_lands_in_correct_quadrant() -> void:
	# A hit travelling DOWN-RIGHT came from the UP-LEFT: indicator is in the
	# top-left quadrant (x < center, y < center).
	var p: Vector2 = Hud.indicator_edge_position(Vector2(1.0, 1.0), VP, MARGIN)
	assert_lt(p.x, VP.x * 0.5,
		"a down-right hit anchors the indicator left of center (source side)")
	assert_lt(p.y, VP.y * 0.5,
		"a down-right hit anchors the indicator above center (source side)")


func test_indicator_edge_position_stays_within_bounds() -> void:
	var p: Vector2 = Hud.indicator_edge_position(Vector2(1.0, 1.0), VP, MARGIN)
	assert_gte(p.x, MARGIN - 0.5, "x stays within the left margin")
	assert_lte(p.x, VP.x - MARGIN + 0.5, "x stays within the right margin")
	assert_gte(p.y, MARGIN - 0.5, "y stays within the top margin")
	assert_lte(p.y, VP.y - MARGIN + 0.5, "y stays within the bottom margin")


func test_indicator_edge_position_diagonal_reaches_a_corner_edge() -> void:
	# A 45-degree source direction should touch at least one of the bounding
	# rectangle edges (the larger projection saturates to its margin).
	var p: Vector2 = Hud.indicator_edge_position(Vector2(1.0, 1.0), VP, MARGIN)
	var on_x_edge := absf(p.x - MARGIN) < 0.5
	var on_y_edge := absf(p.y - MARGIN) < 0.5
	assert_true(on_x_edge or on_y_edge,
		"a diagonal source direction touches a screen edge")


func test_indicator_edge_position_zero_is_safe_and_centered() -> void:
	var p: Vector2 = Hud.indicator_edge_position(Vector2.ZERO, VP, MARGIN)
	assert_almost_eq(p.x, VP.x * 0.5, 0.5,
		"a ZERO hit direction is safe: the indicator stays centered (x)")
	assert_almost_eq(p.y, VP.y * 0.5, 0.5,
		"a ZERO hit direction is safe: the indicator stays centered (y)")
