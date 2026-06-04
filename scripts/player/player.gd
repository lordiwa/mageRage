## The hero CharacterBody2D. Owns shared movement state (abilities, facing, jump
## buffer); the per-state movement logic lives in the FSM children. Collision is
## set up per GDD 5.C: the hero IS on the Player layer and detects Environment +
## Enemies.
##
## In this movement demo all traversal abilities are pre-unlocked so every verb
## (run / leap / dash / glide / flight) is immediately usable.
class_name Player extends CharacterBody2D

const JUMP_BUFFER := 0.10      # grace window before landing for a buffered jump

## Unlocked elements. Each gates a movement verb in the FSM:
## fire -> leap+dash, ice -> glide, electricity -> flight.
@export var abilities: Dictionary = {"fire": true, "ice": true, "electricity": true}

## -1 = facing left, +1 = facing right. Used by air dash for its burst direction.
var facing := 1.0

## DD-008 double-jump: number of jumps fired since leaving the ground. The first
## leap (Move -> Jump) registers as 1; a SECOND jump press in the air (with
## electricity) promotes to FlightState. Reset to 0 on landing.
var jump_count := 0

var _jump_buffer := 0.0

## Combat (TASK-006): the MagicManager holds Fire/Ice/Electricity SpellData and
## casts via the Mana child; Muzzle is the projectile spawn origin. All optional
## so the movement-only tests/fakes that don't add these nodes still work.
@onready var _magic: MagicManager = get_node_or_null("MagicManager")
@onready var _mana: Mana = get_node_or_null("Mana")
@onready var _muzzle: Node2D = get_node_or_null("Muzzle")

## DD-009 player damage: a Health child takes enemy-projectile damage, gated by
## brief i-frames (no control stun); death respawns at the recorded start.
## Optional so movement-only fakes without a Health child still run.
@onready var _health: Health = get_node_or_null("Health")
@onready var _sprite: ColorRect = get_node_or_null("Sprite")
var _iframes := Invulnerability.new()
var _spawn_position := Vector2.ZERO
var _blink_accum := 0.0

# --- DD-009 player-damage API ------------------------------------------------

## i-frame blink tuning (placeholder visual feedback; no control stun per DD-009).
const _BLINK_PERIOD := 0.12

## Record the current position as the respawn point. Called on _ready (so a death
## returns the hero to where the level placed it) and re-callable from tests.
func record_spawn() -> void:
	_spawn_position = global_position

## Enemy projectile damage entry point. Blocked entirely while i-frames are
## active (no damage, no stun). On a landed hit: subtract HP, open i-frames; if
## that hit was lethal, respawn at the recorded start with full health.
func take_player_damage(amount: float) -> void:
	if amount <= 0.0 or _health == null:
		return
	if _iframes.is_active():
		return
	_health.take_damage(amount)
	_iframes.trigger()
	if _health.is_dead():
		respawn()

## Tick the i-frame window. Called from _process; exposed for unit tests.
func tick_iframes(delta: float) -> void:
	_iframes.update(delta)

## True while the player cannot take damage (drives the blink, not movement).
func is_invulnerable() -> bool:
	return _iframes.is_active()

## DD-009 respawn: full health, back to the recorded spawn (deterministic, no
## hard penalty — demo). TASK-012: open brief spawn-protection i-frames so an
## in-flight enemy projectile can't instantly re-hit the freshly respawned hero
## (fair/deterministic, DD-001).
func respawn() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	if _health != null:
		_health.revive()
	_iframes = Invulnerability.new()
	_iframes.trigger()
	if _sprite != null:
		_sprite.visible = true

## HUD accessors (decoupled poll, like mana).
func player_hp() -> float:
	return _health.current_health if _health != null else 0.0

func max_player_hp() -> float:
	return _health.max_health if _health != null else 0.0

func _ready() -> void:
	# GDD 5.C: I am Player; I collide with Environment and Enemies.
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(3, true)
	# DD-009: capture the start position so death respawns the hero here.
	record_spawn()

func _process(delta: float) -> void:
	# Record a jump press into the buffer regardless of which state is active,
	# so a press just before landing still fires (consumed by MoveState).
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)

	tick_iframes(delta)
	_process_blink(delta)
	_process_magic(delta)

## DD-009: blink the sprite while invulnerable (readable i-frame feedback, no
## control stun). Sprite stays visible when not invulnerable.
func _process_blink(delta: float) -> void:
	if _sprite == null:
		return
	if is_invulnerable():
		_blink_accum += delta
		if _blink_accum >= _BLINK_PERIOD:
			_blink_accum = 0.0
			_sprite.visible = not _sprite.visible
	elif not _sprite.visible:
		_sprite.visible = true

## DD-008 loadout swap + dual-trigger cast. Selecting an element promotes it to
## the primary slot (demoting the prior primary to secondary). cast_primary fires
## the primary slot, cast_secondary the secondary — both in the facing direction,
## paying mana via MagicManager.
func _process_magic(delta: float) -> void:
	if _magic == null:
		return
	if _mana != null:
		_mana.regenerate(delta)
	if Input.is_action_just_pressed("element_1"):
		_magic.select(0)
	elif Input.is_action_just_pressed("element_2"):
		_magic.select(1)
	elif Input.is_action_just_pressed("element_3"):
		_magic.select(2)
	var origin: Node2D = _muzzle if _muzzle != null else self
	if Input.is_action_just_pressed("cast_primary"):
		_magic.cast_primary(origin, Vector2(facing, 0.0))
	if Input.is_action_just_pressed("cast_secondary"):
		_magic.cast_secondary(origin, Vector2(facing, 0.0))

## Read-only accessors for the HUD (decoupled: the HUD polls, the player exposes).
func current_mana() -> float:
	return _mana.current_mana if _mana != null else 0.0

func max_mana() -> float:
	return _mana.max_mana if _mana != null else 0.0

## DD-008 HUD accessors: the primary/secondary equipped elements.
func primary_spell() -> SpellData:
	return _magic.primary if _magic != null else null

func secondary_spell() -> SpellData:
	return _magic.secondary if _magic != null else null

## DD-008 double-jump bookkeeping. The FSM calls register_jump() when a leap
## fires and reset_jumps() on landing; JumpState/GlideState read jump_count to
## decide whether a fresh jump press is the genuine second jump (-> flight).
func register_jump() -> void:
	jump_count += 1

func reset_jumps() -> void:
	jump_count = 0

## Peek: is a jump currently buffered? Does NOT clear the buffer, so a state can
## check the floor/coyote condition before committing to fire.
func has_buffered_jump() -> bool:
	return _jump_buffer > 0.0

## Returns true once if a jump was buffered, clearing it. Call only when the jump
## actually fires.
func consume_jump_buffer() -> bool:
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		return true
	return false
