## Unit tests for the auto-scroll camera (scripts/levels/shmup_scroller.gd, ShmupScroller)
## — the FOUNDATION of the TASK-065 auto-scroll shmup mode (DD-014).
##
## The scroller is a Camera2D subclass that advances its global_position.x by a constant
## SCROLL_SPEED every physics tick. ALL motion is exercised DETERMINISTICALLY by calling
## advance(delta) directly — NEVER through real frames (the GUT flake footgun + the ticket's
## explicit "do NOT rely on real frames" requirement). The viewport-rect math (used by the
## player clamp) is likewise a pure, frame-free helper.
##
## What it proves:
##   1. SCROLL_SPEED is a named, positive, tunable constant (AC: tunable scroll speed).
##   2. advance(delta) moves global_position.x by exactly SCROLL_SPEED * delta (rightward),
##      and ONLY x (y is untouched) — the classic horizontal shmup constraint.
##   3. visible_world_rect() returns the camera's visible world rect derived from the
##      viewport size / zoom + camera position (NOT magic numbers).
##   4. clamp_point_to_rect() keeps a point inside a rect when pushed past EACH edge — the
##      pure helper the level controller uses to carry the player with the frame.
extends GutTest

const ShmupScrollerScript := preload("res://scripts/levels/shmup_scroller.gd")


## Build a bare ShmupScroller, parent it (auto-freed) so it has a viewport/tree.
func _make_scroller() -> ShmupScroller:
	var cam := ShmupScrollerScript.new() as ShmupScroller
	add_child_autofree(cam)
	return cam


func test_scroll_speed_is_a_named_positive_constant() -> void:
	# AC: the auto-scroll advances at a constant TUNABLE SCROLL_SPEED.
	assert_true(ShmupScroller.SCROLL_SPEED > 0.0,
		"ShmupScroller.SCROLL_SPEED must exist and be a positive tunable constant")


func test_advance_moves_x_by_scroll_speed_times_delta() -> void:
	# The core: advance(delta) carries the camera rightward by SCROLL_SPEED * delta. Called
	# DIRECTLY (no real frames) so the assertion is exact and deterministic.
	var cam := _make_scroller()
	cam.global_position = Vector2(100.0, 50.0)
	var delta := 0.1
	cam.advance(delta)
	assert_almost_eq(cam.global_position.x, 100.0 + ShmupScroller.SCROLL_SPEED * delta, 0.001,
		"advance(delta) moves x by exactly SCROLL_SPEED * delta")


func test_advance_only_moves_horizontally() -> void:
	# Classic horizontal shmup: the auto-scroll is purely rightward — y never changes.
	var cam := _make_scroller()
	cam.global_position = Vector2(0.0, 77.0)
	cam.advance(0.25)
	assert_almost_eq(cam.global_position.y, 77.0, 0.001,
		"the auto-scroll never moves the camera vertically (horizontal constraint)")


func test_advance_accumulates_over_multiple_ticks() -> void:
	# Repeated ticks accumulate linearly: 5 * (SCROLL_SPEED * dt).
	var cam := _make_scroller()
	cam.global_position = Vector2.ZERO
	var dt := 0.02
	for i in range(5):
		cam.advance(dt)
	assert_almost_eq(cam.global_position.x, 5.0 * ShmupScroller.SCROLL_SPEED * dt, 0.001,
		"successive advance() ticks accumulate the scroll linearly")


# --- Visible world rect (player-clamp source; viewport-derived, no magic numbers) ---

func test_visible_world_rect_is_centered_on_the_camera_and_sized_by_the_viewport() -> void:
	# The rect the player is clamped into: centered on the camera position, sized by the
	# viewport size / zoom (NOT hardcoded). With zoom 1 the rect spans viewport_size.
	var cam := _make_scroller()
	cam.global_position = Vector2(500.0, 0.0)
	cam.zoom = Vector2.ONE
	var view: Vector2 = cam.get_viewport_rect().size
	var rect := cam.visible_world_rect()
	# The rect is centered on the camera (anchor mode drag-center default in our scene).
	assert_almost_eq(rect.get_center().x, 500.0, 1.0,
		"the visible rect is centered on the camera x")
	assert_almost_eq(rect.size.x, view.x, 1.0,
		"the visible rect width is the viewport width (zoom 1, no magic numbers)")
	assert_almost_eq(rect.size.y, view.y, 1.0,
		"the visible rect height is the viewport height (zoom 1)")


func test_visible_world_rect_shrinks_with_zoom() -> void:
	# Zoom 2 halves the visible world size (zoom magnifies, so less world is seen). Proves
	# the rect is zoom-derived, not a magic constant.
	var cam := _make_scroller()
	cam.global_position = Vector2.ZERO
	cam.zoom = Vector2(2.0, 2.0)
	var view: Vector2 = cam.get_viewport_rect().size
	var rect := cam.visible_world_rect()
	assert_almost_eq(rect.size.x, view.x / 2.0, 1.0,
		"zoom 2 halves the visible world width (rect is zoom-derived)")


# --- Pure clamp helper (carries the player with the frame) -------------------

func test_clamp_point_pulls_a_point_past_the_right_edge_back_inside() -> void:
	var rect := Rect2(0.0, 0.0, 100.0, 100.0)
	var clamped := ShmupScroller.clamp_point_to_rect(Vector2(150.0, 50.0), rect)
	assert_almost_eq(clamped.x, 100.0, 0.001, "a point past the RIGHT edge clamps to the edge")
	assert_almost_eq(clamped.y, 50.0, 0.001, "the in-range y is untouched")


func test_clamp_point_pulls_a_point_past_each_edge_back_inside() -> void:
	var rect := Rect2(0.0, 0.0, 100.0, 100.0)
	# Left edge.
	assert_almost_eq(ShmupScroller.clamp_point_to_rect(Vector2(-30.0, 50.0), rect).x, 0.0, 0.001,
		"past the LEFT edge clamps to x=0")
	# Top edge.
	assert_almost_eq(ShmupScroller.clamp_point_to_rect(Vector2(50.0, -30.0), rect).y, 0.0, 0.001,
		"past the TOP edge clamps to y=0")
	# Bottom edge.
	assert_almost_eq(ShmupScroller.clamp_point_to_rect(Vector2(50.0, 130.0), rect).y, 100.0, 0.001,
		"past the BOTTOM edge clamps to y=100")


func test_clamp_point_leaves_an_inside_point_unchanged() -> void:
	var rect := Rect2(0.0, 0.0, 100.0, 100.0)
	var inside := Vector2(40.0, 60.0)
	var clamped := ShmupScroller.clamp_point_to_rect(inside, rect)
	assert_almost_eq(clamped.x, 40.0, 0.001, "an inside point keeps its x")
	assert_almost_eq(clamped.y, 60.0, 0.001, "an inside point keeps its y")
