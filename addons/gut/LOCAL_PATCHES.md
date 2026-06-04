# Local patches to the vendored GUT addon

GUT is vendored under `addons/gut/` (version **9.4.0**). The patches below are local
modifications that are **NOT upstream** and will be **silently lost** if GUT is
re-vendored / upgraded. Re-apply them (or verify upstream fixed them) after any GUT bump,
then re-run the suite and confirm the headless output has no `SCRIPT ERROR` lines.

## P-001 — `gut_loader.gd` Nil→bool guard (TASK-024)

- **File:** `addons/gut/gut_loader.gd` (`_static_init`, ~line 35–42)
- **Symptom (before):** headless GUT run printed
  `SCRIPT ERROR: Trying to assign value of type 'Nil' to a variable of type 'bool'. at: _static_init (gut_loader.gd)`
  — non-failing (suite stayed green exit 0) but dirtied the run and could mask a real error.
- **Cause:** a `ProjectSettings.get(...)` read can return `null` when the setting is
  unregistered, and the result was assigned straight into a typed `bool`.
- **Patch:** null-coalesce the read to the static default before the typed-`bool`
  assignment (behavior-preserving: default stays `true`; a registered value still flows
  through). See the inline `TASK-024:` comment at the patch site.
- **On upgrade:** check whether upstream GUT (>9.4.0) already guards this; if so, drop the
  patch. Otherwise re-apply.
