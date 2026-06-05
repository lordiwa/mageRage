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

## Slot ids carried by cast_failed so the HUD can react per-slot if it wants.
enum {SLOT_PRIMARY, SLOT_SECONDARY}

@export var spells: Array[SpellData] = []
@export var mana: Mana

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

## Seed value that marks an accumulator as "ready to fire now". Large enough to clear
## any element's fire_interval so a fresh hold (or element swap) fires on tick 1.
const _READY_MARGIN := 1000.0

func _ready() -> void:
	# Both slots start cadence-ready so the very first held frame can fire.
	_primary_accum = _READY_MARGIN
	_secondary_accum = _READY_MARGIN
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
	var interval := spell.fire_interval if spell != null else _READY_MARGIN
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
