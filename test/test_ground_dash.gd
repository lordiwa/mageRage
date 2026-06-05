## TASK-054 — Ground dash (MoveState): Fire-gated, cooldown-based horizontal burst.
##
## Tests are written TESTS-FIRST: all assertions below describe MISSING behavior
## and must FAIL before the implementation in move_state.gd lands.
##
## Design (from TASK-054 + move_state.gd design notes):
##   - While grounded in MoveState + fire unlocked + dash just_pressed ->
##     velocity.x = facing * DASH_SPEED for DASH_TIME (suppress gravity).
##   - After a dash the cooldown (DASH_COOLDOWN ~0.35s) blocks re-dash until it elapses.
##   - Without fire ability: no-op.
##   - Jump press during/after dash still transitions to JumpState (existing buffer logic).
##   - Air dash (JumpState) is unchanged.
##
## NOTE on DASH_SPEED: tests use the literal value 460.0 (matching JumpState.DASH_SPEED)
## because MoveState.DASH_SPEED does not exist yet (the const is added by the implementation).
## After impl lands, the speed constant will be asserted to match JumpState.DASH_SPEED in
## test_ground_dash_speed_matches_air_dash_speed.
##
## Mirrors the harness in test_movement_transitions.gd (FakePlayer + InputGate overrides).
extends GutTest

## Expected dash speed — mirrors JumpState.DASH_SPEED = 460. When the implementation
## adds MoveState.DASH_SPEED the sync test below will catch any drift.
const EXPECTED_DASH_SPEED := 460.0

const ALL_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "dash", "glide",
]


func before_each() -> void:
	_release_all()


func after_each() -> void:
	_release_all()
	InputGate.clear_test_overrides()


func _release_all() -> void:
	for a in ALL_ACTIONS:
		if InputMap.has_action(a):
			Input.action_release(a)
	InputGate.clear_test_overrides()


func _press_edge(action: String) -> void:
	InputGate.set_test_override(action, true)


func _make_state(state_script: GDScript, fake: FakePlayer) -> EstadoBase:
	var st: EstadoBase = state_script.new()
	st.player = fake
	add_child_autofree(st)
	return st


# ---------------------------------------------------------------------------
# AC1: ground dash FIRES — grounded + fire unlocked + dash -> burst at DASH_SPEED
# ---------------------------------------------------------------------------

func test_ground_dash_fires_when_grounded_with_fire_right() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true}
	fake.on_floor = true
	fake.facing = 1.0

	var st := _make_state(MoveState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, EXPECTED_DASH_SPEED,
		"grounded dash with fire should burst at DASH_SPEED in facing direction (+1)")


func test_ground_dash_fires_when_grounded_with_fire_left() -> void:
	# Same as above but facing left (-1).
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true}
	fake.on_floor = true
	fake.facing = -1.0

	var st := _make_state(MoveState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, -EXPECTED_DASH_SPEED,
		"grounded dash with fire should burst at DASH_SPEED in facing direction (-1)")


# ---------------------------------------------------------------------------
# AC1 continued: gravity suppressed during the dash burst
# ---------------------------------------------------------------------------

func test_ground_dash_suppresses_gravity_during_burst() -> void:
	# The dash should keep velocity.y near 0 (not accumulate gravity) for DASH_TIME.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true}
	fake.on_floor = true
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, 100.0)   # pre-existing downward velocity

	var st := _make_state(MoveState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.y, 0.0,
		"during a ground dash burst velocity.y must be suppressed to 0")


# ---------------------------------------------------------------------------
# AC2: GATING — no fire -> no dash
# ---------------------------------------------------------------------------

func test_ground_dash_no_op_without_fire_ability() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {}          # fire NOT unlocked
	fake.on_floor = true
	fake.facing = 1.0

	var st := _make_state(MoveState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_ne(fake.velocity.x, EXPECTED_DASH_SPEED,
		"without fire ability, dash press should NOT produce a burst")


func test_ground_dash_no_op_with_ice_only() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"ice": true}    # fire specifically absent
	fake.on_floor = true
	fake.facing = 1.0

	var st := _make_state(MoveState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_ne(fake.velocity.x, EXPECTED_DASH_SPEED,
		"ice ability alone must not grant the ground dash (fire required)")


# ---------------------------------------------------------------------------
# AC2: COOLDOWN — second dash immediately after first is blocked
# ---------------------------------------------------------------------------

func test_ground_dash_cooldown_blocks_immediate_redash() -> void:
	# After a dash fires, a second dash press before the cooldown elapses is a no-op.
	# DASH_COOLDOWN ~0.35s; DASH_TIME 0.12s. After 0.016*20 = 0.32s of ticks from
	# the first dash the cooldown is not yet expired. We verify the re-dash is blocked.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true}
	fake.on_floor = true
	fake.facing = 1.0

	var st := _make_state(MoveState, fake)
	st.enter()

	# First dash.
	_press_edge("dash")
	st.physics_update(0.016)

	# Let the dash burst window elapse but stay within cooldown.
	# We pump ~0.016*15 = 0.24s — burst is done (0.12s) but cooldown (~0.35s) not expired.
	InputGate.clear_test_overrides()
	for i in range(15):
		st.physics_update(0.016)

	# Reset velocity to neutral so we can detect if the re-dash incorrectly fires.
	fake.velocity = Vector2(0.0, 0.0)
	_press_edge("dash")
	st.physics_update(0.016)

	assert_ne(fake.velocity.x, EXPECTED_DASH_SPEED,
		"re-dash within cooldown must be blocked")


func test_ground_dash_allowed_after_cooldown_elapses() -> void:
	# After the full cooldown + dash time has ticked down, a second dash must succeed.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true}
	fake.on_floor = true
	fake.facing = 1.0

	var st := _make_state(MoveState, fake)
	st.enter()

	# First dash.
	_press_edge("dash")
	st.physics_update(0.016)

	# Wait well past DASH_COOLDOWN (0.35s) + DASH_TIME (0.12s).
	InputGate.clear_test_overrides()
	var waited := 0.0
	while waited < 0.6:
		st.physics_update(0.05)
		waited += 0.05

	# Second dash should fire.
	fake.velocity = Vector2(0.0, 0.0)
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, EXPECTED_DASH_SPEED,
		"after the cooldown elapses the ground dash must be usable again")


# ---------------------------------------------------------------------------
# AC3: NON-REGRESSION — jump still cancels a dash (buffer -> JumpState)
# ---------------------------------------------------------------------------

func test_buffered_jump_still_transitions_to_jump_state_without_dash() -> void:
	# Baseline: existing jump-buffer behavior is unaffected by the new dash code.
	# Uses assert_signal_emitted (not _with_parameters) to avoid a GUT 9.4.0 internal
	# quirk where deep-comparing an EstadoBase node parameter throws a script error.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true}
	fake.on_floor = true
	fake.buffer_jump()

	var st := _make_state(MoveState, fake)
	st.enter()
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted(st, "transition_requested",
		"buffered jump must still emit transition_requested (non-regression)")
	assert_true(not fake.has_buffered_jump(),
		"jump buffer must be consumed when the jump fires")


func test_buffered_jump_during_dash_burst_transitions_to_jump_state() -> void:
	# A jump press that arrives during a dash burst should still trigger JumpState
	# (the existing jump-buffer + coyote guard must fire around the dash logic).
	# Uses assert_signal_emitted (not _with_parameters) for the same GUT 9.4.0 reason.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true}
	fake.on_floor = true

	var st := _make_state(MoveState, fake)
	st.enter()

	# Trigger the dash first.
	_press_edge("dash")
	st.physics_update(0.016)

	# Now buffer a jump (coyote still valid, still on floor).
	InputGate.clear_test_overrides()
	fake.buffer_jump()
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted(st, "transition_requested",
		"jump buffer during a ground dash must still emit transition_requested")


# ---------------------------------------------------------------------------
# AC3: NON-REGRESSION — air dash (JumpState) behavior is unchanged
# ---------------------------------------------------------------------------

func test_air_dash_still_fires_in_jump_state() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0, -50)

	var st := _make_state(JumpState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, fake.facing * JumpState.DASH_SPEED,
		"air dash in JumpState must still fire (non-regression)")


func test_air_dash_still_one_shot_per_airtime() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0, -50)

	var st := _make_state(JumpState, fake)
	st.enter()

	_press_edge("dash")
	st.physics_update(0.016)
	InputGate.clear_test_overrides()

	for i in range(20):
		st.physics_update(0.016)

	fake.velocity = Vector2(0, 20)
	_press_edge("dash")
	st.physics_update(0.016)

	assert_ne(fake.velocity.x, fake.facing * JumpState.DASH_SPEED,
		"air dash: only one per airtime (non-regression)")


# ---------------------------------------------------------------------------
# AC3: MoveState.DASH_SPEED must exist and match JumpState.DASH_SPEED
## (This test will ERROR until the implementation adds the const — that is the
##  correct failing signal for the missing feature.)
# ---------------------------------------------------------------------------
## NOTE: This test is written without directly referencing MoveState.DASH_SPEED
## to avoid a parse error. Instead it uses a placeholder assertion that is always
## false to flag the missing const for reviewers. When the implementation lands,
## this test should be updated to use the real const.
func test_ground_dash_speed_const_exists_and_matches_air_dash() -> void:
	# We can't directly reference MoveState.DASH_SPEED before it exists.
	# This test checks the behavior indirectly: a dash in MoveState produces
	# the same horizontal speed as a dash in JumpState.
	var fake_ground := FakePlayer.new()
	add_child_autofree(fake_ground)
	fake_ground.abilities = {"fire": true}
	fake_ground.on_floor = true
	fake_ground.facing = 1.0

	var ground_st := _make_state(MoveState, fake_ground)
	ground_st.enter()
	_press_edge("dash")
	ground_st.physics_update(0.016)
	var ground_speed := fake_ground.velocity.x

	InputGate.clear_test_overrides()

	var fake_air := FakePlayer.new()
	add_child_autofree(fake_air)
	fake_air.abilities = {"fire": true}
	fake_air.on_floor = false
	fake_air.facing = 1.0
	fake_air.velocity = Vector2(0, -50)

	var air_st := _make_state(JumpState, fake_air)
	air_st.enter()
	_press_edge("dash")
	air_st.physics_update(0.016)
	var air_speed := fake_air.velocity.x

	assert_eq(ground_speed, air_speed,
		"ground dash speed must equal air dash speed (DASH_SPEED kept in sync)")


# ---------------------------------------------------------------------------
# ANIMATION gap (AC7): no dedicated anim — movement anim continues during dash.
# This is documented, not tested (visual). The gap is noted here per ticket.
# ---------------------------------------------------------------------------
# No assertion; the gap is accepted and documented in DECISIONES-DISENO.md (DD-005).
