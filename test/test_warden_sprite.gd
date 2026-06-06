## TASK-058 structural tests for the Warden boss AnimatedSprite2D integration.
##
## Loads scenes/warden.tscn headless and asserts:
##   1. The "Sprite" node is an AnimatedSprite2D (the greybox ColorRect is removed).
##   2. The SpriteFrames carries idle/walk/attack/hurt with the right loop flags
##      (idle/walk loop; attack/hurt one-shot) — built from warden_frames.tres.
##   3. The AnimatedSprite2D resolves to NEAREST texture filtering (crisp pixel-art).
##   4. The body RectangleShape2D collision is BYTE-IDENTICAL (72, 96) — the
##      gameplay-safety gate (boss reachability / encounter math must not drift).
##   5. The Label, StateMachine, and Health children survive the swap (boss wiring
##      kept exactly).
##   6. The boss feet seat on the collision bottom (measured opaque bbox of idle 0).
##
## Uses process_frame await (structure only, no physics await) so it cannot poison
## later input-edge tests.
extends GutTest

const WARDEN_SCENE := preload("res://scenes/warden.tscn")

const WARDEN_ANIMS := ["idle", "walk", "attack", "hurt"]
const LOOPING := {"idle": true, "walk": true}
const NON_LOOPING := ["attack", "hurt"]

## Byte-identical boss collision (the gameplay-safety gate).
const WARDEN_BODY_SIZE := Vector2(72.0, 96.0)


func _make() -> CharacterBody2D:
	var node := WARDEN_SCENE.instantiate() as CharacterBody2D
	add_child_autofree(node)
	await get_tree().process_frame
	return node


## Resolve a CanvasItem's effective texture filter (PARENT_NODE inheritance up the
## tree, then the project default). Mirrors test_enemy_sprites / test_hero_sprite.
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


func test_warden_sprite_is_animated() -> void:
	var node: CharacterBody2D = await _make()
	var sprite := node.get_node_or_null("Sprite")
	assert_not_null(sprite, "a node named 'Sprite' exists")
	assert_true(sprite is AnimatedSprite2D,
		"'Sprite' is an AnimatedSprite2D (greybox ColorRect replaced)")


func test_warden_sprite_has_expected_anims_and_loops() -> void:
	var node: CharacterBody2D = await _make()
	var sprite := node.get_node_or_null("Sprite") as AnimatedSprite2D
	assert_not_null(sprite, "'Sprite' is an AnimatedSprite2D")
	if sprite == null:
		return
	assert_not_null(sprite.sprite_frames, "the boss AnimatedSprite2D has a SpriteFrames")
	if sprite.sprite_frames == null:
		return
	for anim_name in WARDEN_ANIMS:
		assert_true(sprite.sprite_frames.has_animation(anim_name),
			"warden SpriteFrames has animation '%s'" % anim_name)
	for anim_name in LOOPING:
		if sprite.sprite_frames.has_animation(anim_name):
			assert_true(sprite.sprite_frames.get_animation_loop(anim_name),
				"warden animation '%s' loops" % anim_name)
	for anim_name in NON_LOOPING:
		if sprite.sprite_frames.has_animation(anim_name):
			assert_false(sprite.sprite_frames.get_animation_loop(anim_name),
				"warden animation '%s' is a one-shot (no loop)" % anim_name)


func test_warden_sprite_nearest_filter() -> void:
	var node: CharacterBody2D = await _make()
	var sprite := node.get_node_or_null("Sprite") as AnimatedSprite2D
	assert_not_null(sprite, "'Sprite' is an AnimatedSprite2D")
	if sprite == null:
		return
	assert_eq(_effective_texture_filter(sprite), CanvasItem.TEXTURE_FILTER_NEAREST,
		"the warden AnimatedSprite2D resolves to NEAREST filtering (crisp pixel-art)")


func test_warden_collision_byte_identical() -> void:
	var node: CharacterBody2D = await _make()
	var col := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_not_null(col, "CollisionShape2D exists")
	var rect := col.shape as RectangleShape2D
	assert_not_null(rect, "the collision shape is a RectangleShape2D")
	assert_eq(rect.size, WARDEN_BODY_SIZE, "warden body collision is byte-identical (72, 96)")


func test_warden_boss_wiring_survives_swap() -> void:
	var node: CharacterBody2D = await _make()
	assert_not_null(node.get_node_or_null("Label"), "the HP Label is kept")
	assert_not_null(node.get_node_or_null("StateMachine"), "the StateMachine is kept")
	assert_not_null(node.get_node_or_null("Health"), "the Health child is kept")
	assert_not_null(node.get_node_or_null("AnimationController"),
		"the AnimationController child is added (like the other enemies)")


func test_warden_feet_seated() -> void:
	var node: CharacterBody2D = await _make()
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
	var used := img.get_used_rect()
	var frame_h := float(img.get_height())
	var feet_row_px := float(used.position.y + used.size.y)
	assert_true(sprite.centered, "the AnimatedSprite2D is centered (offset math assumes it)")
	var local_feet_y := (feet_row_px - frame_h * 0.5) * sprite.scale.y + sprite.position.y
	var collision_bottom_y := WARDEN_BODY_SIZE.y * 0.5   # shape center at (0,0)
	# Tolerance a touch looser than the drones: the big-but-fair boss scale is a
	# documented playtest tweak, but feet should still land near the floor.
	assert_almost_eq(local_feet_y, collision_bottom_y, 3.0,
		"measured opaque feet seat on the boss collision bottom (~%.0f local y)" % collision_bottom_y)
