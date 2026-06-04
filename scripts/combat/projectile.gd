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
## TASK-022 per-element shot behavior (copied from SpellData in setup()).
var shot_type: int = SpellData.ShotType.SINGLE
var chain_radius: float = 160.0

var _velocity := Vector2.ZERO
var _remaining_targets := 1
var _hit := {}      # instance_id -> true, so we never double-hit one drone
var _life := 0.0

## TASK-022 per-element TRAIL: a short fading Line2D that records the last N world
## positions tinted by the element color (ProjectileStyle stays the color source).
const TRAIL_POINTS := 10
var _trail: Line2D = null

## TASK-014 readability: the Polygon2D body is restyled per element in setup() via
## ProjectileStyle (single source of truth). Cached so the style survives even if
## setup() runs before _ready (tests instance + setup in either order).
@onready var _sprite: Polygon2D = get_node_or_null("Sprite")
var _shape: int = ProjectileStyle.DEFAULT_SHAPE
var _color: Color = ProjectileStyle.DEFAULT_COLOR

## TASK-022 strong size differentiation per element (placeholder primitives): Fire
## reads heavier/bigger, Ice a large angular shard, Electricity a slim fast bolt.
## Applied as the Sprite's Polygon2D scale so ProjectileStyle stays the single
## source of truth for color/shape (we only scale, never re-type the polygon).
const ELEMENT_SCALE := {
	SpellData.Element.FIRE: Vector2(1.6, 1.6),          # heavy fireball
	SpellData.Element.ICE: Vector2(1.5, 1.3),           # large angular shard
	SpellData.Element.ELECTRICITY: Vector2(1.7, 0.7),   # long, slim bolt
	SpellData.Element.ANTIMATTER: Vector2(1.3, 1.3),
}
const DEFAULT_SCALE := Vector2(1.0, 1.0)
var _visual_scale := DEFAULT_SCALE

func _ready() -> void:
	# PlayerMagic layer 4; detect Enemies (layer 3) only.
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(4, true)
	set_collision_mask_value(3, true)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_ensure_trail()
	# Apply whatever style is cached (setup() may have run before we entered tree).
	_apply_visual()

## Called by MagicManager.cast_primary()/cast_secondary(): copy spell data and aim.
func setup(spell: SpellData, direction: Vector2) -> void:
	element = spell.element
	base_damage = spell.damage
	speed = spell.speed
	applies_slow = spell.applies_slow
	max_targets = maxi(spell.max_targets, 1)
	shot_type = spell.shot_type
	chain_radius = spell.chain_radius
	_remaining_targets = max_targets
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_velocity = dir * speed
	rotation = dir.angle()
	# TASK-014: style the body from the cast element (color + silhouette) so the
	# shot is readable at a glance. ProjectileStyle is the single source of truth.
	var style := ProjectileStyle.for_element(element)
	_color = style["color"]
	_shape = style["shape"]
	# TASK-022: per-element size so each shot reads as a different weight/silhouette.
	_visual_scale = ELEMENT_SCALE.get(element, DEFAULT_SCALE)
	_apply_visual()

## Push the cached element style onto the Polygon2D body. Null-safe: a projectile
## styled before it enters the tree applies on _ready instead.
func _apply_visual() -> void:
	if _sprite == null:
		_sprite = get_node_or_null("Sprite")
	if _sprite == null:
		return
	_sprite.color = _color
	_sprite.polygon = ProjectileStyle.polygon_for(_shape)
	# TASK-022: scale the silhouette per element (size differentiation) and tint
	# the trail with the SAME element color (ProjectileStyle remains the source).
	_sprite.scale = _visual_scale
	if _trail != null:
		_trail.default_color = Color(_color.r, _color.g, _color.b, 0.55)


## TASK-022: lazily build the fading per-element trail (a Line2D drawn in global
## space). Cheap placeholder juice — a few recent positions tapering in width and
## alpha, tinted by the element color. Null-safe so headless tests don't require it.
func _ensure_trail() -> void:
	if _trail != null:
		return
	_trail = Line2D.new()
	_trail.name = "Trail"
	_trail.width = 5.0
	_trail.top_level = true                       # draw in world space, not local
	_trail.default_color = Color(_color.r, _color.g, _color.b, 0.55)
	# Taper the tail: full width at the head, thinning toward the oldest point.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.15))
	curve.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = curve
	add_child(_trail)


## TASK-022: push the current world position onto the trail, capped to N points.
func _update_trail() -> void:
	if _trail == null:
		return
	_trail.add_point(global_position)
	while _trail.get_point_count() > TRAIL_POINTS:
		_trail.remove_point(0)

## Readability accessors (TASK-014 tests / HUD): the applied element tint + shape.
func visual_color() -> Color:
	return _color

func visual_shape() -> int:
	return _shape

func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_update_trail()
	_life += delta
	if _life >= LIFETIME:
		queue_free()

func _on_body_entered(body: Node) -> void:
	_try_hit(body)

func _on_area_entered(area: Node) -> void:
	_try_hit(area)

func _try_hit(target: Node) -> void:
	# A spent shot (already freed this frame) deals no further hits.
	if is_queued_for_deletion():
		return
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
	# TASK-010: pass the projectile's travel direction so the drone can drive
	# knockback + the hit signal away from where the shot came from.
	var hit_dir := _velocity.normalized()
	drone.apply_elemental_hit(element, base_damage, applies_slow, hit_dir)
	_remaining_targets -= 1
	# TASK-022 per-element shot behavior:
	#   SINGLE/PIERCE share the same straight-through bookkeeping (max_targets
	#   gates how many distinct enemies are hit; PIERCE never redirects).
	#   CHAIN additionally redirects toward the nearest not-yet-hit enemy in range.
	if _remaining_targets <= 0:
		queue_free()
		return
	if shot_type == SpellData.ShotType.CHAIN:
		_chain_to_next_target()


## TASK-022 CHAIN (Electricity): redirect velocity toward the nearest not-yet-hit
## enemy within chain_radius and keep flying (preserving speed). If there is no
## such enemy, the bolt is spent — free it. Discovery is via the "enemies" group,
## filtered by the already-hit set; the nearest-pick is the pure ProjectileChain
## helper. Null/empty safe (no group / no tree -> free).
func _chain_to_next_target() -> void:
	var tree := get_tree()
	if tree == null:
		queue_free()
		return
	var positions := PackedVector2Array()
	var nodes: Array = []
	for n in tree.get_nodes_in_group("enemies"):
		if not (n is Node2D):
			continue
		if _hit.has(n.get_instance_id()):
			continue
		if n.is_queued_for_deletion():
			continue
		positions.append((n as Node2D).global_position)
		nodes.append(n)
	var idx := ProjectileChain.nearest_index(global_position, positions, chain_radius)
	if idx == -1:
		# No unhit enemy within reach: the arc is spent.
		queue_free()
		return
	var next := nodes[idx] as Node2D
	var dir := (next.global_position - global_position)
	if dir == Vector2.ZERO:
		dir = _velocity.normalized()
	dir = dir.normalized()
	_velocity = dir * speed
	rotation = dir.angle()
