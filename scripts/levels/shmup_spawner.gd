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

## TASK-069: the per-wave MOVEMENT pattern. Mirrors ShmupMotion.MotionPattern 1:1 (same order,
## same int values) so a wave dict + a test can name it as ShmupSpawner.MotionPattern.* and the
## int flows straight into ShmupMotion.next_position(). STRAIGHT (default) keeps the original
## flat-drift behavior; SINE/HOMING/DIVE add variety + the enter-then-lock-on follow. The motion
## MATH is PURE in ShmupMotion (frame-free, unit-tested); test_shmup_motion guards the enum.
enum MotionPattern { STRAIGHT, SINE, HOMING, DIVE }

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
## {enemy_type, count, spacing, y_pattern, t_start, motion}:
##   enemy_type : index into ENEMY_SCENES (which existing drone to stream);
##   count      : how many enemies the wave emits;
##   spacing    : seconds between successive emits within the wave;
##   y_pattern  : a YPattern (LINE/SINE/TOP/BOTTOM) entry formation (the SPAWN y);
##   t_start    : seconds (since the spawner started) the wave's first emit fires;
##   motion     : TASK-069 — a MotionPattern (STRAIGHT/SINE/HOMING/DIVE) ongoing MOVEMENT.
##                Optional; defaults to STRAIGHT (the original flat-drift behavior).
## Provisional pacing — TASK-067 owns the speed/cadence tuning. TASK-069 adds the motion mix so
## enemies ENTER then LOCK ON (variety + the "follow you" feel). Mixed armor across waves so the
## player swaps element mid-stream (DD-006 read preserved). Settable so a test owns the schedule.
## TASK-070: DENSE + LINGERING. The level runs ~35.5s (Shmup01.LEVEL_LENGTH 6400 / SCROLL_SPEED
## 180). Enemies are now FRAME-CARRIED (they linger ~30s) so OVERLAPPING waves accumulate several
## on screen at once. Reworked from 4 waves / 16 enemies to a denser stream that SPANS the full
## lane (last wave starts ~30s in, before the level ends), keeps mixed armor (0 Empire ELEC / 1
## Shield ICE) + all four motion patterns + the enter-then-lock-on feel. Provisional / playtest-
## tunable: ~dozens total, ~4-8+ concurrent. Kept FAIR (DD-001) — denser + lingering, not a wall:
## tighter spacing + overlap, NOT bigger single bursts; telegraph+fire intact.
const DEFAULT_WAVES: Array = [
	# Opener: a STRAIGHT line — pacing rest, lets the player read the armor color.
	{"enemy_type": 0, "count": 5, "spacing": 0.7, "y_pattern": YPattern.LINE, "t_start": 1.0,
		"motion": MotionPattern.STRAIGHT},
	# Early weave (overlaps the opener) — a second armor enters from the top.
	{"enemy_type": 1, "count": 5, "spacing": 0.8, "y_pattern": YPattern.TOP, "t_start": 4.0,
		"motion": MotionPattern.SINE},
	# Homing pressure: enter, then track the player (the core follow-you ask).
	{"enemy_type": 0, "count": 6, "spacing": 0.6, "y_pattern": YPattern.SINE, "t_start": 8.0,
		"motion": MotionPattern.HOMING},
	# Dive jab from below while the homers + earlier waves still linger.
	{"enemy_type": 1, "count": 5, "spacing": 0.7, "y_pattern": YPattern.BOTTOM, "t_start": 12.0,
		"motion": MotionPattern.DIVE},
	# Mid-level straight reinforcement (fills the lane, keeps the screen busy).
	{"enemy_type": 0, "count": 6, "spacing": 0.6, "y_pattern": YPattern.LINE, "t_start": 16.0,
		"motion": MotionPattern.STRAIGHT},
	# A weaving Shield wave overlapping the straight reinforcement.
	{"enemy_type": 1, "count": 5, "spacing": 0.7, "y_pattern": YPattern.SINE, "t_start": 19.0,
		"motion": MotionPattern.SINE},
	# Back-half homing wave (the lane is full now; element-swap pressure).
	{"enemy_type": 0, "count": 6, "spacing": 0.6, "y_pattern": YPattern.TOP, "t_start": 23.0,
		"motion": MotionPattern.HOMING},
	# Late dive finale — swoop the player as the level closes out.
	{"enemy_type": 1, "count": 5, "spacing": 0.7, "y_pattern": YPattern.BOTTOM, "t_start": 27.0,
		"motion": MotionPattern.DIVE},
	# Closing straight stragglers spanning to near the finish line.
	{"enemy_type": 0, "count": 5, "spacing": 0.7, "y_pattern": YPattern.LINE, "t_start": 30.5,
		"motion": MotionPattern.STRAIGHT},
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

## TASK-069: the live PLAYER (duck-typed Node2D: read .global_position) the homing/dive/lock-on
## patterns steer toward. Fed by the level controller via set_player(); a test injects a fake.
## Null is safe (the patterns fall back to plain leftward drift with no target).
var _player: Object

## TASK-069: per-active-enemy MOTION state, keyed by the enemy handle's instance id. Each entry
## is a ShmupMotion state dict {pattern, spawn, center_y, elapsed} the spawner advances per tick
## via ShmupMotion.next_position() — the spawner OWNS the streamed enemy's position by pattern.
var _motion: Dictionary = {}

## Seconds elapsed since the spawner began driving update() — the wave clock.
var _clock := 0.0

## TASK-070 FRAME-CARRY: the scroller's left-edge x as of the PREVIOUS tick. Each tick the
## spawner carries every live enemy right by (this tick's left edge - last) so the enemy moves
## RELATIVE to the advancing frame — its dwell is governed by the small ShmupMotion cross-drift,
## not the camera speed. NAN until the first _advance_active reads the scroller (carry = 0 the
## first tick). Read off the scroller's OWN rect so it's decoupled from SCROLL_SPEED + frame-rate.
var _last_left_edge := NAN

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
	# TASK-069: opt the streamed enemy into shmup motion (the spawner OWNS its position) so its
	# drone FSM movement states yield position control — and seed its per-enemy motion state.
	if enemy is Object and "shmup_motion" in enemy:
		enemy.shmup_motion = true
	var motion_pattern: int = int(wave.get("motion", MotionPattern.STRAIGHT))
	_motion[(enemy as Object).get_instance_id()] = {
		"pattern": motion_pattern,
		"spawn": at,
		"center_y": at.y,
		"elapsed": 0.0,
	}


## TASK-069: drive every live enemy's position by its assigned MOTION pattern (the spawner OWNS
## the streamed enemy's position; its drone FSM movement states yield via the shmup_motion flag).
## Each enemy runs its entry pattern for ENTRY_LOCK_DELAY then locks on toward the LIVE player —
## STRAIGHT just drifts left (the original behavior), so an enemy without a motion record (or a
## non-Node2D fake) degrades to the plain leftward drift. Skips any handle that vanished.
func _advance_active(delta: float) -> void:
	var player_pos := _player_position()
	# TASK-070 FRAME-CARRY: how far the scroller's frame advanced (right) since the last tick.
	# Adding this to every enemy on top of its pattern step makes the motion RELATIVE to the
	# frame, so an enemy keeps pace with the scroll and only the (small) ShmupMotion cross-drift
	# erodes its lead -> it LINGERS. Computed from the scroller's OWN left-edge delta (not the
	# SCROLL_SPEED const), so it stays decoupled + frame-rate independent. Zero on the first tick.
	var carry_dx := _frame_carry_dx()
	var carry := Vector2(carry_dx, 0.0)
	for enemy in _active:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var node := enemy as Node2D
		var key := (enemy as Object).get_instance_id()
		if _motion.has(key):
			var state: Dictionary = _motion[key]
			node.global_position = ShmupMotion.next_position(
				state, node.global_position, player_pos, delta) + carry
			state["elapsed"] = float(state.get("elapsed", 0.0)) + delta
		else:
			# No motion record (legacy / direct-tracked handle): plain leftward drift + carry.
			node.global_position.x += -ENTRY_SPEED * delta + carry_dx


## TASK-070 FRAME-CARRY amount (px) this tick: the scroller's visible-rect left-edge advance
## since the previous tick. Reads the LIVE rect, updates the stored edge, and returns 0 on the
## very first tick (no previous edge) or when no scroller is wired. Pure side effect on
## _last_left_edge so the carry stays decoupled from SCROLL_SPEED + the frame rate.
func _frame_carry_dx() -> float:
	if _scroller == null:
		return 0.0
	var left_edge: float = _scroller.visible_world_rect().position.x
	var dx := 0.0
	if not is_nan(_last_left_edge):
		dx = left_edge - _last_left_edge
	_last_left_edge = left_edge
	return dx


## The live player's world position for lock-on/homing/dive, or a far-LEFT fallback (so a
## pattern with no player target simply keeps advancing toward the left edge). Defensive.
func _player_position() -> Vector2:
	if _player != null and is_instance_valid(_player) and _player is Node2D:
		return (_player as Node2D).global_position
	return Vector2(-1.0e9, 0.0)


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
			# TASK-069: drop the per-enemy motion record alongside the release (no leak).
			_motion.erase((enemy as Object).get_instance_id())
			if release_callback.is_valid():
				release_callback.call(enemy)
			continue
		survivors.append(enemy)
	_active = survivors


## Release predicate: off the LEFT edge (fully past it) or dead. TASK-067 (folds the TASK-066
## review MEDIUM): the REAL EmpireDrone/ShieldDrone is a CharacterBody2D ROOT whose is_dead()
## lives on a Health CHILD node, NOT on the root — so the old root-level `enemy.is_dead()`
## check was DEAD CODE for real drones (they were only ever cleaned by the validity prune).
## _is_enemy_dead() now queries the Health child first (the real-drone contract) and falls back
## to a root-level is_dead() (the test FakeEnemy), so both a real drone and a bare fake work.
func _should_release(enemy: Object, left_edge: float) -> bool:
	if enemy is Node2D and (enemy as Node2D).global_position.x < left_edge:
		return true
	if _is_enemy_dead(enemy):
		return true
	return false


## Dead-enemy detection that matches how enemies ACTUALLY die: query the Health CHILD's
## is_dead() (the real EmpireDrone/ShieldDrone shape, "Health" node off the body root) and
## fall back to a root-level is_dead() for a bare duck-typed fake. Defensive at every step
## (a missing child / method is simply "not dead").
func _is_enemy_dead(enemy: Object) -> bool:
	if enemy is Node:
		var health := (enemy as Node).get_node_or_null("Health")
		if health != null and health.has_method("is_dead") and health.is_dead():
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


# --- Player wiring (TASK-069 lock-on target) ---------------------------------

## Feed the spawner the live PLAYER (duck-typed Node2D) the homing/dive/lock-on patterns steer
## toward. Mirrors set_scroller — the level controller wires it on _ready; a test injects a fake.
func set_player(player: Object) -> void:
	_player = player


## True once a player has been fed (wiring assertion for the level test).
func has_player() -> bool:
	return _player != null


## TASK-069 accessor: the resolved MOTION pattern of a live enemy handle (or STRAIGHT if it has
## no record). Public so a test can assert a wave's motion field flows through to the enemy.
func motion_for(enemy: Object) -> int:
	if enemy == null:
		return MotionPattern.STRAIGHT
	var state: Variant = _motion.get(enemy.get_instance_id(), null)
	if state == null:
		return MotionPattern.STRAIGHT
	return int((state as Dictionary).get("pattern", MotionPattern.STRAIGHT))


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
