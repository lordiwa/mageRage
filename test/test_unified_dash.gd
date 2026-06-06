## TASK-055 — Unified repeatable dash (MoveState/JumpState/GlideState/FlightState).
##
## TESTS-FIRST: all assertions encode MISSING behavior and must FAIL before the
## implementation in dash_component.gd + state updates land.
##
## Design (from TASK-055):
##   - A single DashComponent node owns DASH_SPEED=700, DASH_TIME=0.16, DASH_COOLDOWN=0.30
##     and the burst+cooldown timers. All four states delegate to it.
##   - Burst: velocity.x = facing * DASH_SPEED; velocity.y = 0.0 (no altitude gain).
##   - Gravity suppressed for DASH_TIME; then state's normal control resumes.
##   - Repeatable everywhere via DASH_COOLDOWN (replaces JumpState's one-per-airtime).
##   - Fire-gated; InputGate.just_pressed("dash") seam.
##   - AIR dash (off floor) is SUPPRESSED while player.is_flight_suppressed() (anti-magic
##     zone); GROUND dash (on floor) is unaffected.
##   - Cooldown is SHARED (a dash in any state blocks re-dash until it elapses).
##
## Mirrors the harness in test_movement_transitions.gd / test_ground_dash.gd.
extends GutTest

## Tuning values from TASK-055 ticket. Must match DashComponent constants.
const DASH_SPEED := 700.0
const DASH_TIME  := 0.16
const DASH_COOLDOWN := 0.30

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


## Build a FakePlayer with a DashComponent child attached, so states can call
## player.get_node_or_null("DashComponent"). The DashComponent is fresh (zero timers).
func _make_fake_player_with_dash() -> FakePlayer:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	var dash_comp := DashComponent.new()
	dash_comp.name = "DashComponent"
	fake.add_child(dash_comp)
	return fake


func _make_state(state_script: GDScript, fake: FakePlayer) -> EstadoBase:
	var st: EstadoBase = state_script.new()
	st.player = fake
	add_child_autofree(st)
	return st


# ---------------------------------------------------------------------------
# TUNING: new constants live in ONE place (DashComponent)
# ---------------------------------------------------------------------------

func test_dash_component_constants_are_correct() -> void:
	# AC2: constants live in one shared place with the new tuning values.
	assert_eq(DashComponent.DASH_SPEED, DASH_SPEED,
		"DashComponent.DASH_SPEED must be 700")
	assert_eq(DashComponent.DASH_TIME, DASH_TIME,
		"DashComponent.DASH_TIME must be 0.16")
	assert_eq(DashComponent.DASH_COOLDOWN, DASH_COOLDOWN,
		"DashComponent.DASH_COOLDOWN must be 0.30")


# ---------------------------------------------------------------------------
# AC1: GROUND dash (MoveState) — fires + repeats after cooldown
# ---------------------------------------------------------------------------

func test_move_state_dash_fires_right() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = true
	fake.facing = 1.0

	var st := _make_state(MoveState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, DASH_SPEED,
		"MoveState ground dash should burst at DASH_SPEED=700 facing right")


func test_move_state_dash_fires_left() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = true
	fake.facing = -1.0

	var st := _make_state(MoveState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, -DASH_SPEED,
		"MoveState ground dash should burst at -DASH_SPEED=700 facing left")


func test_move_state_dash_suppresses_vertical() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = true
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, 150.0)

	var st := _make_state(MoveState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.y, 0.0,
		"ground dash must zero velocity.y (no altitude gain)")


func test_move_state_dash_repeats_after_cooldown() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = true
	fake.facing = 1.0

	var st := _make_state(MoveState, fake)
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

	# Second dash must fire.
	fake.velocity = Vector2.ZERO
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, DASH_SPEED,
		"MoveState dash must be repeatable after cooldown elapses")


# ---------------------------------------------------------------------------
# AC1: JUMP air dash — fires + repeats (cooldown-based, NOT one-per-airtime)
# ---------------------------------------------------------------------------

func test_jump_state_dash_fires_right() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, -50.0)

	var st := _make_state(JumpState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, DASH_SPEED,
		"JumpState air dash should burst at DASH_SPEED=700 facing right")


func test_jump_state_dash_fires_left() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = false
	fake.facing = -1.0
	fake.velocity = Vector2(0.0, -50.0)

	var st := _make_state(JumpState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, -DASH_SPEED,
		"JumpState air dash should burst at -DASH_SPEED=700 facing left")


func test_jump_state_dash_suppresses_vertical() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, 100.0)

	var st := _make_state(JumpState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.y, 0.0,
		"JumpState air dash must zero velocity.y (no altitude gain)")


func test_jump_state_dash_repeats_after_cooldown() -> void:
	# AC1: air dash is now cooldown-based, NOT one-per-airtime.
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, -50.0)

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

	# Second dash must fire (was previously blocked by one-per-airtime).
	fake.velocity = Vector2(0.0, 20.0)
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, DASH_SPEED,
		"JumpState dash must be REPEATABLE after cooldown (replace one-per-airtime)")


# ---------------------------------------------------------------------------
# AC1: GLIDE dash — fires + repeats after cooldown
# ---------------------------------------------------------------------------

func test_glide_state_dash_fires_right() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true, "ice": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, 30.0)  # descending (glide-typical)

	var st := _make_state(GlideState, fake)
	# Hold glide so we don't immediately exit to JumpState.
	Input.action_press("glide")
	_press_edge("dash")
	st.physics_update(0.016)
	Input.action_release("glide")

	assert_eq(fake.velocity.x, DASH_SPEED,
		"GlideState dash should burst at DASH_SPEED=700 facing right")


func test_glide_state_dash_fires_left() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true, "ice": true}
	fake.on_floor = false
	fake.facing = -1.0
	fake.velocity = Vector2(0.0, 30.0)

	var st := _make_state(GlideState, fake)
	Input.action_press("glide")
	_press_edge("dash")
	st.physics_update(0.016)
	Input.action_release("glide")

	assert_eq(fake.velocity.x, -DASH_SPEED,
		"GlideState dash should burst at -DASH_SPEED=700 facing left")


func test_glide_state_dash_suppresses_vertical() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true, "ice": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, 80.0)  # descending

	var st := _make_state(GlideState, fake)
	Input.action_press("glide")
	_press_edge("dash")
	st.physics_update(0.016)
	Input.action_release("glide")

	assert_eq(fake.velocity.y, 0.0,
		"GlideState dash must zero velocity.y (no altitude gain)")


func test_glide_state_dash_repeats_after_cooldown() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true, "ice": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, 30.0)

	var st := _make_state(GlideState, fake)

	# First dash.
	Input.action_press("glide")
	_press_edge("dash")
	st.physics_update(0.016)
	InputGate.clear_test_overrides()

	# Wait past DASH_COOLDOWN.
	var waited := 0.0
	while waited < 0.50:
		st.physics_update(0.05)
		waited += 0.05

	# Second dash must fire.
	fake.velocity = Vector2(0.0, 30.0)
	_press_edge("dash")
	st.physics_update(0.016)
	Input.action_release("glide")

	assert_eq(fake.velocity.x, DASH_SPEED,
		"GlideState dash must be repeatable after cooldown")


# ---------------------------------------------------------------------------
# AC1: FLIGHT dash — fires + repeats after cooldown
# ---------------------------------------------------------------------------

func test_flight_state_dash_fires_right() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true, "electricity": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake._flight_suppressed = false

	var st := _make_state(FlightState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, DASH_SPEED,
		"FlightState dash should burst at DASH_SPEED=700 facing right")


func test_flight_state_dash_fires_left() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true, "electricity": true}
	fake.on_floor = false
	fake.facing = -1.0
	fake._flight_suppressed = false

	var st := _make_state(FlightState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, -DASH_SPEED,
		"FlightState dash should burst at -DASH_SPEED=700 facing left")


func test_flight_state_dash_suppresses_vertical() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true, "electricity": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, 50.0)
	fake._flight_suppressed = false

	var st := _make_state(FlightState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.y, 0.0,
		"FlightState dash must zero velocity.y (no altitude gain)")


func test_flight_state_dash_repeats_after_cooldown() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true, "electricity": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake._flight_suppressed = false

	var st := _make_state(FlightState, fake)
	st.enter()

	# First dash.
	_press_edge("dash")
	st.physics_update(0.016)

	# Wait past DASH_COOLDOWN.
	InputGate.clear_test_overrides()
	var waited := 0.0
	while waited < 0.50:
		st.physics_update(0.05)
		waited += 0.05

	# Second dash must fire.
	fake.velocity = Vector2.ZERO
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, DASH_SPEED,
		"FlightState dash must be repeatable after cooldown")


# ---------------------------------------------------------------------------
# AC2: COOLDOWN blocks immediate re-dash; shared across states
# ---------------------------------------------------------------------------

func test_cooldown_blocks_immediate_redash_in_jump_state() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, -50.0)

	var st := _make_state(JumpState, fake)
	st.enter()

	# First dash.
	_press_edge("dash")
	st.physics_update(0.016)

	# Let burst window elapse but stay within cooldown.
	InputGate.clear_test_overrides()
	var waited := 0.0
	while waited < 0.20:
		st.physics_update(0.016)
		waited += 0.016

	# Second dash press must be blocked.
	fake.velocity = Vector2.ZERO
	_press_edge("dash")
	st.physics_update(0.016)

	assert_ne(fake.velocity.x, DASH_SPEED,
		"re-dash within DASH_COOLDOWN must be blocked in JumpState")


func test_cooldown_is_shared_across_states() -> void:
	# A dash in JumpState blocks a dash in MoveState until the cooldown elapses.
	# This proves the cooldown is owned by the DashComponent (shared on player),
	# not per-state.
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, -50.0)

	var jump_st := _make_state(JumpState, fake)
	jump_st.enter()

	# Dash in JumpState — starts the cooldown.
	_press_edge("dash")
	jump_st.physics_update(0.016)
	InputGate.clear_test_overrides()

	# Simulate landing: switch to MoveState WITHOUT waiting for cooldown.
	var dash_comp := fake.get_node_or_null("DashComponent") as DashComponent
	assert_not_null(dash_comp, "DashComponent must exist on FakePlayer")

	# Tick a short time (< DASH_COOLDOWN).
	for _i in range(5):
		jump_st.physics_update(0.016)

	# Now switch perspective: MoveState on the same fake player.
	fake.on_floor = true
	var move_st := _make_state(MoveState, fake)
	move_st.enter()

	fake.velocity = Vector2.ZERO
	_press_edge("dash")
	move_st.physics_update(0.016)

	# Cooldown from the JumpState dash must still be blocking.
	assert_ne(fake.velocity.x, DASH_SPEED,
		"cooldown from air dash must block ground dash in MoveState (shared cooldown)")


# ---------------------------------------------------------------------------
# AC3: GATING — no fire -> no-op in every state
# ---------------------------------------------------------------------------

func test_no_dash_without_fire_in_move_state() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {}   # no fire
	fake.on_floor = true
	fake.facing = 1.0

	var st := _make_state(MoveState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_ne(fake.velocity.x, DASH_SPEED,
		"MoveState: no dash without fire ability")


func test_no_dash_without_fire_in_jump_state() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {}   # no fire
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, -50.0)

	var st := _make_state(JumpState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_ne(fake.velocity.x, DASH_SPEED,
		"JumpState: no dash without fire ability")


func test_no_dash_without_fire_in_glide_state() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"ice": true}   # no fire
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, 30.0)

	var st := _make_state(GlideState, fake)
	Input.action_press("glide")
	_press_edge("dash")
	st.physics_update(0.016)
	Input.action_release("glide")

	assert_ne(fake.velocity.x, DASH_SPEED,
		"GlideState: no dash without fire ability")


func test_no_dash_without_fire_in_flight_state() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"electricity": true}   # no fire
	fake.on_floor = false
	fake.facing = 1.0
	fake._flight_suppressed = false

	var st := _make_state(FlightState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_ne(fake.velocity.x, DASH_SPEED,
		"FlightState: no dash without fire ability")


# ---------------------------------------------------------------------------
# AC3: SUPPRESSION — air dash no-op while is_flight_suppressed() + not on floor
# ---------------------------------------------------------------------------

func test_air_dash_suppressed_in_anti_magic_zone_jump_state() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, -50.0)
	fake.set_flight_suppressed(true)   # inside un-purged anti-magic zone

	var st := _make_state(JumpState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_ne(fake.velocity.x, DASH_SPEED,
		"air dash in JumpState must be suppressed inside an un-purged anti-magic zone")


func test_air_dash_suppressed_in_anti_magic_zone_glide_state() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true, "ice": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, 30.0)
	fake.set_flight_suppressed(true)

	var st := _make_state(GlideState, fake)
	Input.action_press("glide")
	_press_edge("dash")
	st.physics_update(0.016)
	Input.action_release("glide")

	assert_ne(fake.velocity.x, DASH_SPEED,
		"air dash in GlideState must be suppressed inside an un-purged anti-magic zone")


func test_air_dash_suppressed_in_anti_magic_zone_flight_state() -> void:
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true, "electricity": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.set_flight_suppressed(true)

	# Note: FlightState will transition to MoveState on suppression check before the dash.
	# We test that the dash does NOT produce the burst velocity.
	var st := _make_state(FlightState, fake)
	# Don't call enter() here to avoid the transition-to-MoveState on the first frame.
	# Instead, manually test that DashComponent.try_air_dash returns false when suppressed.
	var dash_comp := fake.get_node_or_null("DashComponent") as DashComponent
	assert_not_null(dash_comp, "DashComponent must be a child of FakePlayer")

	_press_edge("dash")
	var fired := dash_comp.try_air_dash(fake)
	assert_false(fired,
		"DashComponent.try_air_dash must return false when is_flight_suppressed()")


func test_ground_dash_works_even_when_flight_suppressed() -> void:
	# AC3: ground dash is NOT suppressed — only air dash is.
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = true
	fake.facing = 1.0
	fake.set_flight_suppressed(true)  # inside the anti-magic zone, but on floor

	var st := _make_state(MoveState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, DASH_SPEED,
		"ground dash (on floor) must still work inside an anti-magic zone")


func test_air_dash_works_after_zone_cleared() -> void:
	# AC3: once the zone is cleared (suppression false) the air dash fires normally.
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, -50.0)
	fake.set_flight_suppressed(false)  # zone purged / exited

	var st := _make_state(JumpState, fake)
	st.enter()
	_press_edge("dash")
	st.physics_update(0.016)

	assert_eq(fake.velocity.x, DASH_SPEED,
		"air dash must work normally once the anti-magic zone is cleared")


# ---------------------------------------------------------------------------
# AC4: NON-REGRESSION — existing transitions unchanged
# ---------------------------------------------------------------------------

func test_jump_cancel_still_cancels_ground_dash() -> void:
	# Jump press during a ground dash still transitions to JumpState.
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = true

	var st := _make_state(MoveState, fake)
	st.enter()

	# Trigger dash.
	_press_edge("dash")
	st.physics_update(0.016)

	# Buffer a jump.
	InputGate.clear_test_overrides()
	fake.buffer_jump()
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted(st, "transition_requested",
		"buffered jump during ground dash must still emit transition_requested")


func test_double_jump_to_flight_still_works_with_shared_dash() -> void:
	# Regression: JumpState's double-jump -> FlightState path must be intact after
	# the dash logic is refactored to use DashComponent.
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true, "electricity": true}
	fake.on_floor = false
	fake.velocity = Vector2(0.0, -100.0)
	fake.jump_count = 1  # first leap already registered

	var st := _make_state(JumpState, fake)
	_press_edge("jump")
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "FlightState"],
		"double-jump -> FlightState must still work after JumpState refactor")


func test_glide_to_flight_still_works_with_shared_dash() -> void:
	# Regression: GlideState's double-jump -> FlightState path must be intact.
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true, "ice": true, "electricity": true}
	fake.on_floor = false
	fake.velocity = Vector2(0.0, 30.0)
	fake.jump_count = 1

	var st := _make_state(GlideState, fake)
	Input.action_press("glide")
	_press_edge("jump")
	watch_signals(st)
	st.physics_update(0.016)
	Input.action_release("glide")

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "FlightState"],
		"GlideState double-jump -> FlightState must still work after GlideState refactor")


func test_flight_suppressed_still_drops_to_move_state() -> void:
	# Regression: FlightState still drops to MoveState when suppressed (existing behavior).
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"electricity": true}
	fake.on_floor = false
	fake.set_flight_suppressed(true)

	var st := _make_state(FlightState, fake)
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "MoveState"],
		"FlightState must still drop to MoveState when is_flight_suppressed()")


func test_jump_launch_impulse_intact_after_refactor() -> void:
	# Regression: JumpState.enter() still applies the launch impulse.
	var fake := _make_fake_player_with_dash()
	fake.velocity = Vector2.ZERO

	var st := _make_state(JumpState, fake)
	st.enter()

	assert_eq(fake.velocity.y, JumpState.JUMP_VELOCITY,
		"JumpState launch impulse must be intact after the DashComponent refactor")


func test_glide_to_jump_when_released() -> void:
	# Regression: GlideState still drops back to JumpState when glide is released.
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true, "ice": true}
	fake.on_floor = false
	fake.velocity = Vector2(0.0, 30.0)

	var st := _make_state(GlideState, fake)
	# Glide not held -> should request JumpState.
	watch_signals(st)
	st.physics_update(0.016)

	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "JumpState"],
		"GlideState must fall to JumpState when glide is released (non-regression)")


# ---------------------------------------------------------------------------
# AC4: BYPASS REACHABILITY — dash cannot cross anti-magic gap un-purged
# ---------------------------------------------------------------------------

func test_suppressed_air_dash_produces_no_horizontal_burst() -> void:
	## Bypass guard: with suppression active, a dash attempt in the air produces
	## ZERO horizontal burst — the hero cannot move using the dash in the zone.
	## This is a unit-level proxy for "the hero cannot cross the ~88px barrier
	## using an air dash without purging". The real-physics crossing is guarded
	## by test_anti_magic_zone_physics.gd (existing crucial test).
	var fake := _make_fake_player_with_dash()
	fake.abilities = {"fire": true}
	fake.on_floor = false
	fake.facing = 1.0
	fake.velocity = Vector2(0.0, 0.0)  # stationary
	fake.set_flight_suppressed(true)

	var dash_comp := fake.get_node_or_null("DashComponent") as DashComponent
	assert_not_null(dash_comp, "DashComponent must be accessible from FakePlayer")

	_press_edge("dash")
	var fired := dash_comp.try_air_dash(fake)

	assert_false(fired,
		"try_air_dash must return false (suppressed) — no burst, no horizontal crossing")
	assert_ne(fake.velocity.x, DASH_SPEED,
		"velocity.x must not reach DASH_SPEED when suppressed in the air")
