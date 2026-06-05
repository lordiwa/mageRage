@tool
extends SceneTree

## One-shot builder (TASK-043): constructs the VISUAL City-tileset TileMapLayer that
## skins sector_02's greybox surfaces, packs it as res://levels/sector_02_tiles.tscn,
## and exits. It paints cells over the EXISTING collision footprints (it does NOT define
## or alter any collision — the TileSet carries no physics layer; the sector_02
## StaticBody2D CollisionShape2Ds remain the single source of truth).
##
## Run headless:
##   Godot --headless --path <root> -s res://tools/build_sector_02_tiles.gd
##
## Grid: native tile 128px; the TileMapLayer is scaled 0.5 so each cell = 64 world px.
## A cell (cx,cy) covers world [cx*64 .. cx*64+64] x [cy*64 .. cy*64+64] (layer at origin).
## Source 0 = Tile_88 (fill grate body); Source 1 = Tile_85 (rail-capped top surface).

const TILESET_PATH := "res://assets/tilesets/city/city_tileset.tres"
const OUT_PATH := "res://levels/sector_02_tiles.tscn"
const CELL := 64.0
const FILL := 0   # source_id for Tile_88 (full grate body)
const CAP := 1    # source_id for Tile_85 (rail-capped top surface)
const ATLAS := Vector2i(0, 0)

## TASK-048 floor-alignment nudge. The CAP texture (Tile_27) is TRANSPARENT for its
## top ~44.53% — its solid grey lip only begins partway down the tile — so the floor
## cap cell (whose CELL-top sits at world y=320, the snapped cap row for floor top 328)
## renders its VISIBLE lip at 320 + 0.4453*64 = 348.5, i.e. ~20px BELOW the hero's feet
## (the live bug: "estoy flotando en el aire"). We nudge the whole layer UP so that
## visible lip lands on the collision floor top (y=328). VISUAL ONLY — the layer carries
## no physics; the StaticBody2D collision is untouched. Derived (not magic) below.
const CAP_OPAQUE_ONSET := 0.4453   # measured first-opaque row of Tile_27 (256px tall)
const FLOOR_TOP := 328.0           # collision floor top (reused DD-011 corridor metric)
const FLOOR_CAP_CELL_TOP := 320.0  # floor cap row cy=5 cell-top at layer position 0
## Shift so (cap cell-top + opaque header) == the collision floor top: -20.5px.
const LAYER_Y_NUDGE := FLOOR_TOP - (FLOOR_CAP_CELL_TOP + CAP_OPAQUE_ONSET * CELL)


## World-rect -> inclusive cell range [cx0..cx1] x [cy0..cy1] that COVERS the rect.
func _cells_for(x0: float, y0: float, x1: float, y1: float) -> Array:
	var cx0 := int(floor(x0 / CELL))
	var cy0 := int(floor(y0 / CELL))
	var cx1 := int(ceil(x1 / CELL)) - 1
	var cy1 := int(ceil(y1 / CELL)) - 1
	return [cx0, cy0, cx1, cy1]


func _paint_surface(layer: TileMapLayer, x0: float, y0: float, x1: float, y1: float, capped_top: bool) -> void:
	var r := _cells_for(x0, y0, x1, y1)
	var cx0: int = r[0]
	var cy0: int = r[1]
	var cx1: int = r[2]
	var cy1: int = r[3]
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var src := FILL
			if capped_top and cy == cy0:
				src = CAP
			layer.set_cell(Vector2i(cx, cy), src, ATLAS)


func _init() -> void:
	var tileset: TileSet = load(TILESET_PATH)
	if tileset == null:
		push_error("TileSet failed to load: %s" % TILESET_PATH)
		quit(1)
		return

	var layer := TileMapLayer.new()
	layer.name = "CityTiles"
	layer.tile_set = tileset
	layer.scale = Vector2(0.5, 0.5)   # 128px tiles -> 64px world cells
	layer.z_index = -2                # above the z<-10 parallax, below entities
	# TASK-048: seat every cap's VISIBLE solid lip on its collision surface (see above).
	layer.position = Vector2(0.0, LAYER_Y_NUDGE)

	# --- Surfaces, from the EXACT collision footprints in sector_02.tscn ---------
	# Floor: pos(2300,360) shape 4600x64 -> x[0..4600] y[328..392]; capped top.
	_paint_surface(layer, 0.0, 328.0, 4600.0, 392.0, true)
	# Ceiling: pos(2300,-320) shape 4600x64 -> x[0..4600] y[-352..-288]; fill.
	_paint_surface(layer, 0.0, -352.0, 4600.0, -288.0, false)
	# WallLeft: pos(-32,0) shape 64x768 -> x[-64..0] y[-384..384]; fill.
	_paint_surface(layer, -64.0, -384.0, 0.0, 384.0, false)
	# LedgeA: pos(560,200) shape 260x24 -> x[430..690] y[188..212]; capped.
	_paint_surface(layer, 430.0, 188.0, 690.0, 212.0, true)
	# LedgeB: pos(900,80) shape 260x24 -> x[770..1030] y[68..92]; capped.
	_paint_surface(layer, 770.0, 68.0, 1030.0, 92.0, true)
	# LedgeC: pos(1240,-40) shape 260x24 -> x[1110..1370] y[-52..-28]; capped.
	_paint_surface(layer, 1110.0, -52.0, 1370.0, -28.0, true)
	# BossWallLeft: pos(3900,70) shape 48x520 -> x[3876..3924] y[-190..330]; fill.
	_paint_surface(layer, 3876.0, -190.0, 3924.0, 330.0, false)
	# BossStep: pos(4100,220) shape 300x24 -> x[3950..4250] y[208..232]; capped.
	_paint_surface(layer, 3950.0, 208.0, 4250.0, 232.0, true)
	# Combat-pocket floor accent: a capped strip under the pocket marker (3200,288)
	# along the floor top so the combat pocket reads as a tiled platform pad. The
	# floor already tiles here; add nothing collision-bearing (purely the floor cap).

	var packed := PackedScene.new()
	var err := packed.pack(layer)
	if err != OK:
		push_error("pack() failed: %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, OUT_PATH)
	if err != OK:
		push_error("save() failed: %d" % err)
		quit(1)
		return
	print("BUILT %s with %d painted cells" % [OUT_PATH, layer.get_used_cells().size()])
	quit(0)
