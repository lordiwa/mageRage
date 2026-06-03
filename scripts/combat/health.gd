## Health component (composition over inheritance, godot-game-dev SKILL §6).
##
## Tracks current/max HP, clamps damage at 0, and emits `health_changed` on every
## change plus `died` exactly once when HP reaches 0. Attach as a child node of any
## entity (player, drone) and listen to its signals.
class_name Health extends Node

signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0
var current_health: float = 0.0
var _dead := false

func _ready() -> void:
	current_health = max_health

## Apply `amount` damage. Non-positive amounts are ignored (no healing here).
## Clamps at 0 and emits `died` once when HP first reaches 0.
func take_damage(amount: float) -> void:
	if amount <= 0.0 or _dead:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_dead = true
		died.emit()

func is_dead() -> bool:
	return _dead or current_health <= 0.0
