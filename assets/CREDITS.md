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
- **Files:** `Tile_85.png`, `Tile_88.png` (curated from the pack's Medium/128px set),
  plus the derived `city_tileset.tres` `TileSet`.
- **Author:** Franco Giachetti / Simirk
- **Pack:** "City / Industrial Platform Tileset"
- **Use:** weathered grey industrial grate tiles (full X-brace body + rail-capped top)
  built into a `TileSet` and painted by the `CityTiles` `TileMapLayer` to VISUALLY skin
  sector_02's greybox surfaces (floor / ceiling / left wall / ledges / boss wall+step).
  Purely decorative — the TileSet carries no physics layer; collision remains on the
  sector_02 `StaticBody2D` nodes.
