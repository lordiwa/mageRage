## Shmup enemy MOTION math (TASK-069, DD-014) — PURE, deterministic, frame-free per-tick
## position helpers for the streamed shmup enemies. Mirrors ShmupSpawner.y_for_pattern: every
## rule is a static function over an explicit state dict + the LIVE player position, so each
## pattern is unit-testable with NO real frames, NO node, NO scene.
##
## HUMAN DESIGN-LOCK (this session): each streamed enemy ENTERS on its assigned pattern for a
## brief ENTRY_LOCK_DELAY (read-the-armor beat, telegraph-before-threat DD-001), then LOCKS ON
## and steers toward the player's LIVE position while still drifting left with the frame.
##
## Four data-driven movement patterns:
##   STRAIGHT — flat leftward drift (baseline / pacing rest); never steers.
##   SINE     — oscillate y around a center while advancing left (the spawn-Y sine, now ongoing).
##   HOMING   — lock-on dominant: after the entry beat, steer toward the live player ("follow you").
##   DIVE     — arc in fast, swoop toward the player ONCE, then peel away.
##
## The state dict the spawner attaches per enemy: {pattern:int, spawn:Vector2, center_y:float,
## elapsed:float}. The spawner advances elapsed each tick; this helper is otherwise stateless.
class_name ShmupMotion extends RefCounted

## The four per-wave movement patterns (data-driven, selectable per wave).
enum MotionPattern { STRAIGHT, SINE, HOMING, DIVE }

## Enter-then-lock-on beat (s): an enemy follows its entry pattern this long so the player can
## read its armor color, THEN locks on and steers toward the live player. Tunable; SHORT/fair.
const ENTRY_LOCK_DELAY := 0.5

## Baseline leftward CROSS-drift (px/s) — TASK-070: with the spawner now FRAME-CARRYING each
## live enemy (it adds the auto-scroll camera's per-tick x advance on top of this pattern step),
## DRIFT_SPEED is the small FRAME-RELATIVE cross speed, NOT the camera-relative exit speed. It is
## deliberately SMALL so a STRAIGHT/SINE enemy traverses the ~1152px frame slowly and LINGERS
## ~30s (vs the old ~4.6s exit, when 70 px/s was fighting the 180 px/s camera). Tunable.
const DRIFT_SPEED := 35.0

## SINE ongoing-motion knobs: vertical amplitude (px) around the center y and the angular
## frequency (rad/s) of the weave. Tunable — a readable, not-dizzying weave.
const SINE_AMPLITUDE := 90.0
const SINE_FREQ := 3.0

## HOMING / lock-on steer speed (px/s) toward the live player once locked on. Above DRIFT so the
## enemy visibly tracks; capped (a const, not a chase) so it stays fair and still advances.
const HOMING_SPEED := 130.0

## DIVE knobs: how fast it swoops (px/s) toward the player during the swoop window, how long the
## swoop lasts (s) after the entry beat, and the peel-away speed (px/s) it veers off at after.
const DIVE_SWOOP_SPEED := 240.0
const DIVE_SWOOP_TIME := 0.7
const DIVE_PEEL_SPEED := 160.0


## True once this enemy's entry beat has elapsed and it should lock on (steer at the player).
## Pure over the elapsed timer + the tunable delay (mirrors DroneAi.telegraph_elapsed).
static func is_locked_on(elapsed: float) -> bool:
	return elapsed >= ENTRY_LOCK_DELAY


## The next position for a streamed enemy this tick, given its motion `state`, current `pos`, the
## LIVE `player` position, and `delta`. Pure + deterministic: same inputs -> same output, no node
## state read. The spawner bumps state.elapsed AFTER calling this each tick.
static func next_position(state: Dictionary, pos: Vector2, player: Vector2,
		delta: float) -> Vector2:
	var pattern: int = int(state.get("pattern", MotionPattern.STRAIGHT))
	var elapsed: float = float(state.get("elapsed", 0.0))
	match pattern:
		MotionPattern.SINE:
			return _sine_step(state, pos, elapsed, delta)
		MotionPattern.HOMING:
			return _homing_step(pos, player, elapsed, delta)
		MotionPattern.DIVE:
			return _dive_step(pos, player, elapsed, delta)
		_:
			return _straight_step(pos, delta)


## STRAIGHT: flat leftward drift, constant y (no steering, ever). The pacing-rest baseline.
static func _straight_step(pos: Vector2, delta: float) -> Vector2:
	return pos + Vector2(-DRIFT_SPEED * delta, 0.0)


## SINE: drift left while the y oscillates around the enemy's center_y. y is set ABSOLUTELY from
## elapsed (a true sine, phase-independent of accumulated float error), x drifts left.
static func _sine_step(state: Dictionary, pos: Vector2, elapsed: float, delta: float) -> Vector2:
	var center_y: float = float(state.get("center_y", pos.y))
	# Use elapsed AFTER this tick so y actually advances on the very first step too.
	var phase := (elapsed + delta) * SINE_FREQ
	var y := center_y + sin(phase) * SINE_AMPLITUDE
	return Vector2(pos.x - DRIFT_SPEED * delta, y)


## HOMING: ENTER (flat drift) until the lock-on beat, THEN steer toward the LIVE player while
## still drifting left with the frame. Lock-on dominant — the core "follow you" pattern.
static func _homing_step(pos: Vector2, player: Vector2, elapsed: float, delta: float) -> Vector2:
	if not is_locked_on(elapsed):
		return _straight_step(pos, delta)
	var to_player := player - pos
	var steer := to_player.normalized() if to_player != Vector2.ZERO else Vector2.ZERO
	# Steer toward the player AND keep drifting with the frame (capped, so it stays fair).
	return pos + steer * HOMING_SPEED * delta + Vector2(-DRIFT_SPEED * delta, 0.0)


## DIVE: ENTER (flat drift) until the lock-on beat, then SWOOP fast toward the player for
## DIVE_SWOOP_TIME, then PEEL AWAY (veer off the player) — a single committed swoop, not a chase.
static func _dive_step(pos: Vector2, player: Vector2, elapsed: float, delta: float) -> Vector2:
	if not is_locked_on(elapsed):
		return _straight_step(pos, delta)
	var to_player := player - pos
	var dir := to_player.normalized() if to_player != Vector2.ZERO else Vector2.RIGHT
	var swoop_end := ENTRY_LOCK_DELAY + DIVE_SWOOP_TIME
	if elapsed < swoop_end:
		# Swoop window: arc hard toward the player (no extra drift — the swoop IS the motion).
		return pos + dir * DIVE_SWOOP_SPEED * delta
	# Peel away: veer OFF the player (opposite the swoop dir) so the gap grows again.
	return pos - dir * DIVE_PEEL_SPEED * delta + Vector2(-DRIFT_SPEED * delta, 0.0)
