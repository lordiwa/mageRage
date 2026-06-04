## TASK-028 REAL-PHYSICS regression for the anti-magic flight-suppression gate.
##
## The FakePlayer FSM tests (test_anti_magic_zone.gd) are fast guards, but FakePlayer's
## move_and_slide is a no-op, so they cannot catch a "the dropped hero re-jumps / drifts
## over the barrier" bug — only a real CharacterBody2D simulation can. This drives the
## ACTUAL Player into the ACTUAL placed sector_01 zone AT ALTITUDE and asserts:
##   1. While the field is UN-PURGED, an already-flying hero entering high is dropped as a
##      pure FALL and cannot end up past the in-zone barrier (no re-loft, no drift-over).
##   2. After purging the field, the same hero CAN fly up-and-over through the top flight
##      gap and cross the barrier (flight restored).
##
## Per TASK-024: input EDGES are routed through the InputGate seam, so this test (which
## awaits physics frames) cannot poison later input-edge tests. It drives only HELD axis
## input (move_right / move_up) via Input.action_press — the reliable, non-edge path —
## never the poisoned just_pressed edge, and releases it in teardown.
extends GutTest

const SECTOR := preload("res://levels/sector_01.tscn")

# Placed-zone geometry (sector_01.tscn): zone origin (2400,160). The Barrier spans the
# corridor from the floor (world y=328) up to world y=-200, leaving an ~88px FLIGHT-ONLY
# gap at the very top (ceiling bottom y=-288 .. -200). Barrier Col local (40,-96) size
# 48x528 -> world center (2440,64), right edge x=2464.
const BARRIER_RIGHT_X := 2464.0
const ENTRY_X := 2360.0          # just LEFT of the barrier, inside the field
const ENTRY_Y := 60.0            # high up (mid-wall) — the bypass case the review found


func after_each() -> void:
	for a in ["move_right", "move_up"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	InputGate.clear_test_overrides()


# Build the sector, place the hero flying high just left of the barrier, force the
# StateMachine into FlightState, and simulate `frames` physics steps while holding the
# given axis actions. Returns the hero's final/max global x and final state.
func _fly_into_zone(frames: int, purge_first: bool, held: Array) -> Dictionary:
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	var player: Node2D = level.get_node_or_null("Player")
	var sm = player.get_node_or_null("StateMachine")
	var amz = (level as Sector01).anti_magic_zone()
	assert_not_null(player, "the sector has a Player")
	assert_not_null(sm, "the Player has a StateMachine")
	assert_not_null(amz, "the placed anti-magic zone resolves")

	if purge_first:
		amz.purge(SpellData.Element.ELECTRICITY)

	# Place the hero high and just left of the barrier. Seed the suppression flag the way
	# the Field Area2D would on body_entered (set directly so placement is deterministic
	# and independent of overlap frame-order).
	player.global_position = Vector2(ENTRY_X, ENTRY_Y)
	player.velocity = Vector2.ZERO
	player.set_flight_suppressed(not purge_first)

	# Drive the hero into FlightState through the real StateMachine, hold the axis input,
	# and let physics run.
	sm._on_transition_requested(sm.current_state, "FlightState")
	for a in held:
		Input.action_press(a)
	var max_x: float = player.global_position.x
	for _i in range(frames):
		await get_tree().physics_frame
		max_x = maxf(max_x, player.global_position.x)
	for a in held:
		Input.action_release(a)
	return {"final_x": player.global_position.x, "max_x": max_x, "state": sm.current_state.name}


func test_high_entry_hero_cannot_pass_barrier_while_unpurged() -> void:
	# Review HIGH #2: a hero entering the un-purged field AT ALTITUDE (y=60) holding RIGHT
	# must be dropped as a FALL (no upward re-loft, no drift-over) and so cannot clear the
	# full-height barrier's right edge, no matter how many frames it tries.
	var result: Dictionary = await _fly_into_zone(120, false, ["move_right"])
	assert_lt(result["max_x"], BARRIER_RIGHT_X,
		"an un-purged field never lets a high-altitude flier cross the barrier (max x %.1f < %.1f)"
		% [result["max_x"], BARRIER_RIGHT_X])
	assert_ne(result["state"], "FlightState",
		"the hero is not still flying inside the un-purged field")


func test_high_entry_hero_can_pass_barrier_after_purge() -> void:
	# Once purged, the field no longer suppresses: the same hero flies UP-and-RIGHT,
	# threads the top flight gap, and crosses the barrier x. Proves the gate OPENS (the
	# route is genuinely flight-gated, not permanently walled).
	var result: Dictionary = await _fly_into_zone(180, true, ["move_right", "move_up"])
	assert_gt(result["max_x"], BARRIER_RIGHT_X,
		"after purge the flier climbs over and crosses the barrier (max x %.1f > %.1f)"
		% [result["max_x"], BARRIER_RIGHT_X])
