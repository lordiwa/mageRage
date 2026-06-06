## TASK-052 animation controller for the hero AnimatedSprite2D.
##
## Listens to StateMachine.state_changed and each frame reads velocity / facing /
## casting / hurt to select the correct animation and set flip_h on the
## AnimatedSprite2D. Keeps the selection logic in a PURE static function so it is
## unit-testable without a scene.
##
## State -> animation mapping:
##   MoveState  + on_floor + |vel.x| <= WALK_THRESHOLD  -> "idle"  (loop)
##   MoveState  + on_floor + |vel.x| > WALK_THRESHOLD   -> "walk"  (loop)
##   JumpState  + vel.y <= 0                             -> "jump"  (one-shot/hold)
##   JumpState  + vel.y > 0                              -> "fall"  (one-shot/hold)
##   GlideState                                          -> "fall"  (documented gap)
##   FlightState                                         -> "flight" (loop)
##   casting (any state)                                 -> "attack" (one-shot overlay)
##   hurt (any state, highest priority)                  -> "hurt"  (one-shot)
##
## Gaps documented:
##   - GlideState: no dedicated PixelLab anim; uses "fall" as fallback.
##   - Death: no dedicated anim; holds last hurt frame (respawn resets via Player).
class_name AnimationController extends Node

## Minimum |vel.x| to play the walk animation (below this: idle).
const WALK_THRESHOLD := 10.0

## The AnimatedSprite2D child of the player, resolved in _ready.
var _sprite: AnimatedSprite2D

## Whether the attack one-shot is currently playing (prevents re-triggering).
var _attack_playing := false

## Reference to the player node (set from player.gd on _ready).
var _player: CharacterBody2D

## Current FSM state name (updated via state_changed signal).
var _current_state := "MoveState"

## Whether the hurt animation is currently playing.
var _hurt_playing := false


func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if _player == null:
		return
	_sprite = _player.get_node_or_null("Sprite") as AnimatedSprite2D
	if _sprite == null:
		return
	# Connect to the StateMachine's state_changed signal.
	var sm := _player.get_node_or_null("StateMachine")
	if sm != null and sm.has_signal("state_changed"):
		sm.state_changed.connect(_on_state_changed)
	# Connect animation_finished to handle one-shot returns.
	_sprite.animation_finished.connect(_on_animation_finished)
	# Start in idle.
	_sprite.play("idle")


func _on_state_changed(state_name: String) -> void:
	_current_state = state_name


func _on_animation_finished() -> void:
	if _attack_playing:
		_attack_playing = false
		# Return to movement animation after attack.
		_update_movement_animation()
	if _hurt_playing:
		_hurt_playing = false
		_update_movement_animation()


func _physics_process(_delta: float) -> void:
	if _sprite == null or _player == null:
		return
	# Update flip_h every frame from facing.
	# _player is CharacterBody2D (Player subclass); use get() for duck-typed access,
	# explicitly typed as Variant to avoid the inferred-Variant warning-as-error.
	var player_facing: Variant = _player.get("facing")
	if player_facing != null:
		_sprite.flip_h = facing_to_flip_h(float(player_facing))
	# Drive animation selection (hurt / attack have priority).
	_drive_animation()


## Drive animation state from current conditions.
func _drive_animation() -> void:
	if _sprite == null or _player == null:
		return
	var vel: Vector2 = _player.velocity
	var on_floor: bool = _player.is_on_floor()
	# Hurt flag: check if we just took a hit this frame (player exposes is_invulnerable
	# in the frame a hit lands because _iframes.trigger() runs synchronously in
	# take_player_damage before this _physics_process). We detect the frame the
	# animation isn't already playing.
	# Casting: true when an attack anim was just requested externally.
	# (The casting flag is pushed via play_attack() from player.gd.)
	# Both one-shots are managed externally via play_attack() / play_hurt() calls
	# from player.gd — here we only update the movement animation when not in a one-shot.
	if _attack_playing or _hurt_playing:
		return
	var anim := select_animation(_current_state, vel, on_floor, false, false)
	if _sprite.animation != anim:
		_sprite.play(anim)


## Update the movement animation without touching one-shot state.
func _update_movement_animation() -> void:
	if _sprite == null or _player == null:
		return
	var vel: Vector2 = _player.velocity
	var on_floor: bool = _player.is_on_floor()
	var anim := select_animation(_current_state, vel, on_floor, false, false)
	_sprite.play(anim)


## Play the attack one-shot. Called from player.gd when a cast actually fires.
func play_attack() -> void:
	if _sprite == null:
		return
	_attack_playing = true
	_hurt_playing = false
	_sprite.play("attack")


## Play the hurt one-shot. Called from player.gd when a hit lands.
func play_hurt() -> void:
	if _sprite == null:
		return
	_hurt_playing = true
	_attack_playing = false
	_sprite.play("hurt")


## --- Pure static API (unit-testable without a scene) -------------------------

## Select the animation name for the given state. This is the canonical mapping:
##   hurt (highest priority) -> "hurt"
##   casting                 -> "attack"
##   FlightState             -> "flight"
##   GlideState              -> "fall" (documented fallback; no dedicated anim)
##   JumpState + vel.y <= 0  -> "jump"
##   JumpState + vel.y > 0   -> "fall"
##   MoveState + |vel.x|>thr -> "walk"
##   MoveState otherwise     -> "idle"
##   unknown                 -> "idle" (safe default)
static func select_animation(state_name: String, velocity: Vector2,
		_on_floor: bool, casting: bool, hurt: bool) -> String:
	# Hurt is highest priority (a landed hit is the loudest beat).
	if hurt:
		return "hurt"
	# Casting overrides movement animations with the attack one-shot.
	if casting:
		return "attack"
	match state_name:
		"FlightState":
			return "flight"
		"GlideState":
			# Gap: no dedicated glide anim. Fallback to "fall" (descend frame).
			return "fall"
		"JumpState":
			return "jump" if velocity.y <= 0.0 else "fall"
		"MoveState":
			if absf(velocity.x) > WALK_THRESHOLD:
				return "walk"
			return "idle"
		_:
			# Unknown / future states -> safe idle fallback.
			return "idle"


## Convert a facing value to AnimatedSprite2D.flip_h.
## The EAST frames naturally face right; flip for left-facing.
static func facing_to_flip_h(facing: float) -> bool:
	return facing < 0.0
