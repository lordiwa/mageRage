## Integration-lite test for the TASK-066 enemy stream WIRING into levels/shmup_01.tscn.
##
## The deterministic spawn/position/despawn LOGIC is unit-tested frame-free in
## test_shmup_spawner.gd (fake scroller + spawn spy + fake enemy). Here we prove only the
## WIRING: shmup_01.tscn still loads clean headless WITH the spawner node present, and the
## controller exposes the spawner so it runs in-level. We do NOT drive real enemy frames.
##
## What it proves:
##   1. shmup_01.tscn still instances clean headless (no regression from adding the spawner).
##   2. the level carries a ShmupSpawner, reachable via the Shmup01 controller, fed the
##      auto-scroll camera as its scroller (so it spawns at the live right edge).
##   3. the spawner reuses the EXISTING flying-drone enemy scenes (the enemy factory resolves
##      a real drone PackedScene), not a new enemy type.
extends GutTest

const SHMUP := preload("res://levels/shmup_01.tscn")


func _make_level() -> Node2D:
	var level := SHMUP.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	return level


func test_shmup_level_still_instances_clean_with_the_spawner() -> void:
	var level: Node2D = await _make_level()
	assert_not_null(level, "shmup_01.tscn instantiates with the enemy spawner wired")
	assert_true(level is Shmup01, "the root still carries the Shmup01 controller")


func test_level_carries_a_spawner_wired_to_the_scroller() -> void:
	var level: Node2D = await _make_level()
	var shmup := level as Shmup01
	assert_true(shmup.has_method("spawner"), "the controller exposes a spawner() accessor")
	var spawner: ShmupSpawner = shmup.spawner()
	assert_not_null(spawner, "the level instances a ShmupSpawner")
	assert_true(spawner is ShmupSpawner, "the spawner is a ShmupSpawner")
	# It must spawn at the LIVE right edge: it is fed the auto-scroll camera as its scroller.
	assert_true(spawner.has_scroller(),
		"the spawner is fed the auto-scroll camera so it spawns at the live right edge")


func test_spawner_reuses_existing_drone_scenes_not_a_new_enemy() -> void:
	# AC: REUSE the existing flying-drone enemies — the factory must resolve a real, existing
	# enemy PackedScene for each enemy_type, never invent a new one.
	var level: Node2D = await _make_level()
	var spawner: ShmupSpawner = (level as Shmup01).spawner()
	assert_not_null(spawner, "the spawner resolves")
	# Every enemy_type referenced by the wave stream maps to an existing PackedScene.
	for wave in spawner.waves:
		var scene: PackedScene = spawner.enemy_scene_for(wave["enemy_type"])
		assert_not_null(scene,
			"each wave enemy_type maps to an existing drone PackedScene (no new enemy type)")
