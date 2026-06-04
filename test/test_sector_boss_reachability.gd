## TASK-029 REAL-PHYSICS reachability test for the end-of-sector boss room.
##
## The deterministic unit tests (test_sector_boss.gd) drive the trigger/defeat wiring
## directly. This complements them by proving the boss room is genuinely REACHABLE in
## the connected sector geometry: a flying hero, placed just LEFT of the BossWallLeft,
## threads the ~98px FLIGHT-ONLY top gap over the wall, descends into the boss room, and
## crosses into the real BossRoomTrigger Area2D — which fires its body_entered and starts
## the Warden encounter through the ACTUAL Sector01 handler (no hand-emitted signal).
##
## Suite-safe per TASK-024/-028: it awaits physics frames using HELD-AXIS input only
## (move_right / move_up via Input.action_press) — never the poisoned just_pressed edge —
## and releases the held actions + clears the InputGate overrides in teardown, so it
## cannot poison later input-edge tests.
extends GutTest

const SECTOR := preload("res://levels/sector_01.tscn")

# Placed geometry (sector_01.tscn): BossWallLeft at (3300,70), 48x520 -> top y=-190,
# right edge x=3324. The ceiling bottom is y=-288, leaving a ~98px flight-only gap above
# the wall. The BossRoomTrigger sits at (3600,80) spanning 520x600 -> left edge x=3340.
const WALL_RIGHT_X := 3324.0
const ENTRY_X := 3260.0          # just LEFT of the wall, in the corridor
const ENTRY_Y := -150.0          # high, near the top gap the flier must thread


func after_each() -> void:
	for a in ["move_right", "move_up", "move_down"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	InputGate.clear_test_overrides()


func test_flying_hero_reaches_the_boss_room_and_starts_the_encounter() -> void:
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var sector := level as Sector01
	var player: Node2D = level.get_node_or_null("Player")
	var sm = player.get_node_or_null("StateMachine")
	assert_not_null(player, "the sector has a Player")
	assert_not_null(sm, "the Player has a StateMachine")
	assert_false(sector.is_encounter_started(), "the encounter is not started before traversal")

	# Place the flier high, just left of the boss wall, and drive it into FlightState
	# through the real StateMachine. Flight is available from the start (DD-011), and the
	# boss room is past the anti-magic zone, so no suppression applies here.
	player.global_position = Vector2(ENTRY_X, ENTRY_Y)
	player.velocity = Vector2.ZERO
	sm._on_transition_requested(sm.current_state, "FlightState")

	# Hold RIGHT throughout; hold UP to thread the top gap over the wall, then swap to
	# DOWN to descend INTO the boss room (and the trigger's y-span) instead of skimming
	# the ceiling above it. Flight has no gravity, so an explicit down-axis is required.
	Input.action_press("move_right")
	Input.action_press("move_up")
	var max_x: float = player.global_position.x
	for i in range(360):
		await get_tree().physics_frame
		# Once past the wall, dive: release UP and hold DOWN so the flier drops into the
		# boss room's vertical band where the trigger detects it.
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
