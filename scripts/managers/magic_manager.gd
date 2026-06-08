## MagicManager (godot-game-dev SKILL Workflow 2): holds the three SpellData
## (Fire/Ice/Electricity) and a DD-008 two-slot loadout (PRIMARY + SECONDARY).
## Only READS SpellData (data-driven magic); never one script per spell.
##
## DD-008 loadout: select(index) promotes that element to PRIMARY and demotes the
## previous primary to SECONDARY — a stack of the last two distinct elements.
## Re-selecting the current primary is a no-op. cast_primary fires the primary
## slot, cast_secondary the secondary; each checks+spends mana per cast.
##
## Split for headless testing: try_cast_primary()/try_cast_secondary() do the mana
## check/spend and return the SpellData to spawn (or null); cast_primary()/
## cast_secondary() wire that to an actual projectile spawn.
class_name MagicManager extends Node

signal loadout_changed(primary: SpellData, secondary: SpellData)

## TASK-015 no-mana feedback: emitted ONLY when a cast was attempted with a real
## spell in the slot but rejected because mana < cost. NOT emitted on a successful
## cast, and NOT emitted for an empty slot (a missing spell is not a mana failure).
## The PlayerHUD listens to this to flash/pulse the mana bar.
signal cast_failed(slot: int)

## TASK-038 (M2.1 combat-feel) hold-to-fire: emitted on every REAL held cast that
## actually fires (after mana is spent), carrying the slot id and the SpellData. Lets
## the HUD/audio/tests observe the cadence without depending on a projectile scene.
signal cast_fired(slot: int, spell: SpellData)

## TASK-040 (DD-013) dual-cast COMBO: emitted on every REAL combo shot (after BOTH
## manas are spent), carrying the blended combo SpellData. Lets the HUD/audio/tests
## observe combos without depending on a projectile scene.
signal combo_fired(spell: SpellData)

## Slot ids carried by cast_failed so the HUD can react per-slot if it wants.
enum {SLOT_PRIMARY, SLOT_SECONDARY}

@export var spells: Array[SpellData] = []
@export var mana: Mana

## TASK-067 (DD-014): per-level FIRE-CADENCE override. EVERY hold-to-fire interval (the
## single-slot per-element fire_interval AND the combo interval) is multiplied by this at
## READ time — it NEVER mutates the shared SpellData.fire_interval data. < 1.0 => shorter
## intervals => FASTER fire (the shmup pace); DEFAULT 1.0 is a no-op, so the sectors keep the
## M2.1 per-element cadence (Fire 0.18 / Elec 0.28 / Ice 0.40) byte-identical. The shmup_01
## controller sets it < 1.0 on _ready.
@export var cadence_scale := 1.0

## TASK-014 outgoing-cast feedback: a brief element-tinted flash spawned at the
## muzzle on every REAL cast (reuses the impact_spark one-shot). Optional so
## movement-only fakes/tests without it still cast cleanly.
@export var muzzle_flash_scene: PackedScene

## DD-008 two-element loadout. primary fires on cast_primary, secondary on
## cast_secondary.
var primary: SpellData
var secondary: SpellData

## TASK-037 (M2.1 combat-feel) shooting-stutter fix: instead of instantiate()/
## queue_free() a projectile (and its per-shot Line2D + Curve trail) on EVERY shot,
## each distinct projectile PackedScene gets a ProjectilePool. Casts acquire a
## reused instance; on expiry/spend the projectile returns to its pool. Pools are
## created lazily per scene + parented under the spawn parent so the instances live
## where the casts spawn them. Visuals/behavior are unchanged — only node lifetime.
var _pools: Dictionary = {}     # PackedScene -> ProjectilePool

## TASK-038 hold-to-fire: independent "time since last shot" accumulators, one per
## SLOT (not per element — so holding both triggers fires each on its own element's
## interval). Seeded high (READY_MARGIN) so the first held tick fires immediately and
## deterministically; each fired shot resets its slot's accumulator to 0. delta is
## fed in by the player each frame (no hidden _process), keeping the gate pure/testable.
var _primary_accum := 0.0
var _secondary_accum := 0.0

## TASK-040 (DD-013) dual-cast COMBO cadence. A THIRD accumulator, independent of the
## two single-slot ones, gates how often a blended combo may fire — seeded ready so
## the first valid dual-trigger fires immediately, reset to 0 on every combo shot.
var _combo_accum := 0.0

## DD-013 dual-trigger WINDOW bookkeeping. To fire a combo BOTH triggers must engage
## within a short window (~0.12s) of each other (so a deliberate single isn't turned
## into a combo by a late second press). `_solo_hold_accum` measures how long exactly
## ONE trigger has been held alone; when the second joins, the combo engages only if
## that solo lag was within the window. `_dual_engaged` latches a valid dual-hold and
## clears when either trigger releases.
var _solo_hold_accum := 0.0
var _dual_engaged := false

## Seed value that marks an accumulator as "ready to fire now". Large enough to clear
## any element's fire_interval so a fresh hold (or element swap) fires on tick 1.
const _READY_MARGIN := 1000.0

## DD-013 dual-trigger window (seconds): both triggers must engage within this of each
## other to count as a combo, not two singles. Provisional / tunable.
const COMBO_WINDOW := 0.12

## DD-013 anti-dominance combo cadence premium: the combo interval is the SLOWER of
## the two single intervals, multiplied by this (> 1), so combos always fire on a
## strictly slower cadence than either single shot. Provisional / tunable.
const COMBO_CADENCE_PREMIUM := 1.6

func _ready() -> void:
	# Both slots start cadence-ready so the very first held frame can fire.
	_primary_accum = _READY_MARGIN
	_secondary_accum = _READY_MARGIN
	# DD-013: the combo cadence also starts ready, and no dual-trigger is engaged yet.
	_combo_accum = _READY_MARGIN
	_solo_hold_accum = 0.0
	_dual_engaged = false
	# Default loadout: the first two distinct spells (primary, secondary).
	if spells.size() >= 1:
		primary = spells[0]
	if spells.size() >= 2:
		secondary = spells[1]
	loadout_changed.emit(primary, secondary)

## Select the element in slot `index`: promote it to PRIMARY and demote the
## previous primary to SECONDARY (last-two-distinct stack). Re-selecting the
## current primary is a no-op. Out-of-range indices are ignored.
func select(index: int) -> void:
	if index < 0 or index >= spells.size():
		return
	var chosen := spells[index]
	if chosen == primary:
		return                       # already primary: no-op
	secondary = primary              # demote old primary
	primary = chosen                 # promote selection
	# TASK-038: a loadout change re-arms both slots so the newly promoted/demoted
	# elements fire immediately on the next held tick (deterministic, no dead frame).
	_primary_accum = _READY_MARGIN
	_secondary_accum = _READY_MARGIN
	# DD-013: a loadout change also re-arms the combo cadence so a fresh blend fires
	# immediately on the next valid dual-trigger.
	_combo_accum = _READY_MARGIN
	loadout_changed.emit(primary, secondary)

## The element of the primary slot (or -1 if none).
func primary_element() -> int:
	return primary.element if primary != null else -1

## The element of the secondary slot (or -1 if none).
func secondary_element() -> int:
	return secondary.element if secondary != null else -1

## Pure predicate: can the player pay for `spell` right now? True only when both
## a Mana component and a spell exist and current mana >= the spell's cost. Used
## to distinguish a low-mana rejection (-> cast_failed) from an empty slot.
func can_afford(spell: SpellData) -> bool:
	return mana != null and spell != null and mana.current_mana >= spell.mana_cost

## Validate and pay for casting `spell`. Returns the SpellData on success (mana
## spent) or null when there is no spell or mana < cost (mana untouched).
func _try_cast(spell: SpellData) -> SpellData:
	if spell == null or mana == null:
		return null
	if not mana.spend(spell.mana_cost):
		return null
	return spell

## Validate and pay for a PRIMARY-slot cast (see _try_cast).
func try_cast_primary() -> SpellData:
	return _try_cast(primary)

## Validate and pay for a SECONDARY-slot cast (see _try_cast).
func try_cast_secondary() -> SpellData:
	return _try_cast(secondary)

## Spawn the projectile for `spell` from `origin` toward `direction`. Returns true
## if a projectile was spawned.
func _spawn(spell: SpellData, origin: Node2D, direction: Vector2) -> bool:
	if spell == null or spell.projectile == null:
		return false
	var parent := _spawn_parent(origin)
	if parent == null:
		return false
	# TASK-037: acquire a pooled (reused) projectile instead of instantiating one
	# per shot. The pool resets the instance; setup() re-aims + re-styles it. This
	# is identical in look/behavior to a fresh spawn, minus the allocation hitch.
	var pool := _pool_for(spell.projectile, parent)
	var p := pool.acquire()
	if p == null:
		return false
	p.global_position = origin.global_position
	if p.has_method("setup"):
		p.setup(spell, direction)
	# TASK-014: only flashes on a real cast (this path runs after mana is spent),
	# so a failed/zero-mana cast — which returns before _spawn — never flashes.
	_spawn_muzzle_flash(spell, origin, parent)
	return true


## TASK-037: get (or lazily create) the ProjectilePool for a projectile scene. The
## pool node is parented under the spawn parent so pooled instances live in the same
## scene the casts spawn into; it persists across casts so instances are reused.
func _pool_for(scene: PackedScene, parent: Node) -> ProjectilePool:
	var pool: ProjectilePool = _pools.get(scene)
	if pool != null and is_instance_valid(pool):
		return pool
	pool = ProjectilePool.new()
	pool.scene = scene
	parent.add_child(pool)
	_pools[scene] = pool
	return pool

## Where spawned spells/flashes are parented: the current scene, falling back to
## the tree root when there is no current scene (headless tests / pre-scene cast).
func _spawn_parent(origin: Node2D) -> Node:
	var tree := origin.get_tree()
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root

## Spawn the element-tinted muzzle flash at the cast origin. Null-safe: a missing
## scene (movement-only setups) is a silent no-op.
func _spawn_muzzle_flash(spell: SpellData, origin: Node2D, parent: Node) -> void:
	if muzzle_flash_scene == null or parent == null:
		return
	var flash := muzzle_flash_scene.instantiate()
	parent.add_child(flash)
	if flash is Node2D:
		flash.global_position = origin.global_position
	if flash.has_method("burst"):
		flash.burst(spell.element)

## Full runtime PRIMARY cast: spends mana and spawns the primary projectile.
## TASK-015: a slot that HAS a spell the player can't afford emits cast_failed so
## the HUD can flash the mana bar (an empty slot stays silent).
func cast_primary(origin: Node2D, direction: Vector2) -> bool:
	if primary != null and not can_afford(primary):
		cast_failed.emit(SLOT_PRIMARY)
		return false
	return _spawn(try_cast_primary(), origin, direction)

## Full runtime SECONDARY cast: spends mana and spawns the secondary projectile
## (see cast_primary for the cast_failed feedback hook).
func cast_secondary(origin: Node2D, direction: Vector2) -> bool:
	if secondary != null and not can_afford(secondary):
		cast_failed.emit(SLOT_SECONDARY)
		return false
	return _spawn(try_cast_secondary(), origin, direction)

# --- TASK-038 hold-to-fire cadence ------------------------------------------
# The player calls these every frame with the held-trigger flag and the frame
# delta. They ALWAYS advance the slot accumulator by delta (so cadence keeps time
# whether or not the trigger is down); a shot fires only when the trigger is held,
# the accumulator has reached the slot element's data-driven fire_interval, AND
# mana affords it. A real fire spends mana, spawns the pooled projectile, resets
# that slot's accumulator and emits cast_fired. Per-element constants live in the
# SpellData (fire_interval), never here.

## Held PRIMARY cast (see _held_cast). Ticks the primary accumulator and fires the
## primary slot at its element's interval while `held`.
func try_cast_primary_held(origin: Node2D, direction: Vector2, held: bool, delta: float) -> bool:
	var fired := _held_cast(primary, SLOT_PRIMARY, _primary_accum, origin, direction, held, delta)
	_primary_accum = fired.accum
	return fired.shot


## Held SECONDARY cast (see _held_cast). Ticks the secondary accumulator and fires
## the secondary slot at its element's interval while `held`.
func try_cast_secondary_held(origin: Node2D, direction: Vector2, held: bool, delta: float) -> bool:
	var fired := _held_cast(
		secondary, SLOT_SECONDARY, _secondary_accum, origin, direction, held, delta)
	_secondary_accum = fired.accum
	return fired.shot


## Core cadence step for one slot. Advances `accum` by delta (capped so it can't grow
## unbounded across long idle holds), then — if held, ready, and affordable — spends
## mana, spawns the pooled projectile, emits cast_fired and resets the accumulator.
## Returns {shot: bool, accum: float} so the caller can store the slot's new timer.
func _held_cast(
	spell: SpellData,
	slot: int,
	accum: float,
	origin: Node2D,
	direction: Vector2,
	held: bool,
	delta: float,
) -> Dictionary:
	# TASK-067: scale the per-element interval by the per-level cadence_scale (default 1.0
	# = no-op; the shmup sets < 1.0 for faster fire). Reads the SpellData interval; never
	# mutates it. A null spell stays at READY_MARGIN (the scale is irrelevant there).
	var interval := spell.fire_interval * cadence_scale if spell != null else _READY_MARGIN
	# Advance the timer; cap at READY_MARGIN so a long release doesn't overflow but a
	# ready slot still fires on the first held tick.
	accum = minf(accum + delta, _READY_MARGIN)
	if not held:
		return {"shot": false, "accum": accum}
	if spell == null or accum < interval:
		return {"shot": false, "accum": accum}
	if not can_afford(spell):
		return {"shot": false, "accum": accum}   # mana gates: keep timer ready, retry next tick
	if not mana.spend(spell.mana_cost):
		return {"shot": false, "accum": accum}
	_spawn(spell, origin, direction)             # pooled spawn (no-op without a scene)
	cast_fired.emit(slot, spell)
	return {"shot": true, "accum": 0.0}           # reset this slot's cadence


# --- TASK-040 (DD-013) dual-cast COMBO ---------------------------------------
# Pressing BOTH triggers (within a short window) fires ONE blended COMBO projectile
# via the SAME pooled path — NOT two singles. Anti-dominance cost: the combo costs
# BOTH elements' mana (sum) AND fires on a SLOWER combo cadence than either single,
# so spamming combos is mana- and time-expensive (a tactical choice, not a win
# button). The combo mapping is the pure, commutative ComboTable; ANTIMATTER and
# same-element pairs never spawn a blended combo. Deterministic (DD-001): time is the
# `delta` fed in, no wall-clock / RNG.

## The dual-trigger window (seconds) both triggers must engage within. Exposed so the
## player/tests reference the same tunable value.
func combo_window() -> float:
	return COMBO_WINDOW


## The combo cadence (seconds between combos): the SLOWER of the two single intervals
## times the anti-dominance premium, so it is always slower than either single shot.
func combo_interval(spell_a: SpellData, spell_b: SpellData) -> float:
	var a := spell_a.fire_interval if spell_a != null else _READY_MARGIN
	var b := spell_b.fire_interval if spell_b != null else _READY_MARGIN
	# TASK-067: scale by the per-level cadence_scale (default 1.0 no-op) so combos speed up
	# alongside the singles in the shmup while staying anti-dominant (still * COMBO premium).
	return maxf(a, b) * COMBO_CADENCE_PREMIUM * cadence_scale


## The summed mana cost of a combo: BOTH elements' costs (anti-dominance — a combo
## always costs strictly more than either single shot). Null slots cost nothing.
func combo_mana_cost() -> float:
	var a := primary.mana_cost if primary != null else 0.0
	var b := secondary.mana_cost if secondary != null else 0.0
	return a + b


## Drive the dual-trigger combo for one frame. ALWAYS advances the combo accumulator
## by delta (cadence keeps time) and tracks the dual-trigger window.
##
## When BOTH triggers are held the player is in COMBO MODE — `suppress_singles` is
## true so the player TRADES fast single fire for the slow combo rhythm (you don't
## also get full-rate in-between singles; MEDIUM fix). On a cadence-ready, in-window,
## affordable frame it FIRES exactly one shot:
##   - KIND_COMBO     -> spawn the blended combo projectile (Fire/Ice/Elec pairs);
##   - KIND_EMPOWERED -> same element both slots: spawn ONE shot scaled by
##                       ComboTable.EMPOWERED_MULTIPLIER (HIGH-2; never two singles).
## Both pay the SUMMED mana (anti-dominance, all-or-nothing) and reset the combo
## cadence, and emit combo_fired. KIND_NONE (Antimatter / single trigger) never fires
## here — the normal single path handles it.
##
## Returns {"shot": bool, "kind": int, "suppress_singles": bool}: `shot` is true only
## when a combo/empowered shot actually fired this frame; `suppress_singles` tells the
## player whether to mute the two single shots this frame (true whenever both held).
func try_cast_combo_held(
	origin: Node2D,
	direction: Vector2,
	primary_held: bool,
	secondary_held: bool,
	delta: float,
) -> Dictionary:
	# Cadence keeps time regardless of input (capped like the single slots).
	_combo_accum = minf(_combo_accum + delta, _READY_MARGIN)
	# Track the dual-trigger window: how the two triggers engaged relative to each other.
	_update_dual_window(primary_held, secondary_held, delta)

	var both_held := primary_held and secondary_held
	# Resolve what this pair blends to (pure, commutative).
	var result := ComboTable.combo_for(primary_element(), secondary_element())
	if not both_held:
		return {"shot": false, "kind": ComboTable.KIND_NONE, "suppress_singles": false}
	# Antimatter / unmapped: no dual-cast output. Fall back to normal singles (do NOT
	# suppress — comboing isn't possible with these slots).
	if result.kind == ComboTable.KIND_NONE:
		return {"shot": false, "kind": ComboTable.KIND_NONE, "suppress_singles": false}

	# Both held AND a real blend/empower: COMBO MODE. Suppress the in-between singles
	# regardless of whether the (slower) cadence fires this frame.
	var out := {"shot": false, "kind": result.kind, "suppress_singles": true}
	# Require a VALID dual-trigger window + ready combo cadence.
	if not _dual_engaged or _combo_accum < combo_interval(primary, secondary):
		return out
	# Anti-dominance: pay BOTH manas (all-or-nothing).
	var cost := combo_mana_cost()
	if mana == null or mana.current_mana < cost or not mana.spend(cost):
		return out
	# Fire ONE shot: the blended combo, or the empowered single (same element).
	var to_spawn: SpellData = result.spell
	if result.kind == ComboTable.KIND_EMPOWERED:
		to_spawn = _empowered_spell(primary)
	_spawn(to_spawn, origin, direction)            # SAME pooled path as singles
	combo_fired.emit(to_spawn)
	_combo_accum = 0.0                             # reset the combo cadence
	out["shot"] = true
	return out


## HIGH-2 empowered single: a one-off copy of the slot spell with damage scaled by
## ComboTable.EMPOWERED_MULTIPLIER (~1.5x). A duplicate so the source .tres is never
## mutated; the projectile/pool/style path is reused unchanged (data-driven). Null-safe.
func _empowered_spell(spell: SpellData) -> SpellData:
	if spell == null:
		return null
	var boosted := spell.duplicate() as SpellData
	boosted.damage = spell.damage * ComboTable.EMPOWERED_MULTIPLIER
	return boosted


## DD-013 window tracker. While exactly one trigger is held, accrue the solo lag. When
## the second trigger joins, the combo ENGAGES only if that lag was within the window;
## a late join (lag > window) is treated as two deliberate singles, not a combo. Any
## release clears the engaged latch and the solo timer.
func _update_dual_window(primary_held: bool, secondary_held: bool, delta: float) -> void:
	if primary_held and secondary_held:
		# Both down: engage only if the second joined within the window of the first.
		if not _dual_engaged:
			_dual_engaged = _solo_hold_accum <= COMBO_WINDOW
		_solo_hold_accum = 0.0
	elif primary_held or secondary_held:
		# Exactly one down: time how long it's been alone (the window the other has to
		# join within). A lapse here is what blocks a late second trigger from comboing.
		_solo_hold_accum += delta
		_dual_engaged = false
	else:
		# Neither down: reset the window.
		_solo_hold_accum = 0.0
		_dual_engaged = false
