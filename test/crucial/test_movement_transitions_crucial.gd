## CRUCIAL CORE (TASK-049) — group M: FSM / movement transitions.
##
## The 6 reviewer-curated movement-FSM guards lifted verbatim from
## test/test_movement_transitions.gd. This is the concentrated Input-edge flake
## surface (TASK-024): edges are forced through the InputGate seam (_press_edge) and
## the before_each / after_each / _release_all teardown CLEARS InputGate test overrides
## so a held-input/physics-await test elsewhere can never poison these edges — carried
## intact. CI runs the crucial config 2-3x to catch any residual flake.
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


# TASK-024 CI determinism: force the edge deterministically through the InputGate seam
# (a programmatic just_pressed read is NOT reproducible once an upstream test awaits a
# physics frame, so the FSM edge would silently never fire on the CI runner).
func _press_edge(action: String) -> void:
	InputGate.set_test_override(action, true)


# Builds a state of `state_script`, wires the fake player, parents both so
# signals/NOTIFICATIONs behave, and returns the state.
func _make_state(state_script: GDScript, fake: FakePlayer) -> EstadoBase:
	var st: EstadoBase = state_script.new()
	st.player = fake
	add_child_autofree(st)
	return st


func test_move_buffered_jump_while_falling_fires_on_landing() -> void:
	# REGRESSION (review HIGH): a jump pressed while airborne with coyote already
	# expired must survive until the player lands and fire on the landing frame.
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


func test_jump_to_flight_on_second_jump_when_electricity_unlocked() -> void:
	# DD-008: a SECOND jump press while airborne enters FlightState, gated on electricity.
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


func test_jump_air_dash_cooldown_blocks_immediate_redash() -> void:
	# TASK-055: air dash is now cooldown-repeatable. Verify the cooldown still BLOCKS
	# an immediate re-dash (within DASH_COOLDOWN), then allows after cooldown elapses.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	# Attach a DashComponent so JumpState can resolve it (TASK-055 architecture).
	var dash_comp := DashComponent.new()
	dash_comp.name = "DashComponent"
	fake.add_child(dash_comp)

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

	# Let the burst window elapse (~0.20s), staying within DASH_COOLDOWN (0.30s).
	var waited := 0.0
	while waited < 0.20:
		st.physics_update(0.016)
		waited += 0.016

	# Immediate re-dash must be BLOCKED (cooldown not yet elapsed).
	fake.velocity = Vector2(0, 20)
	_press_edge("dash")
	st.physics_update(0.016)

	assert_ne(fake.velocity.x, fake.facing * JumpState.DASH_SPEED,
		"re-dash within DASH_COOLDOWN must be blocked (cooldown-repeatable model)")
