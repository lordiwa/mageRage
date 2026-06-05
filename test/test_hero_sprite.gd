## TASK-052 structural tests for the hero AnimatedSprite2D integration.
##
## These tests load player.tscn headless and assert:
##   1. The "Sprite" node is an AnimatedSprite2D (greybox ColorRect removed).
##   2. FacingMark ColorRect has been removed.
##   3. The SpriteFrames on the AnimatedSprite2D has all the expected animation names.
##   4. The CollisionShape2D RectangleShape2D is still size (24, 40) — byte-identical.
##   5. The AnimatedSprite2D carries a non-null SpriteFrames resource.
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
