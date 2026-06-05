@tool
extends SceneTree

## sector_02 visual surfaces as EXACT solid slate slabs (Sprite2D, tiled) matching each
## collision footprint 1:1. The visible TOP of every slab == that surface's collision top,
## so the hero ALWAYS stands ON the surface — no 64px tile-grid snap, no transparent-cap
## gap (the old Tile_27 cap was transparent on its top ~44% and kept leaving the hero
## floating above an invisible space). A thin lighter EDGE (Polygon2D) tops each WALKABLE
## surface so you can read where you stand. VISUAL ONLY: nothing here carries physics — the
## sector_02 StaticBody2D CollisionShape2Ds remain the single source of truth for collision.
##
## Run headless to regenerate res://levels/sector_02_tiles.tscn:
##   Godot --headless --path <root> -s res://tools/build_sector_02_tiles.gd

const SLATE_PATH := "res://assets/tilesets/city/Tile_30.png"  # solid dark-slate, fully opaque
const OUT_PATH := "res://levels/sector_02_tiles.tscn"
const EDGE_COLOR := Color(0.42, 0.47, 0.55, 1.0)              # lighter slate "lip"
const EDGE_H := 6.0

var _root: Node2D
var _slate: Texture2D


## One solid slate slab covering the world rect [x0..x1] x [y0..y1] EXACTLY (top-left at
## (x0,y0)). `walkable` adds a thin lighter edge strip flush with the collision top.
func _slab(sname: String, x0: float, y0: float, x1: float, y1: float, walkable: bool) -> void:
	var s := Sprite2D.new()
	s.name = sname
	s.texture = _slate
	s.centered = false
	s.position = Vector2(x0, y0)
	s.region_enabled = true
	s.region_rect = Rect2(0.0, 0.0, x1 - x0, y1 - y0)   # tiles the slate across the surface
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_root.add_child(s)
	s.owner = _root
	if walkable:
		var lip := Polygon2D.new()
		lip.name = sname + "Edge"
		lip.color = EDGE_COLOR
		lip.polygon = PackedVector2Array([
			Vector2(x0, y0), Vector2(x1, y0),
			Vector2(x1, y0 + EDGE_H), Vector2(x0, y0 + EDGE_H),
		])
		_root.add_child(lip)
		lip.owner = _root


func _init() -> void:
	_slate = load(SLATE_PATH)
	if _slate == null:
		push_error("slate texture missing: %s" % SLATE_PATH)
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
	print("BUILT %s with %d exact slate slabs" % [OUT_PATH, _root.get_child_count()])
	quit(0)
