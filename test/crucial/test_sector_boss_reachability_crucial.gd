## CRUCIAL CORE forwarder (TASK-049) — the fast push/PR gate.
##
## test_sector_boss_reachability.gd is 100% crucial (a single real-physics
## flight-bypass reachability test guarding M1's regressions), so the crucial
## core pulls the WHOLE file by extending it. No logic is duplicated; the parent's
## InputGate-clearing after_each teardown is inherited intact (flake-safe).
##
## See docs/CRUCIAL-TESTS.md (group A). The full nightly suite still runs the
## original under res://test, so this is a pure superset relationship.
extends "res://test/test_sector_boss_reachability.gd"
