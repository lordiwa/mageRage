# Mage Rage — Art Asset Credits

This file credits third-party art committed into the `assets/` tree. The project
holds the rights to use and commit these assets (confirmed by the project owner);
the attribution below is provided as courtesy.

## Parallax backgrounds

### `assets/parallax/ice_cave/` — ice-cavern wall backdrop (sector_02, current)
- **Files:** `cave_far.png`, `cave_near.png` (512x256 tileable ice-cave wall textures).
- **Pack:** "Super Pixel" ice-cavern terrain set, **style_A** (`bg_cave_far` / `bg_cave_near`).
- **Author / source:** `AssetBundles/newTerrain/.../super_pixel_ice_cavern` (gitignored
  raw pack; only the used PNGs are committed here).
- **Usage rights:** Project owner holds rights to use and commit these assets.
- **Use:** replaces the old city skyline so the backdrop matches the dark-ice terrain
  re-skin. The 3 `Parallax2D` layers (`scenes/parallax_background.tscn`, scroll
  0.15/0.45/0.80) each tile a cave-wall Sprite2D across a 2048px region with
  `repeat_size.x = 2048` (a multiple of the 512 tile, wider than the viewport, so it
  covers the whole clamped level — not just the start) and per-depth `modulate` (far
  opaque, mid/near semi-transparent) for layered depth. Dimmed further by the sector_02
  Backdrop instance `modulate`. NEAREST-filtered.

### `assets/parallax/sector_02/` — industrial skyline (legacy; kept for reuse)
- **Files:** `Background_Layer_1.png`, `Background_Layer_2.png`, `Background_Layer_3.png`
- **Author:** Franco Giachetti / Simirk
- **Pack:** "City / Industrial Platform Tileset"
- **Use:** the original three horizontal-parallax skyline layers (far / mid / near). No
  longer referenced after the ice-cave backdrop swap; kept on disk for possible reuse.

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

### `assets/tilesets/ice/` — dark-ice crystalline terrain (sector_02 DARKER surface re-skin)
- **Files:** `ice_fill_A.png` (16x16 crystalline interior fill), `ice_top_A.png` (16x16
  icy capped top edge, tiles seamlessly horizontally), `ice_pillar_A.png` (16x16 bolted
  pillar column tile used as the elemental-gate / anti-magic-barrier door jambs). All
  16x16, native ice-cavern palette.
- **Pack:** "Super Pixel" ice-cavern terrain set, **style_A**.
- **Author / source:** `AssetBundles/newTerrain/.../super_pixel_ice_cavern` (gitignored
  raw pack; only the used PNGs are committed here).
- **Usage rights:** Project owner holds rights to use and commit these assets.
- **Use:** re-skins the sector_02 surfaces DARKER ("ice oscurecido"). The bright ice
  palette is TINTED DOWN per-node via `modulate` so the map reads dark/moody while
  keeping the crystal texture. `tools/build_sector_02_tiles.gd` tiles `ice_fill_A` across
  each collision footprint as the dark crystal body and lays a thin `ice_top_A` cap strip
  flush with the collision top of every WALKABLE surface (floor / ledges / boss step) so
  platforms still read at a glance. The same fill + pillar pieces frame the
  `elemental_gate` and `anti_magic_zone` doors (dark crystal jambs with the element-color
  energy seam kept as the DD-003 telegraph). Replaces the old grey `city/Tile_30` slate
  slabs. VISUAL ONLY — the slabs/frames carry no physics; collision stays on the
  `StaticBody2D` nodes (byte-identical).
- **Rendering:** each slab/frame Sprite2D carries a per-node `texture_filter = 1`
  (CanvasItem NEAREST) so the 16px tiles stay crisp; the project default stays Linear for
  the downscaled parallax.

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
