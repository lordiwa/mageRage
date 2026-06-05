## TASK-045/046/048/051 — VISUAL-ONLY regression tests for sector_02 / the shared player camera.
##
## Covers the live-playtest bugs fixed during the sector_02 art pass:
##  - BUG-1: a near-black sector `Background` ColorRect occluded the parallax skyline.
##  - BUG-2: the shared player Camera2D had no limits, so the flying hero's view left the
##    backdrops into void; each sector now clamps the camera in its _ready (per-level).
##  - FLOOR: the City TileMapLayer (transparent-topped cap tile + 64px grid snap) left the
##    hero floating above an invisible gap and the elevated ledges as tall floating towers
##    ("estoy flotando en el aire" / bugpiso.png). The surfaces are now solid slate SLABS
##    (Sprite2D children of CityTiles) sized 1:1 to each collision footprint, so the VISIBLE
##    top == the collision top by construction. These tests pin that.
##
## SAFETY: VISUAL ONLY. These tests touch z_index, Camera2D.limit_*, and the slab Sprite
## transforms only — never any collision shape, body position or corridor metric. The
## corridor-span + boss-reachability tests (test_sector_02.gd / test_sector_boss_reachability)
## remain the collision truth and must keep passing UNCHANGED. Structure-only, no physics await.
extends GutTest

const SECTOR := preload("res://levels/sector_02.tscn")
const SECTOR_01 := preload("res://levels/sector_01.tscn")
const PLAYER := preload("res://scenes/player.tscn")
## Non-sector levels that reuse the shared player; they must NOT inherit a sector clamp.
const ENCOUNTER := preload("res://levels/encounter.tscn")
const ARENA := preload("res://levels/arena.tscn")

## The default Godot viewport (no [display] section): 1152x648, half-extents 576x324.
const VIEW_HALF := Vector2(576, 324)

## The chosen, finite camera limits each sector applies to the hero's Camera2D AT RUNTIME
## (in its _ready), clamping the view to THAT sector's playable bounds. The shared player
## scene carries NO limits, so non-sector levels (encounter/arena/test_level) stay
## unclamped — the clamp is per-level, not baked into the shared player.
const CAM_LEFT := 0
const CAM_TOP := -320
const CAM_BOTTOM := 360
const SECTOR_02_RIGHT := 4600
const SECTOR_01_RIGHT := 4200

## The Godot default Camera2D limits (the "no limit" sentinel). The shared player scene must
## KEEP this on every side; only a sector's _ready replaces it on that sector's own camera.
const DEFAULT_LIMIT := 10000000


func _make_sector() -> Node2D:
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	return level


# --- FLOOR/PLATFORM SLABS (TASK-046/048/051 resolved by the slab rewrite) ------
# The whole floor saga: collision works (the hero rests at floor_top y=328) but the VISIBLE
# surface didn't reach the feet, so the hero looked airborne, and the elevated ledges painted
# as tall floating dark towers. Root cause was the City TileMapLayer — a cap tile transparent
# for its top ~44% plus 64px grid snap, which no per-cell shimming fully tamed. The surfaces
# are now solid slate SLABS (Sprite2D children of CityTiles) sized 1:1 to each collision
# footprint, so the VISIBLE top == the collision top by construction. These tests pin that
# invariant so the floating-hero / tall-tower regressions cannot return.
#
# SAFETY: VISUAL ONLY. The slabs (+ their edge Polygon2Ds) carry NO physics; these tests read
# the slab Sprite transforms + each surface's collision shape (to DERIVE the target y, never
# mutating it). The corridor-span + boss-reachability tests remain the collision truth.

const FLOOR_TOP := 328.0
## How close (world px) each slab's visible top must sit to its collision top.
const SLAB_EPS := 1.5
## The camera bottom limit — the floor slab must reach past it so no void shows below.
const CAM_BOTTOM_Y := 360.0
## Max visible height (world px) of an ELEVATED platform slab — a thin slab, not a tower.
const ELEVATED_SLAB_MAX_H := 80.0

## Every walkable surface and the COLLISION node whose top its slab must seat on.
const WALKABLE_SURFACES := {
	"Floor": "Environment/Floor/Col",
	"LedgeA": "Environment/LedgeA/Col",
	"LedgeB": "Environment/LedgeB/Col",
	"LedgeC": "Environment/LedgeC/Col",
	"BossStep": "Environment/BossStep/Col",
}


## The COLLISION top (world y) of a surface, read live from its CollisionShape2D.
func _collision_top(level: Node2D, col_path: String) -> float:
	var col := level.get_node(col_path) as CollisionShape2D
	var rect := col.shape as RectangleShape2D
	return col.global_position.y - rect.size.y * 0.5


## A surface's visible slab Sprite (a child of the instanced CityTiles node).
func _slab(level: Node2D, slab_name: String) -> Sprite2D:
	return level.get_node_or_null("Environment/CityTiles/" + slab_name) as Sprite2D


func test_each_walkable_slab_top_sits_on_its_collision_top() -> void:
	# THE invariant the whole floor saga was about: the VISIBLE surface top lands exactly on
	# the collision top, so the hero/platform always reads as standing ON solid ground — no
	# invisible gap above the asset, no floating. True by construction with exact slabs.
	var level: Node2D = await _make_sector()
	for name in WALKABLE_SURFACES:
		var slab := _slab(level, name)
		assert_not_null(slab, "%s has a visible slab Sprite under CityTiles" % name)
		if slab == null:
			continue
		var top := _collision_top(level, WALKABLE_SURFACES[name])
		# centered = false → the Sprite's global_position.y IS its visible top edge.
		assert_almost_eq(slab.global_position.y, top, SLAB_EPS,
			"%s slab visible top (%.1f) sits on ITS collision top (%.1f)"
			% [name, slab.global_position.y, top])


func test_floor_slab_fills_below_the_camera() -> void:
	# The floor is the large ground surface: its slab must reach past the camera bottom limit
	# so it never reads as a thin floating strip with void below (the window-resize complaint).
	var level: Node2D = await _make_sector()
	var slab := _slab(level, "Floor")
	assert_not_null(slab, "the floor slab resolves")
	var bottom := slab.global_position.y + slab.region_rect.size.y * slab.scale.y
	assert_gt(bottom, CAM_BOTTOM_Y,
		"the floor slab bottom (%.1f) reaches below the camera bottom (%.1f) — no thin-strip void"
		% [bottom, CAM_BOTTOM_Y])


func test_elevated_slabs_are_thin_not_towers() -> void:
	# The elevated platforms (ledges, boss step) read as THIN slabs, not the ~130-190px floating
	# dark towers the old tile painter produced (bugpiso.png). Bound their visible height.
	var level: Node2D = await _make_sector()
	for name in ["LedgeA", "LedgeB", "LedgeC", "BossStep"]:
		var slab := _slab(level, name)
		assert_not_null(slab, "%s slab resolves" % name)
		if slab == null:
			continue
		var h := slab.region_rect.size.y * slab.scale.y
		assert_lte(h, ELEVATED_SLAB_MAX_H,
			"%s is a thin slab (height %.0f <= %.0fpx), not a floating tower"
			% [name, h, ELEVATED_SLAB_MAX_H])


func test_surface_slabs_carry_no_physics() -> void:
	# VISUAL ONLY: the CityTiles slabs are Sprite2D/Polygon2D — no CollisionObject anywhere,
	# so collision stays solely on the sector StaticBody2D nodes.
	var level: Node2D = await _make_sector()
	var tiles := level.get_node_or_null("Environment/CityTiles")
	assert_not_null(tiles, "the CityTiles visual node resolves")
	if tiles == null:
		return
	for child in tiles.get_children():
		assert_false(child is CollisionObject2D,
			"CityTiles child %s carries no physics (visual only)" % child.name)


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


# --- BUG-1 (per-sector): each sector's backstop covers its camera-reachable view -
# A sector applies its own clamp at runtime, so its flat backstop fill must enclose the
# worst-case camera-reachable view rect (its clamp window grown by the viewport
# half-extents) or void shows at the camera extremes. This pins the sector_01 far-right
# void the clamp would otherwise expose (its old fill ended short of the new bound).

## The worst-case camera-reachable view rect for a sector with the given right bound.
func _camera_reachable_rect(right_bound: int) -> Rect2:
	var min_corner := Vector2(CAM_LEFT, CAM_TOP) - VIEW_HALF
	var max_corner := Vector2(right_bound, CAM_BOTTOM) + VIEW_HALF
	return Rect2(min_corner, max_corner - min_corner)


func _assert_backstop_covers_camera(bg: ColorRect, right_bound: int, where: String) -> void:
	assert_not_null(bg, "%s has a flat backstop Background ColorRect" % where)
	var bg_rect := Rect2(bg.global_position, bg.size)
	var reachable := _camera_reachable_rect(right_bound)
	assert_true(bg_rect.encloses(reachable),
		"%s backstop %s encloses the camera-reachable view %s (no void at any extreme)"
		% [where, str(bg_rect), str(reachable)])


func test_sector_02_backstop_covers_the_camera_reachable_view() -> void:
	var level: Node2D = await _make_sector()
	_assert_backstop_covers_camera(
		level.get_node_or_null("Background") as ColorRect, SECTOR_02_RIGHT, "sector_02")


func test_sector_01_backstop_covers_the_camera_reachable_view() -> void:
	# Regression: the per-level clamp lets the camera reach past sector_01's old flat fill
	# (which ended at x=4500) and showed void on the far right. Its backstop must now
	# enclose the full camera-reachable rect for sector_01's own bound.
	var level := SECTOR_01.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	_assert_backstop_covers_camera(
		level.get_node_or_null("Background") as ColorRect, SECTOR_01_RIGHT, "sector_01")


# --- BUG-2: each sector clamps the hero's Camera2D in _ready (NOT the shared scene) --

## Resolve the hero's Camera2D from an instanced + readied sector.
func _sector_camera(level: Node2D) -> Camera2D:
	var player := level.get_node_or_null("Player")
	assert_not_null(player, "the sector has a Player")
	return player.get_node_or_null("Camera2D") as Camera2D


func test_shared_player_scene_carries_no_baked_camera_limits() -> void:
	# The shared player scene must NOT carry per-level bounds: instanced ALONE its camera
	# keeps the ±1e7 default on every side, so non-sector levels (encounter/arena/test_level)
	# that reuse it stay unclamped. Sectors set the clamp at runtime instead.
	var player := PLAYER.instantiate()
	add_child_autofree(player)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	assert_not_null(cam, "the player scene has a Camera2D")
	assert_eq(absi(cam.limit_left), DEFAULT_LIMIT, "the bare player keeps the default limit_left")
	assert_eq(absi(cam.limit_top), DEFAULT_LIMIT, "the bare player keeps the default limit_top")
	assert_eq(absi(cam.limit_right), DEFAULT_LIMIT, "the bare player keeps the default limit_right")
	assert_eq(absi(cam.limit_bottom), DEFAULT_LIMIT, "the bare player keeps the default limit_bottom")


func test_sector_02_camera_has_finite_non_default_limits() -> void:
	# After the sector's _ready runs, the hero camera no longer uses the ±1e7 default.
	var level: Node2D = await _make_sector()
	var cam := _sector_camera(level)
	assert_not_null(cam, "the sector's hero camera resolves")
	assert_ne(absi(cam.limit_left), DEFAULT_LIMIT, "limit_left is no longer the ±1e7 default")
	assert_ne(absi(cam.limit_top), DEFAULT_LIMIT, "limit_top is no longer the ±1e7 default")
	assert_ne(absi(cam.limit_right), DEFAULT_LIMIT, "limit_right is no longer the ±1e7 default")
	assert_ne(absi(cam.limit_bottom), DEFAULT_LIMIT, "limit_bottom is no longer the ±1e7 default")


func test_sector_02_camera_limits_match_the_level_bounds() -> void:
	# sector_02 clamps to its own playable bounds (right=4600).
	var level: Node2D = await _make_sector()
	var cam := _sector_camera(level)
	assert_eq(cam.limit_left, CAM_LEFT, "limit_left clamps to the corridor inner-left face (x=0)")
	assert_eq(cam.limit_right, SECTOR_02_RIGHT, "limit_right clamps to sector_02's inner-right face (x=4600)")
	assert_eq(cam.limit_top, CAM_TOP, "limit_top clamps to the ceiling band (y=-320)")
	assert_eq(cam.limit_bottom, CAM_BOTTOM, "limit_bottom clamps to the floor band (y=+360)")
	assert_lt(cam.limit_left, cam.limit_right, "the horizontal limits are correctly ordered")
	assert_lt(cam.limit_top, cam.limit_bottom, "the vertical limits are correctly ordered")


func test_sector_01_camera_limits_match_its_own_narrower_bounds() -> void:
	# sector_01 clamps to ITS bounds (right=4200, narrower than sector_02) — proving the
	# clamp is per-level, not a single shared value that would void/crop the other sector.
	var level := SECTOR_01.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var cam := _sector_camera(level)
	assert_eq(cam.limit_left, CAM_LEFT, "sector_01 limit_left clamps to its inner-left face (x=0)")
	assert_eq(cam.limit_right, SECTOR_01_RIGHT, "sector_01 limit_right clamps to ITS inner-right face (x=4200)")
	assert_eq(cam.limit_top, CAM_TOP, "sector_01 limit_top clamps to the ceiling band (y=-320)")
	assert_eq(cam.limit_bottom, CAM_BOTTOM, "sector_01 limit_bottom clamps to the floor band (y=+360)")
	assert_ne(absi(cam.limit_right), DEFAULT_LIMIT, "sector_01's camera is clamped, not default")


# --- Regression: non-sector levels reusing the shared player stay UNCLAMPED ---

func _assert_level_camera_is_unclamped(level: Node2D, tag: String) -> void:
	var player := level.get_node_or_null("Player")
	assert_not_null(player, "%s instances a Player that reuses the shared scene" % tag)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	assert_not_null(cam, "%s's reused Player has a Camera2D" % tag)
	assert_eq(absi(cam.limit_left), DEFAULT_LIMIT, "%s keeps the default (unclamped) limit_left" % tag)
	assert_eq(absi(cam.limit_top), DEFAULT_LIMIT, "%s keeps the default (unclamped) limit_top" % tag)
	assert_eq(absi(cam.limit_right), DEFAULT_LIMIT, "%s keeps the default (unclamped) limit_right" % tag)
	assert_eq(absi(cam.limit_bottom), DEFAULT_LIMIT, "%s keeps the default (unclamped) limit_bottom" % tag)


func test_encounter_level_camera_stays_unclamped() -> void:
	var level := ENCOUNTER.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	_assert_level_camera_is_unclamped(level, "encounter")


func test_arena_level_camera_stays_unclamped() -> void:
	var level := ARENA.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	_assert_level_camera_is_unclamped(level, "arena")
