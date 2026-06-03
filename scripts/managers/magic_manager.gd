## MagicManager (godot-game-dev SKILL Workflow 2): holds the three SpellData
## (Fire/Ice/Electricity), equips/cycles between them, and on cast checks+spends
## mana then spawns the equipped spell's projectile in the aim direction. Only
## READS SpellData (data-driven magic); never one script per spell.
##
## Split for headless testing: try_cast() does the mana check/spend and returns the
## SpellData to spawn (or null); cast() wires that to an actual projectile spawn.
class_name MagicManager extends Node

signal equipped_changed(spell: SpellData)

@export var spells: Array[SpellData] = []
@export var mana: Mana

var equipped: SpellData
var _index := 0

func _ready() -> void:
	equip(0)

## Equip the spell in slot `index`. Out-of-range indices are ignored.
func equip(index: int) -> void:
	if index < 0 or index >= spells.size():
		return
	_index = index
	equipped = spells[index]
	equipped_changed.emit(equipped)

## Advance to the next spell, wrapping around.
func cycle() -> void:
	if spells.is_empty():
		return
	equip((_index + 1) % spells.size())

## The element of the currently equipped spell (or -1 if none).
func equipped_element() -> int:
	return equipped.element if equipped != null else -1

## Validate and pay for a cast. Returns the equipped SpellData on success (mana
## spent) or null when there is no spell or mana < cost (mana untouched).
func try_cast() -> SpellData:
	if equipped == null or mana == null:
		return null
	if not mana.spend(equipped.mana_cost):
		return null
	return equipped

## Full runtime cast: spends mana and spawns the projectile from `origin` toward
## `direction`. Returns true if a projectile was spawned.
func cast(origin: Node2D, direction: Vector2) -> bool:
	var spell := try_cast()
	if spell == null or spell.projectile == null:
		return false
	var p := spell.projectile.instantiate()
	p.global_position = origin.global_position
	if p.has_method("setup"):
		p.setup(spell, direction)
	origin.get_tree().current_scene.add_child(p)
	return true
