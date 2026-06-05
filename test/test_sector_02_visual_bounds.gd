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
## Non-sector levels that reuse the shared player; they must NOT inherit a sector clamp.
const ENCOUNTER := preload("res://levels/encounter.tscn")
const ARENA := preload("res://levels/arena.tscn")

## The default Godot viewport (no [display] section): 1152x648, half-extents 576x324.
const VIEW_HALF := Vector2(576, 324)

## The chosen, finite camera limits each sector applies to the hero's Camera2D AT RUNTIME
## (in its _ready), clamping the view to THAT sector's playable bounds. The shared player
## scene carries NO limits, so non-sector levels (encounter/arena/test_level) stay
## unclamped — the clamp is per-level, not baked into the shared player.
##   - Horizontal: the corridor inner faces (WallLeft inner x=0; WallRight inner x). The two
##     sectors differ: sector_02 right=4600, sector_01 right=4200 (its right wall is at
##     x=4232 → inner x=4200) — so the test asserts each sector's OWN right bound.
##   - Vertical: the ceiling/floor body centers (y=-320 / y=+360), a band that keeps the
##     view inside the widened backstop with no void at the extremes (shared by both).
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


# --- TASK-048: the VISIBLE tile floor sits under the hero's feet (no float) ----
# Live-playtest bug: collision works (the hero rests at floor_top y=328) but the
# VISIBLE grey tile floor does NOT reach the feet, so the hero looks airborne. The
# root cause: the floor-cap tile (Tile_27) is TRANSPARENT for its top ~44.5% — its
# solid grey lip only begins partway down the cell — so painting the cap row at cell
# cy=5 (cell-top world y=320) puts the visible solid lip ~28px BELOW the cell top,
# i.e. ~20px BELOW the feet, showing parallax through the gap. The fix nudges the
# TileMapLayer up so the cap's VISIBLE solid lip lands at the collision floor top.
#
# SAFETY: VISUAL ONLY. These tests read only the TileMapLayer position / tile_set
# and the Floor collision shape (to derive the target y, NEVER mutating it). The
# corridor-span + boss-reachability tests remain the collision truth UNCHANGED.

## The collision floor top (DD-011 reused metric); the hero's feet rest here.
const FLOOR_TOP := 328.0
## The floor-cap row in CityTiles cell space (the walkable TOP surface row).
const FLOOR_CAP_CELL_Y := 5
## The cap texture whose opaque lip is the visible ground edge the hero stands ON.
const CAP_TEXTURE := "Tile_27.png"
## How close (world px) the cap's visible solid lip must sit to the collision floor
## top so the hero reads as standing ON solid ground (sub-pixel rounding tolerance).
const LIP_EPS := 2.0


## The fraction (0..1) down the cap texture at which its first opaque row appears —
## the cap art is transparent above this, so this is where the visible lip begins.
func _cap_opaque_onset_fraction(tiles: TileMapLayer) -> float:
	var src: TileSetAtlasSource = null
	for i in range(tiles.tile_set.get_source_count()):
		var sid := tiles.tile_set.get_source_id(i)
		var s := tiles.tile_set.get_source(sid) as TileSetAtlasSource
		if s != null and s.texture != null and s.texture.resource_path.get_file() == CAP_TEXTURE:
			src = s
			break
	assert_not_null(src, "the cap texture %s resolves in the TileSet" % CAP_TEXTURE)
	var img := src.texture.get_image()
	var h := img.get_height()
	var w := img.get_width()
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.16:
				return float(y) / float(h)
	return 0.0


## World Y of the cap row cell's TOP edge (cell-top, not the visible lip), via the
## live TileMapLayer transform (so a position nudge is reflected).
func _cap_cell_top_world_y(tiles: TileMapLayer) -> float:
	var cell := Vector2i(3, FLOOR_CAP_CELL_Y)  # a cell over the spawn column
	var center := tiles.to_global(tiles.map_to_local(cell))
	var cell_world_h := float(tiles.tile_set.tile_size.y) * tiles.scale.y
	return center.y - cell_world_h * 0.5


func _floor_top(level: Node2D) -> float:
	var floor_col := level.get_node("Environment/Floor/Col") as CollisionShape2D
	var floor_rect := floor_col.shape as RectangleShape2D
	return floor_col.global_position.y - floor_rect.size.y * 0.5


func test_floor_cap_visible_lip_sits_at_the_collision_floor_top() -> void:
	# The whole TASK-048 bug: the cap's VISIBLE solid lip (cell-top + opaque-onset)
	# must land at the collision floor top (y=328) so the hero visibly stands ON the
	# tile floor with no parallax-showing void under the feet.
	var level: Node2D = await _make_sector()
	var tiles := level.get_node("Environment/CityTiles") as TileMapLayer
	var floor_top := _floor_top(level)
	assert_almost_eq(floor_top, FLOOR_TOP, 1.0, "the collision floor top is the reused y=328")
	var onset := _cap_opaque_onset_fraction(tiles)
	var cell_world_h := float(tiles.tile_set.tile_size.y) * tiles.scale.y
	var lip_world_y := _cap_cell_top_world_y(tiles) + onset * cell_world_h
	assert_almost_eq(lip_world_y, floor_top, LIP_EPS,
		"the cap tile's VISIBLE solid lip (cell-top %.1f + %.1f%% onset) sits at the "
		% [_cap_cell_top_world_y(tiles), onset * 100.0]
		+ "collision floor top %.1f so the hero stands ON the floor (no float)" % floor_top)


func test_floor_cap_lip_is_not_below_the_feet_line() -> void:
	# Regression guard for the exact symptom ("flotando en el aire"): the visible lip
	# must NOT sit below the feet line — if it does, the feet hover over the cap's
	# transparent header and the parallax shows through.
	var level: Node2D = await _make_sector()
	var tiles := level.get_node("Environment/CityTiles") as TileMapLayer
	var onset := _cap_opaque_onset_fraction(tiles)
	var cell_world_h := float(tiles.tile_set.tile_size.y) * tiles.scale.y
	var lip_world_y := _cap_cell_top_world_y(tiles) + onset * cell_world_h
	assert_lte(lip_world_y, _floor_top(level) + LIP_EPS,
		"the visible cap lip is at/above the feet line (not below it, which would float "
		+ "the hero over the cap's transparent header: lip=%.1f)" % lip_world_y)


func test_floor_cap_covers_the_player_spawn_column() -> void:
	# The visible floor must actually exist under the spawn x — a painted cap cell on
	# the floor-cap row at the spawn column (so there IS tile floor where the hero lands).
	var level: Node2D = await _make_sector()
	var tiles := level.get_node("Environment/CityTiles") as TileMapLayer
	var spawn := level.get_node("PlayerSpawn") as Node2D
	var spawn_cell := tiles.local_to_map(tiles.to_local(
		Vector2(spawn.global_position.x, _floor_top(level) + 1.0)))
	assert_eq(spawn_cell.y, FLOOR_CAP_CELL_Y,
		"the cell directly under the spawn feet is the floor-cap row (cy=%d)" % FLOOR_CAP_CELL_Y)
	assert_gte(tiles.get_cell_source_id(spawn_cell), 0,
		"a tile is actually painted under the spawn column (the floor exists there)")


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
# The whole reason the clamp is per-level (not baked into player.tscn): encounter, arena
# and test_level reuse the player and must keep their pre-TASK-045 unclamped camera so we
# introduce NO far-right void / vertical crop into scenes we are not deciding to ship.

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
