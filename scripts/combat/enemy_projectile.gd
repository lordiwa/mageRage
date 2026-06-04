## DD-009 enemy projectile (Area2D). The drone's shot that closes the combat loop
## back onto the hero. Collision per godot-game-dev SKILL Workflow 3, extended with
## a NEW physics layer: lives on EnemyAttack (layer 5), masks Player (layer 2)
## ONLY — it can hit the hero and nothing else (not other drones, not itself).
##
## Deliberately SLOWER than the player's projectile so it reads and is dodgeable
## (game-design SKILL: telegraphing/fairness, DD-001). On contact it damages the
## player's Health via Player.take_player_damage (which gates on i-frames); frees
## on hit or after its lifetime.
class_name EnemyProjectile extends Area2D

const LIFETIME := 3.0
## Slower than the player's 400 px/s bolt so it stays readable/dodgeable.
const SPEED := 180.0

var damage: float = 12.0
var _velocity := Vector2.ZERO
var _life := 0.0

func _ready() -> void:
	# EnemyAttack layer 5; detect Player (layer 2) ONLY.
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(5, true)
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

## Called by EmpireDrone.fire_at_player(): aim + damage. Direction is normalized;
## a zero direction defaults to RIGHT so the shot never stalls.
func setup(direction: Vector2, dmg: float) -> void:
	damage = dmg
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_velocity = dir * SPEED
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
	var hero := target
	if not hero.has_method("take_player_damage"):
		# The damage handler may live on a parent (e.g. a hurtbox child).
		hero = target.get_parent()
		if hero == null or not hero.has_method("take_player_damage"):
			return
	resolve_hit(hero)

## Pure-ish hit decision (TASK-012, DD-001): a hit lands only when the hero is NOT
## currently invulnerable. While i-frames are open the shot passes through, so
## i-frames truly mean untouchable. A hero without the gate (older fakes) is
## treated as always hittable.
func should_land_hit(hero: Node) -> bool:
	if hero.has_method("is_invulnerable"):
		return not hero.is_invulnerable()
	return true

## Apply the hit if it should land: damage the hero AND consume the projectile.
## If the hero is invulnerable, pass through — no damage, no queue_free().
func resolve_hit(hero: Node) -> void:
	if not should_land_hit(hero):
		return
	# TASK-016: thread the projectile's TRAVEL direction so the HUD can point its
	# hit-direction indicator back toward the source (-hit_dir). Defaults safely to
	# ZERO before setup() runs (vignette-only on the HUD side).
	hero.take_player_damage(damage, _velocity.normalized())
	queue_free()
