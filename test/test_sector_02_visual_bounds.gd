## TASK-045 — VISUAL-ONLY bugfix regression tests for sector_02 / the shared player camera.
##
## Two live-playtest bugs, encoded structurally so they would have FAILED before the fix:
##
## BUG-1 — a near-black sector-level `Background` ColorRect (z_index = -10) renders IN
## FRONT of every parallax city layer (FarSky z=-30, MidStructures z=-25, NearPillars
## z=-20) and paints over the skyline. The fix either removes that ColorRect or pushes it
## behind ALL parallax layers (z_index strictly less than the minimum layer z) so it only
## acts as a guaranteed full-bleed backstop fill and never occludes the skyline.
##
## BUG-2 — the shared `scenes/player.tscn` Camera2D had NO limits (defaults ±10000000) so
## the freely-flying hero's view leaves the backdrops into void. The fix clamps the camera
## to the playable level bounds. These tests assert the limits are finite (NOT the ±1e7
## default) and equal the chosen level-bound values.
##
## SAFETY: VISUAL ONLY. These tests touch z_index and Camera2D.limit_* only — never any
## collision shape, body position or corridor metric. The corridor-span + boss-reachability
## tests (test_sector_02.gd / test_sector_boss_reachability.gd) remain the collision truth
## and must keep passing UNCHANGED. Structure-only, no physics await (cannot poison input).
extends GutTest

const SECTOR := preload("res://levels/sector_02.tscn")
const SECTOR_01 := preload("res://levels/sector_01.tscn")
const PLAYER := preload("res://scenes/player.tscn")

## The default Godot viewport (no [display] section): 1152x648, half-extents 576x324.
const VIEW_HALF := Vector2(576, 324)

## The chosen, finite camera limits clamping the view to the playable level bounds.
## Horizontal: the corridor inner faces (WallLeft inner x=0, WallRight inner x=4600).
## Vertical: the ceiling/floor OUTER faces (Ceiling top y=-320, Floor bottom y=+360) — a
## 680px band that keeps the view inside the backdrop coverage (~y=-600..600) with no void.
const CAM_LEFT := 0
const CAM_RIGHT := 4600
const CAM_TOP := -320
const CAM_BOTTOM := 360

## The Godot default Camera2D limits (the "no limit" sentinel) the fix must move OFF.
const DEFAULT_LIMIT := 10000000


func _make_sector() -> Node2D:
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	return level


# --- BUG-1: the sector-level backstop never occludes the parallax skyline ----

func test_sector_background_does_not_occlude_the_parallax_skyline() -> void:
	# Either the redundant sector-level Background ColorRect was removed, OR it was pushed
	# strictly behind ALL parallax layers so it is a backstop fill, never an occluder.
	var level: Node2D = await _make_sector()
	var bg := level.get_node_or_null("Background") as ColorRect
	var backdrop := (level as Sector02).parallax_backdrop() as ParallaxBackdrop
	assert_not_null(backdrop, "the parallax backdrop resolves")
	var min_layer_z := 0
	var first := true
	for layer in backdrop.parallax_layers():
		if first or layer.z_index < min_layer_z:
			min_layer_z = layer.z_index
			first = false
	if bg == null:
		# The redundant sector ColorRect was removed entirely — nothing can occlude.
		assert_true(true, "the redundant sector-level Background ColorRect was removed")
	else:
		assert_lt(bg.z_index, min_layer_z,
			"the sector backstop Background draws strictly behind every parallax layer "
			+ "(z=%d < min layer z=%d) so it never occludes the skyline"
			% [bg.z_index, min_layer_z])


func test_kept_backstop_sits_behind_the_parallax_own_fill() -> void:
	# If a sector-level backstop is kept, it must sit at/behind the parallax's own static
	# fill (z=-40) so the depth order is: sector backstop <= parallax fill < skyline layers.
	var level: Node2D = await _make_sector()
	var bg := level.get_node_or_null("Background") as ColorRect
	if bg == null:
		assert_true(true, "no sector-level backstop kept; the parallax's own z=-40 fill back-stops")
		return
	var backdrop := (level as Sector02).parallax_backdrop() as ParallaxBackdrop
	var parallax_fill := backdrop.background_fill()
	assert_not_null(parallax_fill, "the parallax's own fill ColorRect resolves")
	assert_lte(bg.z_index, parallax_fill.z_index,
		"the kept sector backstop sits at or behind the parallax's own fill (z=%d <= %d)"
		% [bg.z_index, parallax_fill.z_index])


# --- BUG-1 (shared): every sector's backstop covers the camera-reachable view -
# The camera limits live on the shared player, so the clamp is the SAME in every
# sector. A sector's flat backstop fill must therefore enclose the worst-case
# camera-reachable view rect (the clamp window grown by the viewport half-extents)
# or void shows at the camera extremes. This pins the sector_01 far-right void the
# shared clamp would otherwise expose (its old fill ended short of the new bound).

## The worst-case camera-reachable view rect given the shared clamp + viewport.
func _camera_reachable_rect() -> Rect2:
	var min_corner := Vector2(CAM_LEFT, CAM_TOP) - VIEW_HALF
	var max_corner := Vector2(CAM_RIGHT, CAM_BOTTOM) + VIEW_HALF
	return Rect2(min_corner, max_corner - min_corner)


func _assert_backstop_covers_camera(bg: ColorRect, where: String) -> void:
	assert_not_null(bg, "%s has a flat backstop Background ColorRect" % where)
	var bg_rect := Rect2(bg.global_position, bg.size)
	var reachable := _camera_reachable_rect()
	assert_true(bg_rect.encloses(reachable),
		"%s backstop %s encloses the camera-reachable view %s (no void at any extreme)"
		% [where, str(bg_rect), str(reachable)])


func test_sector_02_backstop_covers_the_camera_reachable_view() -> void:
	var level: Node2D = await _make_sector()
	_assert_backstop_covers_camera(level.get_node_or_null("Background") as ColorRect, "sector_02")


func test_sector_01_backstop_covers_the_camera_reachable_view() -> void:
	# Regression: the shared clamp lets the camera reach past sector_01's old flat fill
	# (which ended at x=4500) and showed void on the far right. Its backstop must now
	# enclose the full camera-reachable rect.
	var level := SECTOR_01.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	_assert_backstop_covers_camera(level.get_node_or_null("Background") as ColorRect, "sector_01")


# --- BUG-2: the shared player Camera2D is clamped to the level bounds ---------

func _player_camera() -> Camera2D:
	var player := PLAYER.instantiate()
	add_child_autofree(player)
	return player.get_node_or_null("Camera2D") as Camera2D


func test_player_camera_has_finite_non_default_limits() -> void:
	# The camera must no longer use the ±10000000 "no limit" default on any side.
	var cam := _player_camera()
	assert_not_null(cam, "the player scene has a Camera2D")
	assert_ne(absi(cam.limit_left), DEFAULT_LIMIT, "limit_left is no longer the ±1e7 default")
	assert_ne(absi(cam.limit_top), DEFAULT_LIMIT, "limit_top is no longer the ±1e7 default")
	assert_ne(absi(cam.limit_right), DEFAULT_LIMIT, "limit_right is no longer the ±1e7 default")
	assert_ne(absi(cam.limit_bottom), DEFAULT_LIMIT, "limit_bottom is no longer the ±1e7 default")


func test_player_camera_limits_match_the_level_bounds() -> void:
	# The clamp equals the chosen playable bounds so the view never exits the art.
	var cam := _player_camera()
	assert_not_null(cam, "the player scene has a Camera2D")
	assert_eq(cam.limit_left, CAM_LEFT, "limit_left clamps to the corridor inner-left face (x=0)")
	assert_eq(cam.limit_right, CAM_RIGHT, "limit_right clamps to the corridor inner-right face (x=4600)")
	assert_eq(cam.limit_top, CAM_TOP, "limit_top clamps to the ceiling outer face (y=-320)")
	assert_eq(cam.limit_bottom, CAM_BOTTOM, "limit_bottom clamps to the floor outer face (y=+360)")


func test_camera_limits_form_a_sane_ordered_window() -> void:
	# Sanity: left < right and top < bottom (a non-degenerate, correctly-ordered window).
	var cam := _player_camera()
	assert_lt(cam.limit_left, cam.limit_right, "the horizontal limits are correctly ordered")
	assert_lt(cam.limit_top, cam.limit_bottom, "the vertical limits are correctly ordered")
