## DD-004 Ice = control: the real SLOW effect (makes SpellData.applies_slow
## functional). While active, the carrier's move-speed and attack-rate multiplier
## is 0.5; it lasts ~2.5s, is REFRESHED on re-hit, and decays back to 1.0 when it
## expires. Pure, scene-free time bookkeeping so the multiplier curve is unit-
## testable with no rendered drone.
##
## Usage: a drone holds a SlowEffect, calls apply()/refresh() on an Ice hit, ticks
## update(delta) each physics frame, and multiplies its chase speed + attack
## cooldown by multiplier().
class_name SlowEffect extends RefCounted

## DD-009: 50% while active, full (1.0) otherwise; ~2.5s, refreshable.
const SLOW_MULTIPLIER := 0.5
const FULL_MULTIPLIER := 1.0
const DURATION := 2.5

## Seconds of slow remaining. <= 0 means inactive (multiplier 1.0).
var _remaining := 0.0

## Start (or REFRESH) the slow: re-seed the full duration. Called on every Ice hit.
func apply() -> void:
	_remaining = DURATION

## Decay the timer by `delta`, clamped at 0 (recovers to full on expiry).
func update(delta: float) -> void:
	_remaining = maxf(_remaining - delta, 0.0)

## True while the slow is in effect (timer still running).
func is_active() -> bool:
	return _remaining > 0.0

## 0.5 while active, 1.0 once expired — multiply chase speed / attack rate by this.
func multiplier() -> float:
	return SLOW_MULTIPLIER if is_active() else FULL_MULTIPLIER

## Seconds of slow left (never negative).
func remaining() -> float:
	return _remaining
