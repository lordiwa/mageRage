## TASK-056 structural tests for the enemy AnimatedSprite2D integration.
##
## Loads each of the 3 sector_02 combat enemy scenes headless and asserts:
##   1. The "Sprite" node is an AnimatedSprite2D (greybox ColorRect removed).
##   2. The shield_drone's extra "Shield" ColorRect is removed.
##   3. The SpriteFrames carries the expected per-enemy animation names + loop flags.
##   4. The AnimatedSprite2D carries a non-null SpriteFrames resource.
##   5. The AnimatedSprite2D resolves to NEAREST texture filtering (crisp pixel-art).
##   6. Every RectangleShape2D collision is BYTE-IDENTICAL (the gameplay-safety gate):
##        empire_drone & shield_drone body = (28, 36)
##        charger body = (36, 44); charger LungeHitbox = (48, 40)
##   7. The idle frame opaque feet seat on the collision bottom (measured opaque bbox).
##
## Uses process_frame await (structure only, no physics await) so it cannot poison
## later input-edge tests.
extends GutTest

const EMPIRE_SCENE := preload("res://scenes/empire_drone.tscn")
const SHIELD_SCENE := preload("res://scenes/shield_drone.tscn")
const CHARGER_SCENE := preload("res://scenes/charger.tscn")

## Expected animation names per enemy family.
const DRONE_ANIMS := ["idle", "walk", "attack", "hurt"]
const CHARGER_ANIMS := ["idle", "walk", "windup", "charge", "hurt"]

## Loop expectations: idle/walk loop; the rest are one-shots.
const LOOPING := {"idle": true, "walk": true}
const NON_LOOPING := ["attack", "hurt", "windup", "charge"]

## Byte-identical collision sizes (the gameplay-safety gate).
const DRONE_BODY_SIZE := Vector2(28.0, 36.0)
const CHARGER_BODY_SIZE := Vector2(36.0, 44.0)
const CHARGER_LUNGE_SIZE := Vector2(48.0, 40.0)


func _make(scene: PackedScene) -> CharacterBody2D:
	var node := scene.instantiate() as CharacterBody2D
	add_child_autofree(node)
	await get_tree().process_frame
	return node


## Resolve a CanvasItem's effective texture filter, following PARENT_NODE (0)
## inheritance up the tree, then the project default. Mirrors Godot's resolution
## and the hero test (test_hero_sprite.gd).
func _effective_texture_filter(item: CanvasItem) -> int:
	var node: Node = item
	while node != null:
		if node is CanvasItem:
			var f: int = (node as CanvasItem).texture_filter
			if f != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
				return f
		node = node.get_parent()
	var proj_default: int = int(ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter", 1))
	if proj_default == 0:
		return CanvasItem.TEXTURE_FILTER_NEAREST
	return CanvasItem.TEXTURE_FILTER_LINEAR


## Shared structural assertions for a given enemy scene + expected anim set.
func _assert_sprite(node: CharacterBody2D, anims: Array) -> void:
	var sprite := node.get_node_or_null("Sprite")
	assert_not_null(sprite, "a node named 'Sprite' exists")
	assert_true(sprite is AnimatedSprite2D,
		"'Sprite' is an AnimatedSprite2D (greybox ColorRect replaced)")
	var asprite := sprite as AnimatedSprite2D
	if asprite == null:
		return
	assert_not_null(asprite.sprite_frames,
		"the AnimatedSprite2D has a non-null SpriteFrames resource")
	if asprite.sprite_frames == null:
		return
	for anim_name in anims:
		assert_true(asprite.sprite_frames.has_animation(anim_name),
			"SpriteFrames has animation '%s'" % anim_name)
	# Loop flags.
	for anim_name in LOOPING:
		if asprite.sprite_frames.has_animation(anim_name):
			assert_true(asprite.sprite_frames.get_animation_loop(anim_name),
				"animation '%s' loops" % anim_name)
	for anim_name in NON_LOOPING:
		if anim_name in anims and asprite.sprite_frames.has_animation(anim_name):
			assert_false(asprite.sprite_frames.get_animation_loop(anim_name),
				"animation '%s' is a one-shot (no loop)" % anim_name)
	# NEAREST filter (pixel-art, no blur).
	assert_eq(_effective_texture_filter(asprite), CanvasItem.TEXTURE_FILTER_NEAREST,
		"the enemy AnimatedSprite2D resolves to NEAREST filtering (crisp pixel-art)")


## Measured feet-seating: the idle frame opaque bottom maps to the collision bottom.
func _assert_feet_seated(node: CharacterBody2D, half_height: float) -> void:
	var sprite := node.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		pending("Sprite not yet AnimatedSprite2D — IMPL step pending")
		return
	if not sprite.sprite_frames.has_animation("idle"):
		pending("idle animation not yet defined — IMPL step pending")
		return
	var tex := sprite.sprite_frames.get_frame_texture("idle", 0)
	assert_not_null(tex, "idle frame 0 has a texture")
	var img := tex.get_image()
	assert_not_null(img, "idle frame 0 yields an Image")
	var used := img.get_used_rect()
	var frame_h := float(img.get_height())
	var feet_row_px := float(used.position.y + used.size.y)
	assert_true(sprite.centered, "the AnimatedSprite2D is centered (offset math assumes it)")
	var local_feet_y := (feet_row_px - frame_h * 0.5) * sprite.scale.y + sprite.position.y
	var collision_bottom_y := half_height   # shape center is at (0,0)
	assert_almost_eq(local_feet_y, collision_bottom_y, 2.0,
		"measured opaque feet seat on the collision bottom (~%.0f local y)" % half_height)


## --- empire_drone ------------------------------------------------------------

func test_empire_drone_sprite_is_animated() -> void:
	var node: CharacterBody2D = await _make(EMPIRE_SCENE)
	_assert_sprite(node, DRONE_ANIMS)


func test_empire_drone_collision_byte_identical() -> void:
	var node: CharacterBody2D = await _make(EMPIRE_SCENE)
	var col := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_not_null(col, "CollisionShape2D exists")
	var rect := col.shape as RectangleShape2D
	assert_not_null(rect, "the collision shape is a RectangleShape2D")
	assert_eq(rect.size, DRONE_BODY_SIZE, "empire_drone collision is byte-identical (28, 36)")


func test_empire_drone_feet_seated() -> void:
	var node: CharacterBody2D = await _make(EMPIRE_SCENE)
	_assert_feet_seated(node, DRONE_BODY_SIZE.y * 0.5)


## --- shield_drone ------------------------------------------------------------

func test_shield_drone_sprite_is_animated() -> void:
	var node: CharacterBody2D = await _make(SHIELD_SCENE)
	_assert_sprite(node, DRONE_ANIMS)


func test_shield_drone_shield_color_rect_removed() -> void:
	var node: CharacterBody2D = await _make(SHIELD_SCENE)
	assert_null(node.get_node_or_null("Shield"),
		"the greybox Shield ColorRect has been removed from shield_drone.tscn")


func test_shield_drone_collision_byte_identical() -> void:
	var node: CharacterBody2D = await _make(SHIELD_SCENE)
	var col := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_not_null(col, "CollisionShape2D exists")
	var rect := col.shape as RectangleShape2D
	assert_not_null(rect, "the collision shape is a RectangleShape2D")
	assert_eq(rect.size, DRONE_BODY_SIZE, "shield_drone collision is byte-identical (28, 36)")


func test_shield_drone_feet_seated() -> void:
	var node: CharacterBody2D = await _make(SHIELD_SCENE)
	_assert_feet_seated(node, DRONE_BODY_SIZE.y * 0.5)


## --- charger -----------------------------------------------------------------

func test_charger_sprite_is_animated() -> void:
	var node: CharacterBody2D = await _make(CHARGER_SCENE)
	_assert_sprite(node, CHARGER_ANIMS)


func test_charger_body_collision_byte_identical() -> void:
	var node: CharacterBody2D = await _make(CHARGER_SCENE)
	var col := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_not_null(col, "CollisionShape2D exists")
	var rect := col.shape as RectangleShape2D
	assert_not_null(rect, "the collision shape is a RectangleShape2D")
	assert_eq(rect.size, CHARGER_BODY_SIZE, "charger body collision is byte-identical (36, 44)")


func test_charger_lunge_hitbox_collision_byte_identical() -> void:
	var node: CharacterBody2D = await _make(CHARGER_SCENE)
	var lunge := node.get_node_or_null("LungeHitbox")
	assert_not_null(lunge, "the LungeHitbox Area2D still exists")
	var col := lunge.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_not_null(col, "the LungeHitbox CollisionShape2D exists")
	var rect := col.shape as RectangleShape2D
	assert_not_null(rect, "the LungeHitbox shape is a RectangleShape2D")
	assert_eq(rect.size, CHARGER_LUNGE_SIZE, "charger LungeHitbox is byte-identical (48, 40)")


func test_charger_feet_seated() -> void:
	var node: CharacterBody2D = await _make(CHARGER_SCENE)
	_assert_feet_seated(node, CHARGER_BODY_SIZE.y * 0.5)
