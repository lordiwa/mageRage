## TASK-055 — Unified Dash Component (single source of truth).
##
## Owns all dash constants, the burst+cooldown timers, and the suppression check for
## the air dash. All four movement states (MoveState/JumpState/GlideState/FlightState)
## delegate to this node so:
##   - constants are defined in ONE place (no per-state duplication / drift risk).
##   - the cooldown is SHARED across states (a dash in flight keeps the cooldown on
##     landing — a player cannot reset it by switching states).
##   - the air-dash suppression check is centralised (mirrors FlightState's own
##     suppression guard, per DD-011 review HIGH).
##
## This node is a direct child of the Player named "DashComponent". States resolve
## it once per frame: `player.get_node_or_null("DashComponent") as DashComponent`.
##
## Tuning (PROVISIONAL, DD-001 / TASK-055): DASH_SPEED 460->700; DASH_TIME 0.12->0.16
## (~55px -> ~112px); DASH_COOLDOWN 0.35->0.30.
class_name DashComponent extends Node

## Horizontal burst speed (px/s). Provisional — tunable in playtest (DD-001).
const DASH_SPEED   := 700.0
## Duration of the burst window (seconds). velocity.y=0, gravity suppressed.
const DASH_TIME    := 0.16
## Minimum interval between consecutive dashes (seconds). Shared across states.
const DASH_COOLDOWN := 0.30

## > 0 while the burst is active (gravity suppressed, horizontal override on).
var _dash_timer   := 0.0
## > 0 while re-dash is blocked. Does NOT reset on state transitions.
var _dash_cooldown := 0.0


## Tick timers each physics frame. Call from the active state's physics_update.
func update(delta: float) -> void:
	if _dash_timer > 0.0:
		_dash_timer -= delta
	if _dash_cooldown > 0.0:
		_dash_cooldown -= delta


## True while the burst window is active (the state should override velocity and skip
## normal movement code). False once the burst window expires.
func is_dashing() -> bool:
	return _dash_timer > 0.0


## Apply the velocity burst to `player` (x = facing * DASH_SPEED; y = 0).
## Call this every frame the burst is active to lock the trajectory.
func apply_burst(player: Node) -> void:
	player.velocity.x = player.facing * DASH_SPEED
	player.velocity.y = 0.0


## Try to start an AIR dash (off-floor states: JumpState/GlideState/FlightState).
## Returns true if the dash fired; false if blocked by cooldown, no fire ability,
## missing input edge, or anti-magic suppression (is_flight_suppressed()).
##
## CRITICAL SAFETY (TASK-055 / DD-011): an air dash INSIDE an un-purged anti-magic
## zone is suppressed — the zone's ~88px barrier would otherwise be crossable via
## the ~112px horizontal burst without purging. The GROUND dash (try_ground_dash)
## is unaffected (the wall is only bypassed by flight-capable airborne movement).
func try_air_dash(player: Node) -> bool:
	if _dash_cooldown > 0.0:
		return false
	if not player.abilities.has("fire"):
		return false
	if not InputGate.just_pressed("dash"):
		return false
	# Suppress air dash inside an un-purged anti-magic zone (DD-011).
	if player.is_flight_suppressed():
		return false
	# All checks passed: start the burst.
	_dash_timer   = DASH_TIME
	_dash_cooldown = DASH_COOLDOWN
	player.velocity.x = player.facing * DASH_SPEED
	player.velocity.y = 0.0
	return true


## Try to start a GROUND dash (MoveState).
## Returns true if the dash fired; false if blocked by cooldown, no fire ability,
## or missing input edge. NOT suppressed by is_flight_suppressed() (ground-only).
func try_ground_dash(player: Node) -> bool:
	if _dash_cooldown > 0.0:
		return false
	if not player.abilities.has("fire"):
		return false
	if not InputGate.just_pressed("dash"):
		return false
	_dash_timer   = DASH_TIME
	_dash_cooldown = DASH_COOLDOWN
	player.velocity.x = player.facing * DASH_SPEED
	player.velocity.y = 0.0
	return true
