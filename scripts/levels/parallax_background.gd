## TASK-033 (M2 T1) — reusable greybox parallax backdrop for sector_02.
##
## A self-contained depth background dropped into a level. It is built from three
## `Parallax2D` layers (far -> near) of greybox `ColorRect` silhouettes plus one flat
## far-back fill `ColorRect`, all sitting BEHIND the playfield (negative z_index). The
## parallax2d SKILL is authoritative for the technique: each `Parallax2D` auto-tracks
## the active `Player/Camera2D` via `follow_viewport = true` (NO camera/follow code
## here), `autoscroll` is OFF and `repeat_size = (0,0)` so the backdrop is a pure,
## deterministic function of camera position. Lower `scroll_scale.x` = slower = reads
## as farther away (far 0.15 < mid 0.45 < near 0.80); only X is parallaxed (Y = 1.0).
##
## Composition (godot-game-dev §6): the geometry lives in parallax_background.tscn; this
## thin controller only exposes typed, ordered accessors so level logic and tests read
## the structure without scene-tree spelunking.
class_name ParallaxBackdrop extends Node2D

## The three depth layers, authored far -> near in scene-tree order. Names are the
## single source of truth so the ordered accessor is deterministic.
const _LAYER_NAMES: Array[String] = ["FarSky", "MidStructures", "NearPillars"]


## The ordered `Parallax2D` depth layers, far -> near (slowest -> fastest scroll). Typed
## accessor so callers/tests get a clean, ordered structure instead of tree-walking.
func parallax_layers() -> Array[Parallax2D]:
	var layers: Array[Parallax2D] = []
	for layer_name in _LAYER_NAMES:
		var layer := get_node_or_null(layer_name) as Parallax2D
		if layer != null:
			layers.append(layer)
	return layers


## The flat far-back fill `ColorRect` that back-stops the whole level (z_index == -40).
func background_fill() -> ColorRect:
	return get_node_or_null("Background") as ColorRect
