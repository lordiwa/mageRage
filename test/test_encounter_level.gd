## TASK-021 light integration test for the encounter room (levels/encounter.tscn).
##
## Proves the level loads/instances clean headless and that the encounter controller
## spawns the FIRST wave into the `enemies` group with the DESIGNED armor types after
## the opening rest beat — i.e. the data design actually drives the live scene. Kept
## light (one wave) so it stays fast and deterministic; the sequencing edge cases are
## covered purely in test_wave_controller.gd.
extends GutTest

const ENCOUNTER := preload("res://levels/encounter.tscn")
const FIRE := SpellData.Element.FIRE
const ICE := SpellData.Element.ICE


func test_encounter_scene_instances_without_error() -> void:
	var level := ENCOUNTER.instantiate()
	assert_not_null(level, "encounter.tscn instantiates")
	add_child_autofree(level)
	await get_tree().process_frame
	# A Player and the wave controller exist and the level is a Node2D root.
	assert_not_null(level.get_node_or_null("Player"), "level has a Player")
	assert_not_null(level.get_node_or_null("PlayerHUD"), "level wires the PlayerHUD")
	assert_not_null(level.get_node_or_null("DebugHUD"), "level includes the DebugHUD toggle")
	assert_true(level.has_method("current_wave_index"),
		"the root runs the encounter controller")


func test_first_wave_spawns_into_enemies_group_after_rest() -> void:
	var level := ENCOUNTER.instantiate()
	# Make the opening rest near-instant so the test doesn't wait seconds.
	level.rest_delay = 0.0
	add_child_autofree(level)
	# Let the controller tick: _physics_process spawns the wave once rest elapsed.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var enemies := get_tree().get_nodes_in_group("enemies")
	# Wave 1 = a FIRE drone + an ICE drone (2 entries; both flying drones are
	# directly in the `enemies` group).
	assert_gte(enemies.size(), 2,
		"the first wave spawns its enemies into the `enemies` group")
	var armors := {}
	for e in enemies:
		if "armor_type" in e:
			armors[e.armor_type] = true
	assert_true(armors.has(FIRE), "first wave includes a FIRE-armored enemy")
	assert_true(armors.has(ICE), "first wave includes an ICE-armored enemy")
	assert_gte(armors.size(), 2,
		"first wave mixes >=2 distinct armor types (DD-004, live)")
