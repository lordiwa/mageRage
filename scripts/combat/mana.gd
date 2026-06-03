## Mana component (composition over inheritance, godot-game-dev SKILL §6).
##
## Gates casting: can_afford(cost) is false when current < cost; spend(cost)
## subtracts and returns true only when affordable (no-op + false otherwise);
## regenerate(delta) tops mana back up, clamped at max. Emits `mana_changed`.
class_name Mana extends Node

signal mana_changed(current: float, maximum: float)

@export var max_mana: float = 100.0
@export var regen_per_second: float = 10.0
var current_mana: float = 0.0

func _ready() -> void:
	current_mana = max_mana

func can_afford(cost: float) -> bool:
	return current_mana >= cost

## Spend `cost` mana. Returns true on success; an unaffordable spend is a no-op
## returning false (the caller should not fire the spell).
func spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	current_mana -= cost
	mana_changed.emit(current_mana, max_mana)
	return true

## Regenerate mana over `delta` seconds, clamped at max_mana.
func regenerate(delta: float) -> void:
	if current_mana >= max_mana:
		return
	current_mana = minf(current_mana + regen_per_second * delta, max_mana)
	mana_changed.emit(current_mana, max_mana)
