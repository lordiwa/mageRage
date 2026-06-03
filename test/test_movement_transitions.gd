## Unit tests for the movement FSM transition RULES (per-state logic), including
## ability gating. States are exercised in isolation with a FakePlayer and
## simulated Input; we watch `transition_requested` to assert routing intent
## without a rendered scene. These encode the TASK-005 acceptance criteria:
##   - Move + jump-from-floor -> Jump
##   - air + glide-held       -> Glide ; release glide -> back to Jump
##   - flight unlocked + fly  -> Flight ; NO electricity + fly -> NOT Flight
##   - land on floor          -> Move
extends GutTest

const ALL_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "dash", "glide", "fly",
]


func before_each() -> void:
	_release_all()


func after_each() -> void:
	_release_all()


func _release_all() -> void:
	for a in ALL_ACTIONS:
		if InputMap.has_action(a):
			Input.action_release(a)


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


# --- JumpState: glide / land ----------------------------------------------

func test_jump_to_glide_when_descending_and_glide_held() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "ice": true}
	fake.on_floor = false
	fake.velocity = Vector2(0, 50)   # already descending

	var st := _make_state(JumpState, fake)
	# Do NOT call enter() (it would reset velocity.y to the jump impulse).
	Input.action_press("glide")
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
	Input.action_press("glide")
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


# --- Ability gating: Flight requires electricity --------------------------

func test_jump_to_flight_when_electricity_unlocked_and_fly_pressed() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "electricity": true}
	fake.on_floor = false
	fake.velocity = Vector2(0, -100)

	var st := _make_state(JumpState, fake)
	Input.action_press("fly")
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "FlightState"])


func test_jump_no_flight_without_electricity_even_if_fly_pressed() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "ice": true}   # NO electricity
	fake.on_floor = false
	fake.velocity = Vector2(0, -100)

	var st := _make_state(JumpState, fake)
	Input.action_press("fly")
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
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "ice": true}   # NO electricity
	fake.on_floor = false
	fake.velocity = Vector2(0, 30)

	var st := _make_state(GlideState, fake)
	Input.action_press("glide")   # stay in glide (don't fall to JumpState)
	Input.action_press("fly")
	watch_signals(st)
	st.physics_update(0.016)

	# fly is gated out; the only allowed transition with glide held is none.
	assert_signal_not_emitted(st, "transition_requested")


func test_glide_to_move_on_landing() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "ice": true}
	fake.on_floor = true
	fake.velocity = Vector2(0, 10)

	var st := _make_state(GlideState, fake)
	Input.action_press("glide")
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "MoveState"])


# --- FlightState: toggle out ----------------------------------------------

func test_flight_back_to_jump_when_fly_pressed_again() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false

	var st := _make_state(FlightState, fake)
	st.enter()
	Input.action_press("fly")
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "JumpState"])
