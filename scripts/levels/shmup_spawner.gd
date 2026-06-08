## Shmup enemy STREAM (TASK-066) — feeds the existing flying-drone enemies into the auto-scroll
## shmup (levels/shmup_01.tscn) from the RIGHT edge of the scrolling frame, in timed
## DATA-DRIVEN waves. Enemies drift LEFTWARD relative to the world so they approach the hero as
## the frame scrolls past, and are RELEASED (recycled) the moment they leave the LEFT edge or
## die. Reuses the EXISTING EmpireDrone / ShieldDrone scenes + their AI/projectiles — it only
## PLACES them and gives them a shmup entry velocity; it invents no new enemy type.
##
## Scoped entirely to the shmup level (one ShmupSpawner node in shmup_01.tscn). The sectors'
## statically-placed drones are untouched.
##
## UNIT-TESTABLE DETERMINISTICALLY: all timing runs through update(delta) (called directly by a
## test, NOT buried in _physics_process), and BOTH the spawn and the release go through injected
## Callable seams (spawn_callback / release_callback). A test feeds a fake scroller (a fixed
## Rect2), a spawn spy (records type+position, returns a fake enemy) and a release spy — so spawn
## count, position, and despawn are asserted with NO real frames and NO real enemy .tscn
## instancing. In game the seams default to a real drone-instancing factory + a real free path.
class_name ShmupSpawner extends Node

## Vertical entry formations for a wave. The y of each spawned enemy is derived from the live
## camera rect (NOT magic numbers) via y_for_pattern() so a wave reads the same at any viewport.
enum YPattern { LINE, SINE, TOP, BOTTOM }

## How far PAST the right edge of the camera rect an enemy spawns (px) — just off-screen so it
## slides into view rather than popping in. Tunable.
const SPAWN_MARGIN := 64.0

## Leftward world speed (px/s) given to a spawned enemy so it approaches as the frame scrolls.
## Below the drones' own chase speed so their AI still has authority once on-screen. Tunable.
const ENTRY_SPEED := 70.0

## SINE formation knobs (fraction of the rect height for the amplitude; radians of phase added
## per member so a wave of sine enemies traces a wave, not a flat line). Tunable.
const SINE_AMPLITUDE_FRAC := 0.30
const SINE_PHASE_STEP := 0.9

## TOP / BOTTOM inset as a fraction of the rect height from the respective edge (keeps the
## enemy inside the playfield, clear of the greybox bounds). Tunable.
const EDGE_INSET_FRAC := 0.20

## Enemy-type index -> the EXISTING drone scene it reuses. Data-driven waves reference these by
## index so the wave table stays free of resource paths. 0 = Empire (ELEC orb), 1 = Shield (ICE).
const ENEMY_SCENES := {
	0: "res://scenes/empire_drone.tscn",
	1: "res://scenes/shield_drone.tscn",
}

## The DATA-DRIVEN wave stream — the single place to add/retune waves. Each wave is
## {enemy_type, count, spacing, y_pattern, t_start}:
##   enemy_type : index into ENEMY_SCENES (which existing drone to stream);
##   count      : how many enemies the wave emits;
##   spacing    : seconds between successive emits within the wave;
##   y_pattern  : a YPattern (LINE/SINE/TOP/BOTTOM) entry formation;
##   t_start    : seconds (since the spawner started) the wave's first emit fires.
## Provisional pacing — TASK-067 owns the final tuning + win/lose. Settable so a test owns the
## schedule.
const DEFAULT_WAVES: Array = [
	{"enemy_type": 0, "count": 4, "spacing": 0.8, "y_pattern": YPattern.LINE, "t_start": 1.5},
	{"enemy_type": 1, "count": 3, "spacing": 1.0, "y_pattern": YPattern.TOP, "t_start": 6.0},
	{"enemy_type": 0, "count": 5, "spacing": 0.6, "y_pattern": YPattern.SINE, "t_start": 10.0},
]

## The active wave stream (defaults to DEFAULT_WAVES; a test overrides it).
var waves: Array = DEFAULT_WAVES.duplicate(true)

## Spawn seam: called as spawn_callback.call(enemy_type: int, at: Vector2) -> Node2D. Returns the
## spawned enemy handle the spawner tracks for despawn. Defaults to the real drone factory.
var spawn_callback: Callable

## Release seam: called as release_callback.call(enemy: Node2D) when an enemy leaves the LEFT
## edge or dies. Defaults to the real free path.
var release_callback: Callable

## The auto-scroll camera (duck-typed: must expose visible_world_rect() -> Rect2). Fed by the
## level controller; a test feeds a fake. Read each update for the LIVE right edge + rect.
var _scroller: Object

## Seconds elapsed since the spawner began driving update() — the wave clock.
var _clock := 0.0

## Per-wave count of emits already fired, parallel to `waves` (index-aligned).
var _emitted: Array[int] = []

## Currently-live enemies this spawner owns (handles returned by spawn_callback). Drives the
## per-tick entry motion + despawn sweep.
var _active: Array = []


func _ready() -> void:
	# Default the seams to the real game paths (a test overrides them before first update).
	if not spawn_callback.is_valid():
		spawn_callback = Callable(self, "_default_spawn")
	if not release_callback.is_valid():
		release_callback = Callable(self, "_default_release")
	_reset_emit_counters()


## Drive the spawner one tick: advance the wave clock, fire any due emits, carry the live enemies
## leftward, and sweep the off-screen / dead ones back to the pool. Called directly by a test
## (deterministic, frame-free) and by _physics_process in game.
func update(delta: float) -> void:
	_clock += delta
	if _emitted.size() != waves.size():
		_reset_emit_counters()
	_fire_due_spawns()
	_advance_active(delta)
	_sweep_despawns()


func _physics_process(delta: float) -> void:
	update(delta)


## (Re)build the per-wave emit counters to match the current `waves` length.
func _reset_emit_counters() -> void:
	_emitted.clear()
	for _w in waves:
		_emitted.append(0)


## Fire every emit whose scheduled time has arrived. Wave i emits its k-th enemy at
## t_start + k * spacing; we catch up any emits due by the current clock (so a coarse delta never
## drops an enemy). Each emit asks the seam to spawn at the right edge + the wave's y-pattern.
func _fire_due_spawns() -> void:
	for i in range(waves.size()):
		var wave: Dictionary = waves[i]
		var count: int = int(wave.get("count", 0))
		var spacing: float = float(wave.get("spacing", 1.0))
		var t_start: float = float(wave.get("t_start", 0.0))
		while _emitted[i] < count:
			var due_at := t_start + float(_emitted[i]) * spacing
			if _clock < due_at:
				break
			var index := _emitted[i]
			_emitted[i] += 1
			_emit_one(wave, index)


## Spawn a single enemy of `wave` at member `index`: compute the spawn point (right edge +
## SPAWN_MARGIN, y from the wave's pattern), call the spawn seam, and start tracking the handle
## with its leftward entry velocity. A null rect (no scroller) or null handle is a safe no-op.
func _emit_one(wave: Dictionary, index: int) -> void:
	if _scroller == null or not spawn_callback.is_valid():
		return
	var rect: Rect2 = _scroller.visible_world_rect()
	var pattern: int = int(wave.get("y_pattern", YPattern.LINE))
	var at := Vector2(
		rect.position.x + rect.size.x + SPAWN_MARGIN,
		y_for_pattern(pattern, rect, index),
	)
	var enemy: Variant = spawn_callback.call(int(wave.get("enemy_type", 0)), at)
	if enemy == null:
		return
	_active.append(enemy)


## Carry every live enemy LEFTWARD by ENTRY_SPEED * delta (world drift, on top of its own AI), so
## it approaches the hero as the frame scrolls. Skips any handle that vanished.
func _advance_active(delta: float) -> void:
	for enemy in _active:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy is Node2D:
			(enemy as Node2D).global_position.x -= ENTRY_SPEED * delta


## Sweep the active set: release (recycle) any enemy that has left the LEFT edge of the camera
## rect OR reports dead, dropping it from the active set so it is never released twice. Rebuilds
## the active list to also drop freed handles.
func _sweep_despawns() -> void:
	if _scroller == null:
		return
	var rect: Rect2 = _scroller.visible_world_rect()
	var left_edge := rect.position.x
	var survivors: Array = []
	for enemy in _active:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if _should_release(enemy, left_edge):
			if release_callback.is_valid():
				release_callback.call(enemy)
			continue
		survivors.append(enemy)
	_active = survivors


## Release predicate: off the LEFT edge (fully past it) or dead. Duck-typed is_dead() so a fake
## enemy (test) and a real drone (Health-backed is_dead) both work.
func _should_release(enemy: Object, left_edge: float) -> bool:
	if enemy is Node2D and (enemy as Node2D).global_position.x < left_edge:
		return true
	if enemy.has_method("is_dead") and enemy.is_dead():
		return true
	return false


## Pure, frame-free formation helper: the spawn y for member `index` of a wave, derived from the
## camera `rect` (no magic numbers). LINE centers all members; TOP/BOTTOM inset from an edge;
## SINE oscillates around the center, phase-stepped per member so a wave traces a sine.
static func y_for_pattern(pattern: int, rect: Rect2, index: int) -> float:
	var center := rect.position.y + rect.size.y * 0.5
	match pattern:
		YPattern.TOP:
			return rect.position.y + rect.size.y * EDGE_INSET_FRAC
		YPattern.BOTTOM:
			return rect.position.y + rect.size.y * (1.0 - EDGE_INSET_FRAC)
		YPattern.SINE:
			var amp := rect.size.y * SINE_AMPLITUDE_FRAC
			return center + sin(float(index) * SINE_PHASE_STEP) * amp
		_:
			return center


## The existing drone PackedScene a wave's enemy_type reuses (or null for an unknown index).
## Public so a test can assert each wave maps to a REAL existing scene (no new enemy type).
func enemy_scene_for(enemy_type: int) -> PackedScene:
	var path: String = ENEMY_SCENES.get(enemy_type, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


# --- Scroller wiring ---------------------------------------------------------

## Feed the spawner the auto-scroll camera (the live right-edge / rect source). Duck-typed so a
## test can pass a fake exposing visible_world_rect().
func set_scroller(scroller: Object) -> void:
	_scroller = scroller


## True once a scroller has been fed (wiring assertion for the level test).
func has_scroller() -> bool:
	return _scroller != null


# --- Default (real-game) seams -----------------------------------------------

## Default spawn path: instance the existing drone scene for `enemy_type`, place it at `at` in the
## current scene, and hand it back. Reuses the drone's own _ready (collision layer 3, FSM, target
## resolution from the "player" group). Returns null if the scene can't be resolved.
func _default_spawn(enemy_type: int, at: Vector2) -> Node2D:
	var scene := enemy_scene_for(enemy_type)
	if scene == null:
		return null
	var enemy := scene.instantiate() as Node2D
	if enemy == null:
		return null
	var parent: Node = get_parent() if get_parent() != null else self
	parent.add_child(enemy)
	enemy.global_position = at
	return enemy


## Default release path: free the enemy. TASK-044 discipline — the sweep runs from update()
## (driven by _physics_process), which CAN coincide with the enemy's own area/body callbacks, so
## the free is DEFERRED (queue_free) and never a synchronous disable of a live CollisionObject.
func _default_release(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	enemy.queue_free()
