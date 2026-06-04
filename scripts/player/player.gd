## The hero CharacterBody2D. Owns shared movement state (abilities, facing, jump
## buffer); the per-state movement logic lives in the FSM children. Collision is
## set up per GDD 5.C: the hero IS on the Player layer and detects Environment +
## Enemies.
##
## In this movement demo all traversal abilities are pre-unlocked so every verb
## (run / leap / dash / glide / flight) is immediately usable.
class_name Player extends CharacterBody2D

## TASK-016 player-damage feedback. Emitted ONLY when an enemy hit actually LANDS
## (after the i-frame/amount gates pass and HP is subtracted) so the PlayerHUD can
## flash the red edge vignette + a hit-direction indicator. `hit_dir` is the
## projectile's TRAVEL direction (unit, or ZERO when unknown -> vignette only); the
## HUD points its arrow back toward the source along -hit_dir. Decoupled exactly
## like the HUD poll pattern: the player emits, the HUD listens.
signal damaged(amount: float, hit_dir: Vector2)

const JUMP_BUFFER := 0.10      # grace window before landing for a buffered jump

## Twin-stick aiming tuning.
const AIM_RADIUS := 120.0          # reticle orbit radius (px) for stick/PAD aim
const MUZZLE_OFFSET := 10.0        # muzzle distance from the body along the aim
const AIM_STICK_THRESHOLD := 0.2   # min right-stick magnitude to count as PAD aim
const _AIM_FACING_EPS := 0.05      # |aim.x| must exceed this to flip facing

## DD-012 soft aim-assist (aim magnetism) tunables — PROVISIONAL, to be tuned in
## playtest. @export so a designer can dial them in the inspector without code.
## The cast aim (NOT movement / raw aim) is biased toward the nearest enemy that
## sits within AIM_ASSIST_CONE_DEG of the manual aim and within AIM_ASSIST_RANGE:
## full snap inside AIM_ASSIST_INNER_CONE_DEG, partial pull out to the outer cone,
## no assist beyond it (deliberate aim elsewhere is respected). Set the outer cone
## to 0 to disable the assist entirely.
@export var aim_assist_cone_deg := 20.0         # outer cone half-angle (deg)
@export var aim_assist_inner_cone_deg := 8.0    # inner full-snap cone (deg)
@export var aim_assist_range := 400.0           # max assist distance (px)

## Which device last drove aiming. NONE = before any aim input (keyboard-only
## casting falls back to facing); PAD = right stick; MOUSE = cursor position.
enum AimDevice {NONE, PAD, MOUSE}

## Unlocked elements. Each gates a movement verb in the FSM:
## fire -> leap+dash, ice -> glide, electricity -> flight.
@export var abilities: Dictionary = {"fire": true, "ice": true, "electricity": true}

## -1 = facing left, +1 = facing right. Used by air dash for its burst direction.
var facing := 1.0

## Current unit aim vector (the cast direction + reticle direction). Defaults to
## RIGHT; while _aim_device == NONE the per-frame update derives it from facing.
var _aim := Vector2.RIGHT
var _aim_device: AimDevice = AimDevice.NONE

## DD-008 double-jump: number of jumps fired since leaving the ground. The first
## leap (Move -> Jump) registers as 1; a SECOND jump press in the air (with
## electricity) promotes to FlightState. Reset to 0 on landing.
var jump_count := 0

var _jump_buffer := 0.0

## TASK-028 anti-magic zone (DD-011): true while the hero stands inside an un-purged
## Empire dampening field. The flight FSM transitions (Jump/Glide double-jump) read
## this and gate FlightState OUT while it holds. Set by AntiMagicZone on body
## enter/exit and cleared on purge; defaults false so flight works everywhere else.
var _flight_suppressed := false

## Combat (TASK-006): the MagicManager holds Fire/Ice/Electricity SpellData and
## casts via the Mana child; Muzzle is the projectile spawn origin. All optional
## so the movement-only tests/fakes that don't add these nodes still work.
@onready var _magic: MagicManager = get_node_or_null("MagicManager")
@onready var _mana: Mana = get_node_or_null("Mana")
@onready var _muzzle: Node2D = get_node_or_null("Muzzle")

## Twin-stick reticle ("mira"). World-space child that shows the aim direction;
## optional so the headless/minimal-Player tests (no Reticle node) still run.
@onready var _reticle: Node2D = get_node_or_null("Reticle")

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

## TASK-016 subtle player hit-stop. Fed to HitStop.duration_for; deliberately
## gentle (a fraction of a neutral hit) so getting hit has weight WITHOUT being
## punishing. It stays strictly below an enemy super-effective freeze
## (duration_for(1.5)) — the loudest juice is reserved for the rarest beats.
## With BASE_DURATION 0.06: 0.5 -> ~0.03s vs the super-effective ~0.09s.
const PLAYER_HITSTOP_EFFECTIVENESS := 0.5

## TASK-016 light on-hit camera trauma. Small by design (the ScreenShake budget is
## reserved for the loudest beats); a player hit only nudges the frame.
const _HIT_TRAUMA := 0.18

## Record the current position as the respawn point. Called on _ready (so a death
## returns the hero to where the level placed it) and re-callable from tests.
func record_spawn() -> void:
	_spawn_position = global_position

## Enemy projectile damage entry point. Blocked entirely while i-frames are
## active (no damage, no stun). On a landed hit: subtract HP, open i-frames, fire
## the screen-space feedback (red vignette + hit-direction indicator via the
## `damaged` signal, a subtle hit-stop and a light camera nudge); if that hit was
## lethal, respawn at the recorded start with full health.
##
## TASK-016: `hit_dir` is the OPTIONAL projectile travel direction (default ZERO so
## every existing one-arg caller/test keeps working); the HUD points its arrow back
## along -hit_dir. Feedback fires only on a hit that LANDS — never on a blocked
## (i-frame) or non-hit (amount<=0) call.
func take_player_damage(amount: float, hit_dir: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0.0 or _health == null:
		return
	if _iframes.is_active():
		return
	_health.take_damage(amount)
	_iframes.trigger()
	_emit_hit_feedback(amount, hit_dir)
	if _health.is_dead():
		respawn()

## TASK-016: fire the screen-space damage feedback for a LANDED hit. Emits
## `damaged` (the HUD draws the red vignette + hit-direction arrow), triggers the
## subtle player hit-stop, and adds a light, budget-respecting camera trauma. All
## decoupled: signal out to the HUD, autoload for hit-stop, group for the shake —
## no control stun (DD-009).
func _emit_hit_feedback(amount: float, hit_dir: Vector2) -> void:
	damaged.emit(amount, hit_dir)
	# Subtle hit-stop via the HitStop autoload (gentler than enemy super-effective).
	var hit_stop := get_node_or_null("/root/HitStop")
	if hit_stop != null and hit_stop.has_method("freeze"):
		hit_stop.freeze(PLAYER_HITSTOP_EFFECTIVENESS)
	# Light camera nudge (reserved budget): poke any ScreenShake in the group.
	for shake in get_tree().get_nodes_in_group("screen_shake"):
		if shake.has_method("add_trauma"):
			shake.add_trauma(_HIT_TRAUMA)

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

	# Twin-stick aiming: resolve the RAW aim vector ONCE per frame, before
	# casting. Facing reads the raw manual aim (DD-012: the assist must not fight
	# the player's intent). The reticle/muzzle/cast use the ASSISTED aim so the
	# reticle shows where the shot will actually go (DD-012 legibility).
	_aim = aim_direction()
	apply_aim_to_facing()
	var assisted := cast_aim()
	if _muzzle != null:
		_muzzle.position = assisted * MUZZLE_OFFSET
	_update_reticle(assisted)

	_process_magic(delta)

## Last-used device wins for aiming: a mouse motion flags MOUSE as the active
## device; the actual cursor vector is sampled in aim_direction() each frame so
## it stays correct under the smoothed Camera2D.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Last-used device wins: a mouse move switches aiming to the cursor. The
		# actual cursor vector is sampled per-frame in aim_direction().
		_aim_device = AimDevice.MOUSE

# --- Twin-stick aiming -------------------------------------------------------

## Pure helper: the unit direction from `origin` to `target`. When the two
## coincide (degenerate / zero vector) fall back to the current facing direction
## so the result is always a deterministic unit vector.
func aim_from_point(origin: Vector2, target: Vector2) -> Vector2:
	var delta := target - origin
	if delta.length() <= 0.0001:
		return Vector2(facing, 0.0).normalized()
	return delta.normalized()

## The origin spells fire from (and the reticle/mouse aim measures from): the
## muzzle if present, else the body.
func aim_origin() -> Vector2:
	return _muzzle.global_position if _muzzle != null else global_position

## Resolve the current aim direction (last-used device wins):
##   1. Right stick beyond the deadzone -> PAD, normalized stick vector.
##   2. Else if the mouse is the active device -> vector to the cursor.
##   3. Else keep the last aim (persist); or, before any device (NONE), follow
##      facing so keyboard-only casting behaves like before.
func aim_direction() -> Vector2:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > AIM_STICK_THRESHOLD:
		_aim_device = AimDevice.PAD
		return stick.normalized()
	if _aim_device == AimDevice.MOUSE:
		return aim_from_point(aim_origin(), get_global_mouse_position())
	if _aim_device == AimDevice.NONE:
		return Vector2(facing, 0.0).normalized()
	return _aim   # persist the last aim when there is no new input

## True once any aim device (pad or mouse) has been used.
func is_aiming() -> bool:
	return _aim_device != AimDevice.NONE

## DD-012 soft aim-assist: the aim ACTUALLY used for casting (and the reticle).
## Biases the raw manual `_aim` toward the nearest enemy within the assist cone +
## range via the pure AimAssist.assist(); enemies come from the "enemies" group.
## Leaves `_aim` (movement / facing) untouched. With no enemies, a disabled cone
## (cone <= 0), or an enemy outside the cone, this returns the raw `_aim` so
## deliberate aim elsewhere is respected. Safe with no SceneTree (returns `_aim`).
func cast_aim() -> Vector2:
	if aim_assist_cone_deg <= 0.0:
		return _aim
	return AimAssist.assist(
		_aim,
		aim_origin(),
		_gather_enemy_positions(),
		aim_assist_cone_deg,
		aim_assist_inner_cone_deg,
		aim_assist_range,
	)

## Collect live enemy world positions from the "enemies" group for the assist.
## Skips non-Node2D and queued-for-deletion nodes. Empty when there is no tree.
func _gather_enemy_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var tree := get_tree()
	if tree == null:
		return positions
	for n in tree.get_nodes_in_group("enemies"):
		if not (n is Node2D):
			continue
		if (n as Node).is_queued_for_deletion():
			continue
		positions.append((n as Node2D).global_position)
	return positions

## Drive facing from the aim while a device is active and the aim has a clear
## horizontal component. Pure-vertical aim leaves facing untouched; when not
## aiming the FSM owns facing (movement direction).
func apply_aim_to_facing() -> void:
	if is_aiming() and absf(_aim.x) > _AIM_FACING_EPS:
		facing = signf(_aim.x)

## Pure helper: where the orbiting reticle sits in the player's local space for a
## given aim — on the orbit circle at AIM_RADIUS along the aim.
func reticle_local_position(aim: Vector2) -> Vector2:
	return aim * AIM_RADIUS

## Position the reticle for this frame using the ASSISTED aim, so the crosshair
## shows where the shot will actually go (DD-012 legibility). MOUSE aim snaps the
## reticle to the cursor in world space but rotated onto the assisted direction
## (the muzzle->reticle ray follows the assist); PAD/NONE orbit it around the
## player at AIM_RADIUS along the assisted aim. Null-guarded so a minimal Player
## without a Reticle child is fine.
func _update_reticle(aim: Vector2) -> void:
	if _reticle == null:
		return
	if _aim_device == AimDevice.MOUSE:
		# Keep the reticle's DISTANCE at the cursor but point it along the assisted
		# aim, so a magnetized shot and the crosshair stay co-linear.
		var reach := (get_global_mouse_position() - aim_origin()).length()
		_reticle.global_position = aim_origin() + aim * reach
	else:
		_reticle.position = reticle_local_position(aim)

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
	# DD-012: cast along the ASSISTED aim (magnetized toward a roughly-aimed-at
	# enemy), not the raw manual aim. The reticle already reflects this direction.
	var aim := cast_aim()
	if Input.is_action_just_pressed("cast_primary"):
		_magic.cast_primary(origin, aim)
	if Input.is_action_just_pressed("cast_secondary"):
		_magic.cast_secondary(origin, aim)

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

## TASK-028 (DD-011): the AntiMagicZone calls this on body enter (true) / exit (false)
## and on purge (false). The flight FSM transitions read is_flight_suppressed() so an
## un-purged dampening field disables flight without touching DD-008 anywhere else.
func set_flight_suppressed(value: bool) -> void:
	_flight_suppressed = value

func is_flight_suppressed() -> bool:
	return _flight_suppressed

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

# --- Test seams (headless aiming tests; not used by gameplay) -----------------

## Force the current aim vector + active device. Lets headless tests exercise the
## facing/reticle/cast wiring without synthesizing gamepad/mouse input.
func set_aim_for_test(aim: Vector2, device: AimDevice) -> void:
	_aim = aim
	_aim_device = device

## Fire a primary cast immediately using the current aim (mirrors the cast path
## in _process_magic, minus the input poll). For wiring tests. Resolves the
## manager by node name (untyped) so a duck-typed MagicManager double works.
func cast_primary_for_test() -> void:
	var mgr: Node = get_node_or_null("MagicManager")
	if mgr == null or not mgr.has_method("cast_primary"):
		return
	var origin: Node2D = _muzzle if _muzzle != null else self
	# Mirror gameplay: cast along the DD-012 assisted aim.
	mgr.cast_primary(origin, cast_aim())
