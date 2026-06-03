## Unit tests for the StateMachine routing core (no rendered scene needed).
##
## Covers: named transitions resolve, stale requests (from a non-current state)
## are ignored, unknown targets are no-ops, and state_changed fires. These pin
## down the single-owner routing the FSM relies on.
extends GutTest

# Minimal stub state: counts enter/exit so we can assert lifecycle.
class StubState extends EstadoBase:
	var entered := 0
	var exited := 0
	func enter() -> void:
		entered += 1
	func exit() -> void:
		exited += 1


var sm: StateMachine
var move: StubState
var jump: StubState


func before_each() -> void:
	sm = StateMachine.new()
	move = StubState.new()
	move.name = "MoveState"
	jump = StubState.new()
	jump.name = "JumpState"
	sm.add_child(move)
	sm.add_child(jump)
	sm.initial_state = move
	add_child_autofree(sm)   # triggers _ready -> register_states + activate move


func test_initial_state_is_active_and_entered() -> void:
	assert_eq(sm.current_state, move, "initial_state should be current after _ready")
	assert_eq(move.entered, 1, "initial state's enter() should run once")


func test_named_transition_routes_to_target() -> void:
	move.transition_to("JumpState")
	assert_eq(sm.current_state, jump, "transition_to should switch current_state")
	assert_eq(move.exited, 1, "leaving state's exit() should run")
	assert_eq(jump.entered, 1, "entering state's enter() should run")


func test_transition_is_case_insensitive() -> void:
	move.transition_to("jumpstate")
	assert_eq(sm.current_state, jump, "transition lookup should be case-insensitive")


func test_unknown_target_is_noop() -> void:
	move.transition_to("DoesNotExist")
	assert_eq(sm.current_state, move, "unknown target name must not change state")


func test_stale_request_from_non_current_state_ignored() -> void:
	# jump is NOT current; a request from it must be ignored.
	jump.transition_to("MoveState")
	assert_eq(sm.current_state, move, "request from a non-current state is stale -> ignored")


func test_state_changed_signal_emits_on_transition() -> void:
	watch_signals(sm)
	move.transition_to("JumpState")
	assert_signal_emitted_with_parameters(sm, "state_changed", ["JumpState"])
