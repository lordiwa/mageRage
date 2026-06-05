## CRUCIAL CORE (TASK-049) — camera per-level limits (TASK-045) + floor/platform
## slab seating (TASK-046/048/051, resolved by the slab rewrite).
##
## Reviewer-curated guards lifted from test/test_sector_02_visual_bounds.gd:
##   - per-level camera clamp values for sector_02 / sector_01, the shared player carrying
##     NO baked limits, encounter/arena staying unclamped, each sector's backstop covering
##     its camera-reachable view;
##   - each walkable surface's visible SLAB top sits on its collision top (the floating-hero
##     guard), and the elevated platforms are thin slabs not floating towers.
## Structure-only, no physics-frame await -> no Input-edge flake surface. The full nightly
## suite still runs every method under res://test.
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

## --- Floor/platform slab constants ------------------------------------------
const SLAB_EPS := 1.5
const ELEVATED_SLAB_MAX_H := 80.0
const WALKABLE_SURFACES := {
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


## --- Slab seating helpers ---------------------------------------------------

func _collision_top(level: Node2D, col_path: String) -> float:
	var col := level.get_node(col_path) as CollisionShape2D
	var rect := col.shape as RectangleShape2D
	return col.global_position.y - rect.size.y * 0.5


func _slab(level: Node2D, slab_name: String) -> Sprite2D:
	return level.get_node_or_null("Environment/CityTiles/" + slab_name) as Sprite2D


func test_each_walkable_slab_top_sits_on_its_collision_top() -> void:
	# THE floating-hero guard: the VISIBLE surface top lands exactly on the collision top,
	# so the hero/platform always reads as standing ON solid ground (no invisible gap).
	var level: Node2D = await _make_sector()
	for name in WALKABLE_SURFACES:
		var slab := _slab(level, name)
		assert_not_null(slab, "%s has a visible slab Sprite under CityTiles" % name)
		if slab == null:
			continue
		var top := _collision_top(level, WALKABLE_SURFACES[name])
		assert_almost_eq(slab.global_position.y, top, SLAB_EPS,
			"%s slab visible top (%.1f) sits on ITS collision top (%.1f)"
			% [name, slab.global_position.y, top])


func test_elevated_slabs_are_thin_not_towers() -> void:
	# The elevated platforms read as THIN slabs, not the ~130-190px floating towers the old
	# tile painter produced (bugpiso.png).
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
	var level: Node2D = await _make_sector()
	var cam := _sector_camera(level)
	assert_eq(cam.limit_left, CAM_LEFT, "limit_left clamps to the corridor inner-left face (x=0)")
	assert_eq(cam.limit_right, SECTOR_02_RIGHT, "limit_right clamps to sector_02's inner-right face (x=4600)")
	assert_eq(cam.limit_top, CAM_TOP, "limit_top clamps to the ceiling band (y=-320)")
	assert_eq(cam.limit_bottom, CAM_BOTTOM, "limit_bottom clamps to the floor band (y=+360)")
	assert_lt(cam.limit_left, cam.limit_right, "the horizontal limits are correctly ordered")
	assert_lt(cam.limit_top, cam.limit_bottom, "the vertical limits are correctly ordered")


func test_sector_01_camera_limits_match_its_own_narrower_bounds() -> void:
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
