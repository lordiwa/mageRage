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
## Lose = respawn — NOT implemented here, only documented.
class_name Shmup01 extends Node2D

@onready var _player: Node2D = get_node_or_null("Player")
@onready var _player_spawn: Marker2D = get_node_or_null("PlayerSpawn")
@onready var _scroller: ShmupScroller = get_node_or_null("ShmupScroller") as ShmupScroller
## TASK-066: the enemy STREAM. Fed the auto-scroll camera on _ready so it emits the existing
## flying-drone enemies from the LIVE right edge of the scrolling frame in data-driven waves.
@onready var _spawner: ShmupSpawner = get_node_or_null("ShmupSpawner") as ShmupSpawner


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
	# TASK-066: feed the spawner the live auto-scroll camera so it streams enemies in from the
	# camera's RIGHT edge as the frame advances.
	if _spawner != null and _scroller != null:
		_spawner.set_scroller(_scroller)


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
