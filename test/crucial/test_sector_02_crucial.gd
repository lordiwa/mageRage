## CRUCIAL CORE (TASK-049) — sector_02 placed gate/zone + reachability (A/B/C/D).
##
## The 7 reviewer-curated sector_02 guards lifted verbatim from test/test_sector_02.gd
## (which is mostly NON-crucial structure — node-exists / HUD-binding / tileset-paint —
## so the crucial core takes only these methods, NOT the whole file):
##   - the real-physics flying-hero boss reachability test (A — the GUT flake footgun);
##   - the gate blocker spans the corridor + the zone barrier sits above jump apex (B);
##   - the proven flight-safe corridor metrics + monotone spine (C);
##   - gate/zone wrong-element no-op + persistent open/purge (D).
## The after_each releases all held input AND clears InputGate overrides (carried intact)
## so the one await-physics reachability test cannot poison later Input edges. CI runs the
## crucial config 2-3x to catch flake. The full nightly suite still runs all 35 methods
## of test_sector_02.gd under res://test.
extends GutTest

const SECTOR := preload("res://levels/sector_02.tscn")

## Proven corridor metrics (DD-011) — SAME as sector_01.
const CEIL_BOTTOM := -288.0
const FLOOR_TOP := 328.0
const BOUND_EPS := 1.0
## DD-011 flight-bypass guard: the largest clear gap (px) a sealed barrier may leave.
const MAX_GAP := 60.0
## The hero's grounded jump apex above the floor (|JUMP_VELOCITY|^2 / (2*gravity)).
const JUMP_APEX := 73.0

## Retargeted real-physics reachability constants (sector_02.tscn boss approach):
const WALL_RIGHT_X := 3924.0
const REACH_ENTRY_X := 3860.0    # just LEFT of the boss wall, in the corridor
const REACH_ENTRY_Y := -150.0    # high, near the top gap the flier must thread


## Real-physics teardown: release every held axis action AND clear the InputGate test
## overrides so the one await-physics test below cannot poison later input-edge tests.
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


func test_spine_markers_are_monotone_left_to_right() -> void:
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


func test_corridor_uses_the_proven_flight_safe_metrics() -> void:
	# DD-011: keep the SAME proven corridor as sector_01 — ceiling-bottom y=-288,
	# floor-top y=+328.
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


func test_elemental_gate_wrong_element_is_a_noop_fire_opens_persistently() -> void:
	# The wrong element is a no-op (route stays sealed); FIRE opens it PERSISTENTLY.
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
	# DD-011 FLIGHT-BYPASS GUARD: the sealed gate must block the FULL corridor
	# (ceiling bottom y=-288 -> floor top y=+328) leaving only a tiny residual gap.
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
	# DD-011: the in-zone barrier rises above the hero's grounded jump apex (~73px),
	# so only flight (once purged) clears it.
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


func test_flying_hero_reaches_the_boss_room_and_starts_the_encounter() -> void:
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

	player.global_position = Vector2(REACH_ENTRY_X, REACH_ENTRY_Y)
	player.velocity = Vector2.ZERO
	sm._on_transition_requested(sm.current_state, "FlightState")

	# Hold RIGHT throughout; hold UP to thread the top gap, then swap to DOWN to descend
	# INTO the boss room. Flight has no gravity, so an explicit down-axis is required.
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
