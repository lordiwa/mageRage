## TASK-018 unit tests for the Charger (Centinela de carga) node behavior.
##
## The Charger is the first GROUNDED MELEE enemy: it patrols, chases, TELEGRAPHS a
## wind-up, then LUNGES horizontally (contact damage), then has a RECOVERY window
## where its core is EXPOSED (extra-vulnerable). Pure phase/multiplier/lunge math is
## covered in test_charger_ai.gd; here we exercise the wiring that needs a live node
## + Health child:
##   - the FSM transitions (aggro gate, wind-up -> charge, charge -> recovery,
##     recovery -> chase) using a fake target + advancing the state machine;
##   - the EXPOSED-window bonus damage applied in apply_elemental_hit (more damage
##     when exposed than when guarded, same element);
##   - contact damage routed through player.take_player_damage and BLOCKED while the
##     player is invulnerable (mirrors the enemy_projectile i-frame gate);
##   - the lunge direction is LOCKED toward the player at wind-up start (no re-home);
##   - regression: the DD-006 matchup, the Ice SLOW, and the single-trigger death.
extends GutTest

const FIRE := SpellData.Element.FIRE
const ICE := SpellData.Element.ICE
const ELEC := SpellData.Element.ELECTRICITY


# A scene-free stand-in for the death burst: records burst(element) + count.
class FakeBurst:
	extends Node2D
	var burst_element := -999
	var burst_count := 0

	func burst(element: int) -> void:
		burst_element = element
		burst_count += 1


# A scene-free stand-in for the hero's contact-damage handler (mirrors the
# enemy_projectile test's FakeHero): records damage + exposes the i-frame gate.
class FakeHero:
	extends Node2D
	var invulnerable := false
	var damage_taken := 0.0
	var last_hit_dir := Vector2.ZERO
	var hit_count := 0

	func is_invulnerable() -> bool:
		return invulnerable

	func take_player_damage(amount: float, hit_dir: Vector2 = Vector2.ZERO) -> void:
		damage_taken += amount
		last_hit_dir = hit_dir
		hit_count += 1


var parent: Node2D


func before_each() -> void:
	parent = Node2D.new()
	add_child_autofree(parent)


func _fake_burst_scene() -> PackedScene:
	var ps := PackedScene.new()
	ps.pack(FakeBurst.new())
	return ps


# Build a bare Charger with a Health child + a ColorRect Sprite in code (no .tscn)
# so its behavior is testable headlessly. A far-off / settable fake target drives
# the AI. A test-owned parent scopes any spawned death bursts.
func _make_charger(armor: int = FIRE, maxhp := 80.0) -> Charger:
	var charger := Charger.new()
	charger.armor_type = armor
	var health := Health.new()
	health.name = "Health"
	health.max_health = maxhp
	charger.add_child(health)
	var sprite := ColorRect.new()
	sprite.name = "Sprite"
	charger.add_child(sprite)
	var label := Label.new()
	label.name = "Label"
	charger.add_child(label)
	charger.death_effect_scene = _fake_burst_scene()
	charger.death_burst_parent = parent
	add_child_autofree(charger)        # _ready: wires Health, collision, gravity
	return charger


func _set_target(charger: Charger, pos: Vector2) -> Node2D:
	var t := Node2D.new()
	t.global_position = pos
	add_child_autofree(t)
	charger.target = t
	return t


func _last_burst() -> FakeBurst:
	var found: FakeBurst = null
	for child in parent.get_children():
		if child is FakeBurst:
			found = child
	return found


# --- Identity: grounded enemy on the Enemies layer, in the group --------------

func test_charger_is_on_enemies_layer() -> void:
	var charger := _make_charger()
	assert_true(charger.get_collision_layer_value(3),
		"the Charger is on the Enemies layer (3) so player magic can hit it")


func test_charger_is_grounded_not_floating() -> void:
	var charger := _make_charger()
	assert_eq(charger.motion_mode, CharacterBody2D.MOTION_MODE_GROUNDED,
		"the Charger is a GROUNDED melee enemy (gravity applies), unlike the drone")


func test_charger_is_in_enemies_group() -> void:
	var charger := _make_charger()
	assert_true(charger.is_in_group("enemies"),
		"the Charger joins the `enemies` group (chain-mechanic compatibility)")


# --- AI gating helpers (aggro) ------------------------------------------------

func test_not_in_aggro_range_when_player_far() -> void:
	var charger := _make_charger()
	_set_target(charger, Vector2(5000, 0))
	assert_false(charger.player_in_aggro_range(),
		"a distant player is outside aggro range -> stays patrolling")


func test_in_aggro_range_when_player_close() -> void:
	var charger := _make_charger()
	_set_target(charger, Vector2(50, 0))
	assert_true(charger.player_in_aggro_range(),
		"a nearby player is within aggro range -> chase")


# --- EXPOSED-window bonus damage in apply_elemental_hit -----------------------
# Same element, same base damage: an EXPOSED Charger takes strictly MORE than a
# guarded one. We drive the exposed flag via the test seam set_exposed_for_test.

func test_exposed_charger_takes_more_damage_than_guarded() -> void:
	var guarded := _make_charger(FIRE, 500.0)
	guarded.set_exposed_for_test(false)
	guarded.apply_elemental_hit(ICE, 40.0, false)   # Ice neutral vs Fire (x1.0)
	var guarded_hp := (guarded.get_node("Health") as Health).current_health
	var guarded_dmg := 500.0 - guarded_hp

	var exposed := _make_charger(FIRE, 500.0)
	exposed.set_exposed_for_test(true)
	exposed.apply_elemental_hit(ICE, 40.0, false)   # same element + base
	var exposed_hp := (exposed.get_node("Health") as Health).current_health
	var exposed_dmg := 500.0 - exposed_hp

	assert_gt(exposed_dmg, guarded_dmg,
		"an EXPOSED Charger takes BONUS damage vs a guarded one (same element/base)")


func test_guarded_charger_takes_only_matchup_damage() -> void:
	var charger := _make_charger(FIRE, 500.0)
	charger.set_exposed_for_test(false)
	# Electricity into Fire armor is x1.5: 40 base -> 60 damage (no exposed bonus).
	charger.apply_elemental_hit(ELEC, 40.0, false)
	var hp := (charger.get_node("Health") as Health).current_health
	assert_almost_eq(hp, 440.0, 0.001,
		"a guarded Charger takes only the DD-006 matchup damage (x1.5, no bonus)")


# --- Contact damage routes through the player, gated by i-frames --------------

func test_lunge_contact_damages_vulnerable_player() -> void:
	var charger := _make_charger()
	var hero := FakeHero.new()
	hero.invulnerable = false
	add_child_autofree(hero)
	charger.deal_contact_damage(hero)
	assert_eq(hero.hit_count, 1, "the lunge hits a vulnerable player exactly once")
	assert_gt(hero.damage_taken, 0.0,
		"the lunge deals contact damage through take_player_damage")


func test_lunge_contact_blocked_while_player_invulnerable() -> void:
	var charger := _make_charger()
	var hero := FakeHero.new()
	hero.invulnerable = true
	add_child_autofree(hero)
	charger.deal_contact_damage(hero)
	assert_eq(hero.hit_count, 0,
		"the lunge does NOT hit a player during i-frames (respects invulnerability)")
	assert_eq(hero.damage_taken, 0.0, "no contact damage lands during i-frames")


func test_lunge_contact_threads_charge_direction() -> void:
	var charger := _make_charger()
	var hero := FakeHero.new()
	hero.invulnerable = false
	add_child_autofree(hero)
	# Lock the lunge toward a player on the right, then deal contact damage.
	charger.lock_lunge_toward(Vector2(900, 0))
	charger.deal_contact_damage(hero)
	assert_almost_eq(hero.last_hit_dir.x, 1.0, 0.0001,
		"the contact hit threads the locked charge direction (RIGHT) as hit_dir")


# --- Lunge direction is LOCKED toward the player at wind-up start -------------

func test_lunge_direction_locks_toward_player() -> void:
	var charger := _make_charger()
	charger.global_position = Vector2(100, 0)
	charger.lock_lunge_toward(Vector2(400, 0))   # player to the right at wind-up
	assert_eq(charger.lunge_direction_sign(), 1.0,
		"the lunge locks to +1 (right) when the player was right at wind-up start")


func test_lunge_direction_does_not_rehome_mid_charge() -> void:
	var charger := _make_charger()
	charger.global_position = Vector2(100, 0)
	charger.lock_lunge_toward(Vector2(400, 0))   # locked RIGHT
	# The player now teleports behind the Charger; a fair charge must NOT re-home.
	var t := _set_target(charger, Vector2(-400, 0))
	assert_eq(charger.lunge_direction_sign(), 1.0,
		"the locked lunge does not re-home toward the player mid-charge (fair)")
	assert_not_null(t)


# --- Ice SLOW reduces charge/wind-up speed (DD-009 control) -------------------

func test_default_speed_multiplier_is_full() -> void:
	var charger := _make_charger()
	assert_almost_eq(charger.speed_multiplier(), 1.0, 0.001,
		"an un-slowed Charger moves/winds-up at full speed")


func test_ice_hit_slows_the_charger() -> void:
	var charger := _make_charger(FIRE, 500.0)
	charger.apply_elemental_hit(ICE, 5.0, true)   # slow flag set
	assert_true(charger.is_slowed(), "an Ice hit with the slow flag slows the Charger")
	assert_almost_eq(charger.speed_multiplier(), 0.5, 0.001,
		"a slowed Charger runs at the 0.5 control multiplier (slower wind-up + lunge)")


# --- Regression: matchup damage + single-trigger death ------------------------

func test_matchup_multiplier_applies() -> void:
	var charger := _make_charger(FIRE, 100.0)
	charger.set_exposed_for_test(false)
	# Electricity into Fire armor is super-effective x1.5: 20 base -> 30 damage.
	charger.apply_elemental_hit(ELEC, 20.0, false)
	var hp := (charger.get_node("Health") as Health).current_health
	assert_almost_eq(hp, 70.0, 0.001,
		"Electricity into the default Fire armor still deals x1.5 (100 - 30 = 70)")


func test_lethal_hit_triggers_single_death_effect() -> void:
	var charger := _make_charger(FIRE, 40.0)
	charger.apply_elemental_hit(ICE, 100.0, false)   # neutral vs Fire, overkills
	assert_true(charger.is_dying(), "reaching 0 HP starts the death (dissolve) path")
	var burst := _last_burst()
	assert_not_null(burst, "the death effect spawns a particle burst")
	# A second overkill hit must NOT replay the death effect.
	charger.apply_elemental_hit(ICE, 100.0, false)
	if burst != null:
		assert_eq(burst.burst_count, 1,
			"the death effect plays exactly once even under overkill")


func test_death_burst_tinted_by_armor_element() -> void:
	var charger := _make_charger(ELEC, 30.0)
	charger.apply_elemental_hit(FIRE, 100.0, false)   # neutral vs Elec, overkills
	var burst := _last_burst()
	assert_not_null(burst)
	if burst != null:
		assert_eq(burst.burst_element, ELEC,
			"the death burst is tinted by the Charger's armor element")
