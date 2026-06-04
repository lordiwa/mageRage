## TASK-010 hit-feedback: hit-stop ("freeze a few frames on a solid hit" —
## game-design SKILL Game Feel). Briefly drops Engine.time_scale, then restores
## it after a SHORT REAL-TIME delay measured in UNSCALED time, so a slowed
## time_scale can never permanently alter the clock (the restore timer is created
## with ignore_time_scale = true).
##
## Registered as an autoload (`HitStop`) so the single hit path can fire it
## without wiring a node reference. The scheduling DECISION lives in the PURE,
## static function duration_for(effectiveness) — separate from the engine call —
## so it is unit-testable with no running tree.
extends Node

## time_scale held during the freeze (near-stop). 0.0 = full freeze.
const FROZEN_SCALE := 0.05
const BASE_DURATION := 0.06       # seconds of real-time freeze for a neutral hit
const MAX_DURATION := 0.12        # cap so even a super-effective hit stays snappy

var _active := false


## Pure: real-time freeze duration for a DD-006 effectiveness multiplier. A
## stronger (super-effective) hit lingers slightly longer to sell the read; a
## resisted hit is shorter. Always positive and capped at MAX_DURATION.
static func duration_for(effectiveness: float) -> float:
	var d := BASE_DURATION * maxf(effectiveness, 0.5)
	return clampf(d, 0.02, MAX_DURATION)


## Freeze time briefly, then restore on an UNSCALED timer so it self-heals.
func freeze(effectiveness: float = 1.0) -> void:
	if _active:
		return
	_active = true
	Engine.time_scale = FROZEN_SCALE
	var seconds := duration_for(effectiveness)
	# ignore_time_scale = true -> the timer counts REAL seconds, immune to the
	# slowdown we just applied, so time_scale always gets restored.
	var timer := get_tree().create_timer(seconds, true, false, true)
	timer.timeout.connect(_restore)


func _restore() -> void:
	Engine.time_scale = 1.0
	_active = false
