## TASK-021 Encounter room controller (Sala de encuentro).
##
## The live, scene-bound half of the encounter: it owns the actual enemy nodes and
## drives spawning from EncounterWaves.WAVES, while the PURE WaveController decides
## WHEN to advance (ramp-then-rest). This split keeps the sequencing logic unit-
## testable and the node wiring trivial.
##
## Loop each physics frame:
##   - count alive enemies in the `enemies` group (within this level);
##   - while a wave is live and not cleared, do nothing (let the player fight);
##   - once cleared, run a REST beat (a telegraphed pause), then spawn the next wave;
##   - when the last wave is cleared, advance past the end and show a CLEARED label.
##
## Mixed-armor composition (DD-004) lives in the data (EncounterWaves) and is proven
## by test_wave_controller.gd — every wave spawns >=2 distinct armor types.
extends Node2D

## Seconds of rest between a wave being cleared and the next wave spawning
## (doctrine: ramp-then-rest; telegraphed/fair, DD-001).
@export var rest_delay: float = 2.5

## Optional UI seams (wired in the scene). The countdown label telegraphs the next
## wave; the cleared label shows when the whole encounter is done.
@export var wave_label_path: NodePath
@export var cleared_label_path: NodePath

## Where spawned enemies are parented (defaults to this node so they share the level).
@export var enemies_root_path: NodePath

var _wave := WaveController.new()
var _rest_elapsed: float = 0.0
var _wave_active: bool = false
var _spawned_any: bool = false

var _wave_label: Label
var _cleared_label: Label
var _enemies_root: Node


func _ready() -> void:
	_wave.total_waves = EncounterWaves.WAVES.size()
	_wave_label = get_node_or_null(wave_label_path) as Label
	_cleared_label = get_node_or_null(cleared_label_path) as Label
	_enemies_root = get_node_or_null(enemies_root_path)
	if _enemies_root == null:
		_enemies_root = self
	if _cleared_label != null:
		_cleared_label.visible = false
	# Kick off the first wave after a short opening rest so the player can orient.
	_rest_elapsed = 0.0
	_wave_active = false


func _physics_process(delta: float) -> void:
	if _wave.is_complete():
		_on_all_cleared()
		return

	var alive := _count_alive()

	if not _wave_active:
		# Between waves: tick the rest beat, then spawn the current wave.
		_rest_elapsed += delta
		_update_wave_label(true)
		# For the FIRST wave we spawn after the opening rest; for later waves the
		# WaveController has already advanced the index on the previous clear.
		if _rest_elapsed >= rest_delay:
			_spawn_current_wave()
		return

	# A wave is live: advance only when it is cleared AND the rest beat elapsed.
	if _wave.is_wave_cleared(alive):
		_rest_elapsed += delta
		_update_wave_label(true)
		if _wave.should_advance(alive, _rest_elapsed, rest_delay):
			_wave.advance()
			_wave_active = false
			_rest_elapsed = 0.0
	else:
		_rest_elapsed = 0.0
		_update_wave_label(false)


## Spawn every entry of the current wave into the level, in the `enemies` group with
## the designed armor type + position.
func _spawn_current_wave() -> void:
	if not _wave.has_current_wave():
		return
	var wave: Array = EncounterWaves.WAVES[_wave.current_index]
	for entry in wave:
		_spawn_entry(entry)
	_wave_active = true
	_spawned_any = true
	_rest_elapsed = 0.0
	_update_wave_label(false)


## Instance one enemy from an entry dict and apply its armor type. SwarmGroup uses
## `member_armor` (it has no armor_type of its own); the others use `armor_type`.
func _spawn_entry(entry: Dictionary) -> void:
	var path: String = entry.get("scene", "")
	if path == "" or not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var node := packed.instantiate()
	var armor: int = entry.get("armor_type", SpellData.Element.FIRE)
	if "member_armor" in node:
		node.member_armor = armor
	elif "armor_type" in node:
		node.armor_type = armor
	_enemies_root.add_child(node)
	if node is Node2D:
		(node as Node2D).position = entry.get("position", Vector2.ZERO)


## Count enemies still alive in this level. A SwarmGroup is not itself in the
## `enemies` group (its members are), so the group-member count is what matters;
## drones/charger/shield are counted directly. Dying enemies (mid-dissolve) are
## excluded so the next wave isn't gated on a death animation.
func _count_alive() -> int:
	var tree := get_tree()
	if tree == null:
		return 0
	var n := 0
	for e in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dying") and e.is_dying():
			continue
		n += 1
	return n


func _update_wave_label(resting: bool) -> void:
	if _wave_label == null:
		return
	if _wave.is_complete():
		_wave_label.text = ""
		return
	var n: int = _wave.current_index + 1
	var total: int = _wave.total_waves
	if resting:
		_wave_label.text = "WAVE %d / %d  —  incoming…" % [n, total]
	else:
		_wave_label.text = "WAVE %d / %d" % [n, total]


func _on_all_cleared() -> void:
	if _wave_label != null:
		_wave_label.text = ""
	if _cleared_label != null:
		_cleared_label.visible = true


# --- Test / tooling seams -----------------------------------------------------

## Expose the pure controller's current wave index (read-only use in tests).
func current_wave_index() -> int:
	return _wave.current_index

func is_encounter_complete() -> bool:
	return _wave.is_complete()
