## Data-driven spell definition (GDD 5.B / godot-game-dev SKILL Workflow 2): one
## SpellData script, many .tres variants. Carries element, damage, projectile and
## DD-004 identity flags (Ice slow, Electricity chain max_targets).
class_name SpellData extends Resource

enum Element { FIRE, ICE, ELECTRICITY, ANTIMATTER }

## TASK-022 / DD-004 per-element shot behavior, defined in the .tres data so each
## element FIRES differently, not just looks different:
##   SINGLE = stop on the first hit (Fire burst).
##   PIERCE = pass straight through up to max_targets enemies (Ice control).
##   CHAIN  = bounce/arc to the nearest not-yet-hit enemy in chain_radius
##            (Electricity multi-target). Default SINGLE keeps old data working.
enum ShotType { SINGLE, PIERCE, CHAIN }

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

## TASK-022 per-element shot type (see ShotType). Default SINGLE so SpellData
## built without it (older callers/tests) behaves exactly as before.
@export var shot_type: ShotType = ShotType.SINGLE

## TASK-022 CHAIN reach: max distance the bolt may arc to the next unhit enemy.
@export var chain_radius: float = 160.0

## TASK-038 (M2.1 combat-feel) per-element fire rate: seconds between shots while a
## trigger is HELD (hold-to-fire cadence). Data-driven so each element fires at its
## own rhythm (DD-004: Fire fastest, Electricity medium, Ice slowest) with NO
## per-element constants in code. The MagicManager gates each slot's held casts on
## this interval. Default 0.2s keeps SpellData built without it behaving sanely.
@export var fire_interval: float = 0.2
