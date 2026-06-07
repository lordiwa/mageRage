## TASK-018 Charger (Centinela de carga) — a GROUNDED melee guardian, the first
## non-flying, non-ranged Empire enemy (pillar 1: the jailer was the protector — read
## it as a heavy, desperate sentry hurling itself at the intruder, not gleeful evil).
##
## Unlike the FLOATING EmpireDrone, the Charger is a CharacterBody2D WITH gravity
## (MOTION_MODE_GROUNDED). It patrols its post, chases the player, then TELEGRAPHS a
## wind-up before LUNGING horizontally in a LOCKED direction (contact damage via a
## hitbox), and finally STAGGERS in a recovery window where its core is EXPOSED
## (extra-vulnerable — read-and-punish payoff). The charge is a horizontal ground
## lunge the player can leap/dash over or step out of (fair, DD-001); Ice slow
## (DD-004) drags out the wind-up + lunge so a slowed Charger is even easier to read.
##
## Reuses the combat kit wholesale: Health, ElementMatchup (DD-006), SlowEffect
## (DD-004), the apply_elemental_hit juice bundle + element-tinted death dissolve
## (TASK-017), the DroneAi pure range/steer gates, and the node-FSM idiom. All
## charge-phase + exposed-window decisions live in the pure ChargerAi helper.
class_name Charger extends CharacterBody2D

## Armor element drives the DD-006 matchup. Defaults to FIRE — an aggressive melee
## guardian reads as Fire-armored, so it is WEAK to Electricity (per ElementMatchup).
## @export so an encounter room can configure a different weakness.
@export var armor_type: SpellData.Element = SpellData.Element.FIRE

## TASK-010 juice scenes (PLACEHOLDERS). Optional so unit tests / bare chargers run
## without them; null-guarded at the hit path.
@export var damage_number_scene: PackedScene
@export var impact_spark_scene: PackedScene

## TASK-017 death burst scene (element-tinted CPUParticles2D — reuses impact_spark).
## Optional; null-guarded at the death path. Falls back to impact_spark_scene.
@export var death_effect_scene: PackedScene

## TASK-017: where the death burst is parented (defaults to the current scene so the
## burst outlives the freed Charger); a test can inject a scoped, auto-freed container.
var death_burst_parent: Node

## DD-009-style AI tuning (provisional). The transition LOGIC lives in DroneAi /
## ChargerAi (pure, unit-tested) — these are the thresholds fed to them.
@export var aggro_range: float = 320.0   # Patrol -> Chase distance
@export var attack_range: float = 96.0   # Chase -> WindUp distance (must get close)
@export var contact_damage: float = 16.0 # lunge contact damage to the player

## The hero to chase/charge. Resolved on _ready from the "player" group; settable in
## tests. Loosely typed so a fake target works headless.
var target: Node2D

## Spawn point for the Patrol walk (captured on _ready).
var spawn_position := Vector2.ZERO

## DD-004 Ice control: while active, halves move speed, wind-up rate, and lunge speed.
var _slow := SlowEffect.new()

## The LOCKED horizontal lunge sign (+1 right / -1 left). Set once at wind-up start by
## lock_lunge_toward(); the Charge state reads it so the lunge never re-homes (fair).
var _lunge_sign := 1.0

## EXPOSED window flag (extra-vulnerable). Driven by the Recovery state on enter/exit
## via set_exposed(); apply_elemental_hit reads it for the bonus-damage multiplier.
var _exposed := false

## Wind-up color flash while telegraphing (placeholder readable tell, like the drone).
const TELEGRAPH_COLOR := Color(1.0, 0.95, 0.6, 1.0)
const SLOW_TINT := Color(0.45, 0.7, 1.0, 1.0)
## EXPOSED tint: a vulnerable, washed-out flash so the punish window READS (the core
## is open). Sits above slow/armor in the tint priority, below the telegraph.
const EXPOSED_TINT := Color(1.0, 0.55, 0.55, 1.0)
var _telegraphing := false

## TASK-017: latched once the death effect has started so an overkill / chain hit or a
## re-emitted Health.died can never replay the dissolve or double-free.
var _dying := false

## TASK-017 death-beat tuning: dissolve fades alpha + shrinks the sprite, then frees.
const DISSOLVE_END_SCALE := 0.2

## TASK-010: emitted on every landed hit so a coordinator (or test) can react with
## loose coupling. `dir` is the player projectile's travel direction at contact.
signal hit(amount: float, effectiveness: float, dir: Vector2)

@onready var _health: Health = $Health
@onready var _label: Label = get_node_or_null("Label")
## TASK-056: the sprite is now an AnimatedSprite2D. Typed as CanvasItem so the
## flash / tint / dissolve drive `modulate` (works on both the AnimatedSprite2D and
## the bare ColorRect used by unit tests); null-guarded for bare-scene tests.
@onready var _sprite: CanvasItem = get_node_or_null("Sprite")
## TASK-056: state-driven animation controller. The charger is MELEE (no ranged
## cast), so only the hurt one-shot is fired here; windup/charge are driven by the
## FSM state -> animation mapping in the controller. Duck-typed + has_method-guarded.
@onready var _anim_ctrl: Node = get_node_or_null("AnimationController")

## The lunge contact hitbox (Area2D on EnemyAttack layer 5, masks Player layer 2
## ONLY — like EnemyProjectile). Active only during the Charge phase: while monitoring
## it deals contact damage to any overlapping player body. Optional so a bare Charger
## (unit test) without the node still works (the contact path is also exercised
## directly via deal_contact_damage()).
@onready var _lunge_hitbox: Area2D = get_node_or_null("LungeHitbox")

const ARMOR_TINT := {
	SpellData.Element.FIRE: Color(0.85, 0.30, 0.20, 1.0),       # warm red
	SpellData.Element.ICE: Color(0.35, 0.65, 0.95, 1.0),        # cold blue
	SpellData.Element.ELECTRICITY: Color(0.95, 0.85, 0.25, 1.0),# arc yellow
}

## TASK-010 feel tuning (small / sparing per the juice budget).
const FLASH_TIME := 0.06
const KNOCKBACK_STRENGTH := 70.0
const KNOCKBACK_TIME := 0.10
const SHAKE_PER_HIT := 0.18

var _armor_color := Color.WHITE

func _ready() -> void:
	# GDD 5.C: I am an Enemy (layer 3) so the player's magic detects me; collide with
	# Environment (layer 1) so gravity rests me on the floor and walls stop the lunge.
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	# TASK-022 chain compatibility: join the `enemies` group (idempotent).
	if not is_in_group("enemies"):
		add_to_group("enemies")
	# GROUNDED (gravity ON), unlike the FLOATING drone — the FSM applies gravity each
	# physics step and calls move_and_slide so the Charger stays on the ground.
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	_armor_color = ARMOR_TINT.get(armor_type, Color.WHITE)
	if _sprite != null:
		_sprite.modulate = _armor_color
	if _health != null:
		_health.health_changed.connect(_on_health_changed)
		_health.died.connect(_on_died)
	spawn_position = global_position
	_setup_lunge_hitbox()
	_resolve_target()
	_refresh_label(0.0)

## Configure the lunge hitbox: EnemyAttack layer 5, masks Player (layer 2) ONLY (it
## can touch the hero and nothing else), wired to deal contact damage on overlap, and
## DISABLED until the Charge state activates it. Null-guarded for bare-scene tests.
func _setup_lunge_hitbox() -> void:
	if _lunge_hitbox == null:
		return
	_lunge_hitbox.collision_layer = 0
	_lunge_hitbox.collision_mask = 0
	_lunge_hitbox.set_collision_layer_value(5, true)   # EnemyAttack
	_lunge_hitbox.set_collision_mask_value(2, true)    # detect Player ONLY
	_lunge_hitbox.monitoring = false
	if not _lunge_hitbox.body_entered.is_connected(_on_lunge_body_entered):
		_lunge_hitbox.body_entered.connect(_on_lunge_body_entered)
	if not _lunge_hitbox.area_entered.is_connected(_on_lunge_area_entered):
		_lunge_hitbox.area_entered.connect(_on_lunge_area_entered)

## Tick the Ice slow each physics frame. The FSM states own movement; this only
## advances the slow timer and refreshes the visuals.
func _physics_process(delta: float) -> void:
	var was_slowed := _slow.is_active()
	_slow.update(delta)
	_update_tint()
	if was_slowed and not _slow.is_active():
		_refresh_label(0.0, false)

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

## Project gravity for the FSM states to apply (mirrors how the player MoveState reads
## get_gravity()). Grounded, so this is the project default down-vector.
func gravity_vector() -> Vector2:
	return get_gravity()

# --- Combat: player magic lands on the Charger -------------------------------

## Called by a Projectile on contact (DD-006 matchup + TASK-010 juice + DD-004 slow +
## TASK-017 death). Mirrors EmpireDrone.apply_elemental_hit, PLUS the TASK-018 EXPOSED
## bonus: while the core is exposed (Recovery), the matchup damage is multiplied by
## ChargerAi.exposed_multiplier — reading the telegraph + dodge is rewarded.
func apply_elemental_hit(element: int, base_damage: float, slow: bool,
		hit_dir: Vector2 = Vector2.ZERO) -> void:
	var effectiveness := ElementMatchup.multiplier(element, armor_type)
	var dmg := base_damage * effectiveness * ChargerAi.exposed_multiplier(_exposed)
	if _health != null:
		_health.take_damage(dmg)
	if slow:
		_slow.apply()
	_refresh_label(dmg, _slow.is_active())
	# TASK-056: play the hurt one-shot on a landed hit (highest-priority anim).
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

# --- AI queries / actions (FSM states call these; logic in DroneAi/ChargerAi) -

## Distance to the current target, or INF if there is none.
func _distance_to_target() -> float:
	if target == null:
		return INF
	return global_position.distance_to(target.global_position)

## Patrol -> Chase gate (reuses the pure DroneAi range helper).
func player_in_aggro_range() -> bool:
	return DroneAi.in_aggro_range(_distance_to_target(), aggro_range)

## Chase -> WindUp gate: the player is close enough to commit to a lunge.
func player_in_attack_range() -> bool:
	return DroneAi.in_aggro_range(_distance_to_target(), attack_range)

## Unit steering vector toward the player (used by Chase for the horizontal approach).
func steer_toward_player() -> Vector2:
	if target == null:
		return Vector2.ZERO
	return DroneAi.steer_direction(global_position, target.global_position)

## DD-004 Ice control multiplier (0.5 while slowed, 1.0 otherwise). Move speed,
## wind-up rate, and lunge speed all honor it (a slowed Charger is easier to read).
func speed_multiplier() -> float:
	return _slow.multiplier()

func is_slowed() -> bool:
	return _slow.is_active()

## LOCK the lunge: capture the horizontal sign toward `player_pos` ONCE (at wind-up
## start). The Charge state reads lunge_direction_sign() so the lunge never re-homes.
func lock_lunge_toward(player_pos: Vector2) -> void:
	_lunge_sign = ChargerAi.lunge_sign(global_position, player_pos)

## The locked horizontal lunge sign (+1 right / -1 left).
func lunge_direction_sign() -> float:
	return _lunge_sign

## Convenience for the wind-up state: lock toward the CURRENT target's position.
func lock_lunge_at_target() -> void:
	if target != null:
		lock_lunge_toward(target.global_position)

## EXPOSED window control (Recovery state toggles this). Drives the bonus-damage
## multiplier in apply_elemental_hit + the exposed tint.
func set_exposed(exposed: bool) -> void:
	_exposed = exposed
	_update_tint()

func is_exposed() -> bool:
	return _exposed

## Telegraph flash on/off (placeholder readable wind-up tell).
func begin_telegraph() -> void:
	_telegraphing = true
	_update_tint()

func end_telegraph() -> void:
	_telegraphing = false
	_update_tint()

# --- Lunge contact damage to the player (the NEW contact-damage path) ---------

## Deal the lunge's contact damage to a hero, mirroring EnemyProjectile.resolve_hit:
## a hit lands ONLY when the hero is NOT invulnerable (i-frames truly mean
## untouchable, DD-001). Threads the LOCKED charge direction as hit_dir so the
## player HUD can point its hit indicator back along the lunge. The hero may be the
## body or its parent (a hurtbox child), like the projectile path.
func deal_contact_damage(hero: Node) -> void:
	var handler := hero
	if not handler.has_method("take_player_damage"):
		handler = hero.get_parent()
		if handler == null or not handler.has_method("take_player_damage"):
			return
	if not should_land_contact(handler):
		return
	handler.take_player_damage(contact_damage, Vector2(_lunge_sign, 0.0))

## Pure-ish contact hit decision: a hit lands only when the hero is NOT currently
## invulnerable. A hero without the gate (older fakes) is treated as always hittable.
func should_land_contact(hero: Node) -> bool:
	if hero.has_method("is_invulnerable"):
		return not hero.is_invulnerable()
	return true

## Enable/disable the lunge contact hitbox (Charge state turns it on for the lunge,
## off on exit). When enabled, also catch a player ALREADY overlapping at activation
## (body_entered won't re-fire for a body that's already inside).
func activate_lunge_hitbox(active: bool) -> void:
	if _lunge_hitbox == null:
		return
	_lunge_hitbox.monitoring = active
	if active:
		for body in _lunge_hitbox.get_overlapping_bodies():
			deal_contact_damage(body)

func _on_lunge_body_entered(body: Node) -> void:
	deal_contact_damage(body)

func _on_lunge_area_entered(area: Node) -> void:
	deal_contact_damage(area)

# --- Tint / labels / death ----------------------------------------------------

## Tint priority: dying (leave alone) > telegraph > exposed > Ice slow > armor.
func _update_tint() -> void:
	if _dying:
		return
	if _sprite == null:
		return
	if _telegraphing:
		_sprite.modulate = TELEGRAPH_COLOR
	elif _exposed:
		_sprite.modulate = EXPOSED_TINT
	elif _slow.is_active():
		_sprite.modulate = SLOW_TINT
	else:
		_sprite.modulate = _armor_color

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
	var faded := _sprite.modulate
	faded.a = 0.0
	tween.tween_property(_sprite, "modulate", faded, seconds)
	tween.tween_property(_sprite, "scale", Vector2.ONE * DISSOLVE_END_SCALE, seconds)
	tween.chain().tween_callback(queue_free)

func _shake_camera_amount(amount: float) -> void:
	var shake := _find_screen_shake()
	if shake != null and shake.has_method("add_trauma"):
		shake.add_trauma(amount)

func _refresh_label(last_dmg: float, slow := false) -> void:
	if _label == null:
		return
	var hp := _health.current_health if _health != null else 0.0
	var maxhp := _health.max_health if _health != null else 0.0
	var armor: String = SpellData.Element.keys()[armor_type]
	var slow_tag := "  SLOWED" if slow else ""
	var exposed_tag := "  EXPOSED" if _exposed else ""
	_label.text = "CHARGER — %s armor\nHP %d/%d\nlast dmg %.1f%s%s" % [
		armor, int(hp), int(maxhp), last_dmg, slow_tag, exposed_tag]

# --- Test seam ----------------------------------------------------------------

## Force the EXPOSED window for unit tests (drives the bonus-damage multiplier path
## in apply_elemental_hit without stepping the whole FSM through Recovery).
func set_exposed_for_test(exposed: bool) -> void:
	set_exposed(exposed)
