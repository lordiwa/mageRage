## Level selector (scenes/level_select.tscn + scripts/ui/level_select.gd, LevelSelect)
## structure tests. TASK-063. This is the new run/main_scene: a player-facing menu
## that lists the real playable levels and loads the chosen one via
## change_scene_to_file. Decided scope: "pick existing levels" — NO lock/progress.
##
## Modeled on test_sector_02.gd's scene-structure style: instantiate headless,
## settle one frame so _ready runs, assert STRUCTURE only (no real scene swap — a
## headless GUT run can't assert a change_scene visual transition). The change-scene
## intent is verified through the script's seam (_path_for(index) / level_selected
## signal) WITHOUT performing the swap.
##
## What it proves:
##   1. the selector scene instances clean headless and the root is a CanvasLayer
##      running the LevelSelect controller;
##   2. the level list is a single data-driven Array of {path, name} entries that
##      contains the real sector paths AND every listed path resolves via
##      ResourceLoader.exists() (guards typos / dangling future entries);
##   3. the menu builds exactly ONE Button per list entry under its container;
##   4. selecting an entry resolves to the right level path through the seam
##      (_path_for(index) + the level_selected(path) signal) without swapping scenes.
extends GutTest

const LEVEL_SELECT := preload("res://scenes/level_select.tscn")

## The real playable levels the selector MUST list (the future shmup level is added
## as ONE line when it exists; it is intentionally absent now so every listed path
## resolves).
const SECTOR_01_PATH := "res://levels/sector_01.tscn"
const SECTOR_02_PATH := "res://levels/sector_02.tscn"
## TASK-065: the shmup level is now the THIRD real entry (added as one line once it exists).
const SHMUP_01_PATH := "res://levels/shmup_01.tscn"


## Instance the selector, parent it (auto-freed), settle one frame so _ready runs
## (the buttons are generated from the data-driven array in _ready).
func _make_selector() -> CanvasLayer:
	var menu := LEVEL_SELECT.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	return menu


func test_selector_scene_instances_clean_as_a_level_select_canvaslayer() -> void:
	var menu: CanvasLayer = await _make_selector()
	assert_not_null(menu, "level_select.tscn instantiates")
	assert_true(menu is CanvasLayer, "the selector root is a CanvasLayer (HUD convention)")
	assert_true(menu is LevelSelect, "the selector root carries the LevelSelect controller")


func test_level_list_is_data_driven_and_contains_the_real_sectors() -> void:
	# The list is a single Array of {path, name} entries exposed on the script. It
	# contains the two real sectors (so adding the shmup later is ONE line).
	var menu: LevelSelect = await _make_selector()
	var entries: Array = menu.level_entries()
	assert_gt(entries.size(), 0, "the selector exposes a non-empty data-driven level list")
	var paths: Array = []
	for entry in entries:
		assert_true(entry.has("path"), "each entry has a 'path'")
		assert_true(entry.has("name"), "each entry has a display 'name'")
		assert_true((entry["name"] as String).length() > 0, "each entry has a non-empty display name")
		paths.append(entry["path"])
	assert_has(paths, SECTOR_01_PATH, "the list includes Sector 01 (res://levels/sector_01.tscn)")
	assert_has(paths, SECTOR_02_PATH, "the list includes Sector 02 (res://levels/sector_02.tscn)")
	assert_has(paths, SHMUP_01_PATH, "the list includes the shmup level (res://levels/shmup_01.tscn) — TASK-065")


func test_every_listed_level_path_resolves_to_an_existing_scene() -> void:
	# Guard against typos / dangling future entries: EVERY listed path must resolve.
	var menu: LevelSelect = await _make_selector()
	for entry in menu.level_entries():
		var path: String = entry["path"]
		assert_true(ResourceLoader.exists(path),
			"the listed level path resolves to an existing .tscn: %s" % path)


func test_menu_builds_exactly_one_button_per_list_entry() -> void:
	# The menu is generated from the array: one Button per entry under the button
	# container (so the count is meaningful and tracks the data).
	var menu: LevelSelect = await _make_selector()
	var container := menu.button_container()
	assert_not_null(container, "the selector exposes its button container")
	var buttons := 0
	for child in container.get_children():
		if child is Button:
			buttons += 1
	assert_eq(buttons, menu.level_entries().size(),
		"the menu builds exactly one Button per level entry")


func test_first_button_is_focused_on_ready_for_keyboard_gamepad_nav() -> void:
	# Keyboard/gamepad nav: the first entry grabs focus on _ready so nav works
	# immediately without a mouse.
	var menu: LevelSelect = await _make_selector()
	var container := menu.button_container()
	assert_not_null(container, "the button container resolves")
	var first: Button = null
	for child in container.get_children():
		if child is Button:
			first = child
			break
	assert_not_null(first, "there is at least one Button to focus")
	assert_true(first.has_focus(), "the first level button is focused on ready")


func test_path_for_index_seam_maps_each_index_to_its_entry_path() -> void:
	# The change-scene seam: _path_for(index) returns the path the selector would
	# load for that entry — asserted WITHOUT performing the scene swap (headless).
	var menu: LevelSelect = await _make_selector()
	var entries: Array = menu.level_entries()
	for i in range(entries.size()):
		assert_eq(menu._path_for(i), entries[i]["path"],
			"_path_for(%d) maps to that entry's level path" % i)


func test_selecting_an_entry_emits_level_selected_with_its_path() -> void:
	# Selecting an entry announces the chosen path via level_selected(path) — the
	# seam the test verifies in place of the real change_scene swap (a headless run
	# cannot assert a visual scene transition). We connect to the signal directly so
	# we can RECORD the swap target and SUPPRESS the real change_scene (the swap is
	# emitted before the swap call; here we simply never let it run by asserting only
	# the announced path — change_scene_to_file is deferred and harmless under GUT,
	# but recording the signal keeps the assertion swap-free).
	var menu: LevelSelect = await _make_selector()
	var captured: Array = []
	menu.level_selected.connect(func(path: String) -> void: captured.append(path))
	watch_signals(menu)
	menu.select_index(0)
	assert_signal_emitted(menu, "level_selected",
		"selecting an entry emits level_selected")
	assert_eq(captured.size(), 1, "level_selected fires exactly once per selection")
	assert_eq(captured[0], menu._path_for(0),
		"level_selected carries the chosen entry's level path")


# --- TASK-065: the selector now lists 3 levels, all resolving --------------------

func test_selector_lists_three_levels_all_resolving() -> void:
	# The shmup level brings the selector to THREE entries; every listed path must still
	# resolve (the future-entry guard now that a third real path exists).
	var menu: LevelSelect = await _make_selector()
	var entries: Array = menu.level_entries()
	assert_eq(entries.size(), 3, "the selector lists exactly three levels (TASK-065)")
	for entry in entries:
		assert_true(ResourceLoader.exists(entry["path"]),
			"every listed level path resolves: %s" % entry["path"])


# --- TASK-065 (folds TASK-063 reviewer LOW): select_index guards a missing path ---

func test_select_index_refuses_a_nonexistent_path() -> void:
	# The folded TASK-063 reviewer LOW: select_index must guard with ResourceLoader.exists()
	# before change_scene_to_file, so a typo'd / dangling path can't hard-crash the game.
	# We drive it through the _path_for seam by overriding the resolved path indirectly:
	# select_index reads _path_for(index); to test the guard in isolation we assert that a
	# selection whose resolved path does NOT exist NEVER emits level_selected (the announce
	# that immediately precedes the swap), so the swap is refused.
	var menu: LevelSelect = await _make_selector()
	watch_signals(menu)
	# An out-of-range index already yields "" (existing safe no-op) — exercise that the
	# guard ALSO refuses a non-existent (but non-empty) path via the public seam.
	menu.select_path_for_test("res://levels/does_not_exist.tscn")
	assert_signal_not_emitted(menu, "level_selected",
		"a non-existent level path is refused (guarded by ResourceLoader.exists) — no swap")


func test_select_index_still_accepts_a_real_path() -> void:
	# Sanity: the new guard does NOT block a REAL listed path — a valid selection still
	# announces level_selected (and would swap in game).
	var menu: LevelSelect = await _make_selector()
	var captured: Array = []
	menu.level_selected.connect(func(path: String) -> void: captured.append(path))
	menu.select_index(0)
	assert_eq(captured.size(), 1, "a real listed path is still accepted (guard is fail-safe only)")
