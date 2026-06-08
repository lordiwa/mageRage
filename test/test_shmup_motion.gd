## TASK-069 unit tests for ShmupMotion (scripts/levels/shmup_motion.gd) — the PURE,
## frame-free per-tick motion math for the shmup enemy stream.
##
## DD-014 / human design-lock (this session): each streamed enemy ENTERS on its assigned
## pattern for a brief ENTRY_LOCK_DELAY, then LOCKS ON and steers toward the player's LIVE
## position while still drifting left with the frame. Four data-driven movement patterns:
##   STRAIGHT  — flat leftward drift (baseline / pacing rest);
##   SINE      — oscillate y around a center while advancing left;
##   HOMING    — lock-on dominant: steer toward the player's live position;
##   DIVE      — arc in fast, swoop toward the player once, then peel away.
##
## EVERYTHING here is DETERMINISTIC + FRAME-FREE: we call the static next_position() /
## predicates DIRECTLY with explicit elapsed/delta/player args. NO real frames, NO real
## drone .tscn, NO scroller — exactly the ticket's "drive the pattern fns directly" mandate.
extends GutTest

const ShmupMotionScript := preload("res://scripts/levels/shmup_motion.gd")


## Build a fresh per-enemy motion state for `pattern` spawned at `spawn` with center y at the
## spawn's y (the spawner seeds center_y from the wave's y-pattern). Mirrors the record the
## spawner attaches per enemy.
func _state(pattern: int, spawn: Vector2) -> Dictionary:
	return {
		"pattern": pattern,
		"spawn": spawn,
		"center_y": spawn.y,
		"elapsed": 0.0,
	}


## Advance `state` `steps` ticks of `delta` from `pos` toward `player`, returning the final
## position. Mirrors how the spawner drives next_position() each update tick (it also bumps
## state.elapsed). Pure: no node, no frame.
func _drive(state: Dictionary, pos: Vector2, player: Vector2, delta: float, steps: int) -> Vector2:
	var p := pos
	for _i in range(steps):
		p = ShmupMotion.next_position(state, p, player, delta)
		state["elapsed"] += delta
	return p


# --- The pattern enum + entry-lock tunable exist -----------------------------

func test_motion_pattern_enum_has_all_four_patterns() -> void:
	# All four human-locked patterns are first-class enum values (data-driven per wave).
	assert_true("STRAIGHT" in ShmupMotion.MotionPattern,
		"STRAIGHT pattern exists")
	assert_true("SINE" in ShmupMotion.MotionPattern,
		"SINE pattern exists")
	assert_true("HOMING" in ShmupMotion.MotionPattern,
		"HOMING pattern exists")
	assert_true("DIVE" in ShmupMotion.MotionPattern,
		"DIVE pattern exists")


func test_entry_lock_delay_is_a_short_positive_beat() -> void:
	# A brief read-the-armor beat before lock-on (~0.5s, telegraph-before-threat, DD-001).
	assert_gt(ShmupMotion.ENTRY_LOCK_DELAY, 0.0,
		"ENTRY_LOCK_DELAY is a positive beat")
	assert_lt(ShmupMotion.ENTRY_LOCK_DELAY, 1.5,
		"ENTRY_LOCK_DELAY is a SHORT beat (sub-second-ish), not a long stall")


# --- (a) per-pattern motion --------------------------------------------------

func test_straight_is_monotone_left_constant_y() -> void:
	var player := Vector2(0.0, 300.0)   # player well to the LEFT and below
	var state := _state(ShmupMotion.MotionPattern.STRAIGHT, Vector2(1000.0, 100.0))
	var pos := Vector2(1000.0, 100.0)
	var last_x := pos.x
	for _i in range(20):
		pos = ShmupMotion.next_position(state, pos, player, 0.05)
		state["elapsed"] += 0.05
		assert_lt(pos.x, last_x, "STRAIGHT x decreases every tick (monotone leftward)")
		last_x = pos.x
	# STRAIGHT NEVER chases: y is unchanged even though the player is far below.
	assert_almost_eq(pos.y, 100.0, 0.001,
		"STRAIGHT keeps a constant y (flat drift, no steering)")


func test_sine_oscillates_y_around_the_center_while_x_decreases() -> void:
	var player := Vector2(0.0, 100.0)
	var state := _state(ShmupMotion.MotionPattern.SINE, Vector2(1000.0, 300.0))
	var pos := Vector2(1000.0, 300.0)
	var min_y := pos.y
	var max_y := pos.y
	var start_x := pos.x
	for _i in range(80):   # ~4s — at least a full sine period
		pos = ShmupMotion.next_position(state, pos, player, 0.05)
		state["elapsed"] += 0.05
		min_y = minf(min_y, pos.y)
		max_y = maxf(max_y, pos.y)
	# y swings to BOTH sides of the center (an actual oscillation, not a one-way drift).
	assert_lt(min_y, 300.0 - 1.0, "SINE dips BELOW the center y")
	assert_gt(max_y, 300.0 + 1.0, "SINE rises ABOVE the center y")
	# It still advances left over the run.
	assert_lt(pos.x, start_x, "SINE still advances leftward while it weaves")


func test_homing_position_moves_toward_the_player_over_ticks() -> void:
	# Player parked OFF to one side (above) so a homing enemy must CLOSE the y gap.
	var player := Vector2(400.0, 80.0)
	var state := _state(ShmupMotion.MotionPattern.HOMING, Vector2(1000.0, 500.0))
	var pos := Vector2(1000.0, 500.0)
	var start_gap := pos.distance_to(player)
	# Drive past the entry-lock beat so the homing actually steers.
	pos = _drive(state, pos, player, 0.05, 60)   # 3s
	var end_gap := pos.distance_to(player)
	assert_lt(end_gap, start_gap,
		"HOMING closes the distance to the live player position over successive ticks")


func test_dive_arcs_toward_the_player_then_peels_away() -> void:
	# A dive swoops toward the player ONCE then peels away: the gap shrinks to a minimum
	# mid-arc, then GROWS again as it peels — not a monotone approach (that'd be homing).
	var player := Vector2(400.0, 300.0)
	var state := _state(ShmupMotion.MotionPattern.DIVE, Vector2(1000.0, 100.0))
	var pos := Vector2(1000.0, 100.0)
	var min_gap := pos.distance_to(player)
	var min_at := 0
	var gaps: Array = []
	for i in range(120):   # ~6s — long enough to swoop in AND peel away
		pos = ShmupMotion.next_position(state, pos, player, 0.05)
		state["elapsed"] += 0.05
		var g := pos.distance_to(player)
		gaps.append(g)
		if g < min_gap:
			min_gap = g
			min_at = i
	# It got CLOSER than it started (it swooped in).
	assert_lt(min_gap, pos.distance_to(Vector2(1000.0, 100.0)),
		"DIVE swoops toward the player (gap shrinks below the start)")
	# The closest approach is NOT the final tick — it peeled away afterwards.
	assert_lt(min_at, gaps.size() - 1,
		"DIVE reaches its closest approach mid-arc, not at the end")
	# After the closest approach the gap GROWS again (the peel-away).
	assert_gt(gaps[gaps.size() - 1], min_gap,
		"DIVE peels away after the swoop (final gap > closest-approach gap)")


# --- (b) enter-then-lock-on timing (non-tautological) ------------------------

func test_homing_does_not_steer_before_the_entry_lock_delay() -> void:
	# Player parked ABOVE; during the entry beat the enemy must follow its entry slide
	# (leftward drift) and NOT yet close the y gap toward the player.
	var player := Vector2(400.0, 80.0)
	var state := _state(ShmupMotion.MotionPattern.HOMING, Vector2(1000.0, 500.0))
	var pos := Vector2(1000.0, 500.0)
	var delta := 0.05
	# Drive ONLY up to (just under) the entry-lock delay.
	var steps := int(floor(ShmupMotion.ENTRY_LOCK_DELAY / delta)) - 1
	steps = maxi(steps, 1)
	var y_before := pos.y
	pos = _drive(state, pos, player, delta, steps)
	# It advanced LEFT (entry slide) but did NOT yet move its y toward the player.
	assert_lt(pos.x, 1000.0, "during entry the homing enemy still slides in (x decreases)")
	assert_almost_eq(pos.y, y_before, 0.5,
		"BEFORE ENTRY_LOCK_DELAY the homing enemy does NOT steer at the player (y unchanged)")


func test_homing_steers_at_the_live_player_only_after_the_delay() -> void:
	# Same enemy/player, but driven PAST the entry-lock delay: now the y gap must close.
	var player := Vector2(400.0, 80.0)
	var state := _state(ShmupMotion.MotionPattern.HOMING, Vector2(1000.0, 500.0))
	var pos := Vector2(1000.0, 500.0)
	var delta := 0.05
	# Phase 1: entry only (y should not move toward the player).
	var entry_steps := int(floor(ShmupMotion.ENTRY_LOCK_DELAY / delta)) - 1
	entry_steps = maxi(entry_steps, 1)
	pos = _drive(state, pos, player, delta, entry_steps)
	var y_at_lock := pos.y
	# Phase 2: past the lock — now drive on and the y gap to the player must shrink.
	pos = _drive(state, pos, player, delta, 40)
	assert_lt(absf(pos.y - player.y), absf(y_at_lock - player.y),
		"AFTER ENTRY_LOCK_DELAY the enemy steers toward the LIVE player (closes the y gap)")


func test_lock_on_tracks_the_LIVE_player_position_not_a_cached_one() -> void:
	# Non-tautological: move the player MID-RUN after lock-on; the enemy must redirect
	# toward the NEW position (lock-on reads the live arg each tick, not a spawn snapshot).
	var state := _state(ShmupMotion.MotionPattern.HOMING, Vector2(1000.0, 300.0))
	var pos := Vector2(1000.0, 300.0)
	var delta := 0.05
	# Get past the entry beat with the player ABOVE.
	var player_a := Vector2(500.0, 50.0)
	pos = _drive(state, pos, player_a, delta, int(ShmupMotion.ENTRY_LOCK_DELAY / delta) + 10)
	# Now teleport the live player WAY BELOW and keep driving; the enemy must turn DOWNWARD.
	var player_b := Vector2(500.0, 580.0)
	var y_turn := pos.y
	pos = _drive(state, pos, player_b, delta, 30)
	assert_gt(pos.y, y_turn,
		"lock-on follows the LIVE player: when the player jumps down, the enemy turns down")
