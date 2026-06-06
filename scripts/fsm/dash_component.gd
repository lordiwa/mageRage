## TASK-055 — Unified dash component (stub — implementation follows).
## This file is a MINIMAL STUB so the test file parses and all tests FAIL for the
## right reason (missing behavior, not parse errors).
class_name DashComponent extends Node

## Tuning — STUB values (wrong on purpose so tests fail before impl lands).
const DASH_SPEED := 0.0
const DASH_TIME := 0.0
const DASH_COOLDOWN := 0.0

## Stub: always returns false (no dash fires).
func try_dash(_player: Node) -> bool:
	return false

## Stub: always returns false.
func try_air_dash(_player: Node) -> bool:
	return false

## Stub: always returns false.
func try_ground_dash(_player: Node) -> bool:
	return false

## Stub: no-op timer tick.
func update(_delta: float) -> void:
	pass

## Stub: burst not active.
func is_dashing() -> bool:
	return false
