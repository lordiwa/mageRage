## TASK-021 WaveController — the PURE, scene-free wave-sequencing helper for the
## encounter room (Sala de encuentro).
##
## Doctrine (game-design SKILL): ramp-then-rest. The room spawns enemies in bounded
## WAVES; the player clears a wave, gets a short REST beat, then the next (harder)
## wave spawns. This object owns ONLY that sequencing decision — it holds no nodes,
## so it is fully unit-testable. The live `encounter.gd` controller feeds it the
## live alive-count + rest timer and acts on its verdicts (spawn next / show CLEARED).
##
## It also owns the DD-004 composition guarantee helpers (distinct_armor_count /
## wave_is_mixed) so "no wave is dominated by a single element weakness" is a
## data-checkable property over the real EncounterWaves design, not a hand-comment.
class_name WaveController extends RefCounted

## How many waves the encounter contains (set by the caller from EncounterWaves).
var total_waves: int = 0

## Index of the wave currently being fought. Ranges 0..total_waves; equals
## total_waves once the encounter is complete (a sentinel past the last wave).
var current_index: int = 0


## A wave is cleared once none of its enemies remain alive. Non-positive counts
## (0 or a defensive negative) read as cleared.
func is_wave_cleared(alive_count: int) -> bool:
	return alive_count <= 0


## Gate advancing to the next wave behind BOTH conditions (ramp-then-rest):
##   1. the current wave is cleared (no enemies alive), AND
##   2. the rest beat has elapsed (rest_elapsed >= rest_delay, inclusive).
## Never advances once the encounter is already complete.
func should_advance(alive_count: int, rest_elapsed: float, rest_delay: float) -> bool:
	if is_complete():
		return false
	if not is_wave_cleared(alive_count):
		return false
	return rest_elapsed >= rest_delay


## Move to the next wave. Bounded: clamps at total_waves so an extra call past the
## end can never overflow the index.
func advance() -> void:
	current_index = mini(current_index + 1, total_waves)


## True once every wave has been cleared and advanced past (current_index sits on
## the past-the-last sentinel).
func is_complete() -> bool:
	return current_index >= total_waves


## True while there is a real wave to fight (the inverse of is_complete).
func has_current_wave() -> bool:
	return not is_complete()


# --- DD-004 composition guarantee --------------------------------------------

## Number of DISTINCT armor types in a wave's armor-type list. Null/empty safe.
func distinct_armor_count(armor_types: Array) -> int:
	var seen := {}
	for t in armor_types:
		seen[t] = true
	return seen.size()


## True when a wave mixes at least two distinct armor types — so no single element
## dominates the wave and the player is pushed to swap loadout mid-fight (DD-004).
func wave_is_mixed(armor_types: Array) -> bool:
	return distinct_armor_count(armor_types) >= 2
