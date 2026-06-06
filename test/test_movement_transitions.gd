## Unit tests for the movement FSM transition RULES (per-state logic), including
## ability gating. States are exercised in isolation with a FakePlayer and
## simulated Input; we watch `transition_requested` to assert routing intent
## without a rendered scene. These encode the TASK-005 acceptance criteria:
##   - Move + jump-from-floor -> Jump
##   - air + glide-held       -> Glide ; release glide -> back to Jump
##   - DD-008: SECOND jump in air (electricity) -> Flight (double-jump);
##     NO electricity + second jump -> NOT Flight (no dedicated `fly` action)
##   - land on floor          -> Move
extends GutTest

const ALL_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "dash", "glide",
]


func before_each() -> void:
	_release_all()


func after_each() -> void:
	_release_all()
	# Drop any InputGate edge overrides so they never leak into another test/the game.
	InputGate.clear_test_overrides()


func _release_all() -> void:
	for a in ALL_ACTIONS:
		if InputMap.has_action(a):
			Input.action_release(a)
	InputGate.clear_test_overrides()


# A HELD action (e.g. glide): Input.is_action_pressed() reflects the held state
# reliably across frames, so a plain press is deterministic here.
func _hold(action: String) -> void:
	Input.action_press(action)


# TASK-024 CI determinism: an EDGE-triggered action (jump/dash) is gated in the FSM
# via InputGate.just_pressed(), which in game delegates to
# Input.is_action_just_pressed(). That engine edge is NOT reproducible from GUT once
# an upstream test awaits a physics frame (the physics-frame counter advances past
# the programmatic press stamp, so the read is false for the rest of the run) -> the
# flight/dash transition silently never fires ("Signals emitted: []"), green locally
# but RED on the slower CI runner. We force the edge deterministically instead.
func _press_edge(action: String) -> void:
	InputGate.set_test_override(action, true)


# Builds a state of `state_script`, wires the fake player, parents both so
# signals/NOTIFICATIONs behave, and returns [state, captured_target_holder].
func _make_state(state_script: GDScript, fake: FakePlayer) -> EstadoBase:
	var st: EstadoBase = state_script.new()
	st.player = fake
	add_child_autofree(st)
	return st


# --- MoveState: jump from floor -------------------------------------------

func test_move_to_jump_on_buffered_jump_from_floor() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true}
	fake.on_floor = true
	fake.buffer_jump()

	var st := _make_state(MoveState, fake)
	st.enter()                      # seeds coyote time
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "JumpState"])


func test_move_no_jump_without_fire_ability() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {}             # fire NOT unlocked
	fake.on_floor = true
	fake.buffer_jump()

	var st := _make_state(MoveState, fake)
	st.enter()
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_not_emitted(st, "transition_requested")


func test_move_buffered_jump_while_falling_fires_on_landing() -> void:
	# REGRESSION (review HIGH): a jump pressed while airborne with coyote already
	# expired must survive until the player lands and fire on the landing frame.
	# The old guard consumed the buffer every frame before checking coyote, so
	# the buffered press was discarded mid-air and never fired on touchdown.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true}

	var st := _make_state(MoveState, fake)
	st.enter()                       # seeds coyote

	# Player walks off a ledge: airborne, coyote expires.
	fake.on_floor = false
	for i in range(20):              # ~0.32s, well past COYOTE_TIME 0.10s
		st.physics_update(0.05)

	# Press jump while still falling (buffered, coyote already 0).
	fake.buffer_jump()
	st.physics_update(0.016)         # mid-air frame: must NOT discard the buffer

	# Now land.
	fake.on_floor = true
	watch_signals(st)
	st.physics_update(0.016)         # landing frame: buffered jump should fire

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "JumpState"])
	assert_true(fake.has_buffered_jump() == false,
		"buffer should be consumed exactly when the jump fires")


# --- JumpState: glide / land ----------------------------------------------

func test_jump_to_glide_when_descending_and_glide_held() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "ice": true}
	fake.on_floor = false
	fake.velocity = Vector2(0, 50)   # already descending

	var st := _make_state(JumpState, fake)
	# Do NOT call enter() (it would reset velocity.y to the jump impulse).
	_hold("glide")
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "GlideState"])


func test_jump_no_glide_without_ice_ability() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true}  # ice NOT unlocked
	fake.on_floor = false
	fake.velocity = Vector2(0, 50)

	var st := _make_state(JumpState, fake)
	_hold("glide")
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_not_emitted(st, "transition_requested")


func test_jump_to_move_on_landing() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true}
	fake.on_floor = true             # touched down
	fake.velocity = Vector2(0, 10)

	var st := _make_state(JumpState, fake)
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "MoveState"])


# --- DD-008 double-jump: second jump in air -> Flight (electricity-gated) ---

func test_jump_to_flight_on_second_jump_when_electricity_unlocked() -> void:
	# DD-008: there is no dedicated `fly` action. A SECOND jump press while
	# airborne (the first jump already registered) enters FlightState, gated on
	# electricity.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "electricity": true}
	fake.on_floor = false
	fake.velocity = Vector2(0, -100)
	fake.jump_count = 1            # the first (ground) jump already fired

	var st := _make_state(JumpState, fake)
	_press_edge("jump")
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "FlightState"])


func test_jump_no_flight_on_second_jump_without_electricity() -> void:
	# A double-jump without electricity does nothing: no second jump, no flight.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "ice": true}   # NO electricity
	fake.on_floor = false
	fake.velocity = Vector2(0, -100)
	fake.jump_count = 1

	var st := _make_state(JumpState, fake)
	_press_edge("jump")
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_not_emitted(st, "transition_requested")


func test_jump_first_air_jump_press_does_not_fly() -> void:
	# Guard the gate: a jump press in the air when no jump has registered yet
	# (jump_count 0) must NOT enter flight — only the genuine SECOND jump does.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "electricity": true}
	fake.on_floor = false
	fake.velocity = Vector2(0, -100)
	fake.jump_count = 0            # no ground jump registered

	var st := _make_state(JumpState, fake)
	_press_edge("jump")
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_not_emitted(st, "transition_requested")


# --- GlideState: release glide / fly / land -------------------------------

func test_glide_back_to_jump_when_glide_released() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "ice": true}
	fake.on_floor = false
	fake.velocity = Vector2(0, 30)

	var st := _make_state(GlideState, fake)
	# glide NOT held (released in before_each)
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "JumpState"])


func test_glide_to_flight_requires_electricity() -> void:
	# DD-008: a second jump in air promotes to flight, gated on electricity.
	# Without electricity, the jump press while gliding does nothing.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "ice": true}   # NO electricity
	fake.on_floor = false
	fake.velocity = Vector2(0, 30)
	fake.jump_count = 1

	var st := _make_state(GlideState, fake)
	_hold("glide")   # stay in glide (don't fall to JumpState)
	_press_edge("jump")
	watch_signals(st)
	st.physics_update(0.016)

	# jump->flight is gated out; the only allowed transition with glide held is none.
	assert_signal_not_emitted(st, "transition_requested")


func test_glide_to_flight_on_second_jump_with_electricity() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "ice": true, "electricity": true}
	fake.on_floor = false
	fake.velocity = Vector2(0, 30)
	fake.jump_count = 1

	var st := _make_state(GlideState, fake)
	_hold("glide")
	_press_edge("jump")
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "FlightState"])


func test_glide_to_move_on_landing() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "ice": true}
	fake.on_floor = true
	fake.velocity = Vector2(0, 10)

	var st := _make_state(GlideState, fake)
	_hold("glide")
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "MoveState"])


# --- FlightState: exit on landing (DD-008: no toggle-out) ------------------

func test_flight_to_move_when_on_floor() -> void:
	# Landing while flying should drop to MoveState, not re-launch via Jump.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = true

	var st := _make_state(FlightState, fake)
	st.enter()
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "MoveState"])


# --- JumpState: launch impulse ---------------------------------------------

func test_jump_enter_applies_launch_impulse() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.velocity = Vector2(0, 0)

	var st := _make_state(JumpState, fake)
	st.enter()

	assert_eq(fake.velocity.y, JumpState.JUMP_VELOCITY,
		"a real jump entry should apply the launch impulse")


# --- DD-008: jump bookkeeping (register on launch, reset on landing) --------

func test_jump_enter_registers_a_jump() -> void:
	# The first leap registers as jump #1 so a subsequent air press is the
	# genuine double-jump.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.jump_count = 0

	var st := _make_state(JumpState, fake)
	st.enter()

	assert_eq(fake.jump_count, 1,
		"entering JumpState (a real leap) registers a jump")


func test_move_resets_jump_count_on_floor() -> void:
	# Landing resets the jump count so the next airtime starts fresh.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true}
	fake.on_floor = true
	fake.jump_count = 2

	var st := _make_state(MoveState, fake)
	st.enter()
	st.physics_update(0.016)

	assert_eq(fake.jump_count, 0,
		"being grounded resets the double-jump counter")


# --- JumpState: air dash (AC5, TASK-055 updated) ---------------------------
# TASK-055: JumpState now uses DashComponent for the dash. FakePlayer needs a
# DashComponent child so the state can resolve it. DASH_SPEED is now 700.

func _make_fake_with_dash() -> FakePlayer:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	var dash := DashComponent.new()
	dash.name = "DashComponent"
	fake.add_child(dash)
	return fake


func test_jump_air_dash_bursts_in_facing_direction() -> void:
	var fake := _make_fake_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0, -50)

	var st := _make_state(JumpState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, fake.facing * JumpState.DASH_SPEED,
		"air dash should burst horizontally in the facing direction (DASH_SPEED=700)")


func test_jump_air_dash_repeatable_after_cooldown() -> void:
	# TASK-055: air dash is now REPEATABLE after DASH_COOLDOWN (replaces one-per-airtime).
	# After waiting past the cooldown, a second dash must succeed.
	var fake := _make_fake_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0, -50)

	var st := _make_state(JumpState, fake)
	st.enter()

	# First dash fires.
	_press_edge("dash")
	st.physics_update(0.016)
	InputGate.clear_test_overrides()

	# Wait past DASH_COOLDOWN (0.30s).
	var waited := 0.0
	while waited < 0.50:
		st.physics_update(0.05)
		waited += 0.05

	# Second dash must succeed (cooldown elapsed).
	fake.velocity = Vector2(0, 20)
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, fake.facing * JumpState.DASH_SPEED,
		"air dash is now REPEATABLE after DASH_COOLDOWN (TASK-055 replaces one-per-airtime)")
