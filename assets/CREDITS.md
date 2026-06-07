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
- **Rendering:** the hero AnimatedSprite2D carries a per-node `texture_filter = 1`
  (CanvasItem NEAREST) so the pixel-art renders crisp/unblurred. The project-wide
  `default_texture_filter` is left at Linear so the downscaled (scale 0.2) parallax
  skyline backgrounds don't alias; the per-node override targets only the hero.

## Enemy sprites

### `assets/sprites/enemies/` — sector_02 combat enemies (TASK-056)
Three PixelLab pixel-art characters (16-bit McFarlane style, side view, humanoid
template), generated 2026-06-06. EAST-facing frames only (flip_h used for left).
The create_character template is bipedal, so the two flying drones came out as
bipedal armored guardian robots (kept + re-themed as "armored Empire guardians",
reinforcing pillar 1's tragic-quarantine tone).

- **Empire Drone** — `empire_drone/`: idle (4f), walk (6f), attack (6f, cast pose),
  hurt (6f). 68x68 canvas. Teal/grey armored guardian (ELEC armor; the teal-vs-ELEC-
  yellow color read is flagged as an optional later DIRECT retry).
  PixelLab character_id `e70ad1d9-ffaa-45f2-9281-3878bf6196c5`.
- **Shield Drone** — `shield_drone/`: idle (4f), walk (6f), attack (6f), hurt (6f).
  68x68 canvas. Frost-blue armored robot (ICE armor).
  PixelLab character_id `b0aca2f8-efc9-413e-8676-3463293dc867`.
- **Charger** — `charger/`: idle (4f), walk (6f), windup (5f, telegraph), charge (6f,
  lunge), hurt (6f). 92x92 canvas. Dark iron + molten-orange automaton (FIRE armor).
  PixelLab character_id `e09ba82f-b462-4d5b-bf10-a179547a5656`.

- **Author:** Generated via [PixelLab](https://www.pixellab.ai/) by the project owner.
- **Style:** 16-bit McFarlane pixel-art, generated 2026-06-06.
- **Usage rights:** Project owner generated and holds rights to use these assets.
- **SpriteFrames:** built reproducibly by `tools/build_enemy_frames.gd` into
  `resources/enemies/{empire_drone,shield_drone,charger}_frames.tres`.
- **Rendering:** each enemy AnimatedSprite2D carries a per-node `texture_filter = 1`
  (CanvasItem NEAREST) so the pixel-art renders crisp; the project-wide default stays
  Linear so the downscaled (scale 0.2) parallax skyline does not alias.
- **Gaps documented:** death has no dedicated anim (the dissolve holds whatever frame
  is showing, typically the last "hurt" frame — matches the hero); the Charger's
  Recovery state reuses "idle" (the stagger reads via the EXPOSED tint); the Shield
  Drone's up/down shield no longer has a dedicated VISUAL node (block gameplay is
  unchanged) — a later pass could add a shield overlay/anim.

### `assets/sprites/enemies/` — flying drones + Warden boss (TASK-058)
Three PixelLab assets generated 2026-06-06 to replace the bipedal drone look with
FLOATING eye-orbs and to skin the Warden boss greybox. EAST-facing frames only
(flip_h used for left). The old bipedal drone art (`empire_drone/`, `shield_drone/`)
and its `*_frames.tres` are KEPT on disk for possible reuse as a future
ground-guardian enemy.

- **Empire Drone (flying)** — `empire_drone_fly/`: idle (9f), walk (9f), attack
  (9f), hurt (9f). 96x96 canvas. Floating single-eye ELEC drone (teal shell +
  yellow energy ring). PixelLab OBJECT `4b73afcb`.
- **Shield Drone (flying)** — `shield_drone_fly/`: idle (9f), walk (9f), attack
  (9f), hurt (9f). 96x96 canvas. Floating single-eye ICE drone (frost-blue + cyan
  barrier slab). PixelLab OBJECT `1f8a5ca1`.
- **The Warden (boss)** — `warden/`: idle (4f), walk (6f), attack (6f), hurt (6f).
  252x252 source canvas. Hulking armored guardian colossus (side, east-only +
  flip_h). PixelLab CHARACTER v3 `bf3d2472`.

- **Author:** Generated via [PixelLab](https://www.pixellab.ai/) by the project owner.
- **Style:** 16-bit McFarlane pixel-art, generated 2026-06-06.
- **Usage rights:** Project owner generated and holds rights to use these assets.
- **SpriteFrames:** built reproducibly by `tools/build_enemy_frames.gd` into
  `resources/enemies/{empire_drone_fly,shield_drone_fly,warden}_frames.tres`
  (idle/walk loop; attack/hurt one-shot).
- **Rendering:** each AnimatedSprite2D carries a per-node `texture_filter = 1`
  (CanvasItem NEAREST) so the pixel-art renders crisp; the project-wide default
  stays Linear so the downscaled parallax skyline does not alias.
- **Geometry (documented; fine-tuning is a later DIRECT playtest tweak):**
  - Flying drones FLOAT — the opaque eye-orb is CENTERED on the unchanged (28,36)
    collision (no feet-seating). Scale 0.4: Empire ~30x26px @ position (0.2, 0.6);
    Shield ~32x31px @ position (-1.4, 2.6).
  - Warden: 252px source >> (72,96) collision so an integer scale is impossible —
    chose a clean fractional scale **0.4** (big-but-fair) with feet SEATED on the
    collision bottom (position ~ (1, 23.2)); the opaque idle bbox is 53x123 @
    (97,65). On-screen size/seat/feel is flagged for a playtest pass.
- **Gaps documented:** death has no dedicated anim — the dissolve holds whatever
  frame is showing (typically the last "hurt" frame), matching the hero + drones.

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
