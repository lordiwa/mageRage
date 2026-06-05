## CRUCIAL CORE forwarder (TASK-049) — the fast push/PR gate.
##
## test_projectile_pool_physics.gd is 100% crucial (the TASK-044 deferred-disable
## physics-callback contract), so the crucial core pulls the WHOLE file by
## extending it. No logic is duplicated.
##
## See docs/CRUCIAL-TESTS.md (group G).
extends "res://test/test_projectile_pool_physics.gd"
