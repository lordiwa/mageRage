## CRUCIAL CORE (TASK-049) — group N: FSM routing core.
##
## The one reviewer-curated routing guard (a stale request from a non-current state
## is ignored) lifted verbatim from test/test_state_machine.gd with its StubState
## inner class + before_each. No rendered scene needed.
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


func test_stale_request_from_non_current_state_ignored() -> void:
	# jump is NOT current; a request from it must be ignored.
	jump.transition_to("MoveState")
	assert_eq(sm.current_state, move, "request from a non-current state is stale -> ignored")
