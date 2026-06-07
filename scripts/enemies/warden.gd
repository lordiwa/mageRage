## DD-010 mini-boss: "The Warden" (El Carcelero). A large Empire construct fought
## in a closed arena (levels/arena.tscn) — the first minute-to-minute boss, the test
## that forces the player to use the WHOLE kit (game-design SKILL: the trial demands
## the verbs you earned; pillar 1 reads it as a desperate guardian, not gleeful evil).
##
## A CharacterBody2D on the Enemies layer (3) with a Health child (~300 HP) and a
## node-based FSM (Patrol/Chase/Attack, reusing the drone idiom + DroneAi helpers).
## Its ARMOR rotates by HP phase (DD-010 thresholds 66% / 33%): P1 Fire, P2 Ice, P3
## Electricity — forcing the DD-008 loadout swap and honoring the DD-006 RPS. All
## phase/armor/pattern/fan math lives in the PURE WardenPhases helper so it is
## unit-testable and can never drift. Every attack is TELEGRAPHED (wind-up before
## the shot, DD-001 fair play); a slow (DD-009 Ice) makes the boss move AND attack
## slower. Crossing a phase threshold fires a big juice beat (HitStop + ScreenShake)
## and re-telegraphs the new armor color so the player must re-read it.
class_name Warden extends CharacterBody2D

## DD-010 boss tuning (provisional — to afinar in playtest).
@export var max_health: float = 300.0
@export var aggro_range: float = 9999.0    # arena boss: always engaged once seen
@export var attack_range: float = 9999.0   # whole arena is in range (it's a duel)

## TASK-029 sector integration: when instanced into the connected sector (sector_01)
## the Warden is placed DORMANT so it cannot chase/fire across the whole level while
## the hero is still traversing the gates — it only engages once the boss-room trigger
## activates it. Defaults to FALSE so the standalone arena (arena.tscn) is unchanged: a
## bare/arena Warden is awake from the start. A dormant Warden reports no aggro and
## never attacks (the FSM stays in Patrol) until activate() flips this off.
@export var dormant: bool = false

## Per-phase attack cadence (seconds between shots). P3 is faster (DD-010: "more
## rapid"). Indexed by phase-1 (0,1,2). Slow (DD-009) divides the effective rate.
@export var cooldown_p1: float = 1.8
@export var cooldown_p2: float = 1.6
@export var cooldown_p3: float = 1.0

## Per-phase wind-up (telegraph) length. The heavy P1 shot telegraphs longest so the
## big hit always reads (DD-001); P3 is snappier to match its faster cadence.
@export var windup_p1: float = 0.6
@export var windup_p2: float = 0.5
@export var windup_p3: float = 0.4

## Per-phase projectile damage. P1's aimed shot hits hardest (DD-010 "heavy").
@export var damage_p1: float = 18.0
@export var damage_p2: float = 12.0
@export var damage_p3: float = 14.0

## P2 fan volley: number of projectiles and total angular spread (radians).
@export var fan_count: int = 3
@export var fan_spread: float = 0.7   # ~40 degrees total

## DD-010 phase-transition juice (big hit-stop + shake — the boss-blow budget the
## game-design SKILL reserves the loudest feel for).
@export var transition_shake: float = 0.8

## PLACEHOLDER scenes (optional so unit tests / bare bosses run without them).
@export var enemy_projectile_scene: PackedScene

## TASK-017 death burst scene (element-tinted CPUParticles2D — reuses impact_spark).
## Optional so unit tests / bare bosses run without it; null-guarded at the death path.
@export var death_effect_scene: PackedScene

## TASK-017: where the death burst is parented. Defaults to the current scene; a test
## can inject a scoped, auto-freed container. The BOSS itself is NOT freed on death —
## the arena victory state owns its lifetime (DD-010) — so only the burst is spawned.
var death_burst_parent: Node

## The hero to chase/shoot. Resolved from the "player" group on _ready; settable in
## tests. Loosely typed so a fake target works headless.
var target: Node2D
var spawn_position := Vector2.ZERO

## DD-009 Ice control: while active, halves move speed + attack rate.
var _slow := SlowEffect.new()

## Seconds since the last shot; gates the per-phase cooldown via DroneAi.cooldown_ready.
var _time_since_attack := 999.0

## Current phase (1..3) and whether we've fired the victory beat once.
var _phase := 1
var _won := false
var _telegraphing := false

## DD-010 readable armor tints (matches the drone's color language: Fire warm red,
## Ice cold blue, Electricity arc yellow). Telegraph flashes the phase's WEAKNESS
## hue so the player re-reads which element to swap to.
const ARMOR_TINT := {
	SpellData.Element.FIRE: Color(0.85, 0.30, 0.20, 1.0),
	SpellData.Element.ICE: Color(0.35, 0.65, 0.95, 1.0),
	SpellData.Element.ELECTRICITY: Color(0.95, 0.85, 0.25, 1.0),
}
const TELEGRAPH_COLOR := Color(1.0, 0.95, 0.6, 1.0)
const SLOW_TINT := Color(0.45, 0.7, 1.0, 1.0)

## TASK-017: how far the sprite shrinks during the death dissolve (parity with the
## drone's DISSOLVE_END_SCALE; the boss stays a touch larger as it fades).
const DISSOLVE_END_SCALE := 0.6

## Emitted when a phase threshold is crossed (new phase id). Drives the juice beat
## + HUD; lets a coordinator/test react with loose coupling.
signal phase_changed(new_phase: int)
## Emitted once when the boss reaches 0 HP — the arena listens to enter victory.
signal defeated

@onready var _health: Health = $Health
## TASK-058: the boss greybox ColorRect is now an AnimatedSprite2D. Typed as
## CanvasItem so the telegraph/slow/armor tint + the death dissolve drive `modulate`
## (works on both the AnimatedSprite2D and a bare ColorRect used by unit tests);
## null-guarded for bare-scene tests.
@onready var _sprite: CanvasItem = get_node_or_null("Sprite")
@onready var _label: Label = get_node_or_null("Label")
## TASK-058: the state-driven animation controller (one-shot attack/hurt + flip_h),
## mirroring the drones/charger. Duck-typed as Node so a bare boss (unit test)
## without it still runs; calls are has_method-guarded.
@onready var _anim_ctrl: Node = get_node_or_null("AnimationController")

var _armor_color := Color.WHITE

func _ready() -> void:
	# GDD 5.C: I am an Enemy (layer 3); collide with Environment so walls stop me.
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	# TASK-059: a GROUNDED heavy tank (gravity ON), not a FLOATING flier. The FSM
	# states apply gravity_vector() each physics step + call move_and_slide so the
	# boss falls to / rests on the floor and pursues the hero horizontally only
	# (it no longer flies diagonally/vertically). Mirrors the Charger ground idiom.
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	if _health != null:
		_health.max_health = max_health
		_health.current_health = max_health
		_health.health_changed.connect(_on_health_changed)
		_health.died.connect(_on_died)
	_phase = 1
	_armor_color = ARMOR_TINT.get(armor_type(), Color.WHITE)
	_update_tint()
	spawn_position = global_position
	_resolve_target()
	_refresh_label()

## Tick the Ice slow + attack cooldown each physics frame (FSM states own movement).
func _physics_process(delta: float) -> void:
	_slow.update(delta)
	_time_since_attack += delta
	_update_tint()

func _resolve_target() -> void:
	if target != null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var players := tree.get_nodes_in_group("player")
	if not players.is_empty():
		target = players[0]

# --- DD-010 phase / armor / pattern (delegates to pure WardenPhases) ----------

## Current phase (1..3) derived from live HP.
func phase() -> int:
	return _phase

## Current armor element (drives the DD-006 matchup against incoming spells).
func armor_type() -> int:
	return WardenPhases.armor_for_phase(_phase)

## Current attack pattern id (WardenPhases.Pattern).
func pattern() -> int:
	return WardenPhases.pattern_for_phase(_phase)

## Per-phase cadence/wind-up/damage selectors (kept here, fed to the gating helpers).
func phase_cooldown() -> float:
	match _phase:
		2:
			return cooldown_p2
		3:
			return cooldown_p3
		_:
			return cooldown_p1

func phase_windup() -> float:
	match _phase:
		2:
			return windup_p2
		3:
			return windup_p3
		_:
			return windup_p1

func phase_damage() -> float:
	match _phase:
		2:
			return damage_p2
		3:
			return damage_p3
		_:
			return damage_p1

# --- DD-010 combat: take damage with the live-armor matchup -------------------

## A player projectile lands: apply base * DD-006 matchup vs the CURRENT phase armor
## to Health. An Ice hit also starts/refreshes the DD-009 SLOW (Ice = control — the
## P3 window the design promises). Re-checks the phase after the hit so a threshold
## crossing fires the transition beat. `slow` carries the Ice-control flag.
func apply_elemental_hit(element: int, base_damage: float, slow: bool,
		_hit_dir: Vector2 = Vector2.ZERO) -> void:
	if _won:
		return
	var effectiveness := ElementMatchup.multiplier(element, armor_type())
	var dmg := base_damage * effectiveness
	if _health != null:
		_health.take_damage(dmg)
	if slow:
		_slow.apply()
	_refresh_label()
	# TASK-058: play the hurt one-shot on a landed hit (highest-priority anim),
	# mirroring the drones/charger. Skip once defeated so the death dissolve owns it.
	if not _won and _anim_ctrl != null and _anim_ctrl.has_method("play_hurt"):
		_anim_ctrl.play_hurt()

## Re-evaluate the phase from current HP; if it advanced, swap armor + fire the beat.
func _on_health_changed(current: float, maximum: float) -> void:
	var new_phase := WardenPhases.phase_for_hp(current, maximum)
	if new_phase != _phase:
		_enter_phase(new_phase)
	_refresh_label()

## DD-010 phase transition: swap armor + pattern, re-telegraph the new color, and
## fire the loud juice beat (HitStop + big ScreenShake trauma — the boss-blow the
## juice budget reserves). The player must RE-READ the armor to keep swapping.
func _enter_phase(new_phase: int) -> void:
	_phase = new_phase
	_armor_color = ARMOR_TINT.get(armor_type(), Color.WHITE)
	# Reset the cadence so the new phase starts with a fresh telegraph, not a free shot.
	_time_since_attack = 0.0
	_update_tint()
	_big_juice_beat()
	phase_changed.emit(_phase)

func _big_juice_beat() -> void:
	_shake_camera(transition_shake)
	_do_hit_stop(1.5)

func _shake_camera(amount: float) -> void:
	var shake := _find_screen_shake()
	if shake != null and shake.has_method("add_trauma"):
		shake.add_trauma(amount)

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

# --- DD-010 AI queries/actions (FSM states call these; logic in DroneAi) ------

func _distance_to_target() -> float:
	if target == null:
		return INF
	return global_position.distance_to(target.global_position)

func player_in_aggro_range() -> bool:
	# TASK-029: a dormant (sector-placed, un-triggered) boss never sees the player, so
	# the FSM stays in Patrol and it doesn't chase across the level.
	if dormant:
		return false
	return DroneAi.in_aggro_range(_distance_to_target(), aggro_range)

## Chase -> Attack gate: in range AND cooldown ready (slow-adjusted, per phase). A
## slowed boss attacks slower because its effective cooldown is divided by the slow
## multiplier (<1 while slowed) — the DD-009 Ice window.
func can_attack() -> bool:
	if _won:
		return false
	# TASK-029: a dormant boss never fires (it hasn't been triggered yet).
	if dormant:
		return false
	if not DroneAi.in_aggro_range(_distance_to_target(), attack_range):
		return false
	return DroneAi.cooldown_ready(_time_since_attack, phase_cooldown() / speed_multiplier())

func steer_toward_player() -> Vector2:
	if target == null:
		return Vector2.ZERO
	return DroneAi.steer_direction(global_position, target.global_position)

## TASK-059: HORIZONTAL pursuit sign toward the hero (-1 left / +1 right / 0 none).
## The grounded tank chases along x only; gravity owns velocity.y, so this drops any
## vertical component (no flight). Pure + testable; null-target -> 0 (holds still).
func horizontal_steer_sign() -> float:
	if target == null:
		return 0.0
	return signf(target.global_position.x - global_position.x)

## TASK-059: the project gravity for the FSM states to apply each step (mirrors how
## the player MoveState + the Charger read get_gravity()). Grounded heavy tank, so
## this is the project default down-vector — no invented value. In-game get_gravity()
## is authoritative (it respects gravity areas); when the physics state hasn't yet
## populated it (e.g. a freshly-added body, headless unit tests) we fall back to the
## documented project convention (ProjectSettings physics/2d/default_gravity), so the
## boss is reliably pulled DOWN either way.
func gravity_vector() -> Vector2:
	var g := get_gravity()
	if g != Vector2.ZERO:
		return g
	var mag := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	var dir: Vector2 = ProjectSettings.get_setting(
		"physics/2d/default_gravity_vector", Vector2.DOWN)
	return dir * mag

## DD-009 Ice control multiplier (0.5 while slowed, 1.0 otherwise) — move + attack.
func speed_multiplier() -> float:
	return _slow.multiplier()

func is_slowed() -> bool:
	return _slow.is_active()

func is_defeated() -> bool:
	return _won

## TASK-029: true while the boss is placed-but-not-yet-triggered (sector integration).
func is_dormant() -> bool:
	return dormant

## TASK-029: wake the boss so the encounter begins (the boss-room trigger calls this).
## Idempotent and one-way — re-calling is harmless; a defeated boss stays defeated.
## Resets the attack timer so the fight opens with a fresh telegraph, not a free shot.
func activate() -> void:
	if not dormant:
		return
	dormant = false
	_time_since_attack = 0.0

func begin_telegraph() -> void:
	_telegraphing = true
	_update_tint()

func end_telegraph() -> void:
	_telegraphing = false
	_update_tint()

func mark_attacked() -> void:
	_time_since_attack = 0.0

## DD-010: fire the CURRENT phase's pattern at the player. AIMED = one heavy shot;
## FAN = WardenPhases.fan_directions spread of shots; SWEEP = a faster fan (its
## wider arc reads as a sweep). Null-guarded so a bare boss (unit test) without the
## scene assigned simply does nothing.
func fire_pattern() -> void:
	if enemy_projectile_scene == null or target == null or _won:
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var aim := (target.global_position - global_position).normalized()
	var dirs := attack_directions(aim)
	for dir in dirs:
		var proj := enemy_projectile_scene.instantiate()
		tree.current_scene.add_child(proj)
		proj.global_position = global_position
		if proj.has_method("setup"):
			proj.setup(dir, phase_damage())
	# TASK-058: play the attack (wind-up/fire) one-shot when the volley actually
	# fires, mirroring the drones' cast one-shot.
	if _anim_ctrl != null and _anim_ctrl.has_method("play_attack"):
		_anim_ctrl.play_attack()

## The set of projectile directions for the current pattern — pure-ish (delegates
## to WardenPhases.fan_directions) so the per-phase shape is testable.
func attack_directions(aim: Vector2) -> Array:
	match pattern():
		WardenPhases.Pattern.FAN:
			return WardenPhases.fan_directions(aim, fan_count, fan_spread)
		WardenPhases.Pattern.SWEEP:
			# A wider, denser fan reads as a sweep across the arena.
			return WardenPhases.fan_directions(aim, fan_count + 2, fan_spread * 1.6)
		_:
			return WardenPhases.fan_directions(aim, 1, 0.0)   # single heavy shot

## TASK-017: once defeated, leave the sprite alone so the per-frame tint tick can't
## overwrite the death dissolve tween's alpha fade (and shrink).
func _update_tint() -> void:
	if _won:
		return
	if _sprite == null:
		return
	if _telegraphing:
		_sprite.modulate = TELEGRAPH_COLOR
	elif _slow.is_active():
		_sprite.modulate = SLOW_TINT
	else:
		_sprite.modulate = _armor_color

## DD-010 victory: at 0 HP the boss is defeated exactly once — freeze movement and
## emit `defeated` so the arena enters its victory state (freeze + label). TASK-017
## layers the LOUDER shared death beat (element-tinted dissolve + burst) ON TOP of
## the existing flow WITHOUT freeing the boss — the victory state keeps it on screen.
## The `_won` latch makes the whole path single-trigger (overkill / re-emitted died).
## TASK-058 documented gap: there is no dedicated death animation — the dissolve runs
## on whatever frame is showing (typically the last "hurt" frame, since a landed hit
## precedes the kill), matching the hero's + drones' documented death fallback.
func _on_died() -> void:
	if _won:
		return
	_won = true
	velocity = Vector2.ZERO
	_big_juice_beat()
	_play_death_effect()
	defeated.emit()


## TASK-017 boss death beat (LOUDEST per the juice budget): element-tinted burst at
## the boss + a dissolve of the sprite. Does NOT queue_free — the arena victory state
## owns the boss's lifetime (read warden.gd / arena flow), so we only play visuals.
func _play_death_effect() -> void:
	var tuning := DeathEffect.tuning_for(max_health)
	_spawn_death_burst(armor_type())
	_play_dissolve(float(tuning.dissolve_time))


## Element-tinted death burst (reuses impact_spark.burst), tinted by the CURRENT phase
## armor so the kill reads in that phase's color. Parented to the current scene (or an
## injected container). Null-guarded so a bare boss in a unit test simply no-ops.
func _spawn_death_burst(element: int) -> void:
	if death_effect_scene == null:
		return
	var parent: Node = death_burst_parent
	if parent == null:
		var tree := get_tree()
		if tree == null or tree.current_scene == null:
			return
		parent = tree.current_scene
	var burst := death_effect_scene.instantiate()
	parent.add_child(burst)
	if burst is Node2D:
		(burst as Node2D).global_position = global_position
	if burst.has_method("burst"):
		burst.burst(element)


## Dissolve the boss sprite (fade alpha + shrink) — visual only; the boss node stays.
func _play_dissolve(seconds: float) -> void:
	if _sprite == null:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	var faded := _sprite.modulate
	faded.a = 0.0
	tween.tween_property(_sprite, "modulate", faded, seconds)
	tween.tween_property(_sprite, "scale", _sprite.scale * DISSOLVE_END_SCALE, seconds)

func _refresh_label() -> void:
	if _label == null:
		return
	var hp := _health.current_health if _health != null else 0.0
	var maxhp := _health.max_health if _health != null else 0.0
	var armor: String = SpellData.Element.keys()[armor_type()]
	var weak: String = SpellData.Element.keys()[WardenPhases.weakness_for_phase(_phase)]
	_label.text = "THE WARDEN — Phase %d\n%s armor (weak: %s)\nHP %d/%d" % [
		_phase, armor, weak, int(hp), int(maxhp)]
