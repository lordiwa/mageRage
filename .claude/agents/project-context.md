---
project_name: mage-rage
project_type: other
generated_at: 2026-06-03T02:43:24.908Z
schema_version: 1
---

## Stack
- **Engine:** Godot 4.6.3 stable, GDScript (2D).
- **Engine binary (Windows):** `C:\Godot\Godot_v4.6.3-stable_win64.exe` (GUI) and
  `C:\Godot\Godot_v4.6.3-stable_win64_console.exe` (console/CLI). Run headless with
  `--headless`; run a project with `--path <project-dir>`; import assets with
  `--headless --import`.
- **Genre:** 2D side-scroller / metroidvania (see `docs/GDD.md`).
- **Architecture (from GDD):** node-based Finite State Machine for movement
  (`EstadoBase` → `MoveState`/`JumpState`/`GlideState`/`FlightState`); magic as
  custom `Resource` (`SpellData` with `@export`ed `damage`/`speed`/`element_type`/
  `vfx`, instanced as `.tres`); physics via explicit collision Layers/Masks
  (1=Environment, 2=Player, 3=Enemies; player magic on its own layer masking
  Enemies); environment via `TileMapLayer` with Terrains/autotiling.
- **Canon:** narrative truth in `docs/LORE-BIBLE.md`, design in `docs/GDD.md` —
  never contradict the lore.

## Testing conventions
GDScript tests use **GUT (Godot Unit Test)** — install as an addon under
`addons/gut/` and run headless from CI/terminal, e.g.
`C:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`.
Write a failing test before any new behavior lands. Tests live under a top-level
`test/` tree (GUT convention) mirroring the `scripts/` layout; pure-logic nodes
(FSM transitions, `SpellData` math, mana/resource systems) are the priority to
cover since they don't need a rendered scene.

> **Bash gotcha (important):** do NOT prefix Godot/GUT commands with `cd "<path>" && ...`.
> The Bash tool's working dir is already the project root, and a `cd` inside a compound
> command triggers a permission prompt that HANGS the run indefinitely. Invoke the binary
> directly with an absolute `--path`, e.g.
> `"C:\Godot\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\srpar\OneDrive\Documents\mage-rage" -s "res://addons/gut/gut_cmdln.gd" -gdir=res://test -ginclude_subdirs -gexit`.
> Set a Bash timeout so a stuck run returns control.

## Linting and formatting
Run the project's linter and formatter before every commit. If the repo ships a config (e.g., .eslintrc, ruff.toml, .prettierrc, gofmt defaults), defer to it without arguing; if no config exists yet, use the ecosystem-standard tool and add a minimal config rather than reformatting the whole tree in a drive-by change.

## Type-specific guidance
- No project-type-specific assumptions apply — default to conservative, generic engineering practice until the stack reveals itself.
- Stack details were left unspecified at intake; ask the human (or update PROJECT.md) before making non-trivial architectural decisions.
- Prefer the simplest tool that solves the problem; do not import a framework when a 20-line helper would do.
- When in doubt, write the test first — the unspecified domain is exactly the case where tests pin down intent fastest.
