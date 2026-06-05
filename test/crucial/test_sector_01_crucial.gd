## CRUCIAL CORE (TASK-049) — sector_01 placed gate/zone guards (groups B/C/D).
##
## The 5 reviewer-curated sector_01 guards lifted verbatim from test/test_sector_01.gd:
##   - connected left-to-right spine (C);
##   - the placed gate blocker spans the corridor so flight cannot bypass it, and the
##     anti-magic route requires flight (B — the M1 flight-bypass regressions);
##   - placed gate/zone element logic resolves + blocks/suppresses persistently (D).
## Each test instances the sector inline (no shared before_each); structure-only, no
## physics-frame await -> no Input-edge flake surface. The full nightly suite still runs
## the rest of test_sector_01.gd under res://test.
extends GutTest

const SECTOR := preload("res://levels/sector_01.tscn")


func test_markers_lie_on_a_connected_left_to_right_path() -> void:
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


func test_elemental_gate_instance_resolves_and_blocks_a_required_route() -> void:
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
	# verb), so the sealed gate must block the FULL corridor height leaving only a tiny
	# residual gap (< 60px) above and below, so flight cannot thread past it.
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
	# TASK-028 review guard: inside the zone a vertical barrier rises from the floor
	# higher than the hero's jump apex (~73px), so a grounded/jumping/dashing hero
	# cannot pass while suppressed — only flight clears it once purged.
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
	assert_lt(top_y, FLOOR_TOP - JUMP_APEX,
		"the in-zone barrier rises above the jump apex so the route requires flight")
