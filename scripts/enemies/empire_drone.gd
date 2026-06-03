## Empire drone (CharacterBody2D on the Enemies layer 3). The amnesiac-guardian
## target of the combat slice (pillar 1: the jailer was the protector — read it as
## a desperate sentry, not gleeful evil). Has a Health child and an `armor_type`
## that drives the DD-006 matchup; a debug Label shows HP + the last damage taken.
##
## A placeholder ColorRect visual is tinted by armor type so the player can read at
## a glance which element to swap to (game-design SKILL: readability/telegraphing).
class_name EmpireDrone extends CharacterBody2D

## Armor element drives the matchup. Reuses SpellData.Element so Fire/Ice/Elec map
## 1:1 to spell elements (ANTIMATTER is not a valid armor in the RPS).
@export var armor_type: SpellData.Element = SpellData.Element.FIRE

@onready var _health: Health = $Health
@onready var _label: Label = $Label
@onready var _sprite: ColorRect = $Sprite

const ARMOR_TINT := {
	SpellData.Element.FIRE: Color(0.85, 0.30, 0.20, 1.0),       # warm red
	SpellData.Element.ICE: Color(0.35, 0.65, 0.95, 1.0),        # cold blue
	SpellData.Element.ELECTRICITY: Color(0.95, 0.85, 0.25, 1.0),# arc yellow
}

func _ready() -> void:
	# GDD 5.C: I am an Enemy (layer 3). I don't need to mask anything for the
	# slice (the player projectile detects me); collide with Environment so I rest.
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	if _sprite != null:
		_sprite.color = ARMOR_TINT.get(armor_type, Color.WHITE)
	if _health != null:
		_health.health_changed.connect(_on_health_changed)
		_health.died.connect(_on_died)
	_refresh_label(0.0)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

## Called by a Projectile on contact. Applies base * DD-006 matchup to Health.
## `slow` is honored as a control hook (Ice identity) — for the slice it just
## reads through to the debug label; no movement AI to slow yet.
func apply_elemental_hit(element: int, base_damage: float, slow: bool) -> void:
	var dmg := ElementMatchup.apply(base_damage, element, armor_type)
	if _health != null:
		_health.take_damage(dmg)
	_refresh_label(dmg, slow)

func _on_health_changed(_current: float, _maximum: float) -> void:
	pass   # label refresh is driven from apply_elemental_hit so it can show dmg

func _on_died() -> void:
	queue_free()

func _refresh_label(last_dmg: float, slow := false) -> void:
	if _label == null:
		return
	var hp := _health.current_health if _health != null else 0.0
	var maxhp := _health.max_health if _health != null else 0.0
	var armor: String = SpellData.Element.keys()[armor_type]
	var slow_tag := "  SLOWED" if slow else ""
	_label.text = "%s armor\nHP %d/%d\nlast dmg %.1f%s" % [
		armor, int(hp), int(maxhp), last_dmg, slow_tag]
