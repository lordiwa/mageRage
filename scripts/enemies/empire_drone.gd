## Empire drone (CharacterBody2D on the Enemies layer 3). The amnesiac-guardian
## target of the combat slice (pillar 1: the jailer was the protector — read it as
## a desperate sentry, not gleeful evil). Has a Health child and an `armor_type`
## that drives the DD-006 matchup; a debug Label shows HP + the last damage taken.
##
## A placeholder ColorRect visual is tinted by armor type so the player can read at
## a glance which element to swap to (game-design SKILL: readability/telegraphing).
class_name EmpireDrone extends CharacterBody2D

## Armor element drives the matchup. Reuses SpellData.Element so Fire/Ice/Elec map
## 1:1 to spell elements (ANTIMATTER is not a valid armor in the RPS).
@export var armor_type: SpellData.Element = SpellData.Element.FIRE

## TASK-010 juice scenes (PLACEHOLDERS). Optional so unit tests / bare drones run
## without them; null-guarded at the hit path.
@export var damage_number_scene: PackedScene
@export var impact_spark_scene: PackedScene

## DD-009 AI tuning (provisional). The FSM logic itself lives in DroneAi (pure,
## unit-tested) — these are just the thresholds fed to it.
@export var aggro_range: float = 280.0   # Patrol -> Chase distance
@export var attack_range: float = 240.0  # Chase -> Attack distance
@export var attack_cooldown: float = 1.5 # seconds between shots
@export var projectile_damage: float = 12.0

## DD-009 enemy projectile (PLACEHOLDER scene). Optional so bare drones / unit
## tests run without it; null-guarded at the fire path.
@export var enemy_projectile_scene: PackedScene

## The hero to chase/shoot. Resolved on _ready from the "player" group; settable
## in tests. Loosely typed so a fake target works headless.
var target: Node2D

## Spawn point for the Patrol hover (captured on _ready).
var spawn_position := Vector2.ZERO

## DD-004 Ice control: while active, halves chase speed + attack rate.
var _slow := SlowEffect.new()

## Seconds since the last shot; gates the cooldown via DroneAi.cooldown_ready.
var _time_since_attack := 999.0

## Wind-up color flash while telegraphing (placeholder readable tell).
const TELEGRAPH_COLOR := Color(1.0, 0.95, 0.6, 1.0)
## DD-004 Ice tint while slowed (bluish overlay).
const SLOW_TINT := Color(0.45, 0.7, 1.0, 1.0)
var _telegraphing := false

## TASK-010: emitted on every landed hit so a coordinator (or test) can react with
## loose coupling. `dir` is the projectile's travel direction at contact.
signal hit(amount: float, effectiveness: float, dir: Vector2)

@onready var _health: Health = $Health
@onready var _label: Label = $Label
@onready var _sprite: ColorRect = $Sprite

const ARMOR_TINT := {
	SpellData.Element.FIRE: Color(0.85, 0.30, 0.20, 1.0),       # warm red
	SpellData.Element.ICE: Color(0.35, 0.65, 0.95, 1.0),        # cold blue
	SpellData.Element.ELECTRICITY: Color(0.95, 0.85, 0.25, 1.0),# arc yellow
}

## TASK-010 feel tuning (small / sparing per game-design SKILL juice budget).
const FLASH_TIME := 0.06           # seconds the drone flashes white on a hit
const KNOCKBACK_STRENGTH := 70.0   # px positional punch along the shot direction
const KNOCKBACK_TIME := 0.10       # seconds of the knockback tween
const SHAKE_PER_HIT := 0.18        # base trauma added to the camera per hit

var _armor_color := Color.WHITE

func _ready() -> void:
	# GDD 5.C: I am an Enemy (layer 3). I don't need to mask anything for the
	# slice (the player projectile detects me); collide with Environment so I rest.
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	_armor_color = ARMOR_TINT.get(armor_type, Color.WHITE)
	if _sprite != null:
		_sprite.color = _armor_color
	if _health != null:
		_health.health_changed.connect(_on_health_changed)
		_health.died.connect(_on_died)
	# DD-009: FLYING drone — gravity off; the FSM drives all movement.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	spawn_position = global_position
	_resolve_target()
	_refresh_label(0.0)

## DD-009: tick the Ice slow + attack cooldown each physics frame. The FSM states
## (Patrol/Chase/Attack) own movement; this only advances timers and the visuals.
func _physics_process(delta: float) -> void:
	var was_slowed := _slow.is_active()
	_slow.update(delta)
	_time_since_attack += delta
	_update_tint()
	# Keep the SLOWED label live: refresh when the slow state flips off.
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

## Called by a Projectile on contact. Applies base * DD-006 matchup to Health and
## fires the TASK-010 hit-feedback bundle (one hit path -> all juice, coherently):
## hit flash + damage number + impact spark + camera shake + hit-stop + knockback.
## `slow` is the Ice control hook (reads through to the debug label). `hit_dir` is
## the projectile's travel direction (for knockback + the `hit` signal); defaults
## to ZERO so older callers / tests still work.
func apply_elemental_hit(element: int, base_damage: float, slow: bool,
		hit_dir: Vector2 = Vector2.ZERO) -> void:
	var effectiveness := ElementMatchup.multiplier(element, armor_type)
	var dmg := base_damage * effectiveness
	if _health != null:
		_health.take_damage(dmg)
	# DD-004 Ice = control: an Ice hit starts/refreshes the real SLOW effect.
	if slow:
		_slow.apply()
	_refresh_label(dmg, _slow.is_active())
	# --- TASK-010 hit feedback ------------------------------------------------
	_flash()
	_apply_knockback(hit_dir)
	_spawn_damage_number(dmg, effectiveness)
	_spawn_spark(element, hit_dir)
	_shake_camera(effectiveness)
	_do_hit_stop(effectiveness)
	hit.emit(dmg, effectiveness, hit_dir)


## Hit flash: modulate to white for a few frames, then back to the armor tint.
func _flash() -> void:
	if _sprite == null:
		return
	_sprite.color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_sprite, "color", _armor_color, FLASH_TIME)


## Knockback: a short positional punch along the shot's travel direction.
func _apply_knockback(hit_dir: Vector2) -> void:
	var kb := Knockback.knockback_vector(hit_dir, KNOCKBACK_STRENGTH)
	if kb == Vector2.ZERO:
		return
	var target := global_position + kb
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, KNOCKBACK_TIME) \
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
	# Contact point: bias toward the side the shot came from.
	spark.global_position = global_position - hit_dir.normalized() * 12.0
	if spark.has_method("burst"):
		spark.burst(element)


## Add trauma to the Player camera's ScreenShake, scaled by effectiveness — a
## correct-element hit shakes a touch harder (still small per the juice budget).
func _shake_camera(effectiveness: float) -> void:
	var shake := _find_screen_shake()
	if shake != null and shake.has_method("add_trauma"):
		shake.add_trauma(SHAKE_PER_HIT * effectiveness)


func _do_hit_stop(effectiveness: float) -> void:
	# HitStop is an autoload; null-guard so bare-scene tests don't require it.
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var hs := tree.root.get_node_or_null("HitStop")
	if hs != null and hs.has_method("freeze"):
		hs.freeze(effectiveness)


## Locate the ScreenShake node (child of the Player's Camera2D) without hard
## coupling: search the current scene for the first node in the "screen_shake"
## group. Returns null if absent (e.g. a bare drone in a unit test).
func _find_screen_shake() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("screen_shake")
	if nodes.is_empty():
		return null
	return nodes[0]

# --- DD-009 AI queries/actions (FSM states call these; logic in DroneAi) ------

## Distance to the current target, or INF if there is none.
func _distance_to_target() -> float:
	if target == null:
		return INF
	return global_position.distance_to(target.global_position)

## Patrol -> Chase gate.
func player_in_aggro_range() -> bool:
	return DroneAi.in_aggro_range(_distance_to_target(), aggro_range)

## Chase -> Attack gate: in attack range AND cooldown ready (slow-adjusted).
func can_attack() -> bool:
	if not DroneAi.in_aggro_range(_distance_to_target(), attack_range):
		return false
	return DroneAi.cooldown_ready(_time_since_attack, attack_cooldown / speed_multiplier())

## Unit steering vector toward the player (horizontal + a little vertical).
func steer_toward_player() -> Vector2:
	if target == null:
		return Vector2.ZERO
	return DroneAi.steer_direction(global_position, target.global_position)

## DD-004 Ice control multiplier (0.5 while slowed, 1.0 otherwise). Drone chase
## speed and attack rate both honor it.
func speed_multiplier() -> float:
	return _slow.multiplier()

func is_slowed() -> bool:
	return _slow.is_active()

## Telegraph flash on/off (placeholder readable wind-up tell).
func begin_telegraph() -> void:
	_telegraphing = true
	_update_tint()

func end_telegraph() -> void:
	_telegraphing = false
	_update_tint()

## Mark a shot fired: reset the cooldown timer.
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

## Sprite tint priority: telegraph flash > Ice slow tint > armor color.
func _update_tint() -> void:
	if _sprite == null:
		return
	if _telegraphing:
		_sprite.color = TELEGRAPH_COLOR
	elif _slow.is_active():
		_sprite.color = SLOW_TINT
	else:
		_sprite.color = _armor_color

func _on_health_changed(_current: float, _maximum: float) -> void:
	pass   # label refresh is driven from apply_elemental_hit so it can show dmg

func _on_died() -> void:
	queue_free()

func _refresh_label(last_dmg: float, slow := false) -> void:
	if _label == null:
		return
	var hp := _health.current_health if _health != null else 0.0
	var maxhp := _health.max_health if _health != null else 0.0
	var armor: String = SpellData.Element.keys()[armor_type]
	var slow_tag := "  SLOWED" if slow else ""
	_label.text = "%s armor\nHP %d/%d\nlast dmg %.1f%s" % [
		armor, int(hp), int(maxhp), last_dmg, slow_tag]
