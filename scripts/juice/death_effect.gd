## TASK-017 death feedback: the PURE tuning selector for an enemy's death beat.
##
## Enemies shouldn't just blink out — a kill should LAND (game-design SKILL Game
## Feel). On death we play an element-tinted dissolve + a particle burst, scaled by
## the enemy's IMPORTANCE so a routine drone death is modest and the boss death is
## the loudest beat in the fight (the juice budget reserves the biggest feel for the
## rarest, most meaningful moments). "Importance" is just the enemy's max HP: a 60-HP
## drone is quiet, a 300-HP boss is loud.
##
## All of the scaling/clamping DECISION lives here as a static, table-free pure
## function so it is unit-testable with no scene and can never drift between the
## drone and the warden (both call tuning_for()).
class_name DeathEffect extends RefCounted

## Importance reference points. Below MODEST it reads as the floor (drone); at/above
## LOUD it saturates to the boss-blow cap. Between them it lerps.
const MODEST_HP := 60.0      # a routine drone
const LOUD_HP := 300.0       # the Warden boss

## Burst particle count: modest puff for a drone, a real spray for the boss.
const MIN_BURST := 10
const MAX_BURST := 48

## Screen-shake trauma. Kept BELOW the boss phase-transition blow (~0.8) for a
## drone; the boss death is the loudest single shake (capped at the trauma ceiling).
const MIN_SHAKE := 0.20
const MAX_SHAKE := 0.90      # <= 1.0 ScreenShake trauma ceiling

## Hit-stop effectiveness (fed to HitStop.freeze): a small beat for a drone, a
## heavier freeze for the boss.
const MIN_HIT_STOP := 0.6
const MAX_HIT_STOP := 1.5

## Dissolve/fade duration (seconds the sprite tweens to transparent + shrinks).
const MIN_DISSOLVE := 0.20
const MAX_DISSOLVE := 0.45


## Pure: map an enemy's importance (max HP) to a death-beat tuning Dictionary:
##   { burst_amount: int, shake: float, hit_stop: float, dissolve_time: float }
## Monotonic in importance, clamped to sane floors/caps, and always positive for a
## valid enemy (a 0/negative importance still yields the modest floor beat).
static func tuning_for(importance: float) -> Dictionary:
	var t := _weight(importance)
	return {
		"burst_amount": int(round(lerpf(MIN_BURST, MAX_BURST, t))),
		"shake": clampf(lerpf(MIN_SHAKE, MAX_SHAKE, t), 0.0, 1.0),
		"hit_stop": lerpf(MIN_HIT_STOP, MAX_HIT_STOP, t),
		"dissolve_time": lerpf(MIN_DISSOLVE, MAX_DISSOLVE, t),
	}


## Pure: normalized 0..1 loudness weight from importance, clamped to [MODEST, LOUD].
static func _weight(importance: float) -> float:
	var hp := maxf(importance, 0.0)
	if LOUD_HP <= MODEST_HP:
		return 0.0
	return clampf((hp - MODEST_HP) / (LOUD_HP - MODEST_HP), 0.0, 1.0)
