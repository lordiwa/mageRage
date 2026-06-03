## Node-based finite state machine for hero movement (GDD 5.A).
##
## Hangs off the Player. Each EstadoBase child registers under its lowercased
## node name; the machine routes _process / _physics_process to the active
## state and performs name-based transitions, ignoring stale requests. This is
## the single owner of "which state is current" so individual states stay
## ignorant of each other (no boolean-flag soup).
class_name StateMachine extends Node

## Emitted after every successful transition so a HUD can show the live state.
signal state_changed(state_name: String)

## The state to enter on _ready. Assigned in the editor.
@export var initial_state: EstadoBase

## The currently active state, or null before _ready / if misconfigured.
var current_state: EstadoBase

## Lowercased node name -> EstadoBase, built from children at registration.
var states: Dictionary = {}

func _ready() -> void:
	register_states()
	if initial_state != null:
		_activate(initial_state)

## Collects EstadoBase children into `states` and wires their transition signal.
## Split out from _ready so unit tests can build a machine with stub children
## and call this directly without a full scene.
func register_states() -> void:
	states.clear()
	for child in get_children():
		if child is EstadoBase:
			states[child.name.to_lower()] = child
			if not child.transition_requested.is_connected(_on_transition_requested):
				child.transition_requested.connect(_on_transition_requested)

func _process(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)

## Routes a transition request. Ignores requests from a non-current state
## (stale) and unknown target names (no-op), so the machine never lands in an
## undefined state.
func _on_transition_requested(from: EstadoBase, to_name: String) -> void:
	if from != current_state:
		return
	var next: EstadoBase = states.get(to_name.to_lower())
	if next == null:
		return
	if current_state != null:
		current_state.exit()
	_activate(next)

func _activate(state: EstadoBase) -> void:
	current_state = state
	state.enter()
	state_changed.emit(state.name)
