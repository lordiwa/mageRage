## Player magic projectile (Area2D). godot-game-dev SKILL Workflow 3 collision
## scheme: lives on the PlayerMagic layer (4), masks Enemies (3) ONLY, so it can
## never hit the hero. Carries the cast SpellData's element + damage; on contact
## with a drone it applies base_damage * DD-006 matchup to the drone's Health.
##
## DD-004 identities are honored at impact: Ice marks the hit to apply a slow;
## Electricity (max_targets > 1) can chain to additional drones (pierce) before
## freeing instead of dying on the first hit.
class_name Projectile extends Area2D

const LIFETIME := 2.0

var element: int = SpellData.Element.FIRE
var base_damage: float = 10.0
var speed: float = 400.0
var applies_slow: bool = false
var max_targets: int = 1

var _velocity := Vector2.ZERO
var _remaining_targets := 1
var _hit := {}      # instance_id -> true, so we never double-hit one drone
var _life := 0.0

func _ready() -> void:
	# PlayerMagic layer 4; detect Enemies (layer 3) only.
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(4, true)
	set_collision_mask_value(3, true)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

## Called by MagicManager.cast(): copy spell data and aim.
func setup(spell: SpellData, direction: Vector2) -> void:
	element = spell.element
	base_damage = spell.damage
	speed = spell.speed
	applies_slow = spell.applies_slow
	max_targets = maxi(spell.max_targets, 1)
	_remaining_targets = max_targets
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_velocity = dir * speed
	rotation = dir.angle()

func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_life += delta
	if _life >= LIFETIME:
		queue_free()

func _on_body_entered(body: Node) -> void:
	_try_hit(body)

func _on_area_entered(area: Node) -> void:
	_try_hit(area)

func _try_hit(target: Node) -> void:
	var drone := target
	if not drone.has_method("apply_elemental_hit"):
		# Maybe the Health/armor lives on a parent (e.g. a hurtbox area child).
		drone = target.get_parent()
		if drone == null or not drone.has_method("apply_elemental_hit"):
			return
	var id := drone.get_instance_id()
	if _hit.has(id):
		return
	_hit[id] = true
	drone.apply_elemental_hit(element, base_damage, applies_slow)
	_remaining_targets -= 1
	if _remaining_targets <= 0:
		queue_free()
