## TASK-018 Charger AI — pure decision helpers for the node-based FSM.
##
## The Charger FSM (Patrol -> Chase -> WindUp -> Charge -> Recovery) keeps ALL phase
## transition logic + the exposed-window rule in these static, scene-free helpers so
## every threshold is trivially unit-testable and can never silently drift
## (game-design SKILL: fair/deterministic, DD-001 — the charge must be readable and
## dodgeable). The FSM states are thin: they advance a timer and ask these helpers.
##
## Timing gates mirror DroneAi.telegraph_elapsed (>= semantics) so the two enemies
## share the same fair-play feel; the charge-specific pieces (exposed predicate +
## bonus multiplier, horizontal lunge sign) live here.
class_name ChargerAi extends RefCounted

## Bonus damage taken while the core is EXPOSED (Recovery). Read-and-punish payoff:
## landing hits during the stagger window hurts the Charger extra (DD-001 fairness in
## the OTHER direction — the player is rewarded for reading the telegraph + dodge).
const EXPOSED_MULTIPLIER := 2.0

## The FSM state names whose phase exposes the core. Lower-cased so it matches the
## StateMachine's registration (state.name.to_lower()).
const _EXPOSED_STATES := {
	"chargerrecoverystate": true,
}

## True once the wind-up telegraph has fully elapsed — WindUp -> Charge. The lunge
## fires only AFTER the player has had the whole telegraph to react (mandatory
## telegraph, DD-001).
static func windup_elapsed(telegraph_time: float, windup: float) -> bool:
	return telegraph_time >= windup

## True once the fixed lunge duration has elapsed — Charge -> Recovery.
static func charge_elapsed(charge_time: float, duration: float) -> bool:
	return charge_time >= duration

## True once the recovery/stagger window has elapsed — Recovery -> Chase.
static func recovery_elapsed(recovery_time: float, window: float) -> bool:
	return recovery_time >= window

## True when the active FSM phase (identified by state node name) leaves the core
## EXPOSED. Case-insensitive so it agrees with the StateMachine's lower-cased keys.
static func is_exposed_phase(state_name: String) -> bool:
	return _EXPOSED_STATES.has(state_name.to_lower())

## Damage multiplier for the exposed window: a bonus while exposed, 1.0 otherwise.
static func exposed_multiplier(exposed: bool) -> float:
	return EXPOSED_MULTIPLIER if exposed else 1.0

## The horizontal lunge sign (+1 right / -1 left) toward the player. The charge is a
## HORIZONTAL ground lunge: only the x sign matters, and it is LOCKED at wind-up start
## so it never re-homes mid-charge (fair, dodgeable). A purely vertical / degenerate
## offset defaults to +1 (deterministic, never zero/NaN).
static func lunge_sign(from: Vector2, to: Vector2) -> float:
	var dx := to.x - from.x
	if dx == 0.0:
		return 1.0
	return signf(dx)
