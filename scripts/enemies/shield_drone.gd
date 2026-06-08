## TASK-020 Shield Drone (Drone con escudo direccional) — a FLOATING guardian that
## rewards reading the telegraph + aim/positioning (pillar 1: a sentry raising its
## ward, not gleeful evil). It mirrors the EmpireDrone wholesale (floating
## CharacterBody2D, node-FSM Patrol/Chase/Attack, Health, ElementMatchup DD-006,
## SlowEffect DD-004, the apply_elemental_hit juice bundle + TASK-017 single-trigger
## death) and ADDS a DIRECTIONAL frontal shield:
##
##   - While NOT winding up, the shield TRACKS the player and BLOCKS player
##     projectiles that strike its frontal arc — 0 damage, no slow, no Health loss
##     (just a small "clink" flash). Its back/flank stay vulnerable.
##   - During its own attack WIND-UP the shield DROPS (open) — a fair, telegraphed
##     punish window (DD-001): the SAME frontal shot then lands full DD-006 damage.
##
## The pure arc/state rules live in ShieldLogic (scene-free, unit-tested). The
## shield up/down + facing are readable via a Shield ColorRect placed in front of
## the body (tinted/visible when up, dimmed/hidden when down).
class_name ShieldDrone extends CharacterBody2D

## Armor element drives the DD-006 matchup. Defaults to ICE (weak to Fire) so the
## encounter has variety vs the Fire-armored Charger/swarm. @export configurable.
@export var armor_type: SpellData.Element = SpellData.Element.ICE

## TASK-010 juice scenes (PLACEHOLDERS). Optional so unit tests / bare drones run
## without them; null-guarded at the hit path.
@export var damage_number_scene: PackedScene
@export var impact_spark_scene: PackedScene

## TASK-017 death burst scene (element-tinted; reuses impact_spark). Optional;
## null-guarded. Falls back to impact_spark_scene if left unassigned.
@export var death_effect_scene: PackedScene

## TASK-017: where the death burst is parented (defaults to the current scene so the
## burst outlives the freed drone); a test can inject a scoped, auto-freed container.
var death_burst_parent: Node

## DD-009 AI tuning (provisional). Transition LOGIC lives in DroneAi (pure) — these
## are just the thresholds fed to it.
@export var aggro_range: float = 280.0
@export var attack_range: float = 240.0
@export var attack_cooldown: float = 1.6
@export var projectile_damage: float = 12.0

## TASK-020 shield tuning. Half-arc of the frontal cone the shield covers (radians).
## ~80deg half-arc => a ~160deg frontal cone: dead-on + oblique frontal shots are
## blocked, true flank/behind shots slip past. @export so an encounter can tune it.
@export var shield_arc_halfwidth_deg: float = 80.0

## DD-009 enemy projectile (PLACEHOLDER). Optional; null-guarded at the fire path.
@export var enemy_projectile_scene: PackedScene

## The hero to chase/shoot. Resolved on _ready from the "player" group; settable in
## tests. Loosely typed so a fake target works headless.
var target: Node2D

## TASK-069: SHMUP-SCOPED movement opt-in. Default FALSE so sector_01/02 drones are
## BYTE-IDENTICAL (the FSM Patrol/Chase own movement exactly as before). The shmup
## spawner flips it TRUE on streamed enemies so the MOVEMENT states YIELD position
## control (the spawner owns the body per its motion pattern), while the Attack
## telegraph+fire path (and the shield block) still run. MOVEMENT-only.
var shmup_motion := false

## Spawn point for the Patrol hover (captured on _ready).
var spawn_position := Vector2.ZERO

## DD-004 Ice control: while active, halves chase speed + attack rate.
var _slow := SlowEffect.new()

## Seconds since the last shot; gates the cooldown via DroneAi.cooldown_ready.
var _time_since_attack := 999.0

## TASK-020 shield state. `_shield_facing` is the unit direction the shield faces
## (toward the player); `_shield_up` is false during the attack wind-up (dropped).
var _shield_facing := Vector2.RIGHT
var _shield_up := true

## Wind-up color flash while telegraphing (placeholder readable tell).
const TELEGRAPH_COLOR := Color(1.0, 0.95, 0.6, 1.0)
const SLOW_TINT := Color(0.45, 0.7, 1.0, 1.0)
var _telegraphing := false

## TASK-017: latched once the death effect has started so an overkill / chain hit or
## a re-emitted Health.died can never replay the dissolve or double-free.
var _dying := false

const DISSOLVE_END_SCALE := 0.2

## TASK-020 shield visual tuning. The shield reads as a bright UP tint and a dim,
## near-transparent DOWN state so the punish window is obvious. It is parented at a
## small offset in front of the body and rotated to the facing each frame.
const SHIELD_UP_COLOR := Color(0.45, 0.85, 1.0, 0.9)     # bright cyan ward (up)
const SHIELD_DOWN_COLOR := Color(0.45, 0.85, 1.0, 0.12)  # faint ghost (dropped)
const SHIELD_OFFSET := 22.0                              # px in front of the body

## TASK-010: emitted on every landed hit so a coordinator (or test) can react. `dir`
## is the player projectile's travel direction at contact. A BLOCKED hit emits with
## amount 0 / effectiveness 0 so listeners can still read the clink.
signal hit(amount: float, effectiveness: float, dir: Vector2)

@onready var _health: Health = get_node_or_null("Health")
@onready var _label: Label = get_node_or_null("Label")
## TASK-056: the body sprite is now an AnimatedSprite2D. Typed as CanvasItem so the
## flash / tint / dissolve drive `modulate` (works on the AnimatedSprite2D and on the
## bare ColorRect built by unit tests); null-guarded for bare-scene tests.
@onready var _sprite: CanvasItem = get_node_or_null("Sprite")
## TASK-056: the directional-shield VISUAL ColorRect was removed from the real scene
## (the PixelLab body sprite replaces the greybox). The shield BLOCK gameplay is
## unchanged (it lives in ShieldLogic + the up/down state); this node is now present
## only in unit tests (which build a bare ColorRect "Shield"), so every access stays
## null-guarded. The shield up/down VISUAL tell is a documented gap for a later pass.
@onready var _shield: ColorRect = get_node_or_null("Shield")
## TASK-056: state-driven animation controller (one-shot attack/hurt + flip_h).
@onready var _anim_ctrl: Node = get_node_or_null("AnimationController")

const ARMOR_TINT := {
	SpellData.Element.FIRE: Color(0.85, 0.30, 0.20, 1.0),
	SpellData.Element.ICE: Color(0.35, 0.65, 0.95, 1.0),
	SpellData.Element.ELECTRICITY: Color(0.95, 0.85, 0.25, 1.0),
}

## TASK-010 feel tuning (small / sparing per the juice budget).
const FLASH_TIME := 0.06
const KNOCKBACK_STRENGTH := 70.0
const KNOCKBACK_TIME := 0.10
const SHAKE_PER_HIT := 0.18
## A blocked shot gets a tiny "clink" trauma (much smaller than a real hit).
const BLOCK_SHAKE := 0.06

var _armor_color := Color.WHITE


func _ready() -> void:
	# GDD 5.C: I am an Enemy (layer 3) so player magic detects me; collide with
	# Environment (layer 1) so I rest. The FSM drives all movement (gravity off).
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	# TASK-022 chain compatibility: join the `enemies` group (idempotent).
	if not is_in_group("enemies"):
		add_to_group("enemies")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_armor_color = ARMOR_TINT.get(armor_type, Color.WHITE)
	if _sprite != null:
		_sprite.modulate = _armor_color
	if _health != null:
		_health.health_changed.connect(_on_health_changed)
		_health.died.connect(_on_died)
	spawn_position = global_position
	_resolve_target()
	_refresh_shield_visual()
	_refresh_label(0.0)


## DD-009: tick the Ice slow + attack cooldown each physics frame, track the shield
## toward the player (unless winding up), and refresh the visuals.
func _physics_process(delta: float) -> void:
	var was_slowed := _slow.is_active()
	_slow.update(delta)
	_time_since_attack += delta
	_track_shield()
	_update_tint()
	if was_slowed and not _slow.is_active():
		_refresh_label(0.0, false)


## Aim the shield at the player while it is UP; while it is DOWN (wind-up) leave the
## facing frozen (the drop is the telegraph — it does not keep re-aiming).
func _track_shield() -> void:
	if _shield_up and target != null:
		var facing := ShieldLogic.shield_facing_toward(global_position, target.global_position)
		if facing != Vector2.ZERO:
			_shield_facing = facing
	_refresh_shield_visual()


## Find the player (group "player"). Loose so a unit test can set `target` itself.
func _resolve_target() -> void:
	if target != null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var players := tree.get_nodes_in_group("player")
	if not players.is_empty():
		target = players[0]

# --- Combat: player magic lands on the Shield Drone --------------------------

## Called by a Projectile on contact. FIRST checks the directional shield: a frontal
## hit while the shield is UP is BLOCKED (0 damage, no slow, no Health change — just
## a small clink/flash). Otherwise applies base * DD-006 matchup + the TASK-010 juice
## + DD-004 slow + TASK-017 death, exactly like the EmpireDrone.
##
## `hit_dir` is the projectile's TRAVEL direction (it approaches from `-hit_dir`);
## defaults to ZERO so older callers/tests still work (a zero dir is never blocked).
func apply_elemental_hit(element: int, base_damage: float, slow: bool,
		hit_dir: Vector2 = Vector2.ZERO) -> void:
	if _is_hit_blocked(hit_dir):
		_on_blocked(hit_dir)
		return
	var effectiveness := ElementMatchup.multiplier(element, armor_type)
	var dmg := base_damage * effectiveness
	if _health != null:
		_health.take_damage(dmg)
	# DD-004 Ice = control: an Ice hit starts/refreshes the real SLOW effect.
	if slow:
		_slow.apply()
	_refresh_label(dmg, _slow.is_active())
	# TASK-056: play the hurt one-shot only on a REAL landed hit (blocked shots
	# return early above and never reach here).
	if _anim_ctrl != null and _anim_ctrl.has_method("play_hurt"):
		_anim_ctrl.play_hurt()
	# --- TASK-010 hit feedback ------------------------------------------------
	_flash()
	_apply_knockback(hit_dir)
	_spawn_damage_number(dmg, effectiveness)
	_spawn_spark(element, hit_dir)
	_shake_camera(effectiveness)
	_do_hit_stop(effectiveness)
	hit.emit(dmg, effectiveness, hit_dir)


## TASK-020 block test: a hit is blocked when the shield is UP and the shot strikes
## the frontal arc (delegates to the pure ShieldLogic predicate).
func _is_hit_blocked(hit_dir: Vector2) -> bool:
	return ShieldLogic.is_blocked(hit_dir, _shield_facing,
		deg_to_rad(shield_arc_halfwidth_deg), _shield_up)


## Blocked-shot feedback: a small "clink" — flash the SHIELD white briefly, a tiny
## spark at the shield face, a light camera tick. No Health loss, no slow, no death.
func _on_blocked(hit_dir: Vector2) -> void:
	if _shield != null:
		var prev := _shield.color
		_shield.color = Color.WHITE
		var tween := create_tween()
		tween.tween_property(_shield, "color", prev, FLASH_TIME)
	_spawn_spark(armor_type, hit_dir)
	_shake_camera_amount(BLOCK_SHAKE)
	_refresh_label(0.0, _slow.is_active(), true)
	# Signal the clink with zeroed damage so listeners can tell it was negated.
	hit.emit(0.0, 0.0, hit_dir)


func _flash() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", _armor_color, FLASH_TIME)


func _apply_knockback(hit_dir: Vector2) -> void:
	var kb := Knockback.knockback_vector(hit_dir, KNOCKBACK_STRENGTH)
	if kb == Vector2.ZERO:
		return
	var dest := global_position + kb
	var tween := create_tween()
	tween.tween_property(self, "global_position", dest, KNOCKBACK_TIME) \
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
	spark.global_position = global_position - hit_dir.normalized() * 12.0
	if spark.has_method("burst"):
		spark.burst(element)


func _shake_camera(effectiveness: float) -> void:
	var shake := _find_screen_shake()
	if shake != null and shake.has_method("add_trauma"):
		shake.add_trauma(SHAKE_PER_HIT * effectiveness)


func _do_hit_stop(effectiveness: float) -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var hs := tree.root.get_node_or_null("HitStop")
	if hs != null and hs.has_method("freeze"):
		hs.freeze(effectiveness)


func _find_screen_shake() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("screen_shake")
	if nodes.is_empty():
		return null
	return nodes[0]

# --- DD-009 AI queries / actions (FSM states call these; logic in DroneAi) ----

func _distance_to_target() -> float:
	if target == null:
		return INF
	return global_position.distance_to(target.global_position)

func player_in_aggro_range() -> bool:
	return DroneAi.in_aggro_range(_distance_to_target(), aggro_range)

func can_attack() -> bool:
	if not DroneAi.in_aggro_range(_distance_to_target(), attack_range):
		return false
	return DroneAi.cooldown_ready(_time_since_attack, attack_cooldown / speed_multiplier())

func steer_toward_player() -> Vector2:
	if target == null:
		return Vector2.ZERO
	return DroneAi.steer_direction(global_position, target.global_position)

func speed_multiplier() -> float:
	return _slow.multiplier()

func is_slowed() -> bool:
	return _slow.is_active()

## Telegraph + DROP THE SHIELD: the wind-up is the punish window. Begin/end are
## called by the Attack state on enter/exit.
func begin_telegraph() -> void:
	_telegraphing = true
	_shield_up = false
	_update_tint()
	_refresh_shield_visual()

func end_telegraph() -> void:
	_telegraphing = false
	_shield_up = true
	_update_tint()
	_refresh_shield_visual()

func mark_attacked() -> void:
	_time_since_attack = 0.0

## DD-009: spawn one enemy projectile aimed at the player. Null-guarded so a bare
## drone (unit test) without the scene assigned simply does nothing.
func fire_at_player() -> void:
	if enemy_projectile_scene == null or target == null:
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var proj := enemy_projectile_scene.instantiate()
	tree.current_scene.add_child(proj)
	proj.global_position = global_position
	var dir := (target.global_position - global_position).normalized()
	if proj.has_method("setup"):
		proj.setup(dir, projectile_damage)
	# TASK-056: play the attack (cast) one-shot when the shot actually fires.
	if _anim_ctrl != null and _anim_ctrl.has_method("play_attack"):
		_anim_ctrl.play_attack()

# --- Shield state: readable queries + the wind-up predicate -------------------

## Whether the shield is UP (blocking) right now.
func is_shield_up() -> bool:
	return _shield_up

## The current unit shield facing (toward the player while up; frozen while down).
func shield_facing() -> Vector2:
	return _shield_facing

## PURE state rule: the shield is DOWN during the Attack wind-up state and UP
## otherwise (Patrol/Chase). Static so the FSM/tests can ask without a live node.
static func shield_up_during(state_name: String) -> bool:
	return state_name != "DroneAttackState"

# --- Tint / shield visual / labels / death ------------------------------------

## Sprite tint priority: dying (leave alone) > telegraph > Ice slow > armor.
func _update_tint() -> void:
	if _dying:
		return
	if _sprite == null:
		return
	if _telegraphing:
		_sprite.modulate = TELEGRAPH_COLOR
	elif _slow.is_active():
		_sprite.modulate = SLOW_TINT
	else:
		_sprite.modulate = _armor_color


## Position/rotate/tint the shield ColorRect so its UP/DOWN state + facing READ:
## bright + offset in front when up, faint ghost when down (the punish window).
func _refresh_shield_visual() -> void:
	if _shield == null:
		return
	if _dying:
		return
	var facing := _shield_facing
	if facing == Vector2.ZERO:
		facing = Vector2.RIGHT
	_shield.position = facing * SHIELD_OFFSET
	_shield.rotation = facing.angle()
	_shield.color = SHIELD_UP_COLOR if _shield_up else SHIELD_DOWN_COLOR


func _on_health_changed(_current: float, _maximum: float) -> void:
	pass   # label refresh is driven from apply_elemental_hit so it can show dmg

func is_dying() -> bool:
	return _dying


## TASK-017 death: element-tinted dissolve + particle burst, THEN free. Single-trigger
## (guarded by `_dying`) so overkill / a re-emitted died can't replay or double-free.
func _on_died() -> void:
	if _dying:
		return
	_dying = true
	var tuning := DeathEffect.tuning_for(_health.max_health if _health != null else 0.0)
	_spawn_death_burst(armor_type)
	_shake_camera_amount(tuning.shake)
	_do_hit_stop(tuning.hit_stop)
	_play_dissolve(float(tuning.dissolve_time))


func _spawn_death_burst(element: int) -> void:
	var scene: PackedScene = death_effect_scene if death_effect_scene != null else impact_spark_scene
	if scene == null:
		return
	var burst_parent: Node = death_burst_parent
	if burst_parent == null:
		var tree := get_tree()
		if tree == null or tree.current_scene == null:
			return
		burst_parent = tree.current_scene
	var burst := scene.instantiate()
	burst_parent.add_child(burst)
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
	var faded := _sprite.modulate
	faded.a = 0.0
	tween.tween_property(_sprite, "modulate", faded, seconds)
	tween.tween_property(_sprite, "scale", Vector2.ONE * DISSOLVE_END_SCALE, seconds)
	# Fade the shield out alongside the body.
	if _shield != null:
		var shield_faded := _shield.color
		shield_faded.a = 0.0
		tween.tween_property(_shield, "color", shield_faded, seconds)
	tween.chain().tween_callback(queue_free)


func _shake_camera_amount(amount: float) -> void:
	var shake := _find_screen_shake()
	if shake != null and shake.has_method("add_trauma"):
		shake.add_trauma(amount)


func _refresh_label(last_dmg: float, slow := false, blocked := false) -> void:
	if _label == null:
		return
	var hp := _health.current_health if _health != null else 0.0
	var maxhp := _health.max_health if _health != null else 0.0
	var armor: String = SpellData.Element.keys()[armor_type]
	var slow_tag := "  SLOWED" if slow else ""
	var shield_tag := "SHIELD UP" if _shield_up else "SHIELD DOWN"
	var last_line := "BLOCKED" if blocked else "last dmg %.1f" % last_dmg
	_label.text = "SHIELD DRONE — %s armor\nHP %d/%d  [%s]\n%s%s" % [
		armor, int(hp), int(maxhp), shield_tag, last_line, slow_tag]

# --- Test seam ----------------------------------------------------------------

## Force the shield facing + up/down for unit tests (drives the block path in
## apply_elemental_hit without stepping the whole FSM into the wind-up).
func set_shield_for_test(facing: Vector2, up: bool) -> void:
	_shield_facing = facing if facing != Vector2.ZERO else Vector2.RIGHT
	_shield_up = up
	_refresh_shield_visual()
