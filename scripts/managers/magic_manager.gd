## MagicManager (godot-game-dev SKILL Workflow 2): holds the three SpellData
## (Fire/Ice/Electricity) and a DD-008 two-slot loadout (PRIMARY + SECONDARY).
## Only READS SpellData (data-driven magic); never one script per spell.
##
## DD-008 loadout: select(index) promotes that element to PRIMARY and demotes the
## previous primary to SECONDARY — a stack of the last two distinct elements.
## Re-selecting the current primary is a no-op. cast_primary fires the primary
## slot, cast_secondary the secondary; each checks+spends mana per cast.
##
## Split for headless testing: try_cast_primary()/try_cast_secondary() do the mana
## check/spend and return the SpellData to spawn (or null); cast_primary()/
## cast_secondary() wire that to an actual projectile spawn.
class_name MagicManager extends Node

signal loadout_changed(primary: SpellData, secondary: SpellData)

@export var spells: Array[SpellData] = []
@export var mana: Mana

## DD-008 two-element loadout. primary fires on cast_primary, secondary on
## cast_secondary.
var primary: SpellData
var secondary: SpellData

func _ready() -> void:
	# Default loadout: the first two distinct spells (primary, secondary).
	if spells.size() >= 1:
		primary = spells[0]
	if spells.size() >= 2:
		secondary = spells[1]
	loadout_changed.emit(primary, secondary)

## Select the element in slot `index`: promote it to PRIMARY and demote the
## previous primary to SECONDARY (last-two-distinct stack). Re-selecting the
## current primary is a no-op. Out-of-range indices are ignored.
func select(index: int) -> void:
	if index < 0 or index >= spells.size():
		return
	var chosen := spells[index]
	if chosen == primary:
		return                       # already primary: no-op
	secondary = primary              # demote old primary
	primary = chosen                 # promote selection
	loadout_changed.emit(primary, secondary)

## The element of the primary slot (or -1 if none).
func primary_element() -> int:
	return primary.element if primary != null else -1

## The element of the secondary slot (or -1 if none).
func secondary_element() -> int:
	return secondary.element if secondary != null else -1

## Validate and pay for casting `spell`. Returns the SpellData on success (mana
## spent) or null when there is no spell or mana < cost (mana untouched).
func _try_cast(spell: SpellData) -> SpellData:
	if spell == null or mana == null:
		return null
	if not mana.spend(spell.mana_cost):
		return null
	return spell

## Validate and pay for a PRIMARY-slot cast (see _try_cast).
func try_cast_primary() -> SpellData:
	return _try_cast(primary)

## Validate and pay for a SECONDARY-slot cast (see _try_cast).
func try_cast_secondary() -> SpellData:
	return _try_cast(secondary)

## Spawn the projectile for `spell` from `origin` toward `direction`. Returns true
## if a projectile was spawned.
func _spawn(spell: SpellData, origin: Node2D, direction: Vector2) -> bool:
	if spell == null or spell.projectile == null:
		return false
	var p := spell.projectile.instantiate()
	p.global_position = origin.global_position
	if p.has_method("setup"):
		p.setup(spell, direction)
	origin.get_tree().current_scene.add_child(p)
	return true

## Full runtime PRIMARY cast: spends mana and spawns the primary projectile.
func cast_primary(origin: Node2D, direction: Vector2) -> bool:
	return _spawn(try_cast_primary(), origin, direction)

## Full runtime SECONDARY cast: spends mana and spawns the secondary projectile.
func cast_secondary(origin: Node2D, direction: Vector2) -> bool:
	return _spawn(try_cast_secondary(), origin, direction)
