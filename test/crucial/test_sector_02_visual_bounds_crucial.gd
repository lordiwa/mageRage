## CRUCIAL CORE (TASK-049) — camera per-level limits (E, TASK-045) + floor-cap
## alignment (F, TASK-048).
##
## The 9 reviewer-curated guards lifted verbatim from test/test_sector_02_visual_bounds.gd:
##   E (7) — per-level camera clamp values for sector_02 / sector_01, the shared player
##     carrying NO baked limits, encounter/arena staying unclamped, and each sector's
##     backstop covering its camera-reachable view;
##   F (2) — TASK-048 (reworked): EVERY capped walkable surface's visible lip sits on its
##     own collision top, and the floor-cap lip is not below the feet line.
## (Per docs/CRUCIAL-TESTS.md group F: TASK-048 landed reworked + parametrized; the F
## guard is now test_every_capped_surface_lip_sits_on_its_own_collision_top.)
## Structure-only, no physics-frame await -> no Input-edge flake surface. The full nightly
## suite still runs all 13 methods under res://test.
extends GutTest

const SECTOR := preload("res://levels/sector_02.tscn")
const SECTOR_01 := preload("res://levels/sector_01.tscn")
const PLAYER := preload("res://scenes/player.tscn")
const ENCOUNTER := preload("res://levels/encounter.tscn")
const ARENA := preload("res://levels/arena.tscn")

## The default Godot viewport (no [display] section): 1152x648, half-extents 576x324.
const VIEW_HALF := Vector2(576, 324)

const CAM_LEFT := 0
const CAM_TOP := -320
const CAM_BOTTOM := 360
const SECTOR_02_RIGHT := 4600
const SECTOR_01_RIGHT := 4200

## The Godot default Camera2D limits (the "no limit" sentinel).
const DEFAULT_LIMIT := 10000000

## --- TASK-048 floor-cap constants -------------------------------------------
const FLOOR_TOP := 328.0
const FLOOR_CAP_CELL_Y := 5
const CAP_TEXTURE := "Tile_27.png"
const LIP_EPS := 2.0

## Every CAPPED walkable surface in sector_02 and the COLLISION node whose top its cap
## must seat on (read live from the scene).
const CAPPED_SURFACES := {
	"Floor": "Environment/Floor/Col",
	"LedgeA": "Environment/LedgeA/Col",
	"LedgeB": "Environment/LedgeB/Col",
	"LedgeC": "Environment/LedgeC/Col",
	"BossStep": "Environment/BossStep/Col",
}


func _make_sector() -> Node2D:
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	return level


## --- TASK-048 cap helpers ---------------------------------------------------

func _cap_opaque_onset_fraction(tiles: TileMapLayer) -> float:
	for i in range(tiles.tile_set.get_source_count()):
		var sid := tiles.tile_set.get_source_id(i)
		var s := tiles.tile_set.get_source(sid) as TileSetAtlasSource
		if s != null and s.texture != null and s.texture.resource_path.get_file() == CAP_TEXTURE:
			var img := s.texture.get_image()
			for y in range(img.get_height()):
				for x in range(img.get_width()):
					if img.get_pixel(x, y).a > 0.16:
						return float(y) / float(img.get_height())
	return 0.0


func _collision_top(level: Node2D, col_path: String) -> float:
	var col := level.get_node(col_path) as CollisionShape2D
	var rect := col.shape as RectangleShape2D
	return col.global_position.y - rect.size.y * 0.5


func _cap_cell_for_surface(level: Node2D, tiles: TileMapLayer, col_path: String) -> Vector2i:
	var col := level.get_node(col_path) as CollisionShape2D
	var top := _collision_top(level, col_path)
	var probe := Vector2(col.global_position.x, top + 1.0)
	return tiles.local_to_map(tiles.to_local(probe))


func _cap_lip_world_y(tiles: TileMapLayer, cell: Vector2i, onset_frac: float) -> float:
	var center := tiles.to_global(tiles.map_to_local(cell))
	var tile_h := float(tiles.tile_set.tile_size.y)
	var cell_world_h := tile_h * tiles.scale.y
	var cell_top := center.y - cell_world_h * 0.5
	var origin_px := 0.0
	var sid := tiles.get_cell_source_id(cell)
	if sid >= 0:
		var src := tiles.tile_set.get_source(sid) as TileSetAtlasSource
		var atlas := tiles.get_cell_atlas_coords(cell)
		var alt := tiles.get_cell_alternative_tile(cell)
		var data := src.get_tile_data(atlas, alt)
		origin_px = float(data.texture_origin.y)
	# Positive texture_origin moves the drawn texture UP, so it SUBTRACTS from the lip row.
	return cell_top + (onset_frac * tile_h - origin_px) * tiles.scale.y


func _floor_top(level: Node2D) -> float:
	return _collision_top(level, "Environment/Floor/Col")


func test_every_capped_surface_lip_sits_on_its_own_collision_top() -> void:
	# THE rework assertion: for EVERY capped walkable surface, the cap's VISIBLE opaque
	# lip lands on that surface's OWN collision top.
	var level: Node2D = await _make_sector()
	var tiles := level.get_node("Environment/CityTiles") as TileMapLayer
	var onset := _cap_opaque_onset_fraction(tiles)
	assert_gt(onset, 0.0, "the cap art has a measurable transparent header (onset > 0)")
	for name in CAPPED_SURFACES:
		var col_path: String = CAPPED_SURFACES[name]
		var top := _collision_top(level, col_path)
		var cell := _cap_cell_for_surface(level, tiles, col_path)
		assert_gte(tiles.get_cell_source_id(cell), 0,
			"%s: a cap tile is actually painted on its surface (cell %s)" % [name, str(cell)])
		var lip := _cap_lip_world_y(tiles, cell, onset)
		assert_almost_eq(lip, top, LIP_EPS,
			"%s: the cap's visible opaque lip (%.1f) sits on ITS collision top (%.1f) — "
			% [name, lip, top]
			+ "the hero/platform reads solid, no floating cap strip")


func test_floor_cap_lip_is_not_below_the_feet_line() -> void:
	# Regression guard for the exact symptom ("flotando en el aire").
	var level: Node2D = await _make_sector()
	var tiles := level.get_node("Environment/CityTiles") as TileMapLayer
	var onset := _cap_opaque_onset_fraction(tiles)
	var cell := _cap_cell_for_surface(level, tiles, "Environment/Floor/Col")
	var lip := _cap_lip_world_y(tiles, cell, onset)
	assert_lte(lip, _floor_top(level) + LIP_EPS,
		"the visible floor-cap lip is at/above the feet line (not below it: lip=%.1f)" % lip)


## --- BUG-1 (per-sector): each sector's backstop covers its camera-reachable view -

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
	var level := SECTOR_01.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	_assert_backstop_covers_camera(
		level.get_node_or_null("Background") as ColorRect, SECTOR_01_RIGHT, "sector_01")


## --- BUG-2: each sector clamps the hero's Camera2D in _ready (NOT the shared scene) --

func _sector_camera(level: Node2D) -> Camera2D:
	var player := level.get_node_or_null("Player")
	assert_not_null(player, "the sector has a Player")
	return player.get_node_or_null("Camera2D") as Camera2D


func test_shared_player_scene_carries_no_baked_camera_limits() -> void:
	var player := PLAYER.instantiate()
	add_child_autofree(player)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	assert_not_null(cam, "the player scene has a Camera2D")
	assert_eq(absi(cam.limit_left), DEFAULT_LIMIT, "the bare player keeps the default limit_left")
	assert_eq(absi(cam.limit_top), DEFAULT_LIMIT, "the bare player keeps the default limit_top")
	assert_eq(absi(cam.limit_right), DEFAULT_LIMIT, "the bare player keeps the default limit_right")
	assert_eq(absi(cam.limit_bottom), DEFAULT_LIMIT, "the bare player keeps the default limit_bottom")


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
	# sector_01 clamps to ITS bounds (right=4200, narrower than sector_02).
	var level := SECTOR_01.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var cam := _sector_camera(level)
	assert_eq(cam.limit_left, CAM_LEFT, "sector_01 limit_left clamps to its inner-left face (x=0)")
	assert_eq(cam.limit_right, SECTOR_01_RIGHT, "sector_01 limit_right clamps to ITS inner-right face (x=4200)")
	assert_eq(cam.limit_top, CAM_TOP, "sector_01 limit_top clamps to the ceiling band (y=-320)")
	assert_eq(cam.limit_bottom, CAM_BOTTOM, "sector_01 limit_bottom clamps to the floor band (y=+360)")
	assert_ne(absi(cam.limit_right), DEFAULT_LIMIT, "sector_01's camera is clamped, not default")


## --- Regression: non-sector levels reusing the shared player stay UNCLAMPED ---

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
