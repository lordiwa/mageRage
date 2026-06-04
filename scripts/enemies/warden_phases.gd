## DD-010 Warden phase logic — pure, scene-free decision helpers for the mini-boss.
##
## "The Warden" (El Carcelero) is a phase-based mechanical boss whose ARMOR rotates
## by HP threshold, forcing the player to re-read it and swap the DD-008 loadout
## (game-design SKILL: matchup-not-damage-race, no dominant element). All of the
## phase/armor/pattern selection AND the fan-volley geometry live here as static,
## table-driven helpers so every threshold and angle is trivially unit-testable and
## can never silently drift (fair/deterministic, DD-001) — exactly like DroneAi.
##
## Phase table (DD-010: thresholds at 66% and 33% of max HP):
##   Phase 1  (100%  .. >66% HP)  armor FIRE         weak to ELECTRICITY  pattern AIMED
##   Phase 2  (<=66% .. >33% HP)  armor ICE          weak to FIRE         pattern FAN
##   Phase 3  (<=33% ..   0% HP)  armor ELECTRICITY  weak to ICE          pattern SWEEP
class_name WardenPhases extends RefCounted

## DD-010 HP thresholds (fraction of max). At or BELOW a threshold the boss is in
## the next phase: 66% HP is already Phase 2, 33% HP is already Phase 3.
const PHASE2_THRESHOLD := 0.66
const PHASE3_THRESHOLD := 0.33

## Attack-pattern ids, one per phase (DD-010).
enum Pattern {
	AIMED,   ## P1: heavy aimed shot (drone-like but more damage / slower).
	FAN,     ## P2: 3-projectile fan volley.
	SWEEP,   ## P3: faster cadence + a sweep.
}

## Which phase the boss is in for a given current/max HP. Returns 1, 2 or 3.
## Boundaries are inclusive on the lower side (<=) so 66% -> P2 and 33% -> P3,
## matching DD-010's "100-66 / 66-33 / 33-0" bands. A non-positive max defaults to
## phase 1 (no division by zero).
static func phase_for_hp(hp: float, maximum: float) -> int:
	if maximum <= 0.0:
		return 1
	var frac := hp / maximum
	if frac <= PHASE3_THRESHOLD:
		return 3
	if frac <= PHASE2_THRESHOLD:
		return 2
	return 1

## The armor element for a phase (DD-010 + DD-006 RPS): P1 Fire, P2 Ice, P3 Elec.
## Reuses SpellData.Element so it maps 1:1 to spell elements and feeds ElementMatchup.
static func armor_for_phase(phase: int) -> int:
	match phase:
		2:
			return SpellData.Element.ICE
		3:
			return SpellData.Element.ELECTRICITY
		_:
			return SpellData.Element.FIRE

## The spell element the phase's armor is WEAK to (x1.5), for readouts/telegraphs.
## P1 Fire->Electricity, P2 Ice->Fire, P3 Elec->Ice (the DD-006 counter cycle).
static func weakness_for_phase(phase: int) -> int:
	match phase:
		2:
			return SpellData.Element.FIRE
		3:
			return SpellData.Element.ICE
		_:
			return SpellData.Element.ELECTRICITY

## The attack pattern for a phase (DD-010): P1 AIMED, P2 FAN, P3 SWEEP.
static func pattern_for_phase(phase: int) -> int:
	match phase:
		2:
			return Pattern.FAN
		3:
			return Pattern.SWEEP
		_:
			return Pattern.AIMED

## P2 fan volley geometry: `count` unit vectors spread symmetrically around `aim`,
## total angular span `spread` radians (so the outermost shots sit at +-spread/2).
## A single shot fires straight along the aim; a zero aim defaults to RIGHT so the
## volley never collapses to NaN. Each returned vector is normalized.
static func fan_directions(aim: Vector2, count: int, spread: float) -> Array:
	var dirs: Array = []
	if count <= 0:
		return dirs
	var base := aim
	if base == Vector2.ZERO:
		base = Vector2.RIGHT
	base = base.normalized()
	if count == 1:
		dirs.append(base)
		return dirs
	# Spread the shots evenly across [-spread/2, +spread/2], inclusive of both ends.
	var start := -spread * 0.5
	var step := spread / float(count - 1)
	for i in range(count):
		var angle := start + step * float(i)
		dirs.append(base.rotated(angle))
	return dirs
