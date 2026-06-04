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

## TASK-015: the DebugHUD is now a TOGGLEABLE dev overlay (the real player status
## moved to PlayerHUD). Starts hidden by default so the game HUD reads cleanly;
## press `toggle_debug_hud` (F1) to flip it on/off in a playtest.
@export var start_visible: bool = false
@export var toggle_action: StringName = &"toggle_debug_hud"

var _label: Label
var _player: Node
var _state_name := "—"

const _ELEMENT_NAMES := ["FIRE", "ICE", "ELECTRICITY", "ANTIMATTER"]

func _ready() -> void:
	visible = start_visible
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
	# Toggle the dev overlay on/off (F1). Guarded so headless/minimal setups
	# without the action mapped don't error.
	if InputMap.has_action(toggle_action) and Input.is_action_just_pressed(toggle_action):
		visible = not visible
	# Mana/element change continuously; poll rather than wire every source signal.
	if visible and _player != null:
		_refresh()

func _on_state_changed(state_name: String) -> void:
	_state_name = state_name
	_refresh()

func _refresh() -> void:
	if _label == null:
		return
	var primary_txt := "—"
	var secondary_txt := "—"
	var mana_txt := "—"
	var hp_txt := "—"
	if _player != null:
		if _player.has_method("primary_spell"):
			var ps = _player.primary_spell()
			if ps != null:
				primary_txt = _ELEMENT_NAMES[ps.element]
		if _player.has_method("secondary_spell"):
			var ss = _player.secondary_spell()
			if ss != null:
				secondary_txt = _ELEMENT_NAMES[ss.element]
		if _player.has_method("current_mana"):
			mana_txt = "%d/%d" % [int(_player.current_mana()), int(_player.max_mana())]
		# DD-009: player HP readout.
		if _player.has_method("player_hp"):
			hp_txt = "%d/%d" % [int(_player.player_hp()), int(_player.max_player_hp())]
	# DD-008 control hints (gamepad-first, keyboard additive).
	_label.text = "STATE: %s    HP: %s    PRIMARY: %s    SECONDARY: %s    MANA: %s\n[A/D]/[←/→]/[W/S] move  [Space] jump (double = fly)  [Shift] dash  [Alt] glide (hold)\n[1] Fire  [2] Ice  [3] Electricity (primary = last pressed)  [E]/[LMB] cast primary  [Q]/[RMB] cast secondary\nPAD: L-stick move  A jump (double = fly)  RB dash  LB glide (hold)  X/Y/B element  RT primary  LT secondary" % [
		_state_name, hp_txt, primary_txt, secondary_txt, mana_txt]
