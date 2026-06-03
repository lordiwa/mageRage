## On-screen debug label showing the live FSM state plus input hints.
##
## Connects to the StateMachine's `state_changed` signal (decoupled: the HUD
## listens, the machine emits) and updates the label text. Lets us verify
## transitions while playing the movement demo.
extends CanvasLayer

@export var state_machine_path: NodePath
@export var label_path: NodePath

var _label: Label
var _state_name := "—"

func _ready() -> void:
	_label = get_node_or_null(label_path) as Label
	var sm := get_node_or_null(state_machine_path) as StateMachine
	if sm != null:
		sm.state_changed.connect(_on_state_changed)
		# Load-order note: the StateMachine emits state_changed during its own
		# _ready (initial-state activation), which runs before this HUD's _ready
		# (the Player is authored above DebugHUD in the level, and Godot readies
		# nodes in tree order). We therefore miss that first emission and must
		# seed the label from current_state here.
		if sm.current_state != null:
			_state_name = sm.current_state.name
	_refresh()

func _on_state_changed(state_name: String) -> void:
	_state_name = state_name
	_refresh()

func _refresh() -> void:
	if _label == null:
		return
	_label.text = "STATE: %s\n[A/D]/[←/→] move  [Space] jump  [Shift] dash\n[Alt] glide (hold)  [F] fly  [W/S] up/down (flight)" % _state_name
