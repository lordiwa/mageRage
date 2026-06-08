## Shmup 01 — the FOUNDATION greybox of the auto-scroll shoot-em-up mode (TASK-065, DD-014).
##
## A SEPARATE level (reached from the level selector) with a constant-rightward AUTO-SCROLL
## camera. The hero is ALWAYS flying here: the controller pre-grants the electricity (flight)
## ability, sets the per-level Player.shmup_mode flag (so FlightState never drops out — the
## double-tap + landing exits are suppressed) and drives the StateMachine into FlightState on
## _ready, then keeps the hero CLAMPED into the auto-scroll camera's visible rect each physics
## frame so the world scrolls past while the player maneuvers within the frame.
##
## ALL shmup behavior is SCOPED to this level: the flag/grant are set HERE, on _ready, on the
## reused Player instance — sector_01/02 FlightState/Player/combat defaults are untouched.
##
## SCOPE of this ticket is the FOUNDATION ONLY. Enemy streaming (TASK-066) and win/lose
## (TASK-067) are SEPARATE later tickets. DD-014 intent: Win = reach the end of the scroll,
## Lose = revive in-frame and continue — NOT implemented here, only documented.
## TASK-067 (DD-014): adds the win/lose LOOP + the per-level SPEED/CADENCE tuning that makes
## the shmup FEEL fast. WIN = the auto-scroll camera travels a fixed LEVEL_LENGTH from its
## start -> shmup_victory (mirrors sector_02's sector_victory). LOSE = the hero's HP reaches 0
## -> the hero REVIVES IN-FRAME and the loop continues: Player.respawn (DD-009) snaps it to the
## recorded start x, but the auto-scroll camera has advanced, so the next per-frame clamp
## (clamp_player_to_view) carries the revived hero into the LIVE scroll frame; brief defeat
## feedback (shmup_defeat) fires. Tuning is applied via SCOPED override seams set here on _ready
## (Player.fly_speed_scale + MagicManager.cadence_scale), both defaulting to the no-op 1.0 so
## the sectors are byte-identical.
class_name Shmup01 extends Node2D

## TASK-067: per-level FLY-SPEED override factor set on the reused Player on _ready. The hero
## flies FASTER than the sectors WITHOUT changing the shared FlightState.FLY_SPEED (260) — this
## scales it per-level. Tunable; > 1.0 = faster.
const FLY_SPEED_SCALE := 1.6

## TASK-067: per-level FIRE-CADENCE override factor set on the MagicManager on _ready. The
## hold-to-fire intervals are MULTIPLIED by this (never mutating the shared SpellData data), so
## < 1.0 = shorter intervals = FASTER fire. Tunable.
const FIRE_CADENCE_SCALE := 0.6

## TASK-067: the WIN distance — how far (px) the auto-scroll camera travels from its start
## before the level is won. Measured from the scroller's start x captured on _ready. Named +
## tunable. At SCROLL_SPEED 180 px/s this is ~36s of lane.
const LEVEL_LENGTH := 6400.0

## TASK-067: emitted ONCE when the camera passes LEVEL_LENGTH and the shmup is won (mirrors
## sector_02.sector_victory).
signal shmup_victory
## TASK-067: emitted each time the hero dies (HP->0) — drives the brief defeat/retry banner.
## The hero revives in-frame (Player.respawn + the per-frame clamp carry it into the live
## scroll frame) so the loop continues.
signal shmup_defeat

@onready var _player: Node2D = get_node_or_null("Player")
@onready var _player_spawn: Marker2D = get_node_or_null("PlayerSpawn")
@onready var _scroller: ShmupScroller = get_node_or_null("ShmupScroller") as ShmupScroller
## TASK-066: the enemy STREAM. Fed the auto-scroll camera on _ready so it emits the existing
## flying-drone enemies from the LIVE right edge of the scrolling frame in data-driven waves.
@onready var _spawner: ShmupSpawner = get_node_or_null("ShmupSpawner") as ShmupSpawner
## TASK-067: the minimal win/lose banner HUD (optional; the level degrades gracefully without it).
@onready var _banner: Node = get_node_or_null("ShmupBanner")

## TASK-067: the camera x captured on _ready, so progress() measures travel from the start.
var _start_x := 0.0
## TASK-067: latched WIN state (idempotent — shmup_victory fires exactly once).
var _victory := false
## TASK-067: latched "a death has happened" flag for the defeat/retry feedback.
var _died := false


func _ready() -> void:
	# Snap the hero to the spawn marker (the designer can move PlayerSpawn and the hero
	# follows) and record it as the DD-009 respawn anchor.
	if _player != null and _player_spawn != null:
		_player.global_position = _player_spawn.global_position
		if _player.has_method("record_spawn"):
			_player.record_spawn()
	_enter_shmup_flight()
	# The auto-scroll camera (NOT the player-mounted sector camera) drives the view. Start it
	# CENTERED on the spawn so the hero begins at the frame center (inside the visible rect at
	# any viewport size) before the rightward scroll carries the frame — and the clamp can't
	# fight the spawn on the first physics frame.
	if _scroller != null:
		if _player_spawn != null:
			_scroller.global_position = _player_spawn.global_position
		_scroller.make_current()
		# TASK-067: capture the camera's start x so progress() measures lane travel from here.
		_start_x = _scroller.global_position.x
	# TASK-066: feed the spawner the live auto-scroll camera so it streams enemies in from the
	# camera's RIGHT edge as the frame advances.
	if _spawner != null and _scroller != null:
		_spawner.set_scroller(_scroller)
	# TASK-069: feed the spawner the live PLAYER so the homing/dive/lock-on motion patterns can
	# steer toward the hero's live position (enter-then-lock-on follow). Guarded no-op if absent.
	if _spawner != null and _player != null and _spawner.has_method("set_player"):
		_spawner.set_player(_player)
	# TASK-067: apply the per-level SPEED/CADENCE tuning (scoped to this level) + wire the
	# win/lose loop (death feedback + the optional banner).
	_apply_shmup_tuning()
	_wire_win_lose()


## TASK-067: apply the SCOPED per-level tuning seams on the reused Player + MagicManager so the
## shmup plays faster than the sectors WITHOUT touching any shared default. Both seams default
## to the no-op 1.0, so this is the ONLY place they change for the shmup. Guarded/defensive so a
## minimal player without the fields is a safe no-op.
func _apply_shmup_tuning() -> void:
	if _player == null:
		return
	if "fly_speed_scale" in _player:
		_player.fly_speed_scale = FLY_SPEED_SCALE
	var mgr := _player.get_node_or_null("MagicManager")
	if mgr != null and "cadence_scale" in mgr:
		mgr.cadence_scale = FIRE_CADENCE_SCALE


## TASK-067: wire the win/lose loop. LOSE: listen to the player's Health `died` so a HP->0
## (already respawned at the start by Player.respawn, DD-009) ALSO fires the brief defeat
## feedback. The optional banner listens to shmup_victory / shmup_defeat. All decoupled +
## guarded (a missing Health/banner is a safe no-op).
func _wire_win_lose() -> void:
	if _player != null:
		var health := _player.get_node_or_null("Health")
		if health != null and health.has_signal("died") \
				and not health.died.is_connected(_on_player_died):
			health.died.connect(_on_player_died)
	if _banner != null:
		if _banner.has_method("show_victory") and not shmup_victory.is_connected(_banner.show_victory):
			shmup_victory.connect(_banner.show_victory)
		if _banner.has_method("show_defeat") and not shmup_defeat.is_connected(_banner.show_defeat):
			shmup_defeat.connect(_banner.show_defeat)


## DD-014 always-flying setup, scoped to this level on the reused Player instance:
## pre-grant flight (electricity) so the flight verb is reachable, set the per-level
## shmup_mode flag so FlightState never drops the hero, and drive the StateMachine straight
## into FlightState so the world scrolls past an airborne hero from frame one. FlightState
## itself applies no gravity, so being in it = gravity off.
func _enter_shmup_flight() -> void:
	if _player == null:
		return
	if "abilities" in _player:
		_player.abilities["electricity"] = true
	if "shmup_mode" in _player:
		_player.shmup_mode = true
	var sm := _player.get_node_or_null("StateMachine") as StateMachine
	if sm != null and sm.current_state != null:
		# Route through the machine's own transition handler so enter()/exit() fire correctly
		# (the controller's _ready runs after the StateMachine's _ready, so current_state is
		# the initial MoveState here).
		sm._on_transition_requested(sm.current_state, "FlightState")


func _physics_process(_delta: float) -> void:
	clamp_player_to_view()
	check_progress()


## Carry the hero with the advancing frame: clamp its position into the auto-scroll camera's
## visible world rect every physics frame so it can maneuver WITHIN the screen but never leave
## it (off-screen = lost). Public so a headless test can drive the clamp deterministically.
## Guarded so a missing player/scroller is a no-op.
func clamp_player_to_view() -> void:
	if _player == null or _scroller == null:
		return
	var rect := _scroller.visible_world_rect()
	_player.global_position = ShmupScroller.clamp_point_to_rect(_player.global_position, rect)


## Anchor accessor: the auto-scroll camera (read-only, for tests + the controller).
func scroller() -> ShmupScroller:
	return _scroller


## TASK-066 accessor: the enemy stream spawner (read-only, for tests + the controller).
func spawner() -> ShmupSpawner:
	return _spawner


# --- TASK-067 WIN: reach LEVEL_LENGTH ----------------------------------------

## How far (px) the auto-scroll camera has travelled from its start. Pure read off the live
## scroller x minus the captured start x — drives the WIN check. 0 before the camera moves.
func progress() -> float:
	if _scroller == null:
		return 0.0
	return _scroller.global_position.x - _start_x


## WIN check: once the camera's progress passes LEVEL_LENGTH, latch the victory state and fire
## shmup_victory exactly once (mirrors sector_02.sector_victory). Called every physics frame in
## game; public so a headless test drives it deterministically after advancing the scroller.
func check_progress() -> void:
	if _victory:
		return
	if progress() >= LEVEL_LENGTH:
		_victory = true
		shmup_victory.emit()


## True once the camera has reached the finish — the shmup WIN state.
func is_victory() -> bool:
	return _victory


# --- TASK-067 LOSE: HP -> 0 revives the hero in-frame, loop continues --------

## The hero's Health emitted `died` (HP reached 0). The Player already revived itself via
## Player.respawn (DD-009), which snaps it to the recorded level-start x — but the auto-scroll
## camera has advanced, so the next per-frame clamp_player_to_view() carries the revived hero
## back into the LIVE scroll frame (an in-frame revive, NOT a jump back to the level start).
## Here we just latch the death + fire the brief defeat/retry feedback so the minimal banner
## reads. The loop continues (the hero is alive again, in-frame).
func _on_player_died() -> void:
	_died = true
	shmup_defeat.emit()


## True once the hero has died at least once — drives the defeat/retry banner feedback.
func has_died() -> bool:
	return _died
