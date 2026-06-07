---
name: parallax2d
description: >-
  Load when adding or editing a parallax scrolling background in this Godot 4.6
  2D project: working with `Parallax2D` nodes, building/editing the sector_02
  greybox backdrop (far/mid/near depth layers), wiring parallax to the
  player-mounted `Camera2D`, or writing GUT tests that assert parallax STRUCTURE.
  Covers the Parallax2D-vs-legacy-ParallaxBackground decision, the node tree,
  the property values this project uses, GL Compatibility support, and the
  headless-test caveat (layers do NOT scroll under GUT).
---

# Parallax2D (2D Background) — Mage Rage Team Training Skill

> Engine: **Godot 4.6.3 stable**, GDScript, 2D, **GL Compatibility** renderer, 100% greybox.
> M2 introduces exactly one new technique: a parallax background for sector_02.
> Verified against Godot 4.6 stable docs on 2026-06-04 (see Provenance).

## When to Use This Skill

Use whenever you add or edit the scrolling background: creating `Parallax2D` nodes,
laying out the far/mid/near greybox depth layers, choosing `scroll_scale`/`repeat_size`,
reasoning about how parallax tracks the player's `Camera2D`, or writing GUT tests over
the backdrop. If a task only touches movement/FSM/spells, load `godot-game-dev` instead.

## 1. Decision: `Parallax2D`, not legacy `ParallaxBackground`/`ParallaxLayer`

**Use `Parallax2D`.** It is a **`Node2D`** (CanvasItem → Node2D), and the Godot 4.6 docs
**explicitly recommend it** over the older `ParallaxBackground` + `ParallaxLayer` pair,
which the docs describe as "tricky to get right."

| | `Parallax2D` (4.6, recommended) | `ParallaxBackground` + `ParallaxLayer` (legacy) |
|---|---|---|
| Base type | **`Node2D`** | `CanvasLayer` + child layers |
| Fits this project | **Yes** — our levels are all `Node2D`; it sits in the scene tree like any other node, inherits Node2D transform/visibility, and composes naturally | No — a `CanvasLayer` is a separate render layer outside the Node2D tree, with its own follow-viewport quirks |
| Per-layer config | One node per layer, self-contained | Background holds shared state; layers depend on it |

Because every Mage Rage level is built from `Node2D` nodes, `Parallax2D` drops straight
into the scene tree with no `CanvasLayer` plumbing — that is the whole reason we pick it.

## 2. Node tree — 3 greybox depth layers (far → near)

Three `Parallax2D` nodes, each holding `ColorRect` silhouettes, plus one flat fill
`ColorRect` behind everything. Tree order = draw order (later siblings draw on top);
back-stop the order with `z_index` so far stays behind near.

```
Sector02Backdrop            (Node2D — backdrop root)
├── FillBG                  (ColorRect — flat far-back fill, z_index = -40)
├── ParallaxFar             (Parallax2D — scroll_scale.x 0.15, z_index = -30)
│   └── ColorRect(s)        (far silhouettes — distant towers/sky shapes)
├── ParallaxMid            (Parallax2D — scroll_scale.x 0.45, z_index = -20)
│   └── ColorRect(s)        (mid silhouettes)
└── ParallaxNear           (Parallax2D — scroll_scale.x 0.80, z_index = -10)
    └── ColorRect(s)        (near silhouettes — closest, fastest)
```

Lower `scroll_scale.x` = slower = reads as farther away. All backdrop `z_index` values
are negative so the playfield (player, tiles, enemies) always draws in front.

## 3. `Parallax2D` property table (and this project's values)

| Property | Type | Default | What it does | This project |
|---|---|---|---|---|
| `scroll_scale` | Vector2 | (1, 1) | Speed multiplier vs. camera. <1 = farther/slower, >1 = closer/faster | **x = 0.15 / 0.45 / 0.80** (far/mid/near); **y = 1.0** |
| `scroll_offset` | Vector2 | (0, 0) | Manual offset of the node's contents | (0, 0) default |
| `repeat_size` | Vector2 | (0, 0) | Repeats children every N px for an infinite-scroll loop; (0,0) = no repeat | **x > 0** (real art, since TASK-042) — see the COVERAGE rule below; y = 0 |
| `autoscroll` | Vector2 | (0, 0) | Constant auto-scroll velocity (px/s), independent of camera | **(0, 0) — OFF** for deterministic tests |
| `follow_viewport` | bool | true | When true, the node is offset by the active camera's position (this is what makes parallax track the camera) | **true** |

Y scroll is left at scale **1.0** (vertical moves 1:1 with the camera); only X is
parallaxed. `autoscroll` is **off** so the backdrop is a pure function of camera
position — required for reproducible headless assertions (see Section 6).

## 4. Interaction with the player-mounted `Camera2D`

The active `Camera2D` lives at `Player/Camera2D` (position smoothing 8.0). `Parallax2D`
**auto-tracks the active `Camera2D` via `follow_viewport = true`** — when enabled, the
node's offset is driven by the current camera's position, scaled by `scroll_scale`.

**Therefore the backdrop works with ZERO camera changes.** Do not add follow logic,
do not parent the backdrop to the camera, do not touch the camera script. Just place
the `Parallax2D` nodes in the level; they read the active camera automatically. Camera
position smoothing (8.0) is irrelevant to structure — it only affects how the camera
itself eases, which the parallax math then follows for free.

## 5. GL Compatibility renderer note

`Parallax2D` is **pure `CanvasItem` transform math — no shaders**. It just offsets its
children based on camera position × `scroll_scale`. It is **fully supported on the
GL Compatibility renderer** (and on Mobile/Forward+). Nothing here needs a non-GL feature.

## 6. CRITICAL — headless GUT test caveat

**Parallax layers do NOT scroll under GUT headless tests.** Headless runs have no real
viewport motion / camera travel, so `follow_viewport` produces no offset and child
positions stay put. **Never assert motion or position deltas in tests — they will be
flaky-to-impossible and encode a false expectation.**

Tests must assert **STRUCTURE only**:

- layer **count** (3 `Parallax2D` nodes present);
- each layer's `scroll_scale` **values** (x = 0.15 / 0.45 / 0.80, y = 1.0);
- `scroll_scale.x` is **strictly increasing** far → mid → near;
- `z_index` ordering (far behind near; all negative / behind the playfield);
- presence of `ColorRect` **children** under each `Parallax2D` (and the flat fill).

```gdscript
# test/test_sector02_backdrop.gd  (STRUCTURE only — never motion)
extends GutTest

func test_three_parallax_layers_with_increasing_scroll() -> void:
    var backdrop := load("res://scenes/sector_02/sector02_backdrop.tscn").instantiate()
    var layers := backdrop.find_children("*", "Parallax2D", true, false)
    assert_eq(layers.size(), 3, "exactly 3 depth layers")
    var scales: Array[float] = []
    for p in layers:
        scales.append(p.scroll_scale.x)
        assert_eq(p.scroll_scale.y, 1.0, "Y is 1:1, not parallaxed")
        assert_true(p.get_children().any(func(c): return c is ColorRect),
            "each layer holds at least one ColorRect silhouette")
    # strictly increasing far -> near
    for i in range(1, scales.size()):
        assert_gt(scales[i], scales[i - 1], "scroll_scale.x strictly increases far->near")
    backdrop.free()
```

> Do **not** call `move_and_slide()` on a camera in a test and then read parallax child
> positions — there is no rendered viewport to drive the offset, so the delta is 0 and
> the test asserts a falsehood.

## Best Practices

- **Do** use `Parallax2D` (a `Node2D`) — *because* the docs recommend it over the legacy
  `CanvasLayer`-based pair, and our levels are all `Node2D`.
- **Do** keep `scroll_scale.x` strictly increasing far → near (0.15 < 0.45 < 0.80) and Y
  at 1.0 — *because* lower = farther, and we only parallax horizontally.
- **Do** leave `autoscroll` off — *because* a deterministic backdrop is what GUT can assert.
- **COVERAGE RULE (real art, since TASK-042):** each layer must TILE so the backdrop
  covers the WHOLE camera-clamped level, not just the start. Set `repeat_size.x > 0`
  (there is a test enforcing this) AND make it **(a) a multiple of the texture's tiled
  width** so the wrap is seamless, and **(b) WIDER THAN THE VIEWPORT** (~1152px). Parallax2D
  draws only ~`repeat_size` worth of content around the camera; if `repeat_size` is small
  (e.g. 512) the layer runs out as the camera travels and you get a void past the first
  screen. The ice-cave backdrop uses a 512px tile tiled across a 2048px region with
  `repeat_size = (2048, 0)` (4 tiles, > viewport). Keep `repeat_size.y = 0` (no vertical
  tiling; the sprite's region just needs to be tall enough for the clamped vertical view).
- **Do** rely on `follow_viewport = true` for camera tracking — *because* it auto-reads
  the active `Player/Camera2D` with zero camera-script changes.
- **Don't** assert parallax motion/position in headless tests — *because* there is no
  real viewport travel; assert structure (count, scales, ordering, z_index, children).
- **Don't** parent the backdrop to the camera or write follow code — *because*
  `Parallax2D` already does the tracking.

## Common Pitfalls

- **Reached for `ParallaxBackground`/`ParallaxLayer`** → legacy `CanvasLayer` path the
  docs flag as tricky; use `Parallax2D` (Node2D) instead.
- **Backdrop renders in front of the player** → forgot negative `z_index`; backdrop nodes
  must sit behind the playfield.
- **Test asserts a position delta and is flaky/red** → headless has no viewport motion;
  switch the test to structure-only assertions.
- **Layers all move at the same speed** → forgot to differentiate `scroll_scale.x` per
  layer (0.15 / 0.45 / 0.80).
- **Vertical pop/desync** → set Y scroll to something other than 1.0; keep `scroll_scale.y = 1.0`.

## Verification

1. **Unit tests (primary):** GUT structure assertions above; exit code `0`. Run via the
   headless command in `godot-game-dev` (Workflow 7) — do not invent a new one.
2. **Smoke test:** launch the GUI binary, walk the player across sector_02, and eyeball
   that far layers drift slower than near layers and stay behind the playfield.

## Provenance

- **Authored by:** Researcher subagent for ticket `TASK-032` (M2 T0).
- **Primary sources (both cited per the ticket):**
  - `Parallax2D` class reference (Godot 4.6): <https://docs.godotengine.org/en/4.6/classes/class_parallax2d.html>
  - 2D Parallax tutorial (Godot 4.6): <https://docs.godotengine.org/en/4.6/tutorials/2d/2d_parallax.html>
- **Version notes:** `Parallax2D` is the recommended 4.6 node; the legacy
  `ParallaxBackground`/`ParallaxLayer` (CanvasLayer) still exist but are not used here.
- **Last verified:** 2026-06-04.
