# GUT Testing — Extended Reference

Read this for the full GUT command-line surface, config file, doubles/mocks, and a CI
snippet. The everyday headless command is in `SKILL.md` Workflow 7. GUT installs under
`addons/gut/`; enable the plugin in Project Settings → Plugins. Source:
<https://gut.readthedocs.io/en/latest/Command-Line.html>

## The command, dissected

```powershell
C:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
```

| Flag | Meaning |
|------|---------|
| `--headless` | No window, no rendering (engine flag). |
| `--path .` | Project root (folder with `project.godot`). |
| `-s addons/gut/gut_cmdln.gd` | Run GUT's command-line runner script. |
| `-gdir=res://test` | Directory (repeatable) to search for `test_*.gd`. |
| `-ginclude_subdirs` | Recurse into subdirectories of each `-gdir`. |
| `-gexit` | Quit after the run (omit → window stays open). |
| `-gexit_on_success` | Quit only if everything passed (else stay open for inspection). |
| `-gselect=<str>` | Run only scripts whose filename contains `<str>`. |
| `-gunit_test_name=<str>` | Run only tests whose name contains `<str>`. |
| `-gprefix=` / `-gsuffix=` | Override the `test_` prefix / `.gd` suffix conventions. |
| `-gconfig=res://.gutconfig.json` | Use a config file instead of long flag lists. |

**Exit codes:** `0` if all tests pass, `1` if any fail. *Pending* tests do NOT change
the return code. This is what makes the command CI-gateable.

> Use the **console** binary (`..._console.exe`) on Windows, not the plain GUI exe, so
> stdout and the process exit code reach the terminal / CI runner.

## `.gutconfig.json` (so CI and humans run the same thing)

Place at project root; then the command is just
`... -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`.

```json
{
  "dirs": ["res://test"],
  "include_subdirs": true,
  "prefix": "test_",
  "suffix": ".gd",
  "log_level": 1,
  "should_exit": true,
  "should_exit_on_success": false
}
```

## Writing tests

Tests extend `GutTest` (Godot 4 GUT 9.x). Lifecycle hooks: `before_all`,
`before_each`, `after_each`, `after_all`.

```gdscript
extends GutTest

var sm: StateMachine

func before_each() -> void:
    sm = StateMachine.new()
    # add stub EstadoBase children, then add_child_autofree(sm)

func test_transition_routes_to_named_state() -> void:
    # arrange a current state + a target named "FlightState"
    # act: emit transition_requested(current, "FlightState")
    # assert: sm.current_state.name == "FlightState"
    pass

func test_stale_request_is_ignored() -> void:
    # a request whose `from` != current_state must be a no-op
    pass
```

Common asserts: `assert_eq`, `assert_ne`, `assert_true`, `assert_false`, `assert_gt`,
`assert_lt`, `assert_almost_eq` (floats), `assert_has`, `assert_signal_emitted`,
`assert_not_null`. Use `add_child_autofree()` / `autofree()` so nodes are freed between
tests and don't leak.

### Priority coverage (pure logic, no rendered scene)

- **FSM transition routing** — named transitions resolve; stale/unknown ignored.
- **`SpellData` math** — damage/mana/speed defaults and any derived computation.
- **Mana/resource systems** — spend/regenerate/clamp; "can't cast when broke".
- **Ability gating** — `FlightState` unreachable until `abilities["electricity"]`.

These avoid the engine's rendered-scene needs, so they run fast and stable headless.

## Signals & doubles

- Watch a signal before acting: `watch_signals(obj)`, then
  `assert_signal_emitted(obj, "transition_requested")` /
  `assert_signal_emitted_with_parameters(obj, "died", [args])`.
- **Doubles:** `var dbl = double(SomeClass).new()` then `stub(dbl, "method").to_return(x)`;
  `assert_called(dbl, "method")`. Use to isolate a unit from collaborators
  (e.g. stub a `MagicManager` when testing a state). See GUT docs "Doubles".

## CI snippet (GitHub Actions sketch)

```yaml
- name: Run GUT
  run: |
    godot --headless --path . -s addons/gut/gut_cmdln.gd \
      -gconfig=res://.gutconfig.json -gexit
  # nonzero exit (any failing test) fails the job automatically
```

On Linux CI use the matching Godot 4.6 Linux headless binary; locally on Windows use
`C:\Godot\Godot_v4.6.3-stable_win64_console.exe`. Import assets first if needed with a
prior `--headless --import` pass so resources resolve before tests load `.tres` files.

## Version note

Flags above are confirmed against the GUT 9.x command-line docs (Godot 4 line). Confirm
the exact addon version once `addons/gut/` is vendored; `-gselect`/`-gunit_test_name`/
exit-code behavior have been stable across 9.x.
