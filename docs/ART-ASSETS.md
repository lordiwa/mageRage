# MAGE RAGE — ART ASSETS REFERENCE

> **Status:** investigation / reference doc (per DD-005, eng docs are in English).
> **Scope:** catalogs the art dropped into `AssetBundles/`, proposes how it maps
> onto the current 100% greybox game, and recommends an integration + repo-hygiene
> approach. **No scenes, scripts, assets, or git config were modified** producing
> this doc — it is a proposal for the team to act on.
> **Date:** 2026-06-04.

---

## 0. TL;DR

`AssetBundles/` holds **6 third-party asset packs** (each in a hash-named folder),
all **environment art** — tilesets, props/items, and parallax backgrounds. There
are **NO character or enemy sprites and NO VFX/particle art** anywhere in the
bundle, and **no UI element icons** beyond a set of world-map terrain badges.

The single most useful, on-tone find is the **City / industrial platform tileset**
(`431689a73a96c74c20dca76dd77d8366a978ca1e`): weathered teal/grey/red metal tiles,
shipping containers, crates, barrels, railings, stairs, and a **3-layer horizontal
parallax background** — a near-perfect match for the severe industrial Empire
prison. Three sibling tilesets (Dungeon, Village, Volcano) share its HD painterly
style and can skin the Coolant / Foundry biomes. One pack (flat vector forest
parallax) is **off-tone and should be set aside.**

**Biggest gaps:** the player, every enemy class, all per-element projectile/VFX
art, the antimatter ultimate, and HUD element icons still need bespoke art — none
of it is in this bundle. The greybox for those stays as-is for now.

---

## 1. Inventory

Top-level layout: `AssetBundles/<sha1-hash>/…`. Six bundles. Style across the four
"Simirk / Franco Giachetti" tileset packs is a **cohesive family** (HD painterly /
semi-realistic cartoon, 256×256 native tiles, hand-shaded with grime and rivets) —
they intermix cleanly. The terrain-icon pack and the vector-background pack are
**different studios / different styles** and do not match the tilesets.

Each tileset pack ships in **3 resolutions** (`Large`/`Medium`/`Low`, or
256/128/64 px) and includes both **individual PNGs** and **pre-merged
`_Spritesheet_*` atlases**, each PNG paired with a layered **`.psd` source** (the
PSDs are the bulk of the on-disk size). Formats seen: `.png` (export),
`.psd` (source), `.jpg` (a few backgrounds), `.ai` + `.eps` (vector sources),
`.kra` (Krita sources, terrain-icon pack), `.txt` (help/license), `.htm`
(documentation). A few PNG/JPGs already carry Godot `.import` siblings — i.e. at
least one of these packs (the vector backgrounds, and the Volcano `4a8fbe…` pack)
was dragged through a Godot editor at least once already.

### Bundle A — `431689a73a96c74c20dca76dd77d8366a978ca1e` — **City / Industrial Platform Tileset** ⭐
- **Type:** tileset + props + parallax background. **Style:** HD painterly, weathered industrial — grey/teal metal, rust-red panels, hazard stripes.
- **Contents (from `Help File.txt`):** 88 terrain tiles (`Tile_1…Tile_88`), 43 items/objects, 1 layered background (3 horizontally-tileable layers), spritesheets, 3 sizes.
- **Props of note:** `Containers_1..3` (shipping containers), `Crates_1..2`, `Barrel`, `Bin_1..2`, `Cardboard_Box`, `Railing`, `Stairs`, `Door`, `Building_1..4`, `Car_1..3`, `Lantern`, `Air_Conditioner`, `Food_Stand`, `Garbage_Bag`, `Bush_1..2`.
- **Parallax:** `Background_Layer_1.png` (far, blurred teal skyline), `Background_Layer_2.png`, `Background_Layer_3.png` (near). Sampled `Background_Layer_1` = soft cyan city silhouette — depth-friendly.
- **Sheets:** `_Spritesheet_Tileset.png`, `_Spritesheet_Objects.png`. Sampled tileset sheet = brick/metal/container blocks with clean top/edge framing for autotiling.
- **Relevance:** **highest.** This is the Empire-prison aesthetic almost out of the box.

### Bundle B — `8941638c8d2ca96a0641a7270abaf549f9834769` — **Dungeon Platform Tileset**
- **Type:** tileset + props. **Style:** same family, grey cut-stone dungeon walls, dark mortar.
- **Contents (`help file.txt`):** 62 terrain tiles, 5 animated objects, 35 items/objects, 1 background, spritesheets.
- **Props:** `Candle_1..5` (animation frames), `Chest_1..2`, `Coin_a/b/c_1..8` (coin spin frames), `object_1..35`, `Background`.
- **Relevance:** good for interior prison cells / lower-sector stone corridors; the candle + coin frame sets are ready-made `AnimatedSprite2D` material for ambient props / pickups.

### Bundle C — `c03598ac285819a17696e5ed53e453c51c21dddb` — **Village Platform Tileset**
- **Type:** tileset + props. **Style:** same family, mossy grey stone + earth/grass caps + wood bridge.
- **Contents:** ~63 terrain tiles, 2 animated objects, 31 items/objects, 1 background. `Tile_*`, `Object_1..31`, `Chest_1..2`, `Coin_1..8`.
- **Relevance:** the **green/grass content is off-tone** for a prison, but the **grey-stone tiles and the stone-arch/bridge pieces** are usable for older, organic, "the prison once protected" ruined-masonry rooms (supports pillar 1 environmental storytelling). Use selectively.

### Bundle D — `4a8fbe1aae1c1e22f46eddc1073324f78bfa4340` — **Volcano Platform Tileset (HD 3)**
- **Type:** tileset + props + lava. **Style:** same family, dark brown volcanic rock, `Tileset 1` + `Tileset 2`.
- **Contents:** `Tileset 1` & `Tileset 2` (88+ tiles each), `Items and objects/` (`Object1..19`, `platform1..5`, `platform_lava1..5`, `Lava_up1..4`, `Lava_down1..4`, `Gem1..6`, `Coin1..4`, `Cherry`, `Chest1..2`), spritesheets, **JPG + PNG + PSD**, 3 sizes.
- **Relevance:** **the Foundry/Fire-trial biome.** Lava up/down animated strips, lava platforms, and ember-dark rock map directly onto the Fire sector. Gems = collectible/pickup art.

### Bundle E — `0611b4cc5199346e69327ff12348e1a2e88b4a9d` — **"Isle of Lore 2: Terrain Icons" (Steven Colling)**
- **Type:** **UI / world-map terrain badges**, NOT in-level art. **Style:** small circular/diamond/square framed icons, flat-ish illustrated.
- **Contents:** 26 terrain types (pine_forest, arctic, desert, **space**, **city**, castle, cavern, temple, …) × 3 frame shapes × thick/thin × named/unnamed variants; plus full `Documentation.htm`, a colormapper pipeline, and **`.kra`/`.psd` source** + recolor tooling.
- **Relevance:** **not** combat HUD icons. Possibly reusable as **map-screen region markers** if/when the metroidvania map UI is built (e.g. `space`, `city`, `cavern` icons for sectors). Park for later; flag the style as not matching the tilesets.

### Bundle F — `7581d946d68fe2fc1f25a1f5363da04a58691805` — **"Eight Game Backgrounds, Set One" (vector forest/nature)**
- **Type:** parallax/background scenes. **Style:** **flat vector, bright, cheerful, outlined** — green pine trees, clouds, pastel skies. Wide (sampled ~7111×3556).
- **Contents:** `BackgroundOne..Eight.jpg`, `SetOneBackground*Full.png`, layered `EightGameBackgroundsSetOneParts.*` (`.ai`/`.eps`/`.psd`/`.png`) for separable parallax layers. Has Godot `.import` files already.
- **Relevance:** **STYLE MISMATCH.** Cheerful flat-vector forest clashes with both the severe tone and the painterly tilesets. **Recommend setting aside** (do not use for Empire sectors). At most a far-future "Terra surface / memory" flashback could repurpose the vector layering, but not for the prison.

> **Animation note:** no character animation (idle/run/attack) exists anywhere.
> The only frame-based animation is **ambient prop loops** — `Candle_*`, `Coin_*`,
> `Lava_up/down_*` — which become `SpriteFrames` for `AnimatedSprite2D` decor.

---

## 2. Licensing / Provenance

Found and read the license/credit files. **No fully-permissive open license (CC0,
CC-BY, MIT) is present.** Summary:

| Bundle | Author | License doc found | Flag |
|---|---|---|---|
| A City | Franco Giachetti / Simirk (`francogiachetti@gmail.com`) | `Help File.txt` ("Thanks for your purchase!") | **Commercial — purchased.** No license text shipped; terms not in-repo. |
| B Dungeon | Simirk | `help file.txt` ("Thanks for your purchase!") | **Commercial — purchased.** Same. |
| C Village | Simirk | `help file.txt` ("Thanks for your purchase!") | **Commercial — purchased.** Same. |
| D Volcano | Simirk | `help.txt` (title + contact only) | **Commercial — purchased.** Minimal text. |
| E Terrain Icons | Steven Colling | `License.txt` + `README.txt` → **GameDevMarket license** (link only) | License **by reference** (URL), text not bundled. |
| F Vector Backgrounds | (unattributed in files seen) | none found | **Unknown provenance — no author/license file.** |

**Red flags for the orchestrator / human:**
1. **No license text is actually committed** — packs E/F reference an external URL
   or nothing at all; the Simirk packs only say "thanks for your purchase," which
   implies a paid marketplace license (likely GameDevMarket / itch) that typically
   **permits use in a game but forbids redistributing the raw source art**. That
   directly informs the repo-hygiene call in §5 (do **not** push raw PSD/AI sources
   to a public repo).
2. **Bundle F has no provenance at all.** Treat as rights-unconfirmed until the
   human identifies the source.
3. **Action required before shipping any of this art:** the human must confirm the
   purchase/license for each pack (keep receipts/license URLs out-of-band), and
   confirm whether attribution is required (Colling's pack asks to be credited).

---

## 3. Mapping Proposal (assets → greybox targets)

Greybox targets are the ColorRect/StaticBody2D/Polygon2D placeholders named in the
task brief. ✅ = strong fit available now · ⚠️ = partial / off-tone · ❌ = no art in
bundle (stays greybox).

| Greybox target | Current placeholder | Proposed asset source | Fit |
|---|---|---|---|
| **sector_02 parallax** far/mid/near | `parallax_background.tscn` ColorRect towers/pillars in 3 `Parallax2D` layers | Bundle A `Background_Layer_1/2/3.png` (already a 3-layer, horizontally-tileable industrial skyline) | ✅ direct |
| **Level tileset — Foundry (Fire)** biome | `sector_01/02.tscn` StaticBody2D geometry | Bundle D Volcano (`Tileset 1/2`, lava platforms, `Lava_up/down`) | ✅ |
| **Level tileset — Coolant (Ice)** biome | greybox geometry | Bundle A City metal tiles (cold teal/grey) + Bundle B Dungeon stone | ✅ |
| **Level tileset — The Grid (Elec)** biome | greybox geometry | Bundle A City industrial tiles (rails/panels) | ✅ |
| **Generic prison corridor / cells** | greybox geometry | Bundle B Dungeon (cut-stone walls) + Bundle A props | ✅ |
| **Props / set dressing** | none / ColorRect | Bundle A `Containers/Crates/Barrel/Railing/Stairs/Door`; Bundle B `Candle/Chest`; Bundle D `Gem` | ✅ |
| **Ambient animated decor** | none | `Candle_*` (B), `Coin_*` (B/C/D), `Lava_up/down_*` (D) → `AnimatedSprite2D` | ✅ |
| **Map-screen region icons** (future) | none | Bundle E terrain icons (`space`,`city`,`cavern`,`temple`) | ⚠️ different style; map UI not built yet |
| **Player** | `player.tscn` cyan ColorRect `Sprite` (24×40) + yellow `FacingMark` | — | ❌ no character art in bundle |
| **Enemies** (`empire_drone`/`charger`/`shield_drone`/`swarmling`/`warden`) | enemy greybox scenes | — | ❌ no character/enemy art |
| **Per-element projectiles** (`projectile.tscn` Polygon2D + `ProjectileStyle`) | element-tinted polygons (Fire warm / Ice cold / Elec arc / Antimatter violet) | — | ❌ no VFX/particle art; keep procedural polygons |
| **HUD element icons** (TASK-039 trigger HUD, `player_hud.gd`) | colored ColorRect swatches + text labels | — | ❌ no element icons in bundle |
| **Antimatter ultimate VFX** | none / procedural | — | ❌ no VFX art |

### Element color-language check (Fire warm / Ice cold / Elec arc / Antimatter violet)
`ProjectileStyle` and `player_hud.gd` are the **single source of truth** for the
element colors (`FIRE 1.0,0.55,0.20` warm orange · `ICE 0.45,0.80,1.0` cyan ·
`ELECTRICITY 1.0,0.95,0.35` arc yellow · `ANTIMATTER 0.75,0.35,1.0` violet). The
bundle supplies **no element-specific art**, so any future projectile sprites or
HUD icons must be authored to those exact tints — do not let new art drift from the
code constants. Until bespoke icons exist, the HUD's colored swatches already
satisfy the readable-VFX color language; new icons would be an enhancement, not a
blocker.

### Style-mismatch & gap flags
- **Bundle F (vector forest)** clashes with the tone and the painterly tilesets — **do not use** for Empire sectors.
- **Bundle C green/grass** content is off-tone for a prison; use only its grey-stone subset.
- **Bundle E icons** are a third style; acceptable as isolated map-UI badges, not in-world.
- **Hard gaps (no art at all):** player, all 5 enemy classes, projectile/impact VFX, antimatter ultimate, combat HUD element icons. These remain greybox; commission or source separately, authored to the tone + element colors.
- **Mixing caution:** the four Simirk packs match each other; do **not** mix them with E or F in the same shot.

---

## 4. Integration Approach (Godot 4.6)

Idiomatic landing per `godot-game-dev` and `parallax2d` skills:

- **Parallax backdrop (sector_02):** keep the existing `parallax_background.tscn`
  node tree (`Background` + `FarSky`/`MidStructures`/`NearPillars` as `Parallax2D`
  with `scroll_scale` 0.15 / 0.45 / 0.8). **Replace the ColorRect children with
  `Sprite2D`s** textured from Bundle A `Background_Layer_1/2/3.png`, set
  `repeat_size.x` to each layer's texture width for seamless horizontal tiling, and
  keep `follow_viewport = true`. This preserves the GUT structure tests (which only
  assert node structure, since layers don't scroll headless).
- **Level art:** build a Godot **`TileSet`** from each pack's `_Spritesheet_Tileset`
  atlas and paint with **`TileMapLayer`** (GDD §5-D) using **Terrains/autotiling**
  for wall/floor/edge connection. One `TileSet` per biome (Foundry=Volcano,
  Coolant/Grid=City, corridors=Dungeon). Drive collision from the tileset's physics
  layer on the existing **Environment collision layer (layer 1)** — swap StaticBody2D
  greybox for tile collision incrementally, room by room.
- **Props:** individual PNGs → `Sprite2D`. Use **`AtlasTexture`** regions off the
  `_Spritesheet_Objects` sheets to avoid many small imports where convenient.
- **Animated decor:** `Candle_*` / `Coin_*` / `Lava_*` frame sets → `SpriteFrames`
  on `AnimatedSprite2D`.
- **Import settings:** this art is **painterly HD, NOT pixel art** — leave texture
  **filtering ON** (the default), and **do not** force nearest/`filter off`. (The
  `filter off` rule applies only to pixel art, which this bundle does not contain.)
  Mipmaps on for the large parallax layers. Pre-existing `.import` files in bundles
  D and F were generated by a prior editor pass and can be regenerated.
- **Characters/VFX:** nothing to integrate — the player, enemies, projectiles, and
  ultimate stay on their current greybox/procedural path until art is sourced.

### Suggested phased rollout (incremental, no big-bang)
1. **Phase 1 — sector_02 parallax backdrop** (Bundle A 3 layers). Highest visible
   win for the least risk; node structure already exists; great combat-feel backdrop
   for the in-flight TASK-039 work. **Do this first.**
2. **Phase 2 — one biome tileset** (Bundle D Volcano → the Foundry/Fire sector, or
   Bundle A City → Coolant/Grid). Stand up the `TileSet` + autotiling pipeline once,
   reuse it for the others.
3. **Phase 3 — props & animated decor** (containers, crates, candles, lava) to dress
   the now-tiled rooms.
4. **Phase 4 — bespoke art commission** for the hard gaps (player → enemies →
   projectile/ultimate VFX → HUD element icons), authored to the severe tone and the
   `ProjectileStyle` element tints. Player first (most visible character win).
5. **Map-UI badges (Bundle E)** only when the metroidvania map screen is designed.

> The combat-feel/HUD work in flight (TASK-039) does **not** depend on any of this
> art — the HUD's element color language is already code-driven. The parallax
> backdrop (Phase 1) is the one item here that most improves the *look* around that
> work without touching its logic.

---

## 5. Repo-Hygiene Note (recommendation only — no git changes made)

**Current state:** `AssetBundles/` is **untracked** and is **not** listed in
`.gitignore`. As written, a `git add -A` would commit the entire tree — including
every **`.psd`, `.ai`, `.eps`, `.kra` source file** and 3 redundant resolutions of
each tileset. These layered sources are the dominant size cost and are exactly the
files a paid-marketplace license most likely **forbids redistributing**.

**Recommendation (for the human to decide and execute):**
1. **Do not commit the raw bundles as-is.** Add `AssetBundles/` to `.gitignore`
   (it's a staging/inbox folder), and keep the purchased sources **out of the repo**
   (local archive / private storage), per the likely license terms in §2.
2. **Curate a clean `assets/` tree** with only the **PNG exports actually used**, at
   the **one resolution** the game needs (likely `Large`/256 or `Medium`/128) —
   e.g. `assets/tilesets/foundry/`, `assets/parallax/sector_02/`, `assets/props/`.
   Drop `.psd`/`.ai`/`.eps`/`.kra`, the unused resolutions, and the JPG duplicates.
3. **For the binaries you do commit** (curated PNGs, parallax layers), if the team
   wants them versioned, prefer **Git-LFS** via a `.gitattributes`
   (`*.png filter=lfs`, `*.jpg filter=lfs`) so the working repo stays lean. For a
   solo/small project where the curated set is modest, plain commit is acceptable —
   but **only after pruning the PSD/source files.**
4. **Keep `.import` files** for committed textures so CI's headless import pass is
   reproducible (the `godot-ci` skill recipe regenerates `.godot/` but benefits from
   stable `.import` siblings).

No `.gitignore` / `.gitattributes` change has been made — these are proposals.

---

## 6. Provenance of this doc
- **Authored by:** researcher subagent, read-only investigation of `AssetBundles/`.
- **Grounding:** `docs/GDD.md` (§3 mechanics, §5 Godot architecture),
  `docs/LORE-BIBLE.md` (§0 tone, §3 energies, §5 the Empire),
  `.claude/skills/game-design/SKILL.md` (Readable-VFX element color language,
  industrial-prison level design), `.claude/skills/godot-game-dev`,
  `.claude/skills/parallax2d`. Code truth: `scripts/combat/projectile_style.gd`,
  `scripts/ui/player_hud.gd`, `scenes/parallax_background.tscn`, `scenes/player.tscn`,
  `scenes/projectile.tscn`. Bundle license/help files as cited in §2.
- **Method:** full tree walk via Glob; representative image sampling (tileset sheets,
  parallax layers, props, terrain icons) to judge style; license/help text read in
  full. Exact byte sizes were not measured (shell access unavailable in this
  read-only pass); size statements are qualitative (PSD/source files dominate).
