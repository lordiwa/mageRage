@tool
extends SceneTree

## sector_02 visual surfaces as EXACT solid slabs (Sprite2D, tiled) matching each
## collision footprint 1:1. The visible TOP of every slab == that surface's collision top,
## so the hero ALWAYS stands ON the surface — no 64px tile-grid snap, no transparent-cap
## gap (the old Tile_27 cap was transparent on its top ~44% and kept leaving the hero
## floating above an invisible space).
##
## DARK-ICE re-skin (2026-06-07): the body is the ice-cavern crystalline FILL tile
## (assets/tilesets/ice/ice_fill_A.png) and every WALKABLE surface gets a thin icy CAP
## strip (ice_top_A.png) flush with its collision top so you can still read where you
## stand. Both are TINTED DOWN (modulate) so the bright ice-cavern palette reads dark/
## moody ("ice oscurecido") while keeping the crystal texture. VISUAL ONLY: nothing here
## carries physics — the sector_02 StaticBody2D CollisionShape2Ds remain the single
## source of truth for collision.
##
## Run headless to regenerate res://levels/sector_02_tiles.tscn:
##   Godot --headless --path <root> -s res://tools/build_sector_02_tiles.gd

const FILL_PATH := "res://assets/tilesets/ice/ice_fill_A.png"  # crystalline ice body
const CAP_PATH := "res://assets/tilesets/ice/ice_top_A.png"    # icy capped top edge
const OUT_PATH := "res://levels/sector_02_tiles.tscn"
const CAP_H := 16.0                                            # the cap tile's native height
## Darken the bright ice palette so the map reads dark while keeping the crystal texture.
const BODY_TINT := Color(0.46, 0.44, 0.56, 1.0)               # dark crystal body
const CAP_TINT := Color(0.6, 0.64, 0.76, 1.0)                 # muted icy lip (still reads)

var _root: Node2D
var _fill: Texture2D
var _cap: Texture2D


## A Sprite2D tiling `tex` across the world rect top-left (x0,y0) sized (w,h), crisp
## (NEAREST) so the 16px tiles never blur, tinted by `tint`. Returns it added to _root.
func _tile(
	sname: String, tex: Texture2D, x0: float, y0: float, w: float, h: float, tint: Color
) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = sname
	s.texture = tex
	s.centered = false
	s.position = Vector2(x0, y0)
	s.modulate = tint
	s.region_enabled = true
	s.region_rect = Rect2(0.0, 0.0, w, h)            # tiles the texture across the surface
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(s)
	s.owner = _root
	return s


## One dark-crystal slab covering the world rect [x0..x1] x [y0..y1] EXACTLY (top-left at
## (x0,y0)). `walkable` lays a thin icy CAP strip flush with the collision top so the
## surface reads as standing ground.
func _slab(sname: String, x0: float, y0: float, x1: float, y1: float, walkable: bool) -> void:
	_tile(sname, _fill, x0, y0, x1 - x0, y1 - y0, BODY_TINT)
	if walkable:
		# Cap drawn AFTER the body (later sibling = on top); seated at the collision top,
		# never taller than the slab itself (so a thin ledge stays a thin slab).
		var cap_h: float = minf(CAP_H, y1 - y0)
		_tile(sname + "Cap", _cap, x0, y0, x1 - x0, cap_h, CAP_TINT)


func _init() -> void:
	_fill = load(FILL_PATH)
	_cap = load(CAP_PATH)
	if _fill == null or _cap == null:
		push_error("ice terrain textures missing: %s / %s" % [FILL_PATH, CAP_PATH])
		quit(1)
		return

	_root = Node2D.new()
	_root.name = "CityTiles"
	_root.z_index = -2   # above the z<-10 parallax backdrop, below the entities (z 0)

	# --- EXACT collision footprints from sector_02.tscn (slab top == collision top) -------
	# Floor: pos(2300,360) shape 4600x64 -> collision top y=328; extend DOWN to fill the
	# bottom of the view so it never reads as a thin floating strip.
	_slab("Floor", 0.0, 328.0, 4600.0, 700.0, true)
	# Ceiling: pos(2300,-320) shape 4600x64 -> collision bottom y=-288; extend UP to fill.
	_slab("Ceiling", 0.0, -700.0, 4600.0, -288.0, false)
	# WallLeft: pos(-32,0) shape 64x768 -> x[-64..0]; tall.
	_slab("WallLeft", -64.0, -700.0, 0.0, 700.0, false)
	# LedgeA: pos(560,200) shape 260x24 -> top y=188; slim platform slab.
	_slab("LedgeA", 430.0, 188.0, 690.0, 236.0, true)
	# LedgeB: pos(900,80) shape 260x24 -> top y=68.
	_slab("LedgeB", 770.0, 68.0, 1030.0, 116.0, true)
	# LedgeC: pos(1240,-40) shape 260x24 -> top y=-52.
	_slab("LedgeC", 1110.0, -52.0, 1370.0, -4.0, true)
	# BossWallLeft: pos(3900,70) shape 48x520 -> x[3876..3924]; extend down to the floor.
	_slab("BossWall", 3876.0, -190.0, 3924.0, 700.0, false)
	# BossStep: pos(4100,220) shape 300x24 -> top y=208.
	_slab("BossStep", 3950.0, 208.0, 4250.0, 256.0, true)

	var packed := PackedScene.new()
	var e := packed.pack(_root)
	if e != OK:
		push_error("pack() failed: %d" % e)
		quit(1)
		return
	e = ResourceSaver.save(packed, OUT_PATH)
	if e != OK:
		push_error("save() failed: %d" % e)
		quit(1)
		return
	print("BUILT %s with %d slab nodes (dark-ice fill + walkable caps)"
		% [OUT_PATH, _root.get_child_count()])
	quit(0)
