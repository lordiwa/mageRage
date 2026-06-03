## Data-driven spell definition (GDD 5.B / godot-game-dev SKILL Workflow 2): one
## SpellData script, many .tres variants. Carries element, damage, projectile and
## DD-004 identity flags (Ice slow, Electricity chain max_targets).
class_name SpellData extends Resource

enum Element { FIRE, ICE, ELECTRICITY, ANTIMATTER }

@export var display_name: String = ""
@export var element: Element = Element.FIRE
@export var damage: float = 10.0
@export var speed: float = 400.0
@export var mana_cost: float = 5.0
@export var projectile: PackedScene
@export var vfx: PackedScene

## DD-004 Ice = control: marks the hit to apply a slow on the target.
@export var applies_slow: bool = false
## DD-004 Electricity = chain/multi-target: how many drones one cast may hit.
@export var max_targets: int = 1
