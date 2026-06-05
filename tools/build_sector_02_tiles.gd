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
## Atlas source ids in city_tileset.tres (TASK-046 solid-floor mapping):
##   source 0 = Tile_30  (SOLID dark-slate FILL — body/interior/wall/ceiling slab)
##   source 1 = Tile_27  (SOLID grey-capped slate — walkable TOP surface lip)
##   sources 2/3 = Tile_88 / Tile_85 grate ACCENTS (see-through; detail only)

const TILESET_PATH := "res://assets/tilesets/city/city_tileset.tres"
const OUT_PATH := "res://levels/sector_02_tiles.tscn"
const CELL := 64.0
const FILL := 0   # source_id for Tile_30 (solid fill body)
const CAP := 1    # source_id for Tile_27 (solid grey-capped TOP surface)
const ATLAS := Vector2i(0, 0)

## TASK-048 per-surface cap seating. ROOT CAUSE: the cap art (Tile_27) is TRANSPARENT
## for its top ~44.53% of its height, so its VISIBLE grey lip renders ~28.5 world px
## BELOW its cell top. And because every capped surface's collision top sits at a
## DIFFERENT sub-cell offset below the cell the painter snaps the cap to (floor 8 /
## LedgeA 60 / LedgeB 4 / LedgeC 12 / BossStep 16 px), NO single layer translate can
## seat them all — a global nudge that fixes the floor floats the ledge caps.
##
## ROBUST FIX (at the cap ATLAS SOURCE): the painter shifts the cap art per surface via
## a TileData `texture_origin` so its opaque LIP lands exactly on that surface's OWN
## collision top. One cap ALTERNATIVE tile is created per distinct shift; the cap source
## also gets a TALL region so the opaque slate body still covers the cell after the
## shift (no gap under the lip). VISUAL ONLY — the layer/tiles carry no physics; the
## StaticBody2D collision tops are the source of truth this painter reads, never writes.

## The cap texture's opaque-onset fraction (first opaque row / texture height). Measured
## from Tile_27 (the only cap source); recomputed at build time so it cannot drift.
var _cap_onset_frac := 0.4453
## Map: required cap shift in WORLD px (lip-target - lip-default) -> cap alternative id.
var _cap_alt_for_shift := {}
## The cap atlas source (Tile_27), cached after we widen its region for the shift.
var _cap_src: TileSetAtlasSource = null


## World-rect -> inclusive cell range [cx0..cx1] x [cy0..cy1] that COVERS the rect.
func _cells_for(x0: float, y0: float, x1: float, y1: float) -> Array:
	var cx0 := int(floor(x0 / CELL))
	var cy0 := int(floor(y0 / CELL))
	var cx1 := int(ceil(x1 / CELL)) - 1
	var cy1 := int(ceil(y1 / CELL)) - 1
	return [cx0, cy0, cx1, cy1]


## Measure the cap texture's opaque-onset fraction (first opaque row / height) so the
## seating math is derived from the actual art, never a magic number.
func _measure_cap_onset(tileset: TileSet) -> void:
	_cap_src = tileset.get_source(CAP) as TileSetAtlasSource
	if _cap_src == null or _cap_src.texture == null:
		push_error("cap source (id %d) missing texture" % CAP)
		quit(1)
		return
	var img := _cap_src.texture.get_image()
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.16:
				_cap_onset_frac = float(y) / float(h)
				return


## Resolve (creating once) the cap ALTERNATIVE tile whose texture_origin shifts the cap
## art by `shift_world` px so its opaque lip lands on a surface's collision top. The base
## tile (alt 0) is the unshifted cap; alternatives carry the per-surface vertical offset.
## texture_origin is in (unscaled) tile px; the layer scale is 0.5, so 1 world px = 2 tile
## px. Positive texture_origin.y moves the drawn texture UP, so a DOWNWARD lip shift uses a
## negative origin. The cap art is opaque from its lip to its bottom edge; combined with a
## fill cell painted directly under every cap (see _paint_surface) this leaves no gap.
func _cap_alternative_for(shift_world: float) -> int:
	var key := snappedf(shift_world, 0.01)
	if _cap_alt_for_shift.has(key):
		return _cap_alt_for_shift[key]
	if is_equal_approx(key, 0.0):
		_cap_alt_for_shift[key] = 0
		return 0
	var alt := _cap_src.create_alternative_tile(ATLAS)
	var data := _cap_src.get_tile_data(ATLAS, alt)
	# Move the lip DOWN by +shift_world (origin negative) / UP by -shift_world.
	data.texture_origin = Vector2i(0, int(round(-shift_world * 2.0)))
	_cap_alt_for_shift[key] = alt
	return alt


## The cap shift (world px) needed so the cap painted at cell-row `cy0` seats its opaque
## lip on the collision top `y_top`: target lip (y_top) minus the default lip world Y
## (cell-top + onset*CELL).
func _cap_shift_for(cy0: int, y_top: float) -> float:
	var default_lip := float(cy0) * CELL + _cap_onset_frac * CELL
	return y_top - default_lip


func _paint_surface(layer: TileMapLayer, x0: float, y0: float, x1: float, y1: float, capped_top: bool) -> void:
	var r := _cells_for(x0, y0, x1, y1)
	var cx0: int = r[0]
	var cy0: int = r[1]
	var cx1: int = r[2]
	var cy1: int = r[3]
	# Per-surface cap shift: seat the opaque lip on the collision top (y0) of THIS surface.
	var cap_alt := 0
	if capped_top:
		cap_alt = _cap_alternative_for(_cap_shift_for(cy0, y0))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			if capped_top and cy == cy0:
				layer.set_cell(Vector2i(cx, cy), CAP, ATLAS, cap_alt)
			else:
				layer.set_cell(Vector2i(cx, cy), FILL, ATLAS)
	# A shifted cap can expose a thin strip at its cell bottom; back every cap with a FILL
	# body cell directly below so the platform reads solid (visual only — no collision).
	if capped_top:
		for cx in range(cx0, cx1 + 1):
			var below := Vector2i(cx, cy1 + 1)
			if layer.get_cell_source_id(below) < 0:
				layer.set_cell(below, FILL, ATLAS)


func _init() -> void:
	var tileset: TileSet = load(TILESET_PATH)
	if tileset == null:
		push_error("TileSet failed to load: %s" % TILESET_PATH)
		quit(1)
		return

	# TASK-048: measure the cap art's opaque onset and prepare its per-surface shift
	# alternatives so each capped surface seats its lip on its OWN collision top.
	_measure_cap_onset(tileset)

	var layer := TileMapLayer.new()
	layer.name = "CityTiles"
	layer.tile_set = tileset
	layer.scale = Vector2(0.5, 0.5)   # 128px tiles -> 64px world cells
	layer.z_index = -2                # above the z<-10 parallax, below entities

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

	# Persist the cap alternatives (per-surface texture_origin shifts) back to the TileSet
	# so the scene's external .tres reference renders the seated lips. VISUAL ONLY — these
	# are atlas alternatives + texture_origin; the TileSet still carries NO physics layer.
	var ts_err := ResourceSaver.save(tileset, TILESET_PATH)
	if ts_err != OK:
		push_error("tileset save() failed: %d" % ts_err)
		quit(1)
		return

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
	print("BUILT %s with %d painted cells, %d cap alternatives"
		% [OUT_PATH, layer.get_used_cells().size(), _cap_alt_for_shift.size()])
	quit(0)
