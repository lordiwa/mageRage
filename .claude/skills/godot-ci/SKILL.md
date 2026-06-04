---
name: godot-ci
description: >-
  Load when setting up or changing GitHub Actions CI for this Godot 4.6 GDScript
  project: editing any .github/workflows/*.yml, running GUT unit tests headless on
  a CI runner, regenerating the .godot import cache in CI, or configuring
  gdlint/gdtoolkit (gdformat) and .gdlintrc. Use this for the canonical, version-
  pinned recipe (chickensoft-games/setup-godot, headless --import pass, GUT
  gut_cmdln.gd exit codes, tolerant gdlint config, status badge). Verified against
  official docs on 2026-06-04. Engine: Godot 4.6.3 stable, GL Compatibility, pure
  GDScript (no .NET/Mono).
---

# Godot 4.6 CI on GitHub Actions — Mage Rage Team Training Skill

> Engine: **Godot 4.6.3 stable**, renderer **GL Compatibility**, pure GDScript (no Mono).
> Test runner: **GUT 9.6.0** (the Godot 4.6 line) at `res://addons/gut/`.
> Linter: **gdlint** from `gdtoolkit==4.*` in TOLERANT mode.
> Repo: `github.com/lordiwa/mageRage`, default branch `master`.
> All facts version-pinned and verified against primary sources 2026-06-04 (see Provenance).

## When to Use This Skill

Load before touching `.github/workflows/*.yml`, before adding/altering any CI job that
runs Godot headless or GUT, or when configuring `.gdlintrc` / gdtoolkit. The recipe below
is copy-paste-ready and chosen to make the **first CI run green on the existing codebase**
without a style cleanup.

## Decision: how to get Godot onto the runner

Use **`chickensoft-games/setup-godot@v2`** with `use-dotnet: false`. Rationale:

- It is the maintained, cross-platform action; takes an exact semantic version
  (`4.6.3`), exports `GODOT`/`GODOT4` onto PATH, and needs no Docker image pull.
- `barichello/godot-ci` is a Docker image — heavier, primarily oriented at *exports*
  (it bundles export templates we don't need for a GUT-only job), and pins versions
  more coarsely.
- Manual download from the GitHub release works but you own the URL, checksum, unzip,
  and PATH plumbing forever. Only worth it if you must pin a build the action lacks.

For a **GUT-only job (no export)** set `include-templates: false` — export templates are
not needed to run tests, and skipping them speeds the job up.

**GPU / GL Compatibility note:** running GUT headless needs **no GPU**. `--headless`
selects the dummy display + dummy audio drivers; `gl_compatibility` is irrelevant because
no rendering surface is created in a unit-test run. ubuntu-latest works with no extra
system packages.

## The import pass (regenerate `.godot/`)

`.godot/` is gitignored, so CI must rebuild the import cache before tests, or `class_name`
globals and custom `Resource` (`.tres`) loads will fail. Godot **4.4+ has a dedicated
`--import` flag** (PR #90431) that blocks on `EditorFileSystem::first_scan` — it is the
robust path and replaces the old fragile `--editor --quit` / `--quit-after` dance that
used to hang or exit 1 on a cold `.godot/`.

```bash
godot --headless --path "$PWD" --import
```

Robustness rules:
- Always set a **step timeout** (`timeout-minutes: 10`) so a hung import returns control.
- The dedicated `--import` (no `--quit`) is reliable on 4.6; do **not** use bare `--quit`
  on a cold cache (historical issues #77508 / #83449: quits before the scan thread
  finishes → false exit 1). If you ever target < 4.4, the fallback is
  `godot --headless --import && godot --headless --quit-after 100`.
- To fail CI on a parse/script error during import, add `--verbose` and grep the log, or
  rely on the downstream GUT step which will itself fail to load broken scripts. Simplest
  reliable gate: keep import and test as separate steps so a nonzero import fails the job.

## Running GUT headless + exit code

GUT's command-line runner is `res://addons/gut/gut_cmdln.gd`. With **`-gexit`** the process
returns **0 if all tests pass and 1 if any fail** — so CI goes red correctly. Mirror the
known-good local pattern (project memory) and the repo `.gutconfig.json`
(`-gdir=res://test`, `-ginclude_subdirs`, prefix `test_`, suffix `.gd`):

```bash
godot --headless --path "$PWD" \
  -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://test -ginclude_subdirs -gexit
```

Flags worth knowing:
- `-gexit` — exit after the run; 0 pass / 1 fail. **Use this** (not `-gexit_on_success`).
- `-gexit_on_success` — exits *only when zero tests fail*; on failure it stays open and
  would hang CI. **Do not use in CI.**
- `-gjunit_xml_file=res://test_results.xml` — optional JUnit XML for the Actions test
  summary / `actions/upload-artifact`. Nice-to-have, not required.

## gdlint in TOLERANT mode

Install pinned to the Godot-4 line and lint the source + test dirs:

```bash
pip install "gdtoolkit==4.*"
gdlint scripts/ test/
```

gdlint reads a **`.gdlintrc`** (YAML) found by walking up from the cwd. Keep correctness
checks ON and relax pure-style checks so the existing tree passes. `disable: [...]` removes
a check entirely; naming checks take a **regex** (loosen rather than disable); numeric
checks take a threshold. Dump defaults with `gdlint -d` if you need the full list.

Sample `.gdlintrc` (tolerant — fails on real errors, quiet on style):

```yaml
# Correctness checks are intentionally NOT disabled — these still fail the build:
#   unused-argument, unused-variable, unnecessary-pass, expression-not-assigned,
#   comparison-with-itself, duplicated-load, private-method-call.

# Relax style-only checks that would redden a healthy existing codebase:
disable:
  - max-public-methods
  - max-file-lines
  - max-line-length
  - trailing-whitespace
  - no-else-return
  - no-elif-return
  - class-definitions-order

# Loosen naming so existing identifiers pass; regex, not on/off.
# Allows snake_case incl. leading underscore and Godot _on_Signal handlers.
function-name: '(_on_([A-Z][a-z0-9]*)+(_[a-z0-9]+)*|_?[a-z][a-z0-9]*(_[a-z0-9]+)*)'
function-argument-name: '_?[a-z][a-z0-9]*(_[a-z0-9]+)*'
class-variable-name: '_?[a-z][a-z0-9]*(_[a-z0-9]+)*'
function-variable-name: '_?[a-z][a-z0-9]*(_[a-z0-9]+)*'
```

Tune per first-run output: if a *correctness* check fires, fix the code (that's the point);
if a *style* check fires, add it to `disable` (or widen its regex), don't churn the tree.
Per-line escape hatches exist too: `# gdlint:ignore=rule-name` and
`# gdlint:disable=rule-name` / `# gdlint:enable=rule-name` for blocks.

## Reference workflow shape (for the developer to author under `.github/workflows/ci.yml`)

Two jobs, both on `ubuntu-latest`, triggered on push + pull_request to `master`:

1. **lint** — `actions/setup-python` → `pip install "gdtoolkit==4.*"` → `gdlint scripts/ test/`.
2. **test** — `chickensoft-games/setup-godot@v2` (`version: 4.6.3`, `use-dotnet: false`,
   `include-templates: false`) → `actions/checkout` → import step (`--headless --import`,
   `timeout-minutes: 10`) → GUT step (`gut_cmdln.gd ... -gexit`).

Keep import and test as **separate steps** so import failures fail the job distinctly.
Run `actions/checkout` before the import step so the project is on disk.

## Status badge (README / PROJECT.md)

Replace `ci.yml` with the actual workflow filename if different:

```markdown
[![CI](https://github.com/lordiwa/mageRage/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/lordiwa/mageRage/actions/workflows/ci.yml)
```

## Risk: will the first run go red?

Likely failure modes and pre-empts:
- **Import hang / false exit 1** → use the dedicated `--import` (not `--quit`), and a step
  timeout. Verified the cold-cache pitfalls are 4.3-and-earlier (#77508/#83449); 4.4+ fixes
  them via `--import`.
- **gdlint reddens on style** → that's expected; the tolerant `.gdlintrc` above disables the
  noisy style checks up front. Run `gdlint scripts/ test/` locally first and add any
  remaining style offenders to `disable`.
- **gdlint reddens on a real bug** (unused var/arg, unnecessary pass) → fix the code; do not
  disable the check. This is the linter doing its job.
- **GUT version drift** → pin GUT 9.6.0 for Godot 4.6; older GUT (e.g. 9.5) has a reported
  null-pointer on 4.6.

## Provenance

- chickensoft-games/setup-godot README (v2 usage, `use-dotnet`/`include-templates`,
  PATH exports) — https://github.com/chickensoft-games/setup-godot
- GUT Command Line docs 9.6 (`gut_cmdln.gd`, `-gexit` 0/1, `-gexit_on_success`,
  `-gjunit_xml_file`, `-gdir`, `-ginclude_subdirs`) — https://gut.readthedocs.io/en/latest/Command-Line.html
- Godot `--import` flag (PR #90431, added 4.4, blocks on first_scan) —
  https://github.com/godotengine/godot/pull/90431 ;
  cold-cache `--quit` pitfalls — https://github.com/godotengine/godot/issues/77508 ,
  https://github.com/godotengine/godot/issues/83449
- Godot 4.6 command-line tutorial — https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html
- gdtoolkit Linter wiki (rule names, `.gdlintrc` YAML, `disable:`, regex naming, `gdlint -d`,
  ignore/disable comments) — https://github.com/Scony/godot-gdscript-toolkit/wiki/3.-Linter ;
  PyPI (gdtoolkit 4.5.0, `pip install "gdtoolkit==4.*"`) — https://pypi.org/project/gdtoolkit/
