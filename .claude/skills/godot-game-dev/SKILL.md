---
name: godot-game-dev
description: >-
  Load for ANY Godot 4 / GDScript work on the Mage Rage 2D side-scroller: editing
  .gd / .tscn / .tres files; designing scenes & node trees; the node-based movement
  FSM (EstadoBase -> MoveState/JumpState/GlideState/FlightState); SpellData custom
  Resources; collision Layers/Masks; CharacterBody2D movement (gravity, move_and_slide,
  coyote time, jump buffering); TileMapLayer + Terrains/autotiling; project hygiene
  (signals, autoloads, folders, class_name); or writing/running GUT headless unit
  tests. If a task touches Godot, load this first so the code is idiomatic Godot 4.6
  and consistent with docs/GDD.md (section 5).
---

# Godot 4.6 / GDScript (2D) — Mage Rage Team Training Skill

> Engine: **Godot 4.6.3 stable**, GDScript, 2D. Genre: side-scroller / metroidvania.
> This skill encodes the architecture **mandated by `docs/GDD.md` section 5**. Do not
> contradict the GDD or `docs/LORE-BIBLE.md`. Verified against Godot 4.6 stable docs
> on 2026-06-02 (see Provenance). Anything 4.3/4.4-specific is flagged inline.

## When to Use This Skill

Use whenever you touch Godot: any `.gd`, `.tscn`, or `.tres` file; scene/node-tree
design; the movement state machine; `SpellData` resources or the `MagicManager`;
collision layer/mask setup; `CharacterBody2D` movement; `TileMapLayer` level building;
or running the GUT test suite. The GDD forbids "código espagueti" — prefer the
patterns below over ad-hoc boolean flags and per-entity scripts.

## Core Workflows

### 1. Node-based Movement FSM (`EstadoBase` → states)

The GDD mandates a **node-based** FSM, not boolean flags. Each state is a `Node` child
of a `StateMachine` node hanging off the player. Only the active state runs logic; the
machine routes `_process` / `_physics_process` and handles transitions by name.

```gdscript
# scripts/fsm/state_machine.gd
class_name StateMachine extends Node

@export var initial_state: EstadoBase
var current_state: EstadoBase
var states: Dictionary = {}            # lower-case name -> EstadoBase

func _ready() -> void:
    for child in get_children():
        if child is EstadoBase:
            states[child.name.to_lower()] = child
            child.transition_requested.connect(_on_transition_requested)
    if initial_state:
        initial_state.enter()
        current_state = initial_state

func _process(delta: float) -> void:
    if current_state: current_state.update(delta)

func _physics_process(delta: float) -> void:
    if current_state: current_state.physics_update(delta)

func _on_transition_requested(from: EstadoBase, to_name: String) -> void:
    if from != current_state: return            # stale request, ignore
    var next: EstadoBase = states.get(to_name.to_lower())
    if next == null: return
    if current_state: current_state.exit()
    next.enter()
    current_state = next
```

```gdscript
# scripts/fsm/estado_base.gd
class_name EstadoBase extends Node

signal transition_requested(from: EstadoBase, to_name: String)

@export var player: CharacterBody2D          # set in the editor / on _ready

func enter() -> void: pass                    # one-time setup on becoming active
func exit() -> void: pass                     # cleanup on leaving
func update(_delta: float) -> void: pass      # frame logic (input polling)
func physics_update(_delta: float) -> void: pass  # movement / move_and_slide

func transition_to(state_name: String) -> void:
    transition_requested.emit(self, state_name)
```

**Ability gating (the GDD's flight unlock).** Do not branch on `is_flying` flags.
Instead, gate the *transition itself*. A central `abilities` set (e.g. on the player
or an autoload) records unlocked elements; `JumpState`/`GlideState` only offer the
`flightstate` transition once Electricity is absorbed:

```gdscript
# inside JumpState.physics_update(), after applying air movement:
if player.abilities.has("electricity") and Input.is_action_just_pressed("fly"):
    transition_to("FlightState")
```

The progression Move → Jump (Fire) → Glide (Ice) → Flight (Electricity) mirrors the
LORE-BIBLE "movement = mastery" table. Full runnable `MoveState`/`JumpState`/
`GlideState`/`FlightState` bodies (gravity, coyote time, jump buffering) live in
[`references/fsm-states.md`](references/fsm-states.md) — read it when implementing a state.
FSM rationale: this is the community-standard node-based pattern (e.g. GDQuest's
"Finite State Machine in Godot 4"). Godot has no single official FSM tutorial; the
pattern leans on core scripting features — signals and `_process`/`_physics_process`.
<https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html>

### 2. `SpellData` custom Resource (data-driven magic)

Per GDD 5.B: **one** `SpellData` script, many `.tres` files. Never write a script per
spell. A `Resource` is a reference-counted data container that serializes to `.tres`
and is editable in the inspector.

```gdscript
# scripts/resources/spell_data.gd
class_name SpellData extends Resource

enum Element { FIRE, ICE, ELECTRICITY, ANTIMATTER }

@export var display_name: String = ""
@export var element: Element = Element.FIRE
@export var damage: float = 10.0
@export var speed: float = 400.0          # projectile speed px/s
@export var mana_cost: float = 5.0
@export var vfx: PackedScene              # spawned on cast / impact
@export var projectile: PackedScene
```

Create variants in the editor: right-click `resources/spells/` → New Resource →
`SpellData` → set fields → save `fire_bolt.tres`. The `MagicManager` only *reads* data:

```gdscript
# scripts/managers/magic_manager.gd
class_name MagicManager extends Node

@export var equipped: SpellData

func cast(origin: Node2D, direction: Vector2) -> void:
    if equipped == null or equipped.projectile == null: return
    var p := equipped.projectile.instantiate()
    p.global_position = origin.global_position
    p.setup(equipped, direction)          # projectile copies damage/speed/element
    origin.get_tree().current_scene.add_child(p)
```

Why Resources over per-spell scripts: zero code per new spell, designer-editable,
serialized/diff-able as text, and trivially unit-testable (pure data + math).
<https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html>

> Gotcha: `@export var x: Array = []` and other mutable defaults are **shared across
> instances** unless you assign fresh values in code. For per-instance mutable state,
> `duplicate()` the resource or build it in `_init`.

### 3. Collision Layers / Masks (GDD 5.C scheme)

**Layer = what you are. Mask = what you detect.** Layer/mask *value* indices are
**1-based (1–32)** in the API. The GDD scheme:

| # | Named layer    | Used by                          |
|---|----------------|----------------------------------|
| 1 | Environment    | Maze walls/floors (`TileMapLayer`, `StaticBody2D`) |
| 2 | Player         | The hero `CharacterBody2D`        |
| 3 | Enemies        | Empire drones/guards/machinery    |
| 4 | PlayerMagic    | Player projectiles/areas (own layer, masks Enemies only) |

Set names in **Project Settings → Layer Names → 2D Physics** so the editor checkboxes
read "Environment/Player/Enemies/PlayerMagic" instead of bit numbers. Set in code with
the 1-based value API:

```gdscript
# Player body: IS Player, COLLIDES WITH Environment + Enemies
func _ready() -> void:
    set_collision_layer_value(2, true)        # I am on layer 2 (Player)
    set_collision_mask_value(1, true)         # detect Environment
    set_collision_mask_value(3, true)         # detect Enemies

# A magic projectile (Area2D): IS PlayerMagic, DETECTS Enemies ONLY
func _ready() -> void:
    collision_layer = 0
    collision_mask = 0
    set_collision_layer_value(4, true)        # PlayerMagic layer
    set_collision_mask_value(3, true)         # masks Enemies only
    area_entered.connect(_on_area_entered)    # vs Area2D enemies
    body_entered.connect(_on_body_entered)    # vs PhysicsBody2D enemies
```

Keeping player magic off the Player layer is exactly GDD 5.C's rule: the hero never
hits himself, and Godot's broadphase skips irrelevant pairs (perf win).

**Area2D vs body collisions:** an `Area2D` fires `area_entered`/`area_exited` (other
Areas) and `body_entered`/`body_exited` (PhysicsBody2D: CharacterBody2D, StaticBody2D,
RigidBody2D). Use Area2D for hurtboxes/triggers/pickups; use the body's own
`move_and_slide()` collisions for solid traversal.
<https://docs.godotengine.org/en/stable/classes/class_collisionobject2d.html>
<https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html>

### 4. `CharacterBody2D` movement (gravity, coyote time, jump buffer)

In Godot 4, `move_and_slide()` takes **no arguments** and reads the `velocity`
property directly; it returns a `bool` (did a collision occur) and updates `velocity`
in place. Use `get_gravity()` (added in **Godot 4.4**, present in 4.6) to read the
project's default gravity vector.

```gdscript
# scripts/player/player.gd  (skeleton; real per-state logic lives in the FSM)
class_name Player extends CharacterBody2D

const SPEED := 220.0
const JUMP_VELOCITY := -380.0
const COYOTE_TIME := 0.10          # grace after leaving a ledge
const JUMP_BUFFER := 0.10          # grace before landing

var abilities: Dictionary = {}     # e.g. {"fire": true, "ice": true}
var _coyote := 0.0
var _buffer := 0.0

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity += get_gravity() * delta
        _coyote -= delta
    else:
        _coyote = COYOTE_TIME

    if Input.is_action_just_pressed("jump"):
        _buffer = JUMP_BUFFER
    _buffer -= delta

    if _buffer > 0.0 and _coyote > 0.0:
        velocity.y = JUMP_VELOCITY
        _buffer = 0.0
        _coyote = 0.0

    var dir := Input.get_axis("move_left", "move_right")
    velocity.x = dir * SPEED
    move_and_slide()
```

`is_on_floor()` / `is_on_wall()` / `is_on_ceiling()` are valid only *after*
`move_and_slide()`. Coyote time + jump buffering are the standard platformer feel
patterns and matter for the Fire-leap → Ice-glide progression.
<https://docs.godotengine.org/en/stable/tutorials/physics/using_character_body_2d.html>
<https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html>

### 5. `TileMapLayer` + Terrains (the industrial prison)

The single `TileMap` node is **deprecated** (since Godot 4.3). Build the prison from
one or more **`TileMapLayer`** nodes (e.g. `Background`, `Walls`, `Foreground`), each a
sibling node, all sharing one `TileSet` resource. Layer draw order = tree order.

1. Add `TileMapLayer` nodes; assign a shared `TileSet`.
2. In the TileSet, add a **Terrain Set → Terrain**, paint terrain bits on tiles.
3. Paint with the **Terrains** tab so Godot auto-connects edges/corners (autotiling).
4. Put solid geometry on the **Environment** physics layer (#1) via the TileSet's
   Physics layer so the player's `move_and_slide()` collides with walls.

> Godot 4.6 reworked TileMapLayer collision to merge adjacent tile shapes (perf) and
> lets you rotate scene tiles like atlas tiles. Note: Godot 4 terrain matching is
> less reliable than Godot 3 autotiles for *runtime/procedural* painting; for
> hand-authored prison levels it is fine. To migrate an old `TileMap`: select it,
> open its bottom panel, use the toolbox "Extract TileMap layers" action.
> <https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html>
> <https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html>

### 6. Project hygiene

- **Composition over inheritance** — build behavior by *adding child nodes* (Hitbox,
  Health, StateMachine) and instancing scenes, not deep class trees. The FSM and
  `SpellData` above are this principle. <https://docs.godotengine.org/en/stable/getting_started/step_by_step/instancing.html>
- **Signals to decouple** — children emit, parents/managers listen. The FSM uses
  `transition_requested`; magic hits emit `damaged`. Never have a child reach up with
  `get_parent().get_parent()...`. <https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html>
- **Autoload singletons — sparingly.** Good: truly global, single-instance services
  (`GameState`, `AbilityRegistry`, `AudioBus`, save system). Bad: putting gameplay
  entities or per-scene state in autoloads — it creates hidden global coupling. Prefer
  passing data (e.g. an `equipped: SpellData`) over reaching into a singleton.
  <https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html>
- **Folders:** `scenes/`, `scripts/` (mirrors scene tree: `scripts/fsm/`,
  `scripts/managers/`, `scripts/resources/`, `scripts/player/`), `resources/`
  (`.tres`: spells, tilesets), `test/` (GUT, mirrors `scripts/`), `assets/`.
- **Naming:** scripts/files `snake_case.gd`; `class_name` and nodes `PascalCase`;
  vars/functions `snake_case`; constants `CONSTANT_CASE`; signals past-tense
  (`died`, `transition_requested`). Add `class_name` for any type referenced
  elsewhere (FSM states, `SpellData`) so it is globally resolvable.
  <https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html>

### 7. Headless GUT testing

GUT (Godot Unit Test) installs under **`addons/gut/`**. Prioritize pure-logic tests:
FSM transition routing, `SpellData` math (damage/mana), mana/resource systems — none
need a rendered scene. Tests live under `test/` (mirroring `scripts/`), named
`test_*.gd`, extending `GutTest`.

```gdscript
# test/test_spell_data.gd
extends GutTest

func test_fire_bolt_defaults() -> void:
    var s := load("res://resources/spells/fire_bolt.tres") as SpellData
    assert_eq(s.element, SpellData.Element.FIRE)
    assert_gt(s.damage, 0.0)
    assert_gt(s.mana_cost, 0.0)
```

**Exact headless command** (CI-friendly: exits with a status code — `0` all pass,
`1` any fail; pending does not affect it). Run from the project root, using the
**console** binary so stdout/exit codes flow to the terminal:

```powershell
C:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
```

`--headless` = no window/render; `--path .` = project root; `-s <script>` runs
`gut_cmdln.gd`; `-gdir=res://test` = where tests live; `-ginclude_subdirs` recurses;
`-gexit` quits after the run (without it the window stays open). This matches the
command recorded in `.claude/agents/project-context.md`. Heavier GUT options
(`-gselect`, `-gunit_test_name`, `.gutconfig.json`, doubles/mocks) are in
[`references/gut-testing.md`](references/gut-testing.md).
<https://gut.readthedocs.io/en/latest/Command-Line.html>

## Best Practices

- **Do** model movement as FSM nodes — *because* the GDD forbids spaghetti `if/else`
  flag soup for Move/Jump/Glide/Flight.
- **Do** gate ability unlocks at the *transition*, not with `is_flying` booleans —
  *because* it keeps each state ignorant of progression state.
- **Do** make every spell a `.tres` of one `SpellData` script — *because* new spells
  cost seconds, are designer-editable, and unit-test as pure data.
- **Do** name physics layers in Project Settings and keep player magic on its own
  layer masking Enemies only — *because* the hero can't self-hit and Godot's
  broadphase skips dead pairs.
- **Do** use `TileMapLayer`, not `TileMap` — *because* `TileMap` is deprecated since 4.3.
- **Don't** call `is_on_floor()` before `move_and_slide()` — *because* the floor state
  is only updated by the move call.
- **Don't** pass arguments to `move_and_slide()` — *because* in Godot 4 it reads
  `velocity` directly and takes none (a Godot 3 habit).
- **Don't** reach across the tree with chained `get_parent()` or stuff gameplay state
  into autoloads — *because* it creates hidden global coupling; emit signals / pass data.

## Common Pitfalls

- **`move_and_slide(velocity)` (Godot 3 style)** → "too many arguments" error. Set
  `velocity` then call `move_and_slide()` with no args.
- **Floor check returns stale value** → you queried `is_on_floor()` before moving;
  move first, query after.
- **Spell `.tres` edits "leak" between instances** → mutable `@export` defaults (Arrays/
  Dicts/sub-resources) are shared; `duplicate(true)` per instance when you mutate.
- **Collision pair never fires** → Body A's Layer must be in Body B's Mask (and/or vice
  versa); a body with mask but no overlapping layer detects nothing. Also check
  Area2D vs body signal: `area_entered` (Areas) vs `body_entered` (bodies).
- **Used `TileMap`** → deprecated; the inspector nags. Use `TileMapLayer` siblings.
- **GUT window stays open in CI** → you omitted `-gexit`. Add it; check exit code.
- **`get_gravity()` "not found"** → it landed in Godot 4.4; fine on 4.6. On older
  engines read `ProjectSettings.get_setting("physics/2d/default_gravity")`.

## Verification

1. **Unit tests** (primary): run the GUT command in Workflow 7; require exit code `0`.
2. **Linter/format:** Godot's built-in script editor follows the GDScript style guide;
   if `gdformat`/`gdlint` (gdtoolkit) is configured in the repo, run it before commit.
3. **Smoke test:** launch the project from the GUI binary
   (`C:\Godot\Godot_v4.6.3-stable_win64.exe --path .`), confirm: player runs/jumps,
   coyote+buffer feel right, a cast spell hits an Enemy-layer dummy but not the player,
   and walls (Environment layer) stop the player.

## References

Heavy material lives in `references/` and is **not** loaded by default — read these
only when a workflow above points to them.

- [`references/fsm-states.md`](references/fsm-states.md) — full `MoveState`/`JumpState`/
  `GlideState`/`FlightState` implementations with the boolean-flag anti-pattern compared.
- [`references/gut-testing.md`](references/gut-testing.md) — extended GUT options,
  `.gutconfig.json`, doubles/stubs/mocks, CI snippet, asserts cheat-sheet.

## Provenance

- **Authored by:** Researcher subagent for ticket `TASK-003`.
- **Primary sources:**
  - CharacterBody2D (4.6 stable): <https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html>
  - Using CharacterBody2D: <https://docs.godotengine.org/en/stable/tutorials/physics/using_character_body_2d.html>
  - Resources: <https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html>
  - CollisionObject2D (layer/mask value API, 1-based): <https://docs.godotengine.org/en/stable/classes/class_collisionobject2d.html>
  - Physics introduction (layers/masks, Area2D vs body): <https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html>
  - TileMapLayer class: <https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html>
  - Using TileSets / terrains: <https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html>
  - GDScript style guide: <https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html>
  - Singletons/Autoload: <https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html>
  - Signals: <https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html>
  - GUT command line: <https://gut.readthedocs.io/en/latest/Command-Line.html>
  - Godot 4.6 release notes: <https://godotengine.org/releases/4.6/>
- **Version caveats:** `TileMapLayer` is 4.3+; `get_gravity()` is 4.4+ (both present in
  4.6.3). GUT command-line flags confirmed against GUT 9.x docs; exact addon version in
  `addons/gut/` should be confirmed once installed.
- **Last verified:** 2026-06-02.
