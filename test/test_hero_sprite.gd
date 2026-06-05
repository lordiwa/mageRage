## TASK-052 structural tests for the hero AnimatedSprite2D integration.
##
## These tests load player.tscn headless and assert:
##   1. The "Sprite" node is an AnimatedSprite2D (greybox ColorRect removed).
##   2. FacingMark ColorRect has been removed.
##   3. The SpriteFrames on the AnimatedSprite2D has all the expected animation names.
##   4. The CollisionShape2D RectangleShape2D is still size (24, 40) — byte-identical.
##   5. The AnimatedSprite2D carries a non-null SpriteFrames resource.
##   6. The AnimatedSprite2D uses NEAREST texture filtering (pixel-art, no blur) —
##      AC1 regression guard. Pixel-art must not be linear-filtered/blurred.
##   7. The opaque feet of the idle frame, after the node offset/scale, seat on the
##      collision bottom (local y = +20) within ~1px — the MEASURED feet-seating
##      guarantee (Image.get_used_rect()), not an eyeballed claim.
##
## Uses process_frame await (structure only, no physics await) so it cannot poison
## later input-edge tests.
extends GutTest

const PLAYER_SCENE := preload("res://scenes/player.tscn")

## Expected animation names that must exist in the SpriteFrames resource.
const EXPECTED_ANIMS := ["idle", "walk", "jump", "fall", "flight", "attack", "hurt"]

## The collision size must remain byte-identical (24x40).
const COLLISION_SIZE := Vector2(24.0, 40.0)


func _make_player() -> CharacterBody2D:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child_autofree(player)
	await get_tree().process_frame
	return player


## --- Sprite node type --------------------------------------------------------

func test_sprite_node_is_animated_sprite_2d() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite")
	assert_not_null(sprite, "a node named 'Sprite' exists on the player")
	assert_true(sprite is AnimatedSprite2D,
		"'Sprite' is an AnimatedSprite2D (greybox ColorRect replaced)")


func test_facing_mark_color_rect_removed() -> void:
	var player: CharacterBody2D = await _make_player()
	var facing_mark := player.get_node_or_null("FacingMark")
	assert_null(facing_mark,
		"FacingMark ColorRect has been removed from player.tscn")


## --- SpriteFrames resource ---------------------------------------------------

func test_sprite_frames_resource_is_non_null() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	assert_not_null(sprite.sprite_frames,
		"the AnimatedSprite2D has a non-null SpriteFrames resource")


func test_sprite_frames_has_idle_animation() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	assert_true(sprite.sprite_frames.has_animation("idle"),
		"SpriteFrames has an 'idle' animation")


func test_sprite_frames_has_walk_animation() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	assert_true(sprite.sprite_frames.has_animation("walk"),
		"SpriteFrames has a 'walk' animation")


func test_sprite_frames_has_jump_animation() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	assert_true(sprite.sprite_frames.has_animation("jump"),
		"SpriteFrames has a 'jump' animation")


func test_sprite_frames_has_fall_animation() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	assert_true(sprite.sprite_frames.has_animation("fall"),
		"SpriteFrames has a 'fall' animation (jump descend frames fallback)")


func test_sprite_frames_has_flight_animation() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	assert_true(sprite.sprite_frames.has_animation("flight"),
		"SpriteFrames has a 'flight' animation (hover aura)")


func test_sprite_frames_has_attack_animation() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	assert_true(sprite.sprite_frames.has_animation("attack"),
		"SpriteFrames has an 'attack' animation (cast one-shot)")


func test_sprite_frames_has_hurt_animation() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	assert_true(sprite.sprite_frames.has_animation("hurt"),
		"SpriteFrames has a 'hurt' animation (take-damage feedback)")


func test_all_expected_animations_present() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	for anim_name in EXPECTED_ANIMS:
		assert_true(
			sprite.sprite_frames.has_animation(anim_name),
			"SpriteFrames must have animation '%s'" % anim_name)


## --- Idle animation loops; attack/hurt do not --------------------------------

func test_idle_animation_loops() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	if not sprite.sprite_frames.has_animation("idle"):
		pending("idle animation not yet defined — IMPL step pending")
		return
	assert_true(sprite.sprite_frames.get_animation_loop("idle"),
		"idle animation must loop")


func test_walk_animation_loops() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	if not sprite.sprite_frames.has_animation("walk"):
		pending("walk animation not yet defined — IMPL step pending")
		return
	assert_true(sprite.sprite_frames.get_animation_loop("walk"),
		"walk animation must loop")


func test_flight_animation_loops() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	if not sprite.sprite_frames.has_animation("flight"):
		pending("flight animation not yet defined — IMPL step pending")
		return
	assert_true(sprite.sprite_frames.get_animation_loop("flight"),
		"flight animation must loop (hover aura is a looping ambient)")


func test_attack_animation_does_not_loop() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	if not sprite.sprite_frames.has_animation("attack"):
		pending("attack animation not yet defined — IMPL step pending")
		return
	assert_false(sprite.sprite_frames.get_animation_loop("attack"),
		"attack animation must NOT loop (it is a one-shot on cast)")


func test_hurt_animation_does_not_loop() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	if not sprite.sprite_frames.has_animation("hurt"):
		pending("hurt animation not yet defined — IMPL step pending")
		return
	assert_false(sprite.sprite_frames.get_animation_loop("hurt"),
		"hurt animation must NOT loop (one-shot on a landed hit)")


## --- Collision shape unchanged -----------------------------------------------

func test_collision_rectangle_shape_size_unchanged() -> void:
	var player: CharacterBody2D = await _make_player()
	var col := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_not_null(col, "CollisionShape2D still exists")
	var rect := col.shape as RectangleShape2D
	assert_not_null(rect, "the collision shape is a RectangleShape2D")
	assert_eq(rect.size, COLLISION_SIZE,
		"collision RectangleShape2D is still 24x40 (byte-identical)")


## --- Frame count sanity checks -----------------------------------------------

func test_idle_has_nine_frames() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	if not sprite.sprite_frames.has_animation("idle"):
		pending("idle animation not yet defined — IMPL step pending")
		return
	assert_eq(sprite.sprite_frames.get_frame_count("idle"), 9,
		"idle has 9 frames (shifts-weight breath from metadata)")


func test_walk_has_four_frames() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	if not sprite.sprite_frames.has_animation("walk"):
		pending("walk animation not yet defined — IMPL step pending")
		return
	assert_eq(sprite.sprite_frames.get_frame_count("walk"), 4,
		"walk has 4 frames (Walking from metadata)")


func test_attack_has_nine_frames() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	if not sprite.sprite_frames.has_animation("attack"):
		pending("attack animation not yet defined — IMPL step pending")
		return
	assert_eq(sprite.sprite_frames.get_frame_count("attack"), 9,
		"attack has 9 frames (cyan burst from metadata)")


func test_hurt_has_nine_frames() -> void:
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	if not sprite.sprite_frames.has_animation("hurt"):
		pending("hurt animation not yet defined — IMPL step pending")
		return
	assert_eq(sprite.sprite_frames.get_frame_count("hurt"), 9,
		"hurt has 9 frames (takedamage from metadata)")


## --- AC1 regression guard: NEAREST texture filter (no blur) ------------------

func test_hero_sprite_uses_nearest_texture_filter() -> void:
	# AC1: pixel-art must render with nearest filtering (no blur). The project-wide
	# default_texture_filter is Linear (1) here (kept so the DOWNSCALED parallax
	# backgrounds at scale 0.2 don't alias), so the hero AnimatedSprite2D carries an
	# explicit per-node override. CanvasItem.TextureFilter.TEXTURE_FILTER_NEAREST == 1.
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	assert_not_null(sprite, "the hero Sprite is an AnimatedSprite2D")
	# Resolve the EFFECTIVE filter: a node may inherit via PARENT_NODE (0); walk up
	# until a concrete filter is found, else fall back to the project default.
	var effective := _effective_texture_filter(sprite)
	assert_eq(
		effective,
		CanvasItem.TEXTURE_FILTER_NEAREST,
		"the hero AnimatedSprite2D resolves to NEAREST filtering (crisp pixel-art, no blur)")


## Resolve a CanvasItem's effective texture filter, following PARENT_NODE (0)
## inheritance up the tree, then the project default. Mirrors how Godot resolves it.
func _effective_texture_filter(item: CanvasItem) -> int:
	var node: Node = item
	while node != null:
		if node is CanvasItem:
			var f: int = (node as CanvasItem).texture_filter
			if f != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
				# Map the CanvasItem enum directly (NEAREST==1, LINEAR==2, ...).
				return f
		node = node.get_parent()
	# Nothing concrete up the tree: fall back to the project default. The project
	# enum (NEAREST=0, LINEAR=1) differs from the CanvasItem enum (NEAREST=1,
	# LINEAR=2), so translate: project 0 -> NEAREST, anything else -> LINEAR.
	var proj_default: int = int(
		ProjectSettings.get_setting(
			"rendering/textures/canvas_textures/default_texture_filter", 1))
	if proj_default == 0:
		return CanvasItem.TEXTURE_FILTER_NEAREST
	return CanvasItem.TEXTURE_FILTER_LINEAR


## --- Measured feet-seating guarantee (opaque bbox) ---------------------------

func test_idle_feet_seat_on_collision_bottom_measured() -> void:
	# Converts the eyeballed feet-seating claim into a MEASURED guarantee. Loads the
	# first idle frame, computes its opaque bbox via Image.get_used_rect(), maps the
	# bbox bottom row through the AnimatedSprite2D's centered placement + offset +
	# scale, and asserts the feet land on the collision bottom (local y = +20) ~1px.
	var player: CharacterBody2D = await _make_player()
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	if not sprite.sprite_frames.has_animation("idle"):
		pending("idle animation not yet defined — IMPL step pending")
		return

	var tex := sprite.sprite_frames.get_frame_texture("idle", 0)
	assert_not_null(tex, "the idle frame 0 has a texture")
	var img := tex.get_image()
	assert_not_null(img, "the idle frame 0 texture yields an Image")

	var used := img.get_used_rect()          # opaque bbox in pixel space
	var frame_h := float(img.get_height())   # 92 for the hero frames
	var feet_row_px := float(used.position.y + used.size.y)  # bottom edge of opaque pixels

	# AnimatedSprite2D is centered by default: the frame's pixel center (frame_h/2)
	# maps to the node origin, then the node's own position/offset + scale apply.
	# Local feet Y = (feet_row_px - frame_h/2) * scale.y + node.position.y
	assert_true(sprite.centered, "the hero AnimatedSprite2D is centered (offset math assumes it)")
	var local_feet_y := (feet_row_px - frame_h * 0.5) * sprite.scale.y + sprite.position.y

	# Collision bottom in the player's local space: shape center (0,0) + half-height.
	var col := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rect := col.shape as RectangleShape2D
	var collision_bottom_y := col.position.y + rect.size.y * 0.5   # 0 + 20 = +20

	assert_almost_eq(
		local_feet_y, collision_bottom_y, 1.5,
		"measured opaque feet seat on the collision bottom (local y ~= +20)")
