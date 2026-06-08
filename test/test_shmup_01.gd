## shmup_01 level tests (levels/shmup_01.tscn + scripts/levels/shmup_01.gd, Shmup01) —
## the FOUNDATION of the auto-scroll shoot-em-up mode (TASK-065, DD-014). Enemy streaming
## (TASK-066) and win/lose (TASK-067) are SEPARATE later tickets and are NOT built here.
##
## Modeled on test_sector_02.gd's deterministic scene-structure style: instantiate headless,
## settle one frame so _ready runs, assert STRUCTURE + the controller's per-level setup. The
## scroll/clamp MATH is unit-tested deterministically in test_shmup_scroller.gd (no frames);
## here we prove the wiring (the level instances the player + HUD + spawn + the auto-scroll
## camera, and the controller grants/sustains flight + sets the shmup flag + gravity off).
##
## What it proves:
##   1. shmup_01.tscn instances clean headless; the root is a Node2D running Shmup01, with a
##      Player + a PlayerHUD + a PlayerSpawn marker + the auto-scroll camera (ShmupScroller).
##   2. on _ready the hero is snapped to PlayerSpawn (the respawn anchor, record_spawn()).
##   3. the controller PRE-GRANTS flight (electricity) so the hero can fly here, SETS the
##      per-level shmup flag (shmup_mode = true) so flight never drops, and the auto-scroll
##      camera is current (drives the view).
##   4. greybox bounds (floor/ceiling collision geometry) exist — real gameplay, kept
##      deliberate (TASK-065 builds the foundation; enemies/win-lose are later).
extends GutTest

const SHMUP := preload("res://levels/shmup_01.tscn")


## Instance the level, parent it (auto-freed), settle one frame so _ready runs.
func _make_level() -> Node2D:
	var level := SHMUP.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	return level


func test_shmup_scene_instances_clean_headless() -> void:
	var level: Node2D = await _make_level()
	assert_not_null(level, "shmup_01.tscn instantiates")
	assert_true(level is Node2D, "the shmup level root is a Node2D")
	assert_true(level is Shmup01, "the root carries the Shmup01 controller")


func test_level_instances_player_hud_spawn_and_scroller() -> void:
	var level: Node2D = await _make_level()
	assert_not_null(level.get_node_or_null("Player"), "the level instances a Player")
	assert_not_null(level.get_node_or_null("PlayerHUD"), "the level instances the PlayerHUD")
	var spawn := level.get_node_or_null("PlayerSpawn") as Marker2D
	assert_not_null(spawn, "a PlayerSpawn Marker2D resolves")
	var scroller := (level as Shmup01).scroller()
	assert_not_null(scroller, "the auto-scroll camera resolves via Shmup01.scroller()")
	assert_true(scroller is ShmupScroller, "the auto-scroll camera is a ShmupScroller (Camera2D)")


func test_player_is_snapped_to_the_spawn_marker_on_ready() -> void:
	var level: Node2D = await _make_level()
	var spawn := level.get_node_or_null("PlayerSpawn") as Marker2D
	var player := level.get_node_or_null("Player") as Node2D
	assert_not_null(spawn, "PlayerSpawn resolves")
	assert_not_null(player, "the Player resolves")
	assert_almost_eq(player.global_position.x, spawn.global_position.x, 8.0,
		"the player is snapped to the PlayerSpawn marker (x) on ready")
	assert_almost_eq(player.global_position.y, spawn.global_position.y, 8.0,
		"the player is snapped to the PlayerSpawn marker (y) on ready")


func test_controller_pregrants_flight_and_sets_the_shmup_flag() -> void:
	# The shmup is flight-centric (DD-014): the controller pre-grants electricity (so flight
	# is reachable) AND sets the per-level shmup_mode flag so flight never drops to platformer.
	var level: Node2D = await _make_level()
	var player := level.get_node_or_null("Player")
	assert_not_null(player, "the Player resolves")
	assert_true(player.abilities.get("electricity", false),
		"the controller pre-grants flight (electricity) for the shmup level")
	assert_true("shmup_mode" in player, "the Player exposes the per-level shmup_mode flag")
	assert_true(player.shmup_mode,
		"the controller SETS shmup_mode TRUE so the hero stays flying (DD-014)")


func test_player_starts_in_flight_state() -> void:
	# DD-014: the hero is ALWAYS flying. The controller drives the StateMachine into
	# FlightState on _ready so the world scrolls past an airborne hero from frame one.
	var level: Node2D = await _make_level()
	var player := level.get_node_or_null("Player")
	var sm = player.get_node_or_null("StateMachine")
	assert_not_null(sm, "the Player has a StateMachine")
	assert_eq(sm.current_state.name, "FlightState",
		"the hero starts already in FlightState (always-flying shmup)")


func test_auto_scroll_camera_is_current() -> void:
	# The auto-scroll camera (NOT the player-mounted sector camera) drives the view.
	var level: Node2D = await _make_level()
	var scroller := (level as Shmup01).scroller()
	assert_not_null(scroller, "the scroller resolves")
	assert_true(scroller.is_current(), "the auto-scroll camera is the current camera")


func test_greybox_bounds_exist_as_real_collision_geometry() -> void:
	# The foundation keeps deliberate greybox bounds (floor + ceiling) — real gameplay
	# collision that frames the flight lane. Enemies/hazards are TASK-066, not here.
	var level: Node2D = await _make_level()
	var env := level.get_node_or_null("Environment")
	assert_not_null(env, "the level has an Environment node holding the greybox bounds")
	assert_not_null(env.get_node_or_null("Floor"), "the greybox has a Floor bound")
	assert_not_null(env.get_node_or_null("Ceiling"), "the greybox has a Ceiling bound")


# --- Player viewport clamp (the controller carries the player with the frame) ---

func test_controller_clamps_the_player_into_the_camera_rect() -> void:
	# The level controller clamps the player into the scroller's visible world rect every
	# physics frame. Push the player far PAST the right edge, run the controller's clamp,
	# and assert it is pulled back inside the rect (carried with the frame, can't escape).
	var level: Node2D = await _make_level()
	var shmup := level as Shmup01
	var player := level.get_node_or_null("Player") as Node2D
	var scroller := shmup.scroller()
	assert_not_null(player, "the Player resolves")
	assert_not_null(scroller, "the scroller resolves")

	var rect := scroller.visible_world_rect()
	# Shove the player well beyond the right edge of the visible rect.
	player.global_position = Vector2(rect.position.x + rect.size.x + 500.0, rect.get_center().y)
	shmup.clamp_player_to_view()
	assert_true(scroller.visible_world_rect().has_point(player.global_position),
		"the player is clamped back inside the camera's visible world rect (can't leave the frame)")
	assert_almost_eq(player.global_position.x,
		rect.position.x + rect.size.x, 1.0,
		"a player shoved past the right edge is pulled exactly to that edge")
