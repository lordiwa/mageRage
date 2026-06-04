## TASK-019 Swarmling (miembro del Enjambre) — a lightweight FLOATING low-HP drone,
## a member of a SwarmGroup. The swarm's threat is NUMBERS, not single-shot power, so
## a Swarmling is cheap: it reuses the combat kit wholesale (Health, ElementMatchup
## DD-006, SlowEffect DD-004, the apply_elemental_hit juice bundle + the TASK-017
## element-tinted single-trigger death dissolve) but carries no per-member FSM — the
## SwarmGroup steers the cluster.
##
## It is FIRE-armored by default so ELECTRICITY is its 1.5x weak point AND the element
## that CHAINS between linked members (the legible DD-004 anti-dominance showcase:
## chain = good vs groups, Fire/Ice hit one at a time). It is on the Enemies layer (3)
## and in the `enemies` group so the player's magic — and the Electricity chain's
## proximity arc (ProjectileChain) — can find and hit it.
##
## A trimmed sibling of EmpireDrone: it shares the same hit/death code shape so the
## kill reads in the element's color language and overkill / a chain arc landing the
## same frame can never replay the death.
class_name Swarmling extends CharacterBody2D

## Armor element drives the DD-006 matchup. Defaults to FIRE -> weak to Electricity.
## @export so an encounter (or the SwarmGroup) can vary it.
@export var armor_type: SpellData.Element = SpellData.Element.FIRE

## TASK-010 juice scenes (PLACEHOLDERS). Optional; null-guarded at the hit path.
@export var damage_number_scene: PackedScene
@export var impact_spark_scene: PackedScene

## TASK-017 death burst scene (element-tinted; reuses impact_spark). Optional; falls
## back to impact_spark_scene. Null-guarded at the death path.
@export var death_effect_scene: PackedScene

## TASK-017: where the death burst is parented (defaults to the current scene so the
## burst outlives the freed Swarmling); a test can inject a scoped, auto-freed container.
var death_burst_parent: Node

## DD-004 Ice control: while active, halves any movement the group applies.
var _slow := SlowEffect.new()

const SLOW_TINT := Color(0.45, 0.7, 1.0, 1.0)

## TASK-017: latched once the death effect has begun so an overkill / chain arc / a
## re-emitted Health.died can never replay the dissolve or double-free.
var _dying := false

## TASK-017 death-beat tuning: dissolve fades alpha + shrinks the sprite, then frees.
const DISSOLVE_END_SCALE := 0.2

## TASK-010 feel tuning (small per the juice budget; a Swarmling is cheap).
const FLASH_TIME := 0.06
const KNOCKBACK_STRENGTH := 60.0
const KNOCKBACK_TIME := 0.10
const SHAKE_PER_HIT := 0.10

## TASK-010: emitted on every landed hit so a coordinator (or test) can react loosely.
signal hit(amount: float, effectiveness: float, dir: Vector2)

@onready var _health: Health = get_node_or_null("Health")
@onready var _sprite: ColorRect = get_node_or_null("Sprite")

const ARMOR_TINT := {
	SpellData.Element.FIRE: Color(0.85, 0.30, 0.20, 1.0),       # warm red
	SpellData.Element.ICE: Color(0.35, 0.65, 0.95, 1.0),        # cold blue
	SpellData.Element.ELECTRICITY: Color(0.95, 0.85, 0.25, 1.0),# arc yellow
}

var _armor_color := Color.WHITE


func _ready() -> void:
	# GDD 5.C: I am an Enemy (layer 3) so player magic + the chain detect me. I don't
	# mask anything for the slice (the SwarmGroup owns my movement; gravity is off).
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)
	# TASK-022 chain compatibility: join the `enemies` group (idempotent) so the
	# Electricity chain's proximity discovery can arc to me.
	if not is_in_group("enemies"):
		add_to_group("enemies")
	# FLOATING drone — gravity off (like EmpireDrone); the SwarmGroup steers the cluster.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_armor_color = ARMOR_TINT.get(armor_type, Color.WHITE)
	if _sprite != null:
		_sprite.color = _armor_color
	if _health != null and not _health.died.is_connected(_on_died):
		_health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	_slow.update(delta)
	_update_tint()


## DD-004 Ice control multiplier (0.5 while slowed, 1.0 otherwise). The SwarmGroup
## scales the cluster's drift by this so a slowed swarm reads as easier to clear.
func speed_multiplier() -> float:
	return _slow.multiplier()

func is_slowed() -> bool:
	return _slow.is_active()


# --- Combat: player magic lands on the Swarmling (mirrors EmpireDrone) --------

## Called by a Projectile on contact (DD-006 matchup + DD-004 slow + TASK-010 juice +
## TASK-017 death). Light by design — the swarm's threat is numbers.
func apply_elemental_hit(element: int, base_damage: float, slow: bool,
		hit_dir: Vector2 = Vector2.ZERO) -> void:
	var effectiveness := ElementMatchup.multiplier(element, armor_type)
	var dmg := base_damage * effectiveness
	if _health != null:
		_health.take_damage(dmg)
	if slow:
		_slow.apply()
	_flash()
	_apply_knockback(hit_dir)
	_spawn_spark(element, hit_dir)
	_shake_camera(effectiveness)
	hit.emit(dmg, effectiveness, hit_dir)


func _flash() -> void:
	if _sprite == null:
		return
	_sprite.color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_sprite, "color", _armor_color, FLASH_TIME)


func _apply_knockback(hit_dir: Vector2) -> void:
	var kb := Knockback.knockback_vector(hit_dir, KNOCKBACK_STRENGTH)
	if kb == Vector2.ZERO:
		return
	var dest := global_position + kb
	var tween := create_tween()
	tween.tween_property(self, "global_position", dest, KNOCKBACK_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _spawn_spark(element: int, hit_dir: Vector2) -> void:
	if impact_spark_scene == null:
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var spark := impact_spark_scene.instantiate()
	tree.current_scene.add_child(spark)
	spark.global_position = global_position - hit_dir.normalized() * 10.0
	if spark.has_method("burst"):
		spark.burst(element)


func _shake_camera(effectiveness: float) -> void:
	var shake := _find_screen_shake()
	if shake != null and shake.has_method("add_trauma"):
		shake.add_trauma(SHAKE_PER_HIT * effectiveness)


func _find_screen_shake() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("screen_shake")
	if nodes.is_empty():
		return null
	return nodes[0]


# --- Tint / death -------------------------------------------------------------

## Tint priority: dying (leave alone) > Ice slow > armor.
func _update_tint() -> void:
	if _dying or _sprite == null:
		return
	if _slow.is_active():
		_sprite.color = SLOW_TINT
	else:
		_sprite.color = _armor_color


func is_dying() -> bool:
	return _dying


## TASK-017 death: element-tinted dissolve + particle burst, THEN free. Single-trigger
## (guarded by `_dying`) so overkill / a chain arc landing the same frame can't replay
## the effect or double-free the member (the SwarmGroup also listens to drop the link).
func _on_died() -> void:
	if _dying:
		return
	_dying = true
	var tuning := DeathEffect.tuning_for(_health.max_health if _health != null else 0.0)
	_spawn_death_burst(armor_type)
	_shake_camera_amount(tuning.shake)
	_play_dissolve(float(tuning.dissolve_time))


func _spawn_death_burst(element: int) -> void:
	var scene: PackedScene = death_effect_scene if death_effect_scene != null else impact_spark_scene
	if scene == null:
		return
	var parent: Node = death_burst_parent
	if parent == null:
		var tree := get_tree()
		if tree == null or tree.current_scene == null:
			return
		parent = tree.current_scene
	var burst := scene.instantiate()
	parent.add_child(burst)
	if burst is Node2D:
		(burst as Node2D).global_position = global_position
	if burst.has_method("burst"):
		burst.burst(element)


func _play_dissolve(seconds: float) -> void:
	if _sprite == null:
		queue_free()
		return
	var tween := create_tween()
	tween.set_parallel(true)
	var faded := _sprite.color
	faded.a = 0.0
	tween.tween_property(_sprite, "color", faded, seconds)
	tween.tween_property(_sprite, "scale", Vector2.ONE * DISSOLVE_END_SCALE, seconds)
	tween.chain().tween_callback(queue_free)


func _shake_camera_amount(amount: float) -> void:
	var shake := _find_screen_shake()
	if shake != null and shake.has_method("add_trauma"):
		shake.add_trauma(amount)
