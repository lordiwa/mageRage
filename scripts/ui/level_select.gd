## TASK-063 LEVEL SELECTOR — the new run/main_scene. A player-facing menu that lists
## the real playable levels and loads the chosen one via change_scene_to_file, so the
## game boots into a picker instead of straight into a sector.
##
## Decided scope ("pick existing levels"): NO lock/progress state. The level list is a
## SINGLE data-driven Array of {path, name} entries (LEVEL_ENTRIES) so adding the future
## shmup level is ONE line — drop it in once levels/shmup_01.tscn exists (it does NOT
## yet, so it is intentionally absent; every listed path must resolve).
##
## UI convention (mirrors scripts/ui/player_hud.gd — there is NO global theme/font
## resource): a CanvasLayer root, a CenterContainer/VBoxContainer of Buttons built FROM
## the array in _ready, tinted with the inline HUD color language. The first button grabs
## focus on _ready so keyboard/gamepad nav works immediately; the VBoxContainer's vertical
## focus chain handles up/down. Menu nav/confirm REUSE existing input actions (no new
## input-map actions added): move_up/move_down move focus, jump/cast_primary confirm.
##
## The scene swap has a test seam: selecting an entry emits level_selected(path) BEFORE
## the swap, and _path_for(index) maps an index to its level path — so a headless GUT run
## can assert the chosen path WITHOUT performing a (un-assertable) visual scene transition.
class_name LevelSelect extends CanvasLayer

## Announced with the chosen level path the instant an entry is selected — emitted
## BEFORE change_scene_to_file so tests can assert the intent without the swap.
signal level_selected(path: String)

## The single data-driven level list. One {path, name} entry per REAL playable level.
## Adding the future fast shmup level (levels/shmup_01.tscn) is ONE line here once it
## exists; until then it is absent so every listed path resolves (guarded by a test).
const LEVEL_ENTRIES: Array[Dictionary] = [
	{"path": "res://levels/sector_01.tscn", "name": "Sector 01"},
	{"path": "res://levels/sector_02.tscn", "name": "Sector 02"},
]

# --- Look: mirror the inline HUD color language (no global theme exists) ------

## Panel/title chrome echoing the HUD's dark track + light-on-dark label palette.
const TITLE_COLOR := Color(0.85, 0.95, 1.0, 1.0)        # mirrors the HUD mana label
const BUTTON_TEXT_COLOR := Color(0.85, 1.0, 0.85, 1.0)  # mirrors the HUD hp label
const TITLE_TEXT := "MAGE RAGE"
const SUBTITLE_TEXT := "SELECT A LEVEL"

@export var button_container_path: NodePath  # the VBoxContainer the buttons live under

var _container: BoxContainer
var _buttons: Array[Button] = []


# --- Pure data accessors (unit-tested headless) ------------------------------

## The data-driven level list (a copy so callers can't mutate the canonical array).
func level_entries() -> Array[Dictionary]:
	return LEVEL_ENTRIES.duplicate(true)

## The level path the selector would load for entry `index` — the change-scene seam,
## asserted in tests without performing the swap. Out-of-range yields "" (safe).
func _path_for(index: int) -> String:
	if index < 0 or index >= LEVEL_ENTRIES.size():
		return ""
	return LEVEL_ENTRIES[index]["path"]

## The container the per-entry Buttons are generated under (for tests + focus chain).
func button_container() -> BoxContainer:
	return _container


# --- Lifecycle ---------------------------------------------------------------

func _ready() -> void:
	_container = get_node_or_null(button_container_path) as BoxContainer
	if _container == null:
		return
	_build_buttons()
	# Keyboard/gamepad nav works immediately: focus the first entry on ready. The
	# VBoxContainer's vertical focus chain (set below) handles up/down between buttons.
	if not _buttons.is_empty():
		_buttons[0].grab_focus()

## Generate exactly one Button per LEVEL_ENTRIES entry, tinted with the HUD color
## language, and wire its press to select that entry. Focus neighbors chain top->bottom
## (and wrap) so move_up/move_down nav is seamless.
func _build_buttons() -> void:
	for child in _container.get_children():
		child.queue_free()
	_buttons.clear()
	for i in range(LEVEL_ENTRIES.size()):
		var entry := LEVEL_ENTRIES[i]
		var button := Button.new()
		button.text = entry["name"]
		button.add_theme_color_override("font_color", BUTTON_TEXT_COLOR)
		button.add_theme_color_override("font_focus_color", TITLE_COLOR)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_button_pressed.bind(i))
		_container.add_child(button)
		_buttons.append(button)
	_chain_focus_neighbors()

## Wire the vertical focus chain (with wrap) so move_up/move_down cycle the entries.
func _chain_focus_neighbors() -> void:
	var n := _buttons.size()
	if n == 0:
		return
	for i in range(n):
		var above := _buttons[(i - 1 + n) % n]
		var below := _buttons[(i + 1) % n]
		_buttons[i].focus_neighbor_top = _buttons[i].get_path_to(above)
		_buttons[i].focus_neighbor_bottom = _buttons[i].get_path_to(below)
		_buttons[i].focus_previous = _buttons[i].get_path_to(above)
		_buttons[i].focus_next = _buttons[i].get_path_to(below)


# --- Input + selection -------------------------------------------------------

## Menu nav/confirm REUSE existing input actions (no new input-map actions). move_up /
## move_down move focus between entries; jump / cast_primary confirm the focused entry.
## (Godot's default ui_* actions are NOT mapped in this project, so nav is explicit.)
func _unhandled_input(event: InputEvent) -> void:
	if _buttons.is_empty():
		return
	if event.is_action_pressed("move_down"):
		_move_focus(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_up"):
		_move_focus(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump") or event.is_action_pressed("cast_primary"):
		_confirm_focused()
		get_viewport().set_input_as_handled()

## Move keyboard/gamepad focus by `step` entries (wrapping) from the focused button.
func _move_focus(step: int) -> void:
	var current := _focused_index()
	if current < 0:
		current = 0
	var n := _buttons.size()
	var next := (current + step + n) % n
	_buttons[next].grab_focus()

## The index of the currently focused entry button, or -1 if none is focused.
func _focused_index() -> int:
	for i in range(_buttons.size()):
		if _buttons[i].has_focus():
			return i
	return -1

## Confirm the focused entry (or the first if none) — loads that level.
func _confirm_focused() -> void:
	var index := _focused_index()
	if index < 0:
		index = 0
	select_index(index)

func _on_button_pressed(index: int) -> void:
	select_index(index)

## Select entry `index`: announce the chosen path (level_selected) THEN swap to it. The
## announce-before-swap order lets a headless test assert the path via the signal without
## a real change_scene transition. An out-of-range / unresolved path is a safe no-op.
func select_index(index: int) -> void:
	var path := _path_for(index)
	if path.is_empty():
		return
	level_selected.emit(path)
	_change_scene(path)

## The actual scene swap, factored out as an overridable seam. Guarded twice: a missing
## tree (headless construction) is safe, AND the swap only fires when THIS selector is
## the active scene (booted in as main_scene). Under a GUT run the active scene is the
## test runner, so select_index() exercises the emit seam WITHOUT a destructive swap of
## the runner — the signal/path assertions stay clean.
func _change_scene(path: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	if tree.current_scene != self:
		return
	tree.change_scene_to_file(path)
