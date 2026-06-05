## CRUCIAL CORE forwarder (TASK-049) — the fast push/PR gate.
##
## test_anti_magic_zone_physics.gd is 100% crucial (two real-physics flight-bypass
## regressions for the anti-magic zone), so the crucial core pulls the WHOLE file
## by extending it. No logic is duplicated; the parent's InputGate-clearing
## after_each teardown is inherited intact (flake-safe).
##
## See docs/CRUCIAL-TESTS.md (group A).
extends "res://test/test_anti_magic_zone_physics.gd"
