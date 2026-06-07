## Sector 02 integration tests (levels/sector_02.tscn + scripts/levels/sector_02.gd,
## Sector02). Two halves:
##
## T2 (TASK-034) — the LAYOUT + controller + parallax-instance STRUCTURE half. Mirrors
## test_sector_01.gd's deterministic style: scene-structure + position assertions only,
## NO physics-frame await, so it is fast and cannot poison later input-edge tests.
##
## T3 (TASK-035) — the GAMEPLAY-WIRING half added on top: the real FIRE ElementalGate,
## the ELECTRICITY AntiMagicZone, 3 mixed-armor enemies, the dormant Warden + HUDs, and
## the encounter/victory signal wiring (copied verbatim from sector_01). It also adds the
## ONE real-physics held-input reachability test (the GUT flake footgun) which drives a
## flier over the retargeted sector_02 boss wall and asserts the encounter starts — its
## after_each releases all held input AND clears InputGate overrides so it cannot poison
## later input-edge tests.
##
## What it proves (T2 structure):
##   1. the sector instances clean headless and is a Node2D root with a Player;
##   2. the hero is snapped to PlayerSpawn (220,288) on ready (DD: marker wins);
##   3. flight is available at spawn (DD-011 — this ticket gates no movement verb);
##   4. the named spine anchors are MONOTONE increasing left -> right
##      (PlayerSpawn < ElementalGate < AntiMagicZone < combat pocket < BossRoom /
##      BossRoomTrigger), so the hero can route spawn -> boss on a single corridor;
##   5. the ParallaxBackdrop (T1 component) is instanced with its 3 Parallax2D layers;
##   6. the proven corridor metrics are present: ceiling-bottom y=-288 / floor-top
##      y=+328 (the DD-011 flight-bypass-safe height reused from sector_01).
extends GutTest

const SECTOR := preload("res://levels/sector_02.tscn")

## Proven corridor metrics (DD-011) — SAME as sector_01: the full-height ceiling/floor
## bounds that keep M1's reused gate/zone flight-verified. Geometry must reach these.
const CEIL_BOTTOM := -288.0
const FLOOR_TOP := 328.0
const BOUND_EPS := 1.0
## DD-011 flight-bypass guard: the largest clear gap (px) a sealed barrier may leave at
## the top/bottom of the corridor before a flying hero could thread past it.
const MAX_GAP := 60.0
## The hero's grounded jump apex above the floor (|JUMP_VELOCITY|^2 / (2*gravity)).
const JUMP_APEX := 73.0

## The spawn anchor for this sector's spine.
const SPAWN_X := 220.0
const SPAWN_Y := 288.0

## Retargeted real-physics reachability constants (sector_02.tscn boss approach):
## BossWallLeft at (3900,70), shape 48x520 -> top y=70-260=-190 (a ~98px flight-only gap
## to the ceiling bottom y=-288), right edge x=3900+24=3924. BossRoomTrigger at (4200,80),
## shape 520x600 -> left edge x=4200-260=3940. So the flier enters just LEFT of the wall.
const WALL_RIGHT_X := 3924.0
const REACH_ENTRY_X := 3860.0    # just LEFT of the boss wall, in the corridor
const REACH_ENTRY_Y := -150.0    # high, near the top gap the flier must thread


## T3 real-physics teardown: release every held axis action AND clear the InputGate test
## overrides so the one await-physics test below cannot poison later input-edge tests
## (mirrors test_sector_boss_reachability.gd / test_anti_magic_zone_physics.gd exactly).
func after_each() -> void:
	for a in ["move_right", "move_up", "move_down"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	InputGate.clear_test_overrides()


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


func test_elemental_gate_anchor_resolves() -> void:
	# T3 drops the real ElementalGate instance at this anchor; it still resolves via the
	# Sector02.elemental_gate_marker() accessor (now an ElementalGate, not a bare Marker2D)
	# and stays positioned downstream of the spawn on the spine.
	var level: Node2D = await _make_sector()
	var anchor := (level as Sector02).elemental_gate_marker()
	assert_not_null(anchor, "an ElementalGate anchor resolves via Sector02.elemental_gate_marker()")
	assert_true(anchor is Node2D, "the ElementalGate anchor is positioned in 2D space")


func test_anti_magic_zone_anchor_resolves() -> void:
	# T3 drops the real AntiMagicZone instance at this anchor; it still resolves via the
	# Sector02.anti_magic_zone_marker() accessor (now an AntiMagicZone, not a bare Marker2D).
	var level: Node2D = await _make_sector()
	var anchor := (level as Sector02).anti_magic_zone_marker()
	assert_not_null(anchor, "an AntiMagicZone anchor resolves via Sector02.anti_magic_zone_marker()")
	assert_true(anchor is Node2D, "the AntiMagicZone anchor is positioned in 2D space")


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


func test_warden_is_instanced_dormant_in_the_boss_room() -> void:
	# T3: the reused DD-010 Warden is instanced as the sector boss, DORMANT at load so it
	# does not chase/fire across the whole corridor while the hero traverses the gates.
	var level: Node2D = await _make_sector()
	var boss := (level as Sector02).warden()
	assert_not_null(boss, "the Warden resolves via Sector02.warden()")
	assert_true(boss is Warden, "the placed boss is the reusable DD-010 Warden component")
	assert_true((boss as Warden).is_dormant(), "the Warden starts dormant (instanced inactive)")


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


func test_enemies_container_exists_and_is_populated() -> void:
	# T3 seeds the combat presence: the Enemies container now holds the mixed-armor
	# enemies (the empty-container T2 assertion is superseded here).
	var level: Node2D = await _make_sector()
	var enemies := level.get_node_or_null("Enemies")
	assert_not_null(enemies, "an Enemies Node2D container exists")
	assert_true(enemies is Node2D, "the Enemies container is a Node2D")
	assert_gt(enemies.get_child_count(), 0, "the Enemies container is populated (T3 seeds enemies)")


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


# --- City visual skin = solid slate SLABS (structure-only, no physics) -------
# The greybox surfaces are skinned by CityTiles — now a Node2D of solid slate Sprite2D
# SLABS (one per collision footprint) after the slab rewrite replaced the old City
# TileMapLayer (whose transparent-topped cap tile + 64px grid snap left the hero floating
# and the ledges as tall towers). Per-surface slab-top seating is pinned in
# test_sector_02_visual_bounds.gd. VISUAL ONLY: no collision/physics assertion here — the
# corridor-span, gate/zone-blocker and boss-reachability tests remain the collision truth.

func test_city_visual_skin_is_present() -> void:
	var level: Node2D = await _make_sector()
	var env := level.get_node_or_null("Environment")
	assert_not_null(env, "the sector has an Environment node holding the geometry")
	var tiles := env.get_node_or_null("CityTiles")
	assert_not_null(tiles, "the City visual skin (CityTiles) skins the geometry under Environment")
	if tiles == null:
		return
	var slabs := 0
	for child in tiles.get_children():
		if child is Sprite2D:
			slabs += 1
	assert_gt(slabs, 0,
		"the City skin is painted with solid slate slabs (surfaces skinned, not bare greybox)")


# ============================================================================
# T3 (TASK-035) GAMEPLAY WIRING — FIRE gate, ELEC zone, mixed-armor enemies,
# dormant Warden + HUDs, encounter/victory signals, and the ONE real-physics
# held-input reachability test (the flake footgun, retargeted to sector_02).
# ============================================================================


# --- FIRE ElementalGate (DD-003 red / BURN; mirror test_elemental_gate.gd) ---

func test_elemental_gate_is_the_fire_gate_and_starts_sealed() -> void:
	# DD-003: a FIRE gate (red, auto-derives the BURN fiction). It starts sealed and
	# physically blocks the spine the hero must cross toward the boss.
	var level: Node2D = await _make_sector()
	var gate := (level as Sector02).elemental_gate() as ElementalGate
	assert_not_null(gate, "the elemental gate resolves via Sector02.elemental_gate()")
	assert_true(gate is ElementalGate, "the placed gate is the reusable ElementalGate component")
	assert_eq(gate.required_element, SpellData.Element.FIRE,
		"the sector_02 gate keys on FIRE (DD-003 red)")
	assert_eq(gate.interaction, ElementalGate.Interaction.BURN,
		"a FIRE gate auto-derives the BURN fiction")
	assert_false(gate.is_open(), "the placed gate starts sealed")
	assert_true(gate.is_blocking(), "the placed gate physically blocks the spine while sealed")


func test_elemental_gate_wrong_element_is_a_noop_fire_opens_persistently() -> void:
	# The wrong element is a no-op (route stays sealed); FIRE opens it PERSISTENTLY (a
	# later wrong element cannot re-seal it).
	var level: Node2D = await _make_sector()
	var gate := (level as Sector02).elemental_gate() as ElementalGate
	gate.apply_element(SpellData.Element.ICE)
	assert_false(gate.is_open(), "the wrong element (Ice) leaves the FIRE gate sealed")
	gate.apply_element(SpellData.Element.ELECTRICITY)
	assert_false(gate.is_open(), "the wrong element (Electricity) leaves the FIRE gate sealed")
	gate.apply_element(SpellData.Element.FIRE)
	assert_true(gate.is_open(), "FIRE opens the gate")
	assert_false(gate.is_blocking(), "the opened gate no longer blocks the route")
	gate.apply_element(SpellData.Element.ICE)
	assert_true(gate.is_open(), "the open state persists; a later wrong element cannot re-seal it")


func test_gate_blocker_spans_the_corridor_so_flight_cannot_bypass_it() -> void:
	# DD-011 FLIGHT-BYPASS GUARD (the whole point of this ticket): the hero flies from
	# spawn, so the sealed gate must block the FULL corridor (ceiling bottom y=-288 ->
	# floor top y=+328) leaving only a tiny residual gap (< 60px) above and below. Proven
	# at the gate's ACTUAL placed world position (no bespoke barrier — the reused M1 gate
	# at the reused corridor metrics).
	var level: Node2D = await _make_sector()
	var gate := (level as Sector02).elemental_gate() as ElementalGate
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
		"the sealed gate leaves < 60px clear above (a flying hero can't fly over it)")
	assert_lt(gap_below, MAX_GAP,
		"the sealed gate leaves < 60px clear below (a flying hero can't slip under it)")


# --- ELECTRICITY AntiMagicZone (DD-008 flight verb; mirror the zone tests) ---

func test_anti_magic_zone_is_the_electricity_zone_and_suppresses_flight() -> void:
	# DD-008: flight is the Electricity verb, so the anti-flight dampener is purged by
	# ELECTRICITY (yellow, DD-003). It starts suppressing flight (gates the aerial route).
	var level: Node2D = await _make_sector()
	var zone := (level as Sector02).anti_magic_zone() as AntiMagicZone
	assert_not_null(zone, "the anti-magic zone resolves via Sector02.anti_magic_zone()")
	assert_true(zone is AntiMagicZone, "the placed zone is the reusable AntiMagicZone component")
	assert_eq(zone.purge_element, SpellData.Element.ELECTRICITY,
		"the sector_02 zone is purged by ELECTRICITY (DD-008 flight verb / DD-003 yellow)")
	assert_true(zone.is_suppressing(), "the placed zone starts suppressing flight")


func test_anti_magic_zone_wrong_element_noop_electricity_purges_persistently() -> void:
	# The wrong element is a no-op; ELECTRICITY purges it persistently.
	var level: Node2D = await _make_sector()
	var zone := (level as Sector02).anti_magic_zone() as AntiMagicZone
	zone.purge(SpellData.Element.FIRE)
	assert_true(zone.is_suppressing(), "the wrong element (Fire) leaves the zone suppressing")
	zone.purge(SpellData.Element.ICE)
	assert_true(zone.is_suppressing(), "the wrong element (Ice) leaves the zone suppressing")
	zone.purge(SpellData.Element.ELECTRICITY)
	assert_false(zone.is_suppressing(), "ELECTRICITY purges the zone")
	zone.purge(SpellData.Element.FIRE)
	assert_false(zone.is_suppressing(), "the purge persists; a later wrong element cannot re-arm it")


func test_zone_barrier_sits_above_jump_apex_so_route_requires_flight() -> void:
	# DD-011: the in-zone barrier rises above the hero's grounded jump apex (~73px above
	# the floor), so a grounded/jumping/dashing hero can't clear it — only flight (once
	# purged) does. Proven at the zone's ACTUAL placed world position.
	var level: Node2D = await _make_sector()
	var zone := (level as Sector02).anti_magic_zone() as AntiMagicZone
	assert_not_null(zone, "the anti-magic zone resolves")
	var barrier := zone.get_node_or_null("Barrier/Col") as CollisionShape2D
	assert_not_null(barrier, "the zone has a floor-rooted Barrier the route must clear")
	var rect := barrier.shape as RectangleShape2D
	assert_not_null(rect, "the Barrier uses a RectangleShape2D")
	var top_y := barrier.global_position.y - rect.size.y * 0.5
	assert_lt(top_y, FLOOR_TOP - JUMP_APEX,
		"the in-zone barrier rises above the jump apex so the route requires flight")


# --- Boss wiring (mirror test_sector_boss.gd; deterministic, no physics walk) -

func test_boss_room_trigger_is_a_player_masked_area() -> void:
	var level: Node2D = await _make_sector()
	var trigger := (level as Sector02).boss_room_trigger()
	assert_not_null(trigger, "the BossRoomTrigger resolves")
	assert_true(trigger is Area2D, "the BossRoomTrigger is an Area2D so it can detect the player")
	assert_true((trigger as Area2D).get_collision_mask_value(2),
		"the BossRoomTrigger masks the Player layer (detects the hero entering)")


func test_entering_the_trigger_starts_the_encounter_and_activates_the_warden() -> void:
	# Mirror sector_01: a player body entering the trigger starts the encounter and wakes
	# the dormant Warden — through the ACTUAL Sector02 handler (no hand-emitted signal).
	var level: Node2D = await _make_sector()
	var sector := level as Sector02
	var boss := sector.warden() as Warden
	assert_false(sector.is_encounter_started(), "the encounter has not started yet")
	sector.boss_room_trigger().body_entered.emit(level.get_node("Player"))
	assert_true(sector.is_encounter_started(),
		"a body entering the boss-room trigger starts the Warden encounter")
	assert_false(boss.is_dormant(), "starting the encounter wakes the Warden")


func test_boss_bar_is_hidden_while_the_warden_is_dormant() -> void:
	# TASK-030: the Warden HP bar must NOT clutter the screen before the fight. While the
	# placed Warden is still dormant (un-triggered) the bar (track + fill + label) is hidden.
	var level: Node2D = await _make_sector()
	var hud := level.get_node_or_null("BossHUD")
	assert_not_null(hud, "the BossHUD resolves")
	var fill := hud.get_node_or_null("BarFill") as ColorRect
	var track := hud.get_node_or_null("BarTrack") as ColorRect
	var label := hud.get_node_or_null("BarLabel") as Label
	assert_true((level as Sector02).warden().is_dormant(), "the Warden starts dormant")
	assert_false(fill.visible, "the boss bar fill is hidden before the encounter (TASK-030)")
	assert_false(track.visible, "the boss bar track is hidden before the encounter")
	assert_false(label.visible, "the boss bar label is hidden before the encounter")


func test_boss_bar_shows_once_the_warden_is_activated() -> void:
	# TASK-030: starting the encounter (waking the Warden) reveals the HP bar.
	var level: Node2D = await _make_sector()
	var hud := level.get_node_or_null("BossHUD")
	var fill := hud.get_node_or_null("BarFill") as ColorRect
	var label := hud.get_node_or_null("BarLabel") as Label
	((level as Sector02).warden() as Warden).activate()
	hud._refresh()
	assert_true(fill.visible, "the boss bar fill appears once the Warden is activated (TASK-030)")
	assert_true(label.visible, "the boss bar label appears once the Warden is activated")


func test_sector_victory_fires_when_the_warden_is_defeated() -> void:
	# Mirror sector_01: defeating the Warden (its DD-010 `defeated` signal) latches the
	# SECTOR victory state and emits `sector_victory`.
	var level: Node2D = await _make_sector()
	var sector := level as Sector02
	watch_signals(sector)
	assert_false(sector.is_victory(), "the sector starts before victory")
	(sector.warden() as Warden).defeated.emit()
	assert_true(sector.is_victory(),
		"defeating the Warden sets the SECTOR victory state")
	assert_signal_emitted(sector, "sector_victory",
		"the sector emits `sector_victory` when the Warden is defeated")


func test_player_respawns_at_the_sector_spawn() -> void:
	# DD-009: death mid-run respawns the hero at the SECTOR spawn (PlayerSpawn), matching
	# sector_01's path (_ready records the spawn at the marker).
	var level: Node2D = await _make_sector()
	var spawn := level.get_node("PlayerSpawn") as Marker2D
	var player := level.get_node("Player")
	player.global_position = Vector2(REACH_ENTRY_X, REACH_ENTRY_Y)
	player.respawn()
	assert_almost_eq(player.global_position.x, spawn.global_position.x, 8.0,
		"the hero respawns at the SECTOR spawn x (DD-009)")
	assert_almost_eq(player.global_position.y, spawn.global_position.y, 8.0,
		"the hero respawns at the SECTOR spawn y (DD-009)")


func test_boss_hud_is_present_and_bound_to_the_warden() -> void:
	# Reuse the DD-010 BossHUD exactly as sector_01: it resolves and binds to the placed
	# Warden so HP / phase read on screen.
	var level: Node2D = await _make_sector()
	var hud := level.get_node_or_null("BossHUD")
	assert_not_null(hud, "the sector reuses the DD-010 BossHUD")
	assert_eq(hud.get("boss_path"), NodePath("../Warden"),
		"the boss HUD is bound to the placed Warden node")
	assert_not_null((level as Sector02).warden(), "the bound Warden resolves")


func test_debug_hud_is_present_and_bound_to_the_player() -> void:
	# Reuse the DebugHUD exactly as sector_01, re-pointed at this sector's Player.
	var level: Node2D = await _make_sector()
	var hud := level.get_node_or_null("DebugHUD")
	assert_not_null(hud, "the sector reuses the DebugHUD")
	assert_eq(hud.get("player_path"), NodePath("../Player"),
		"the debug HUD is bound to the sector's Player")


# --- TASK-039 loadout + trigger HUD in the PLAYABLE sector -------------------
# The whole point of TASK-039: while PLAYING sector_02 (the main_scene) the hero
# must see WHICH TRIGGER fires WHICH element. The reusable scenes/player_hud.tscn
# (loadout swatches/labels + the RT/LT trigger Labels) is instanced into the
# sector and bound to THIS sector's Player + MagicManager so it reads the live
# loadout. Deterministic structure-style (no physics await), autofreed.

## The default loadout from scenes/player.tscn's MagicManager.spells:
## [firebolt(FIRE), ice_shard(ICE), lightning(ELEC)] -> primary FIRE, secondary ICE.
const _DEFAULT_PRIMARY_EL := SpellData.Element.FIRE
const _DEFAULT_SECONDARY_EL := SpellData.Element.ICE


## Resolve the instanced loadout HUD (the reusable scenes/player_hud.tscn) under the
## sector. Instanced as a direct child "PlayerHUD" CanvasLayer running player_hud.gd.
func _loadout_hud(level: Node2D) -> PlayerHUD:
	return level.get_node_or_null("PlayerHUD") as PlayerHUD


func test_loadout_hud_is_instanced_in_sector_02() -> void:
	# The reusable loadout HUD scene resolves under the playable sector and runs the
	# PlayerHUD script (so the loadout/trigger read appears IN-GAME, not just test_level).
	var level: Node2D = await _make_sector()
	var hud := _loadout_hud(level)
	assert_not_null(hud, "scenes/player_hud.tscn is instanced into sector_02 as PlayerHUD")
	assert_true(hud is PlayerHUD, "the instanced loadout HUD runs the PlayerHUD script")


func test_loadout_hud_is_bound_to_this_sectors_player_and_manager() -> void:
	# The HUD must read THIS sector's Player + MagicManager (the live loadout), wired via
	# the relative NodePaths preset on the instance (../Player, ../Player/MagicManager).
	var level: Node2D = await _make_sector()
	var hud := _loadout_hud(level)
	assert_not_null(hud, "the loadout HUD resolves")
	assert_eq(hud.get("player_path"), NodePath("../Player"),
		"the loadout HUD is bound to the sector's Player")
	assert_eq(hud.get("magic_manager_path"), NodePath("../Player/MagicManager"),
		"the loadout HUD is bound to the sector's MagicManager (live loadout)")
	assert_not_null(level.get_node_or_null("Player/MagicManager"),
		"the bound MagicManager resolves under the sector's Player")


func test_loadout_hud_has_trigger_labels_bound_to_the_right_slots() -> void:
	# The RT/LT trigger glyphs appear in-game: PRIMARY = RT, SECONDARY = LT.
	var level: Node2D = await _make_sector()
	var hud := _loadout_hud(level)
	assert_not_null(hud, "the loadout HUD resolves")
	var primary_trigger := hud.get_node_or_null("PrimaryTrigger") as Label
	var secondary_trigger := hud.get_node_or_null("SecondaryTrigger") as Label
	assert_not_null(primary_trigger, "the HUD contains a PrimaryTrigger Label")
	assert_not_null(secondary_trigger, "the HUD contains a SecondaryTrigger Label")
	assert_eq(primary_trigger.text, PlayerHUD.PRIMARY_TRIGGER,
		"the primary trigger reads RT (which trigger fires the primary slot)")
	assert_eq(secondary_trigger.text, PlayerHUD.SECONDARY_TRIGGER,
		"the secondary trigger reads LT (which trigger fires the secondary slot)")


func test_loadout_hud_element_names_reflect_the_sector_loadout() -> void:
	# The element NAMES read the sector's live default loadout (FIRE primary, ICE secondary).
	var level: Node2D = await _make_sector()
	var hud := _loadout_hud(level)
	assert_not_null(hud, "the loadout HUD resolves")
	var primary_label := hud.get_node_or_null("PrimaryLabel") as Label
	var secondary_label := hud.get_node_or_null("SecondaryLabel") as Label
	assert_not_null(primary_label, "the HUD contains a PrimaryLabel")
	assert_not_null(secondary_label, "the HUD contains a SecondaryLabel")
	assert_eq(primary_label.text, PlayerHUD.element_label(_DEFAULT_PRIMARY_EL),
		"the primary element name reflects the sector loadout (FIRE)")
	assert_eq(secondary_label.text, PlayerHUD.element_label(_DEFAULT_SECONDARY_EL),
		"the secondary element name reflects the sector loadout (ICE)")


func test_loadout_hud_swatch_colors_use_projectile_style_for_the_sector_loadout() -> void:
	# Colors come from the single source of truth (ProjectileStyle), matching the live
	# default loadout. The swatches AND the element-tinted trigger glyphs both read it.
	var level: Node2D = await _make_sector()
	var hud := _loadout_hud(level)
	assert_not_null(hud, "the loadout HUD resolves")
	var primary_swatch := hud.get_node_or_null("PrimarySwatch") as ColorRect
	var secondary_swatch := hud.get_node_or_null("SecondarySwatch") as ColorRect
	assert_not_null(primary_swatch, "the HUD contains a PrimarySwatch")
	assert_not_null(secondary_swatch, "the HUD contains a SecondarySwatch")
	assert_eq(primary_swatch.color,
		ProjectileStyle.for_element(_DEFAULT_PRIMARY_EL)["color"],
		"the primary swatch is the ProjectileStyle Fire color (sector loadout)")
	assert_eq(secondary_swatch.color,
		ProjectileStyle.for_element(_DEFAULT_SECONDARY_EL)["color"],
		"the secondary swatch is the ProjectileStyle Ice color (sector loadout)")


# --- Mixed-armor enemy presence (DD-006) -------------------------------------

func test_three_plus_enemies_in_group_with_mixed_armor() -> void:
	# DD-006: at least 3 enemies in the "enemies" group with MIXED armor_type, so the
	# combat presence tests the element-vs-armor RPS rather than one canned matchup.
	var level: Node2D = await _make_sector()
	assert_not_null(level, "the sector instances")
	var seeded := get_tree().get_nodes_in_group("enemies")
	# Filter to the placed combat enemies (the Warden is also in "enemies"; the seeded
	# combat enemies live under the Enemies container).
	var combat: Array = []
	for e in seeded:
		if e is Node and (e as Node).get_parent() != null and (e as Node).get_parent().name == "Enemies":
			combat.append(e)
	assert_gte(combat.size(), 3,
		"the sector seeds at least 3 combat enemies in the 'enemies' group")
	var armors := {}
	for e in combat:
		assert_true("armor_type" in e, "each combat enemy exposes an armor_type (DD-006)")
		armors[e.armor_type] = true
	assert_gte(armors.size(), 2,
		"the seeded enemies use MIXED armor_type (more than one element of armor)")


# --- THE real-physics reachability test (retargeted; the GUT flake footgun) ---

func test_flying_hero_reaches_the_boss_room_and_starts_the_encounter() -> void:
	# COPY of test_sector_boss_reachability.gd, retargeted to sector_02's boss wall.
	# A flying hero placed just LEFT of BossWallLeft threads the ~98px flight-only top gap
	# over the wall, dives into the boss room, and crosses the REAL BossRoomTrigger Area2D
	# — which starts the Warden encounter through the ACTUAL Sector02 handler. Driven with
	# HELD-AXIS input ONLY (never *_just_pressed). after_each releases input + clears the
	# InputGate overrides so it cannot poison later input-edge tests.
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var sector := level as Sector02
	var player: Node2D = level.get_node_or_null("Player")
	var sm = player.get_node_or_null("StateMachine")
	assert_not_null(player, "the sector has a Player")
	assert_not_null(sm, "the Player has a StateMachine")
	assert_false(sector.is_encounter_started(), "the encounter is not started before traversal")

	# Place the flier high, just left of the boss wall, and drive it into FlightState
	# through the real StateMachine. The boss room is past the anti-magic zone, so no
	# suppression applies here (DD-011: flight is available).
	player.global_position = Vector2(REACH_ENTRY_X, REACH_ENTRY_Y)
	player.velocity = Vector2.ZERO
	sm._on_transition_requested(sm.current_state, "FlightState")

	# Hold RIGHT throughout; hold UP to thread the top gap, then swap to DOWN to descend
	# INTO the boss room (and the trigger's y-span). Flight has no gravity, so an explicit
	# down-axis is required.
	Input.action_press("move_right")
	Input.action_press("move_up")
	var max_x: float = player.global_position.x
	for i in range(360):
		await get_tree().physics_frame
		if i == 50:
			Input.action_release("move_up")
			Input.action_press("move_down")
		max_x = maxf(max_x, player.global_position.x)
		if sector.is_encounter_started():
			break
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")

	assert_gt(max_x, WALL_RIGHT_X,
		"the flier threads the top gap and clears the boss wall (max x %.1f > %.1f)"
		% [max_x, WALL_RIGHT_X])
	assert_true(sector.is_encounter_started(),
		"reaching the boss room (entering the real trigger) starts the Warden encounter")
	assert_false((sector.warden() as Warden).is_dormant(),
		"the Warden wakes once the hero physically reaches the boss room")
