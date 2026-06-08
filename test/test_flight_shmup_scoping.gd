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
## FlightState transition (the TASK-068 grace + release-gated double-tap exit, landing exit)
## fires exactly as before. Those flag-OFF cases are ALSO covered verbatim in
## test_movement_transitions.gd (unchanged); this file pins the OFF path again next to the ON
## path so the contrast is one file, and adds the ON-path cases the sectors never had.
##
## TASK-068 RECONCILE: master's flight regression fix replaced the raw double-tap detector
## with an ENTRY_GRACE + release-gated DELIBERATE double-tap (tap-release-tap AFTER a brief
## entry grace). The flag-OFF cases below were updated to drive that new path (fly past grace,
## then a clean tap-release-tap) — a raw same-frame double edge no longer exits even with the
## flag off. The flag-ON cases use the SAME deliberate, would-otherwise-exit sequence and
## assert NO exit, proving the shmup guard genuinely suppresses a real exit, not a no-op.
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


# TASK-068: tick FlightState past ENTRY_GRACE with jump held UP the whole time, so the
# exit detector is ARMED (a release has been observed) and no edge is counted. Required
# before any deliberate double-tap can register on the new grace + release-gated detector.
func _fly_past_grace(st: EstadoBase) -> void:
	_release_edge("jump")
	var waited := 0.0
	while waited < FlightState.ENTRY_GRACE + 0.05:
		st.physics_update(0.016)
		waited += 0.016


# --- FakePlayer mirrors the Player shmup_mode flag (default FALSE) ------------

func test_fake_player_defaults_shmup_mode_off() -> void:
	# The shared seam: FakePlayer carries shmup_mode mirroring Player, defaulting FALSE so
	# every existing transition test is byte-identical.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	assert_true("shmup_mode" in fake, "FakePlayer exposes a shmup_mode flag (mirrors Player)")
	assert_false(fake.shmup_mode, "shmup_mode defaults FALSE (sector behavior unchanged)")


# --- Flag OFF (default / the sectors): existing exits STILL fire (byte-identical) ---

func test_flag_off_deliberate_double_tap_still_exits_to_move() -> void:
	# DEFAULT path (sectors): the TASK-068 DELIBERATE double-tap — fly past the entry
	# grace, then a clean tap-release-tap within DOUBLE_TAP_WINDOW — still drops to
	# MoveState (byte-identical to master's flight regression fix).
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false
	# shmup_mode left at its FALSE default.

	var st := _make_flight(fake)
	st.enter()
	watch_signals(st)

	_fly_past_grace(st)

	# First clean tap (edge after release).
	_press_edge("jump")
	st.physics_update(0.016)
	# Release between the taps.
	_release_edge("jump")
	st.physics_update(0.016)
	# Second clean tap within DOUBLE_TAP_WINDOW.
	_press_edge("jump")
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "MoveState"],
		"flag OFF: the TASK-068 deliberate double-tap exit still fires (byte-identical)")


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
	# SHMUP path: the SAME deliberate double-tap that exits with the flag off (fly past
	# grace, then a clean tap-release-tap within DOUBLE_TAP_WINDOW) must NOT drop the hero
	# (no accidental fall off-screen). The hero stays in FlightState — proving the shmup
	# guard suppresses a genuine, would-otherwise-fire exit, not a no-op.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false
	fake.shmup_mode = true

	var st := _make_flight(fake)
	st.enter()
	watch_signals(st)

	_fly_past_grace(st)

	_press_edge("jump")
	st.physics_update(0.016)
	_release_edge("jump")
	st.physics_update(0.016)
	_press_edge("jump")
	st.physics_update(0.016)

	assert_signal_not_emitted(st, "transition_requested",
		"flag ON (shmup): the deliberate double-tap exit is suppressed — the hero stays flying")


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
