## On-screen debug label showing the live FSM state, equipped element, and mana.
##
## Connects to the StateMachine's `state_changed` signal (decoupled: the HUD
## listens, the machine emits) for the FSM state, and polls the Player each frame
## for the TASK-006 combat readout (equipped element + current mana). Lets us
## verify transitions and the element-swap micro-loop while playing.
extends CanvasLayer

@export var state_machine_path: NodePath
@export var label_path: NodePath
@export var player_path: NodePath

var _label: Label
var _player: Node
var _state_name := "—"

const _ELEMENT_NAMES := ["FIRE", "ICE", "ELECTRICITY", "ANTIMATTER"]

func _ready() -> void:
	_label = get_node_or_null(label_path) as Label
	_player = get_node_or_null(player_path)
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

func _process(_delta: float) -> void:
	# Mana/element change continuously; poll rather than wire every source signal.
	if _player != null:
		_refresh()

func _on_state_changed(state_name: String) -> void:
	_state_name = state_name
	_refresh()

func _refresh() -> void:
	if _label == null:
		return
	var element_txt := "—"
	var mana_txt := "—"
	if _player != null:
		if _player.has_method("equipped_spell"):
			var spell = _player.equipped_spell()
			if spell != null:
				element_txt = _ELEMENT_NAMES[spell.element]
		if _player.has_method("current_mana"):
			mana_txt = "%d/%d" % [int(_player.current_mana()), int(_player.max_mana())]
	_label.text = "STATE: %s    ELEMENT: %s    MANA: %s\n[A/D]/[←/→] move  [Space] jump  [Shift] dash  [Alt] glide (hold)  [F] fly\n[1] Fire  [2] Ice  [3] Electricity  [Q] cycle  [E]/[LMB] cast" % [
		_state_name, element_txt, mana_txt]
