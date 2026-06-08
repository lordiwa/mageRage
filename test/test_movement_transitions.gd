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


# TASK-062: force the edge OFF for the next frame so a held override does not
# re-fire just_pressed() on every physics step. Simulating distinct taps means
# toggling the override true (an edge) then false (no edge) between frames.
func _release_edge(action: String) -> void:
	InputGate.set_test_override(action, false)


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


# --- TASK-062 / TASK-068: grace + release-gated double-tap to stop flying -----
#
# TASK-068 regression: the entry double-jump (and Godot's multi-physics-frame
# just_pressed latch) used to bleed straight into the exit detector and drop the
# hero back to MoveState the instant flight began ("ya no puede volar"). The fix
# adds (1) an ENTRY_GRACE during which jump edges are ignored for exit, and
# (2) release-gating: a tap only counts as a fresh rising edge AFTER the button
# has been observed released since entering flight, so a held/latched press can
# never register as two taps. Helpers below drive BOTH just_pressed and pressed
# (held/release) deterministically through the InputGate seam.


# Force jump's rising EDGE on (just_pressed=true) AND mark it held (pressed=true)
# for this frame — a realistic "button is down" frame.
func _jump_down() -> void:
	InputGate.set_test_override("jump", true)


# Force jump fully UP for this frame: no edge (just_pressed=false) and not held
# (pressed=false). Used to model the release between two deliberate taps.
func _jump_up() -> void:
	InputGate.set_test_override("jump", false)


# Tick FlightState past ENTRY_GRACE with the jump button held UP the whole time,
# so the detector is armed (a release has been observed) and no edge is counted.
func _fly_past_grace(st: EstadoBase) -> void:
	_jump_up()
	var waited := 0.0
	# Comfortably exceed ENTRY_GRACE with the button released.
	while waited < FlightState.ENTRY_GRACE + 0.05:
		st.physics_update(0.016)
		waited += 0.016


# REGRESSION (the actual bug): a jump edge LATCHED on FlightState's first physics
# frames right after entry (the entry double-jump press / Godot multi-frame edge
# latch) must NOT drop the hero. He stays flying.
func test_flight_entry_edge_latch_does_not_exit() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false

	var st := _make_state(FlightState, fake)
	st.enter()
	watch_signals(st)

	# Simulate the entry edge latching true across the first several physics
	# frames within one render frame (the documented just_pressed pitfall).
	_jump_down()
	for i in range(4):
		st.physics_update(0.016)

	assert_signal_not_emitted(st, "transition_requested")


# REGRESSION: a HELD jump (pressed stays true, just_pressed true across frames)
# must NOT count as two taps. A single uninterrupted hold can never exit.
func test_flight_held_jump_is_not_two_taps() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false

	var st := _make_state(FlightState, fake)
	st.enter()
	watch_signals(st)

	# Fly past grace first (released), then hold jump down continuously.
	_fly_past_grace(st)
	_jump_down()
	for i in range(10):                 # held, no release between
		st.physics_update(0.016)

	assert_signal_not_emitted(st, "transition_requested")


# During-grace jump edges are ignored: even a clean tap-release-tap that happens
# entirely WITHIN the grace window must not exit.
func test_flight_during_grace_double_tap_does_not_exit() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false

	var st := _make_state(FlightState, fake)
	st.enter()
	watch_signals(st)

	# Two clean taps very early — well inside ENTRY_GRACE (0.25s).
	_jump_down()
	st.physics_update(0.016)
	_jump_up()
	st.physics_update(0.016)
	_jump_down()
	st.physics_update(0.016)            # ~0.048s, inside grace -> no exit

	assert_signal_not_emitted(st, "transition_requested")


# DELIBERATE exit: after grace, tap (edge) -> release -> tap again within
# DOUBLE_TAP_WINDOW -> drop to MoveState (a pure fall).
func test_flight_deliberate_double_tap_after_grace_exits_to_move() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false

	var st := _make_state(FlightState, fake)
	st.enter()
	watch_signals(st)

	_fly_past_grace(st)

	# First clean tap (edge after release).
	_jump_down()
	st.physics_update(0.016)
	# Release between the taps.
	_jump_up()
	st.physics_update(0.016)            # ~0.032s into the window
	# Second clean tap within DOUBLE_TAP_WINDOW.
	_jump_down()
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "MoveState"])


# NO-RELEASE: two rising edges after grace WITHOUT a release between them must
# NOT exit (release-gating — the second edge is not a fresh press-after-release).
func test_flight_two_edges_without_release_do_not_exit() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false

	var st := _make_state(FlightState, fake)
	st.enter()
	watch_signals(st)

	_fly_past_grace(st)

	# Jump goes down and STAYS down across frames (held). just_pressed may latch
	# true on each frame, but there is no release between, so it is one tap.
	_jump_down()
	st.physics_update(0.016)
	st.physics_update(0.016)            # still held — no release
	st.physics_update(0.016)

	assert_signal_not_emitted(st, "transition_requested")


# WINDOW-EXPIRY: two CLEAN taps (each a fresh press-after-release) separated by
# MORE than DOUBLE_TAP_WINDOW must NOT exit; the first pending tap expires.
func test_flight_two_clean_taps_past_window_do_not_exit() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false

	var st := _make_state(FlightState, fake)
	st.enter()
	watch_signals(st)

	_fly_past_grace(st)

	# First clean tap.
	_jump_down()
	st.physics_update(0.016)
	_jump_up()

	# Let MORE than DOUBLE_TAP_WINDOW (0.30s) elapse with the button released.
	var waited := 0.0
	while waited < 0.40:
		st.physics_update(0.05)
		waited += 0.05

	# Second clean tap now: outside the window -> fresh first tap, no exit.
	_jump_down()
	st.physics_update(0.016)

	assert_signal_not_emitted(st, "transition_requested")


func test_flight_double_tap_window_is_a_named_constant() -> void:
	# The window/threshold must be a named, tunable constant (AC3).
	assert_true(FlightState.DOUBLE_TAP_WINDOW > 0.0,
		"FlightState.DOUBLE_TAP_WINDOW must exist and be a positive tunable constant")


func test_flight_entry_grace_is_a_named_constant() -> void:
	# ENTRY_GRACE must be a named, tunable constant (AC3, TASK-068).
	assert_true(FlightState.ENTRY_GRACE > 0.0,
		"FlightState.ENTRY_GRACE must exist and be a positive tunable constant")


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
