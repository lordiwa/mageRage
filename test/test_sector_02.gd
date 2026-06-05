## TASK-034 (M2 T2) integration test for the second sector greybox spine
## (levels/sector_02.tscn + scripts/levels/sector_02.gd, Sector02).
##
## This is the LAYOUT + controller + parallax-instance half of sector_02 (M2). It
## mirrors test_sector_01.gd's deterministic STRUCTURE style: scene-structure +
## position assertions only, NO physics-frame await, so it is fast and cannot poison
## later input-edge tests (known GUT cross-script flake). The real-physics boss
## reachability test is the NEXT ticket (T3); this ticket drops only the MARKERS /
## boss-approach geometry / parallax instance, not the gate/zone/enemy/boss WIRING.
##
## What it proves:
##   1. the sector instances clean headless and is a Node2D root with a Player;
##   2. the hero is snapped to PlayerSpawn (220,288) on ready (DD: marker wins);
##   3. flight is available at spawn (DD-011 — this ticket gates no movement verb);
##   4. the named spine markers exist and are MONOTONE increasing left -> right
##      (PlayerSpawn < ElementalGate < AntiMagicZone < combat pocket < BossRoom /
##      BossRoomTrigger), so T3 can route spawn -> boss on a single corridor;
##   5. the Enemies container exists (populated in T3);
##   6. the ParallaxBackdrop (T1 component) is instanced under the level and still
##      carries its 3 Parallax2D depth layers;
##   7. the proven corridor metrics are present: ceiling-bottom y=-288 / floor-top
##      y=+328 (the DD-011 flight-bypass-safe height reused from sector_01).
extends GutTest

const SECTOR := preload("res://levels/sector_02.tscn")

## Proven corridor metrics (DD-011) — SAME as sector_01: the full-height ceiling/floor
## bounds that keep M1's reused gate/zone flight-verified. Geometry must reach these.
const CEIL_BOTTOM := -288.0
const FLOOR_TOP := 328.0
const BOUND_EPS := 1.0

## The spawn anchor for this sector's spine.
const SPAWN_X := 220.0
const SPAWN_Y := 288.0


## Instance the sector, parent it (auto-freed), settle one frame so @onready / _ready
## run (player snap to spawn). No physics await — structure only.
func _make_sector() -> Node2D:
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	return level


func test_sector_scene_instances_without_error() -> void:
	var level: Node2D = await _make_sector()
	assert_not_null(level, "sector_02.tscn instantiates")
	assert_true(level is Node2D, "the sector root is a Node2D")
	assert_true(level is Sector02, "the sector root carries the Sector02 controller")
	assert_not_null(level.get_node_or_null("Player"), "the sector has a Player")


func test_player_spawn_marker_resolves_and_player_starts_there() -> void:
	var level: Node2D = await _make_sector()
	var spawn := level.get_node_or_null("PlayerSpawn") as Marker2D
	assert_not_null(spawn, "a PlayerSpawn Marker2D resolves")
	assert_almost_eq(spawn.global_position.x, SPAWN_X, 1.0, "PlayerSpawn is at x=220")
	assert_almost_eq(spawn.global_position.y, SPAWN_Y, 1.0, "PlayerSpawn is at y=288")
	var player := level.get_node_or_null("Player") as Node2D
	assert_not_null(player, "the Player resolves")
	# The hero is snapped at (or essentially at) the spawn marker on ready.
	assert_almost_eq(
		player.global_position.x, spawn.global_position.x, 8.0,
		"the player spawns at the PlayerSpawn marker (x)")
	assert_almost_eq(
		player.global_position.y, spawn.global_position.y, 8.0,
		"the player spawns at the PlayerSpawn marker (y)")


func test_player_starts_with_flight_available() -> void:
	# DD-008 / DD-011: the slice begins post-flight-awakening. This ticket must NOT
	# gate any movement verb — electricity (the flight key) is already unlocked.
	var level: Node2D = await _make_sector()
	var player := level.get_node_or_null("Player")
	assert_not_null(player, "the Player resolves")
	assert_true("abilities" in player, "the player exposes its abilities set")
	assert_true(
		player.abilities.get("electricity", false),
		"flight (electricity) is available from the start — no flight gate in M2")


func test_elemental_gate_marker_exists() -> void:
	# T3 will drop the real ElementalGate instance here; this ticket places the MARKER.
	var level: Node2D = await _make_sector()
	var marker := (level as Sector02).elemental_gate_marker()
	assert_not_null(marker, "an ElementalGate marker resolves via Sector02.elemental_gate_marker()")
	assert_true(marker is Marker2D, "the ElementalGate anchor is a Marker2D positioned in 2D space")


func test_anti_magic_zone_marker_exists() -> void:
	# T3 will drop the real AntiMagicZone instance here; this ticket places the MARKER.
	var level: Node2D = await _make_sector()
	var marker := (level as Sector02).anti_magic_zone_marker()
	assert_not_null(marker, "an AntiMagicZone marker resolves via Sector02.anti_magic_zone_marker()")
	assert_true(marker is Marker2D, "the AntiMagicZone anchor is a Marker2D positioned in 2D space")


func test_boss_room_and_trigger_resolve_via_accessors() -> void:
	# The boss approach is copied from sector_01: a BossRoom region marker plus a
	# Player-masked BossRoomTrigger Area2D. T3 drops the Warden; this ticket lays the
	# geometry so T3's reused reachability test retargets cleanly.
	var level: Node2D = await _make_sector()
	var sector := level as Sector02
	var boss_room := sector.boss_room()
	assert_not_null(boss_room, "a BossRoom region resolves via Sector02.boss_room()")
	assert_true(boss_room is Node2D, "the BossRoom anchor is positioned in 2D space")
	var trigger := sector.boss_room_trigger()
	assert_not_null(trigger, "a BossRoomTrigger resolves via Sector02.boss_room_trigger()")
	assert_true(trigger is Area2D, "the BossRoomTrigger is an Area2D so it can detect the player")
	assert_true(
		(trigger as Area2D).get_collision_mask_value(2),
		"the BossRoomTrigger masks the Player layer (detects the hero entering) as in sector_01")


func test_no_warden_instanced_yet() -> void:
	# Scope guard: the Warden is T3. This LAYOUT ticket must not instance it.
	var level: Node2D = await _make_sector()
	assert_null(level.get_node_or_null("Warden"), "the Warden is NOT instanced yet (that is T3)")


func test_spine_markers_are_monotone_left_to_right() -> void:
	# Connectedness: the spine runs spawn -> elemental gate -> anti-magic zone ->
	# combat pocket -> boss room as a single monotone left-to-right corridor, so T3
	# can path the hero start -> boss. Assert the strict x-ordering of the spine.
	var level: Node2D = await _make_sector()
	var sector := level as Sector02
	var spawn := level.get_node_or_null("PlayerSpawn") as Node2D
	var gate := sector.elemental_gate_marker() as Node2D
	var zone := sector.anti_magic_zone_marker() as Node2D
	var pocket := sector.combat_pocket() as Node2D
	var boss := sector.boss_room_trigger() as Node2D
	assert_not_null(spawn, "PlayerSpawn resolves")
	assert_not_null(gate, "ElementalGate marker resolves")
	assert_not_null(zone, "AntiMagicZone marker resolves")
	assert_not_null(pocket, "combat pocket resolves")
	assert_not_null(boss, "BossRoomTrigger resolves")
	assert_lt(spawn.global_position.x, gate.global_position.x,
		"the elemental gate is downstream of the spawn")
	assert_lt(gate.global_position.x, zone.global_position.x,
		"the anti-magic zone is downstream of the elemental gate")
	assert_lt(zone.global_position.x, pocket.global_position.x,
		"the combat pocket is downstream of the anti-magic zone")
	assert_lt(pocket.global_position.x, boss.global_position.x,
		"the boss room is the far (downstream) end of the spine")


func test_enemies_container_exists_and_is_empty() -> void:
	# T3 populates the combat pocket; this ticket only provides the empty container.
	var level: Node2D = await _make_sector()
	var enemies := level.get_node_or_null("Enemies")
	assert_not_null(enemies, "an Enemies Node2D container exists (populated in T3)")
	assert_true(enemies is Node2D, "the Enemies container is a Node2D")
	assert_eq(enemies.get_child_count(), 0, "the Enemies container is empty (no enemies until T3)")


func test_parallax_backdrop_is_instanced_under_the_level() -> void:
	# The T1 ParallaxBackdrop component is instanced into the level and resolves via
	# Sector02.parallax_backdrop().
	var level: Node2D = await _make_sector()
	var backdrop := (level as Sector02).parallax_backdrop()
	assert_not_null(backdrop, "the ParallaxBackdrop resolves via Sector02.parallax_backdrop()")
	assert_true(backdrop is ParallaxBackdrop, "the instanced backdrop is the T1 ParallaxBackdrop component")


func test_parallax_backdrop_still_has_its_three_layers() -> void:
	# The instanced backdrop keeps its 3 Parallax2D depth layers (the T1 contract).
	var level: Node2D = await _make_sector()
	var backdrop := (level as Sector02).parallax_backdrop() as ParallaxBackdrop
	assert_not_null(backdrop, "the ParallaxBackdrop resolves")
	var layers := backdrop.parallax_layers()
	assert_eq(layers.size(), 3, "the backdrop still has 3 Parallax2D depth layers")
	for layer in layers:
		assert_true(layer is Parallax2D, "each depth layer is a Parallax2D node")


func test_corridor_uses_the_proven_flight_safe_metrics() -> void:
	# DD-011: keep the SAME proven corridor as sector_01 — ceiling-bottom y=-288,
	# floor-top y=+328. Assert the ceiling/floor geometry reaches exactly those bounds
	# so M1's reused full-height gate/zone stays flight-verified at these metrics.
	var level: Node2D = await _make_sector()
	var env := level.get_node_or_null("Environment")
	assert_not_null(env, "the sector has an Environment node holding the geometry")

	var ceiling := env.get_node_or_null("Ceiling") as StaticBody2D
	assert_not_null(ceiling, "the corridor has a Ceiling StaticBody2D")
	var ceil_col := ceiling.get_node_or_null("Col") as CollisionShape2D
	assert_not_null(ceil_col, "the Ceiling has a CollisionShape2D")
	var ceil_rect := ceil_col.shape as RectangleShape2D
	assert_not_null(ceil_rect, "the Ceiling uses a RectangleShape2D")
	var ceil_bottom: float = ceil_col.global_position.y + ceil_rect.size.y * 0.5
	assert_almost_eq(ceil_bottom, CEIL_BOTTOM, BOUND_EPS,
		"the ceiling bottom is at y=-288 (flight-safe corridor top)")

	var floor_body := env.get_node_or_null("Floor") as StaticBody2D
	assert_not_null(floor_body, "the corridor has a Floor StaticBody2D")
	var floor_col := floor_body.get_node_or_null("Col") as CollisionShape2D
	assert_not_null(floor_col, "the Floor has a CollisionShape2D")
	var floor_rect := floor_col.shape as RectangleShape2D
	assert_not_null(floor_rect, "the Floor uses a RectangleShape2D")
	var floor_top: float = floor_col.global_position.y - floor_rect.size.y * 0.5
	assert_almost_eq(floor_top, FLOOR_TOP, BOUND_EPS,
		"the floor top is at y=+328 (flight-safe corridor bottom)")
