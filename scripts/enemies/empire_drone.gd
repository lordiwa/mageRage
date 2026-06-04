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

## TASK-010 juice scenes (PLACEHOLDERS). Optional so unit tests / bare drones run
## without them; null-guarded at the hit path.
@export var damage_number_scene: PackedScene
@export var impact_spark_scene: PackedScene

## TASK-010: emitted on every landed hit so a coordinator (or test) can react with
## loose coupling. `dir` is the projectile's travel direction at contact.
signal hit(amount: float, effectiveness: float, dir: Vector2)

@onready var _health: Health = $Health
@onready var _label: Label = $Label
@onready var _sprite: ColorRect = $Sprite

const ARMOR_TINT := {
	SpellData.Element.FIRE: Color(0.85, 0.30, 0.20, 1.0),       # warm red
	SpellData.Element.ICE: Color(0.35, 0.65, 0.95, 1.0),        # cold blue
	SpellData.Element.ELECTRICITY: Color(0.95, 0.85, 0.25, 1.0),# arc yellow
}

## TASK-010 feel tuning (small / sparing per game-design SKILL juice budget).
const FLASH_TIME := 0.06           # seconds the drone flashes white on a hit
const KNOCKBACK_STRENGTH := 70.0   # px positional punch along the shot direction
const KNOCKBACK_TIME := 0.10       # seconds of the knockback tween
const SHAKE_PER_HIT := 0.18        # base trauma added to the camera per hit

var _armor_color := Color.WHITE

func _ready() -> void:
	# GDD 5.C: I am an Enemy (layer 3). I don't need to mask anything for the
	# slice (the player projectile detects me); collide with Environment so I rest.
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	_armor_color = ARMOR_TINT.get(armor_type, Color.WHITE)
	if _sprite != null:
		_sprite.color = _armor_color
	if _health != null:
		_health.health_changed.connect(_on_health_changed)
		_health.died.connect(_on_died)
	_refresh_label(0.0)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

## Called by a Projectile on contact. Applies base * DD-006 matchup to Health and
## fires the TASK-010 hit-feedback bundle (one hit path -> all juice, coherently):
## hit flash + damage number + impact spark + camera shake + hit-stop + knockback.
## `slow` is the Ice control hook (reads through to the debug label). `hit_dir` is
## the projectile's travel direction (for knockback + the `hit` signal); defaults
## to ZERO so older callers / tests still work.
func apply_elemental_hit(element: int, base_damage: float, slow: bool,
		hit_dir: Vector2 = Vector2.ZERO) -> void:
	var effectiveness := ElementMatchup.multiplier(element, armor_type)
	var dmg := base_damage * effectiveness
	if _health != null:
		_health.take_damage(dmg)
	_refresh_label(dmg, slow)
	# --- TASK-010 hit feedback ------------------------------------------------
	_flash()
	_apply_knockback(hit_dir)
	_spawn_damage_number(dmg, effectiveness)
	_spawn_spark(element, hit_dir)
	_shake_camera(effectiveness)
	_do_hit_stop(effectiveness)
	hit.emit(dmg, effectiveness, hit_dir)


## Hit flash: modulate to white for a few frames, then back to the armor tint.
func _flash() -> void:
	if _sprite == null:
		return
	_sprite.color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_sprite, "color", _armor_color, FLASH_TIME)


## Knockback: a short positional punch along the shot's travel direction.
func _apply_knockback(hit_dir: Vector2) -> void:
	var kb := Knockback.knockback_vector(hit_dir, KNOCKBACK_STRENGTH)
	if kb == Vector2.ZERO:
		return
	var target := global_position + kb
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, KNOCKBACK_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _spawn_damage_number(amount: float, effectiveness: float) -> void:
	if damage_number_scene == null:
		return
	var dn := damage_number_scene.instantiate()
	get_tree().current_scene.add_child(dn)
	dn.global_position = global_position + Vector2(0, -24)
	if dn.has_method("setup"):
		dn.setup(amount, effectiveness)


func _spawn_spark(element: int, hit_dir: Vector2) -> void:
	if impact_spark_scene == null:
		return
	var spark := impact_spark_scene.instantiate()
	get_tree().current_scene.add_child(spark)
	# Contact point: bias toward the side the shot came from.
	spark.global_position = global_position - hit_dir.normalized() * 12.0
	if spark.has_method("burst"):
		spark.burst(element)


## Add trauma to the Player camera's ScreenShake, scaled by effectiveness — a
## correct-element hit shakes a touch harder (still small per the juice budget).
func _shake_camera(effectiveness: float) -> void:
	var shake := _find_screen_shake()
	if shake != null and shake.has_method("add_trauma"):
		shake.add_trauma(SHAKE_PER_HIT * effectiveness)


func _do_hit_stop(effectiveness: float) -> void:
	# HitStop is an autoload; null-guard so bare-scene tests don't require it.
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var hs := tree.root.get_node_or_null("HitStop")
	if hs != null and hs.has_method("freeze"):
		hs.freeze(effectiveness)


## Locate the ScreenShake node (child of the Player's Camera2D) without hard
## coupling: search the current scene for the first node in the "screen_shake"
## group. Returns null if absent (e.g. a bare drone in a unit test).
func _find_screen_shake() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("screen_shake")
	if nodes.is_empty():
		return null
	return nodes[0]

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
