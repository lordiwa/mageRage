# Mage Rage — Art Asset Credits

This file credits third-party art committed into the `assets/` tree. The project
holds the rights to use and commit these assets (confirmed by the project owner);
the attribution below is provided as courtesy.

## Parallax backgrounds

### `assets/parallax/sector_02/` — industrial skyline (sector_02 backdrop)
- **Files:** `Background_Layer_1.png`, `Background_Layer_2.png`, `Background_Layer_3.png`
- **Author:** Franco Giachetti / Simirk
- **Pack:** "City / Industrial Platform Tileset"
- **Use:** the three authored horizontal-parallax layers (far / mid / near) skinning
  the sector_02 `Parallax2D` backdrop (`scenes/parallax_background.tscn`).

## Tilesets

### `assets/tilesets/city/` — industrial City tiles (sector_02 surface skin)
- **Files:** `Tile_2.png`, `Tile_5.png` (SOLID opaque ground — TASK-046), and
  `Tile_85.png`, `Tile_88.png` (grate accents); all curated from the pack's 128px set,
  plus the derived `city_tileset.tres` `TileSet`.
- **Author:** Franco Giachetti / Simirk
- **Pack:** "City / Industrial Platform Tileset"
- **Use:** `Tile_2` (a solid teal/sage-capped brick) skins the walkable TOP surface and
  `Tile_5` (solid red brick) the body/fill, so the floor / ledges / boss step read as
  CONTINUOUS SOLID GROUND (TASK-046 readability fix). `Tile_88` / `Tile_85` (the weathered
  grey X-brace + rail-capped GRATE tiles) are retained as see-through accent/detail
  sources. Built into a `TileSet` and painted by the `CityTiles` `TileMapLayer` to
  VISUALLY skin sector_02's greybox surfaces (floor / ceiling / left wall / ledges /
  boss wall+step). Purely decorative — the TileSet carries no physics layer; collision
  remains on the sector_02 `StaticBody2D` nodes.
