## TASK-033 (M2 T1) — unit tests for the reusable greybox parallax backdrop
## (scenes/parallax_background.tscn + scripts/levels/parallax_background.gd,
## ParallaxBackdrop).
##
## DD / sector_02 plan: a reusable depth backdrop built from three `Parallax2D`
## layers (far -> near) plus a flat far-back fill ColorRect, all sitting BEHIND the
## playfield (negative z_index). Per the parallax2d SKILL, layers do NOT scroll under
## GUT headless (no viewport travel), so these tests assert STRUCTURE ONLY — never
## motion or position deltas — which also keeps them free of `await physics_frame`
## so they cannot poison later input-edge tests (known GUT cross-script flake).
extends GutTest

const BACKDROP := preload("res://scenes/parallax_background.tscn")

## scroll_scale.x targets far -> near, strictly increasing (slower = farther).
const FAR_SCALE := 0.15
const MID_SCALE := 0.45
const NEAR_SCALE := 0.80
const EPS := 0.001


## Instance the backdrop, parent it (auto-freed) and settle one frame so @onready /
## _ready run. No physics await — structure only.
func _make_backdrop() -> ParallaxBackdrop:
	var backdrop := BACKDROP.instantiate() as ParallaxBackdrop
	add_child_autofree(backdrop)
	await get_tree().process_frame
	return backdrop


func test_scene_loads_and_instantiates_clean() -> void:
	var backdrop: ParallaxBackdrop = await _make_backdrop()
	assert_not_null(backdrop, "the parallax backdrop scene instantiates cleanly")
	assert_true(backdrop is Node2D, "the backdrop root is a Node2D")


func test_exactly_three_parallax_layers_present() -> void:
	var backdrop: ParallaxBackdrop = await _make_backdrop()
	var layers := backdrop.parallax_layers()
	assert_eq(layers.size(), 3, "exactly 3 Parallax2D depth layers (far/mid/near)")
	for layer in layers:
		assert_true(layer is Parallax2D, "each depth layer is a Parallax2D node")


func test_scroll_scale_x_matches_far_mid_near_targets() -> void:
	var backdrop: ParallaxBackdrop = await _make_backdrop()
	var layers := backdrop.parallax_layers()
	assert_almost_eq(layers[0].scroll_scale.x, FAR_SCALE, EPS, "far layer scroll_scale.x ~= 0.15")
	assert_almost_eq(layers[1].scroll_scale.x, MID_SCALE, EPS, "mid layer scroll_scale.x ~= 0.45")
	assert_almost_eq(layers[2].scroll_scale.x, NEAR_SCALE, EPS, "near layer scroll_scale.x ~= 0.80")


func test_scroll_scale_x_strictly_increases_far_to_near() -> void:
	var backdrop: ParallaxBackdrop = await _make_backdrop()
	var layers := backdrop.parallax_layers()
	for i in range(1, layers.size()):
		assert_gt(
			layers[i].scroll_scale.x,
			layers[i - 1].scroll_scale.x,
			"scroll_scale.x strictly increases far -> near (slower = farther)"
		)


func test_each_layer_scroll_scale_y_is_one() -> void:
	# Only X is parallaxed; vertical moves 1:1 with the camera (no vertical pop).
	var backdrop: ParallaxBackdrop = await _make_backdrop()
	for layer in backdrop.parallax_layers():
		assert_almost_eq(layer.scroll_scale.y, 1.0, EPS, "Y scroll is 1:1, not parallaxed")


func test_each_layer_has_at_least_one_colorrect_silhouette() -> void:
	var backdrop: ParallaxBackdrop = await _make_backdrop()
	for layer in backdrop.parallax_layers():
		var rects := layer.find_children("*", "ColorRect", true, false)
		assert_gt(rects.size(), 0, "each Parallax2D layer holds >= 1 ColorRect silhouette")


func test_all_parallax_layers_are_behind_the_playfield() -> void:
	# All depth layers sit well behind the playfield: z_index < -10.
	var backdrop: ParallaxBackdrop = await _make_backdrop()
	for layer in backdrop.parallax_layers():
		assert_lt(layer.z_index, -10, "each Parallax2D layer draws behind the playfield (z_index < -10)")


func test_flat_fill_background_exists_at_z_index_minus_40() -> void:
	# The flat far-back fill ColorRect back-stops the whole level at z_index == -40.
	var backdrop: ParallaxBackdrop = await _make_backdrop()
	var fill := backdrop.background_fill()
	assert_not_null(fill, "the backdrop has a flat fill Background ColorRect")
	assert_true(fill is ColorRect, "the flat fill is a ColorRect")
	assert_eq(fill.z_index, -40, "the flat fill Background sits at z_index == -40")
