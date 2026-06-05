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

## Hero sprites

### `assets/sprites/hero/` — technomagical elemental monk hero (player character)
- **Files:** `idle/` (9f), `walk/` (4f), `jump/` (7f), `flight/` (9f), `attack/` (9f), `hurt/` (9f)
  — all EAST-facing frames only (flip_h used for left-facing; west sets not imported).
- **Author:** Generated via [PixelLab](https://www.pixellab.ai/) by the project owner.
- **Character prompt:** "technomagical elemental monk with human features in pixel art 16 bit mcfarlane style"
- **Size:** 92x92 px per frame, side-view, 8-direction mannequin template.
- **PixelLab group_id:** `2d846152-f61f-44f5-b0e0-16cc081e4697`
- **Usage rights:** Project owner generated and holds rights to use these assets.
- **Animation sources (from metadata.json):**
  - idle ← `The_character_shifts_their_weight_slightly_drawing-9493b1eb` east (technomagical_elemental_monk_with_human)
  - walk ← `Walking-9b229e6c` east (technomagical_elemental_monk_with_human)
  - jump/fall ← `Two-Footed_Jump-719410fa` east — rising frames = jump, descending = fall
  - flight ← `The_bald_fighter_suspended_in_mid-air_with_a_glowi-5f192d39` east (fighting_pose_while)
  - attack ← `attack-4f63bc26` east (fighting_pose_while)
  - hurt ← `takedamage-59543786` east (technomagical_elemental_monk_with_human)
- **Gaps documented:** glide (GlideState) falls back to "fall" frames; death has no anim (holds last hurt frame).

## Tilesets

### `assets/tilesets/city/` — industrial City tiles (sector_02 surface skin)
- **Files:** `Tile_27.png`, `Tile_30.png` (SOLID opaque GREY/SLATE ground — TASK-046),
  and `Tile_85.png`, `Tile_88.png` (grate accents); all curated from the pack's 128px
  set, plus the derived `city_tileset.tres` `TileSet`.
- **Author:** Franco Giachetti / Simirk
- **Pack:** "City / Industrial Platform Tileset"
- **Use:** `Tile_27` (a solid grey-capped slate) skins the walkable TOP surface and
  `Tile_30` (a solid dark-slate slab) the body/fill — including the ceiling underside,
  so the floor / ledges / boss step read as CONTINUOUS SOLID GROUND and the ceiling
  reads as a plain slab (TASK-046 readability fix; severe industrial grey/teal tone).
  `Tile_88` / `Tile_85` (the weathered grey X-brace + rail-capped GRATE tiles) are
  retained as see-through accent/detail sources. Built into a `TileSet` and painted by
  the `CityTiles` `TileMapLayer` to VISUALLY skin sector_02's greybox surfaces (floor /
  ceiling / left wall / ledges / boss wall+step). Purely decorative — the TileSet
  carries no physics layer; collision remains on the sector_02 `StaticBody2D` nodes.
