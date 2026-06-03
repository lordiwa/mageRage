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

## One-shot: when true, the next JumpState entry skips the launch impulse + dash
## reset. Set by FlightState when toggling flight off so leaving flight does not
## grant a free upward leap (and re-grant the air dash).
var suppress_jump_impulse := false

var _jump_buffer := 0.0

## Combat (TASK-006): the MagicManager holds Fire/Ice/Electricity SpellData and
## casts via the Mana child; Muzzle is the projectile spawn origin. All optional
## so the movement-only tests/fakes that don't add these nodes still work.
@onready var _magic: MagicManager = get_node_or_null("MagicManager")
@onready var _mana: Mana = get_node_or_null("Mana")
@onready var _muzzle: Node2D = get_node_or_null("Muzzle")

func _ready() -> void:
	# GDD 5.C: I am Player; I collide with Environment and Enemies.
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(3, true)

func _process(delta: float) -> void:
	# Record a jump press into the buffer regardless of which state is active,
	# so a press just before landing still fires (consumed by MoveState).
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)

	_process_magic(delta)

## Element swap + cast. Swapping is moment-to-moment (the GDD micro-loop); cast
## fires the equipped spell in the facing direction, paying mana via MagicManager.
func _process_magic(delta: float) -> void:
	if _magic == null:
		return
	if _mana != null:
		_mana.regenerate(delta)
	if Input.is_action_just_pressed("element_1"):
		_magic.equip(0)
	elif Input.is_action_just_pressed("element_2"):
		_magic.equip(1)
	elif Input.is_action_just_pressed("element_3"):
		_magic.equip(2)
	elif Input.is_action_just_pressed("element_cycle"):
		_magic.cycle()
	if Input.is_action_just_pressed("cast"):
		var origin: Node2D = _muzzle if _muzzle != null else self
		_magic.cast(origin, Vector2(facing, 0.0))

## Read-only accessors for the HUD (decoupled: the HUD polls, the player exposes).
func current_mana() -> float:
	return _mana.current_mana if _mana != null else 0.0

func max_mana() -> float:
	return _mana.max_mana if _mana != null else 0.0

func equipped_spell() -> SpellData:
	return _magic.equipped if _magic != null else null

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
