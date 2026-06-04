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


func test_elemental_gate_instance_resolves_and_blocks_a_required_route() -> void:
	# TASK-027 (criteria 1 & 3): the placed gate is a real ElementalGate component
	# that resolves via Sector01.elemental_gate(), starts sealed (blocking a route on
	# the spine the player must traverse toward the boss), and opens with its element.
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var gate := (level as Sector01).elemental_gate()
	assert_not_null(gate, "the elemental gate resolves via Sector01.elemental_gate()")
	assert_true(gate is ElementalGate, "the placed gate is the reusable ElementalGate component")
	var eg := gate as ElementalGate
	assert_false(eg.is_open(), "the placed gate starts sealed (blocks the route)")
	assert_true(eg.is_blocking(), "the placed gate physically blocks the spine while sealed")
	# Wrong element keeps it sealed; the configured element opens it persistently.
	var wrong := SpellData.Element.FIRE
	if eg.required_element == wrong:
		wrong = SpellData.Element.ICE
	eg.apply_element(wrong)
	assert_false(eg.is_open(), "the wrong element leaves the placed gate sealed")
	eg.apply_element(eg.required_element)
	assert_true(eg.is_open(), "the configured element opens the placed gate")
	assert_false(eg.is_blocking(), "the opened placed gate no longer blocks the route")


func test_placed_gate_blocker_spans_the_corridor_so_flight_cannot_bypass_it() -> void:
	# TASK-027 review HIGH: the hero has flight from spawn (DD-011 gates no movement
	# verb), so the sealed gate must block the FULL corridor height — a ~200px pillar
	# left a flyable gap and let the player skip the gate. Assert the placed Blocker
	# covers the corridor (ceiling bottom y=-288 -> floor top y=328) leaving only a
	# tiny residual gap (< 60px) above and below, so flight cannot thread past it.
	const CEIL_BOTTOM := -288.0
	const FLOOR_TOP := 328.0
	const MAX_GAP := 60.0
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var gate := (level as Sector01).elemental_gate() as ElementalGate
	assert_not_null(gate, "the elemental gate resolves")
	var shape_node := gate.get_node_or_null("Blocker/Col") as CollisionShape2D
	assert_not_null(shape_node, "the placed gate has a Blocker collision shape")
	var rect := shape_node.shape as RectangleShape2D
	assert_not_null(rect, "the Blocker uses a RectangleShape2D")
	var center_y := shape_node.global_position.y
	var half := rect.size.y * 0.5
	var gap_above: float = (center_y - half) - CEIL_BOTTOM
	var gap_below: float = FLOOR_TOP - (center_y + half)
	assert_lt(gap_above, MAX_GAP,
		"sealed gate leaves < 60px clear above (a flying hero can't fly over it)")
	assert_lt(gap_below, MAX_GAP,
		"sealed gate leaves < 60px clear below (a flying hero can't slip under it)")


func test_anti_magic_zone_instance_resolves_and_suppresses_a_required_route() -> void:
	# TASK-028 (criteria 1/2/3): the placed anti-magic zone is a real AntiMagicZone
	# component that resolves via Sector01.anti_magic_zone(), starts suppressing flight
	# (gating an aerial route on the spine), and is purged persistently by its element.
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var zone := (level as Sector01).anti_magic_zone()
	assert_not_null(zone, "the anti-magic zone resolves via Sector01.anti_magic_zone()")
	assert_true(zone is AntiMagicZone, "the placed zone is the reusable AntiMagicZone component")
	var amz := zone as AntiMagicZone
	assert_true(amz.is_suppressing(), "the placed zone starts suppressing flight (gates the route)")
	# Wrong element keeps it suppressing; the configured element purges it persistently.
	var wrong := SpellData.Element.FIRE
	if amz.purge_element == wrong:
		wrong = SpellData.Element.ICE
	amz.purge(wrong)
	assert_true(amz.is_suppressing(), "the wrong element leaves the placed zone suppressing")
	amz.purge(amz.purge_element)
	assert_false(amz.is_suppressing(), "the configured element purges the placed zone")


func test_anti_magic_route_requires_flight_and_cannot_be_walked_around() -> void:
	# TASK-028 review guard: the gated route must genuinely REQUIRE flight. Inside the
	# zone a vertical barrier rises from the floor higher than the hero's jump apex
	# (~73px above the floor) AND a ceiling-anchored barrier leaves no walkable gap, so
	# a grounded/jumping/dashing hero cannot pass while suppressed — only flight clears
	# it once purged. We assert the in-zone obstruction geometry exists and forces a
	# climb taller than the jump apex.
	const FLOOR_TOP := 328.0
	const JUMP_APEX := 73.0   # |JUMP_VELOCITY|^2 / (2*gravity) ~ 380^2 / (2*980)
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var amz := (level as Sector01).anti_magic_zone() as AntiMagicZone
	assert_not_null(amz, "the anti-magic zone resolves")
	var barrier := amz.get_node_or_null("Barrier/Col") as CollisionShape2D
	assert_not_null(barrier, "the zone has a floor-rooted Barrier the route must clear")
	var rect := barrier.shape as RectangleShape2D
	assert_not_null(rect, "the Barrier uses a RectangleShape2D")
	var top_y := barrier.global_position.y - rect.size.y * 0.5
	# The barrier top must sit higher than the hero's jump apex above the floor, so a
	# grounded jump/dash cannot get over it — flight is required.
	assert_lt(top_y, FLOOR_TOP - JUMP_APEX,
		"the in-zone barrier rises above the jump apex so the route requires flight")


func test_sector_seeds_a_couple_of_enemies_along_the_path() -> void:
	# A light combat presence on the path (criterion: enemies sprinkled along the
	# route). Gates/boss are later tickets; a couple of existing enemies is enough.
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var enemies := get_tree().get_nodes_in_group("enemies")
	assert_gte(enemies.size(), 2,
		"the sector seeds at least two enemies along the traversal path")
