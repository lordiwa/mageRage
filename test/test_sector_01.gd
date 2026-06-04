## TASK-026 integration test for the connected sector level (levels/sector_01.tscn).
##
## This is the spatial spine of Milestone M1 "Fuga del Sector" (PROJECT.md §M1,
## DD-011). It proves the greybox sector:
##   1. instances clean headless (no parse/script error) and is a Node2D root;
##   2. is ONE connected traversable space (not loose arenas) — the player-spawn,
##      the two gate placeholders and the boss room sit on a monotone path so a
##      later ticket can route spawn -> boss;
##   3. starts the hero with FLIGHT already available (DD-008/DD-011) — no movement
##      ability is gated by this ticket;
##   4. exposes the named placeholder markers the follow-up tickets hook into:
##      ElementalGate (TASK-027), AntiMagicZone (TASK-028), and a detectable
##      BossRoomTrigger Area2D (TASK-029).
##
## Kept to scene-structure + position assertions (no input edges) so it is fast and
## deterministic — no physics-frame await that could poison later input tests.
extends GutTest

const SECTOR := preload("res://levels/sector_01.tscn")


func test_sector_scene_instances_without_error() -> void:
	var level := SECTOR.instantiate()
	assert_not_null(level, "sector_01.tscn instantiates")
	add_child_autofree(level)
	await get_tree().process_frame
	assert_true(level is Node2D, "the sector root is a Node2D")
	assert_not_null(level.get_node_or_null("Player"), "the sector has a Player")


func test_player_spawn_marker_resolves_and_player_starts_there() -> void:
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var spawn := level.get_node_or_null("PlayerSpawn") as Marker2D
	assert_not_null(spawn, "a PlayerSpawn Marker2D resolves")
	var player := level.get_node_or_null("Player") as Node2D
	assert_not_null(player, "the Player resolves")
	# The hero is placed at (or essentially at) the spawn marker.
	assert_almost_eq(
		player.global_position.x, spawn.global_position.x, 8.0,
		"the player spawns at the PlayerSpawn marker (x)")
	assert_almost_eq(
		player.global_position.y, spawn.global_position.y, 8.0,
		"the player spawns at the PlayerSpawn marker (y)")


func test_player_starts_with_flight_available() -> void:
	# DD-008 / DD-011: the slice begins post-flight-awakening. This ticket must NOT
	# gate any movement verb — electricity (the flight key) is already unlocked.
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var player := level.get_node_or_null("Player")
	assert_not_null(player, "the Player resolves")
	assert_true("abilities" in player, "the player exposes its abilities set")
	assert_true(
		player.abilities.get("electricity", false),
		"flight (electricity) is available from the start — no flight gate in M1")


func test_elemental_gate_placeholder_exists() -> void:
	# TASK-027 hooks the elemental-environment gate here.
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var gate := level.get_node_or_null("ElementalGate")
	assert_not_null(gate, "an ElementalGate placeholder marker exists (TASK-027)")
	assert_true(gate is Node2D, "the ElementalGate placeholder is positioned in 2D space")


func test_anti_magic_zone_placeholder_exists() -> void:
	# TASK-028 hooks the anti-magic flight-suppression zone here.
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var zone := level.get_node_or_null("AntiMagicZone")
	assert_not_null(zone, "an AntiMagicZone placeholder marker exists (TASK-028)")
	assert_true(zone is Node2D, "the AntiMagicZone placeholder is positioned in 2D space")


func test_boss_room_trigger_is_a_detectable_area() -> void:
	# TASK-029 (Warden) needs a detectable boss-room entry trigger.
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var trigger := level.get_node_or_null("BossRoomTrigger")
	assert_not_null(trigger, "a BossRoomTrigger exists (TASK-029)")
	assert_true(trigger is Area2D, "the BossRoomTrigger is an Area2D so it can detect the player")
	# It must actually mask the Player layer (2) so entry is detectable.
	assert_true(
		(trigger as Area2D).get_collision_mask_value(2),
		"the BossRoomTrigger masks the Player layer (detects the hero entering)")


func test_markers_lie_on_a_connected_left_to_right_path() -> void:
	# Connectedness (criterion 2): the spine runs spawn -> elemental gate ->
	# anti-magic zone -> boss room as a single monotone left-to-right corridor, so
	# a later ticket can path the hero from start to the boss without separate
	# arena scenes. We assert the x-ordering of the markers along that spine.
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var spawn := level.get_node_or_null("PlayerSpawn") as Node2D
	var gate := level.get_node_or_null("ElementalGate") as Node2D
	var zone := level.get_node_or_null("AntiMagicZone") as Node2D
	var boss := level.get_node_or_null("BossRoomTrigger") as Node2D
	assert_not_null(spawn, "PlayerSpawn resolves")
	assert_not_null(gate, "ElementalGate resolves")
	assert_not_null(zone, "AntiMagicZone resolves")
	assert_not_null(boss, "BossRoomTrigger resolves")
	# Monotone left-to-right ordering of the spine.
	assert_lt(spawn.global_position.x, gate.global_position.x,
		"the elemental gate is downstream of the spawn")
	assert_lt(gate.global_position.x, zone.global_position.x,
		"the anti-magic zone is downstream of the elemental gate")
	assert_lt(zone.global_position.x, boss.global_position.x,
		"the boss room is the far (downstream) end of the spine")


func test_boss_room_marker_node_is_present() -> void:
	# A named boss-room region marker (in addition to the trigger) so level tooling
	# and later tickets can find the boss arena anchor.
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var boss_room := level.get_node_or_null("BossRoom")
	assert_not_null(boss_room, "a BossRoom region node exists (TASK-029 anchor)")


func test_sector_seeds_a_couple_of_enemies_along_the_path() -> void:
	# A light combat presence on the path (criterion: enemies sprinkled along the
	# route). Gates/boss are later tickets; a couple of existing enemies is enough.
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var enemies := get_tree().get_nodes_in_group("enemies")
	assert_gte(enemies.size(), 2,
		"the sector seeds at least two enemies along the traversal path")
