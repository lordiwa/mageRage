## TASK-054 — Ground dash (MoveState): Fire-gated, cooldown-based horizontal burst.
## TASK-055 UPDATE: dash constants are now owned by DashComponent; DASH_SPEED=700,
## DASH_TIME=0.16, DASH_COOLDOWN=0.30. FakePlayer instances need a DashComponent child
## added for the states to resolve the dash logic.
##
## Design (from TASK-054 + TASK-055 + move_state.gd design notes):
##   - While grounded in MoveState + fire unlocked + dash just_pressed ->
##     velocity.x = facing * DashComponent.DASH_SPEED for DashComponent.DASH_TIME
##     (suppress gravity). After a dash the cooldown (DashComponent.DASH_COOLDOWN)
##     blocks re-dash. Repeatable after the cooldown elapses.
##   - Without fire ability: no-op.
##   - Jump press during/after dash still transitions to JumpState (existing buffer).
##   - Air dash (JumpState) is now cooldown-repeatable (TASK-055 — see test_unified_dash.gd).
##
## Mirrors the harness in test_movement_transitions.gd (FakePlayer + InputGate overrides).
extends GutTest

## Expected dash speed — matches DashComponent.DASH_SPEED (700) per TASK-055.
const EXPECTED_DASH_SPEED := 700.0

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


## Build a FakePlayer with a DashComponent child, matching the real Player scene
## layout so states can resolve `player.get_node_or_null("DashComponent")`.
func _make_fake_with_dash() -> FakePlayer:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	var dash := DashComponent.new()
	dash.name = "DashComponent"
	fake.add_child(dash)
	return fake


func _make_state(state_script: GDScript, fake: FakePlayer) -> EstadoBase:
	var st: EstadoBase = state_script.new()
	st.player = fake
	add_child_autofree(st)
	return st


# ---------------------------------------------------------------------------
# AC1: ground dash FIRES — grounded + fire unlocked + dash -> burst at DASH_SPEED
# ---------------------------------------------------------------------------

func test_ground_dash_fires_when_grounded_with_fire_right() -> void:
	var fake := _make_fake_with_dash()
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
	var fake := _make_fake_with_dash()
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
	var fake := _make_fake_with_dash()
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
	var fake := _make_fake_with_dash()
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
	var fake := _make_fake_with_dash()
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
	# DASH_COOLDOWN is 0.30s; DASH_TIME is 0.16s. After 0.016*15 = 0.24s from the
	# first dash the burst is done (0.16s) but cooldown (0.30s) is not yet expired.
	var fake := _make_fake_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = true
	fake.facing = 1.0

	var st := _make_state(MoveState, fake)
	st.enter()

	# First dash.
	_press_edge("dash")
	st.physics_update(0.016)

	# Let the dash burst window elapse but stay within cooldown.
	# We pump ~0.016*15 = 0.24s — burst is done (0.16s) but cooldown (~0.30s) not expired.
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
	var fake := _make_fake_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = true
	fake.facing = 1.0

	var st := _make_state(MoveState, fake)
	st.enter()

	# First dash.
	_press_edge("dash")
	st.physics_update(0.016)

	# Wait well past DASH_COOLDOWN (0.30s) + DASH_TIME (0.16s).
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
	var fake := _make_fake_with_dash()
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
	# A jump press that arrives during a dash burst should still trigger JumpState.
	var fake := _make_fake_with_dash()
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
# AC3: NON-REGRESSION — air dash (JumpState) behavior with DashComponent
# ---------------------------------------------------------------------------

func test_air_dash_still_fires_in_jump_state() -> void:
	# TASK-055: JumpState now uses DashComponent; verify the dash still fires at
	# the new DASH_SPEED (700) in the facing direction.
	var fake := _make_fake_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0, -50)

	var st := _make_state(JumpState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, EXPECTED_DASH_SPEED,
		"air dash in JumpState must still fire at the new DASH_SPEED (non-regression)")


func test_air_dash_repeatable_after_cooldown_in_jump_state() -> void:
	# TASK-055: air dash is now REPEATABLE (cooldown-based, not one-per-airtime).
	# After waiting past DASH_COOLDOWN, a second dash must succeed.
	var fake := _make_fake_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0, -50)

	var st := _make_state(JumpState, fake)
	st.enter()

	# First dash.
	_press_edge("dash")
	st.physics_update(0.016)

	# Wait past DASH_COOLDOWN (0.30s).
	InputGate.clear_test_overrides()
	var waited := 0.0
	while waited < 0.50:
		st.physics_update(0.05)
		waited += 0.05

	# Second dash must fire (repeatable via cooldown).
	fake.velocity = Vector2(0, 20)
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, EXPECTED_DASH_SPEED,
		"air dash is now REPEATABLE after DASH_COOLDOWN (TASK-055 replaces one-per-airtime)")


# ---------------------------------------------------------------------------
# AC3: DashComponent has the correct constants (single source of truth)
# ---------------------------------------------------------------------------

func test_dash_component_speed_matches_expected() -> void:
	# AC2: DASH_SPEED lives in DashComponent only; JumpState.DASH_SPEED mirrors it
	# for backwards-compat test references.
	assert_eq(DashComponent.DASH_SPEED, EXPECTED_DASH_SPEED,
		"DashComponent.DASH_SPEED must be 700")
	assert_eq(JumpState.DASH_SPEED, DashComponent.DASH_SPEED,
		"JumpState.DASH_SPEED backward-compat mirror must equal DashComponent.DASH_SPEED")


# ---------------------------------------------------------------------------
# ANIMATION gap (AC7): no dedicated anim — movement anim continues during dash.
# This is documented, not tested (visual). The gap is noted here per ticket.
# ---------------------------------------------------------------------------
# No assertion; the gap is accepted and documented in DECISIONES-DISENO.md (DD-005).
