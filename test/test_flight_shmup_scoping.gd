## Per-level FlightState scoping tests for the auto-scroll shmup mode (TASK-065, DD-014).
##
## In the shmup level the hero is ALWAYS flying: dropping out of flight = falling off-screen
## = accidental death. So when the per-level flag player.shmup_mode is TRUE, FlightState must
## SUPPRESS both DD-008/TASK-062 flight EXITS — the double-tap-jump exit AND the landing
## (is_on_floor) exit — so the hero stays in FlightState. The DD-011 anti-magic SUSPENSION
## exit is NOT a shmup concern (there are no anti-magic zones in the shmup), but it is left
## untouched for safety and not exercised here.
##
## CRITICAL byte-identical guard: the flag DEFAULTS FALSE, and with it false EVERY existing
## FlightState transition (double-tap exit, single-tap no-exit, landing exit) fires exactly
## as before. Those flag-OFF cases are ALSO covered verbatim in test_movement_transitions.gd
## (unchanged); this file pins the OFF path again next to the ON path so the contrast is one
## file, and adds the ON-path cases the sectors never had.
##
## Edges are forced deterministically through the InputGate seam (TASK-024 flake guard); the
## after_each clears the overrides so they never leak into a later input-edge test.
extends GutTest

const ALL_ACTIONS := ["jump"]


func after_each() -> void:
	for a in ALL_ACTIONS:
		if InputMap.has_action(a):
			Input.action_release(a)
	InputGate.clear_test_overrides()


func _press_edge(action: String) -> void:
	InputGate.set_test_override(action, true)


func _release_edge(action: String) -> void:
	InputGate.set_test_override(action, false)


func _make_flight(fake: FakePlayer) -> FlightState:
	var st := FlightState.new()
	st.player = fake
	add_child_autofree(st)
	return st


# --- FakePlayer mirrors the Player shmup_mode flag (default FALSE) ------------

func test_fake_player_defaults_shmup_mode_off() -> void:
	# The shared seam: FakePlayer carries shmup_mode mirroring Player, defaulting FALSE so
	# every existing transition test is byte-identical.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	assert_true("shmup_mode" in fake, "FakePlayer exposes a shmup_mode flag (mirrors Player)")
	assert_false(fake.shmup_mode, "shmup_mode defaults FALSE (sector behavior unchanged)")


# --- Flag OFF (default / the sectors): existing exits STILL fire (byte-identical) ---

func test_flag_off_double_tap_jump_still_exits_to_move() -> void:
	# DEFAULT path (sectors): two jump edges within the window still drop to MoveState.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false
	# shmup_mode left at its FALSE default.

	var st := _make_flight(fake)
	st.enter()
	watch_signals(st)

	_press_edge("jump")
	st.physics_update(0.016)
	_release_edge("jump")
	st.physics_update(0.016)
	_press_edge("jump")
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "MoveState"],
		"flag OFF: the TASK-062 double-tap exit still fires (byte-identical)")


func test_flag_off_landing_still_exits_to_move() -> void:
	# DEFAULT path (sectors): touching the floor while flying still drops to MoveState.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = true

	var st := _make_flight(fake)
	st.enter()
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "MoveState"],
		"flag OFF: the landing exit still fires (byte-identical)")


# --- Flag ON (shmup): both exits are SUPPRESSED, the hero stays flying -------

func test_flag_on_double_tap_jump_does_not_exit() -> void:
	# SHMUP path: two jump edges within the window must NOT drop the hero (no accidental
	# fall off-screen). The hero stays in FlightState.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false
	fake.shmup_mode = true

	var st := _make_flight(fake)
	st.enter()
	watch_signals(st)

	_press_edge("jump")
	st.physics_update(0.016)
	_release_edge("jump")
	st.physics_update(0.016)
	_press_edge("jump")
	st.physics_update(0.016)

	assert_signal_not_emitted(st, "transition_requested",
		"flag ON (shmup): the double-tap exit is suppressed — the hero stays flying")


func test_flag_on_landing_does_not_exit() -> void:
	# SHMUP path: even is_on_floor() must NOT drop the hero out of flight (the shmup floor,
	# if any, never strands the always-flying hero into platformer movement).
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = true
	fake.shmup_mode = true

	var st := _make_flight(fake)
	st.enter()
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_not_emitted(st, "transition_requested",
		"flag ON (shmup): the landing exit is suppressed — the hero stays flying")
