## Base class for all movement FSM states (GDD 5.A: node-based FSM).
##
## Each concrete state (MoveState/JumpState/GlideState/FlightState) is a Node
## child of a StateMachine. Only the active state's update / physics_update run;
## states request transitions by name via the `transition_requested` signal so
## the StateMachine stays the single owner of routing.
class_name EstadoBase extends Node

## Emitted when a state wants the machine to switch. `from` lets the machine
## ignore stale requests coming from a state that is no longer current.
signal transition_requested(from: EstadoBase, to_name: String)

## The CharacterBody2D this state drives. Wired in the editor (or in code for
## unit tests). Typed loosely as Node so headless tests can inject a fake.
@export var player: Node

## One-time setup when this state becomes active.
func enter() -> void:
	pass

## Cleanup when leaving this state.
func exit() -> void:
	pass

## Per-frame logic (input polling). Routed by StateMachine._process.
func update(_delta: float) -> void:
	pass

## Physics-step logic (movement / move_and_slide). Routed by physics_process.
func physics_update(_delta: float) -> void:
	pass

## Helper a state calls to request a transition to another state by node name.
func transition_to(state_name: String) -> void:
	transition_requested.emit(self, state_name)
