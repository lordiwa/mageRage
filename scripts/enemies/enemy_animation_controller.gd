## TASK-056 reusable animation controller for the sector_02 combat enemies.
##
## ONE script drives all three enemies (EmpireDrone, ShieldDrone, Charger): it
## listens to StateMachine.state_changed, and each physics frame reads the enemy's
## velocity + attacking/hurt one-shot flags to select the correct animation and set
## flip_h on the sibling AnimatedSprite2D "Sprite". The selection logic is a PURE
## static function so it is unit-testable without a scene (mirrors the hero's
## AnimationController, TASK-052).
##
## State -> animation mapping (handles BOTH drone and charger state names):
##   hurt (highest priority)  -> "hurt"   (one-shot)
##   attacking (drone cast)   -> "attack" (one-shot)
##   DronePatrolState         -> "idle"   (loop)
##   DroneChaseState          -> "walk"   (loop)
##   DroneAttackState         -> "attack"
##   ChargerPatrolState       -> "idle"
##   ChargerChaseState        -> "walk"
##   ChargerWindUpState       -> "windup"
##   ChargerChargeState       -> "charge"
##   ChargerRecoveryState     -> "idle"   (no dedicated recovery anim; fallback)
##   unknown / future state   -> "idle"   (safe default)
##
## Facing: the enemies have no `facing` field — they face the direction they move.
## The controller remembers the last non-trivial horizontal velocity sign and flips
## the EAST-facing frames left when that sign is negative (hero flip_h convention).
##
## Documented gap: death has no dedicated animation. The enemy's _on_died() runs its
## dissolve on whatever frame is showing (typically the last "hurt" frame), matching
## the hero's documented death fallback.
class_name EnemyAnimationController extends Node

## Minimum |vel.x| (px/s) before the controller updates the remembered facing sign;
## below this the last facing is held (so a stationary idle/windup keeps its facing).
const FACING_EPS := 4.0

## The AnimatedSprite2D sibling, resolved in _ready.
var _sprite: AnimatedSprite2D

## The enemy CharacterBody2D (parent), resolved in _ready.
var _enemy: CharacterBody2D

## Current FSM state name (updated via state_changed).
var _current_state := ""

## One-shot flags. While either is playing the movement animation is suppressed
## until animation_finished returns control.
var _attack_playing := false
var _hurt_playing := false

## Last remembered horizontal facing sign (+1 right / -1 left). Starts facing right
## (east frames natural orientation).
var _facing := 1.0


func _ready() -> void:
	_enemy = get_parent() as CharacterBody2D
	if _enemy == null:
		return
	_sprite = _enemy.get_node_or_null("Sprite") as AnimatedSprite2D
	if _sprite == null:
		return
	var sm := _enemy.get_node_or_null("StateMachine")
	if sm != null and sm.has_signal("state_changed"):
		sm.state_changed.connect(_on_state_changed)
		# Seed the current state from the machine if it is already active.
		var cur: Variant = sm.get("current_state")
		if cur != null and cur is Node:
			_current_state = (cur as Node).name
	if not _sprite.animation_finished.is_connected(_on_animation_finished):
		_sprite.animation_finished.connect(_on_animation_finished)
	# Start on idle (or whatever the seeded state maps to).
	_sprite.play(_movement_anim())


func _on_state_changed(state_name: String) -> void:
	_current_state = state_name


func _on_animation_finished() -> void:
	if _attack_playing:
		_attack_playing = false
		_sprite.play(_movement_anim())
	if _hurt_playing:
		_hurt_playing = false
		_sprite.play(_movement_anim())


func _physics_process(_delta: float) -> void:
	if _sprite == null or _enemy == null:
		return
	# Update facing from movement direction (hold last facing while ~stationary).
	var vx: float = _enemy.velocity.x
	if absf(vx) > FACING_EPS:
		_facing = signf(vx)
	_sprite.flip_h = facing_to_flip_h(_facing)
	# One-shots own the sprite until they finish.
	if _attack_playing or _hurt_playing:
		return
	var anim := select_animation(_current_state, _enemy.velocity, false, false)
	if _sprite.animation != anim:
		_sprite.play(anim)


## Movement-only animation (no one-shot), used to return after attack/hurt.
func _movement_anim() -> String:
	if _enemy == null:
		return "idle"
	return select_animation(_current_state, _enemy.velocity, false, false)


## Play the attack one-shot. Called by the enemy when a cast/projectile fires.
func play_attack() -> void:
	if _sprite == null:
		return
	if not _sprite.sprite_frames or not _sprite.sprite_frames.has_animation("attack"):
		return
	_attack_playing = true
	_hurt_playing = false
	_sprite.play("attack")


## Play the hurt one-shot. Called by the enemy when a hit lands.
func play_hurt() -> void:
	if _sprite == null:
		return
	if not _sprite.sprite_frames or not _sprite.sprite_frames.has_animation("hurt"):
		return
	_hurt_playing = true
	_attack_playing = false
	_sprite.play("hurt")


## --- Pure static API (unit-testable without a scene) -------------------------

## Select the animation name for the given state. Handles BOTH drone and charger
## state names. `hurt` has the highest priority, then `attacking`, then the state.
static func select_animation(state_name: String, _velocity: Vector2,
		attacking: bool, hurt: bool) -> String:
	if hurt:
		return "hurt"
	if attacking:
		return "attack"
	match state_name:
		"DronePatrolState", "ChargerPatrolState":
			return "idle"
		"DroneChaseState", "ChargerChaseState":
			return "walk"
		"DroneAttackState":
			return "attack"
		"ChargerWindUpState":
			return "windup"
		"ChargerChargeState":
			return "charge"
		"ChargerRecoveryState":
			# No dedicated recovery anim; documented fallback to idle (stagger reads
			# via the EXPOSED tint, not a unique frame).
			return "idle"
		_:
			# Unknown / future state -> safe idle fallback.
			return "idle"


## Convert a facing sign to AnimatedSprite2D.flip_h. EAST frames face right
## natively; flip for left-facing. (Same convention as the hero controller.)
static func facing_to_flip_h(facing: float) -> bool:
	return facing < 0.0
