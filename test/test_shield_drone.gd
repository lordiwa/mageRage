## TASK-020 unit tests for the Shield Drone (Drone con escudo direccional) node.
##
## The Shield Drone is a FLOATING drone variant (reuses the EmpireDrone AI/Health/
## ElementMatchup/SlowEffect/apply_elemental_hit juice + TASK-017 death) with a
## DIRECTIONAL frontal shield. While NOT winding up, the shield tracks the player
## and BLOCKS player projectiles that strike its frontal arc (0 damage, no slow,
## no Health change). During its attack WIND-UP the shield DROPS — a telegraphed
## punish window — so the same frontal shot then lands FULL DD-006 matchup damage,
## as does any flank/behind shot. Pure arc/state math lives in ShieldLogic
## (test_shield_logic.gd); here we exercise the wiring that needs a live node +
## Health child: identity/layer/group, the block path in apply_elemental_hit, and
## regression of the matchup / Ice slow / single-trigger death.
##
## A test seam lets us set the shield facing + up/down directly so we don't have to
## step the whole FSM through the wind-up to reach a known shield state.
extends GutTest

const FIRE := SpellData.Element.FIRE
const ICE := SpellData.Element.ICE
const ELEC := SpellData.Element.ELECTRICITY
const DEG := PI / 180.0


# A scene-free stand-in for the death burst: records burst(element) + count.
class FakeBurst:
	extends Node2D
	var burst_element := -999
	var burst_count := 0

	func burst(element: int) -> void:
		burst_element = element
		burst_count += 1


var parent: Node2D


func before_each() -> void:
	parent = Node2D.new()
	add_child_autofree(parent)


func _fake_burst_scene() -> PackedScene:
	var ps := PackedScene.new()
	ps.pack(FakeBurst.new())
	return ps


# Build a bare Shield Drone with a Health child + a ColorRect Sprite + a ColorRect
# Shield in code (no .tscn) so its behavior is testable headlessly.
func _make_drone(armor: int = ICE, maxhp := 60.0) -> ShieldDrone:
	var drone := ShieldDrone.new()
	drone.armor_type = armor
	var health := Health.new()
	health.name = "Health"
	health.max_health = maxhp
	drone.add_child(health)
	var sprite := ColorRect.new()
	sprite.name = "Sprite"
	drone.add_child(sprite)
	var shield := ColorRect.new()
	shield.name = "Shield"
	drone.add_child(shield)
	var label := Label.new()
	label.name = "Label"
	drone.add_child(label)
	drone.death_effect_scene = _fake_burst_scene()
	drone.death_burst_parent = parent
	add_child_autofree(drone)        # _ready wires Health, collision, group, shield
	return drone


func _last_burst() -> FakeBurst:
	var found: FakeBurst = null
	for child in parent.get_children():
		if child is FakeBurst:
			found = child
	return found


func _hp(drone: ShieldDrone) -> float:
	return (drone.get_node("Health") as Health).current_health


# --- Identity: floating enemy on the Enemies layer, in the group --------------

func test_shield_drone_is_on_enemies_layer() -> void:
	var drone := _make_drone()
	assert_true(drone.get_collision_layer_value(3),
		"the Shield Drone is on the Enemies layer (3) so player magic can hit it")


func test_shield_drone_is_floating_not_grounded() -> void:
	var drone := _make_drone()
	assert_eq(drone.motion_mode, CharacterBody2D.MOTION_MODE_FLOATING,
		"the Shield Drone FLOATS (gravity off), like the EmpireDrone")


func test_shield_drone_is_in_enemies_group() -> void:
	var drone := _make_drone()
	assert_true(drone.is_in_group("enemies"),
		"the Shield Drone joins the `enemies` group (chain-mechanic compatibility)")


func test_shield_drone_default_armor_is_ice() -> void:
	var drone := ShieldDrone.new()
	assert_eq(drone.armor_type, SpellData.Element.ICE,
		"the Shield Drone defaults to ICE armor (weak to Fire) for encounter variety")
	drone.free()


# --- Block: shield UP + frontal hit deals 0 damage (Health unchanged) ---------

func test_frontal_hit_with_shield_up_deals_zero_damage() -> void:
	var drone := _make_drone(ICE, 60.0)
	# Shield faces RIGHT; the shot travels LEFT, approaching head-on into the face.
	drone.set_shield_for_test(Vector2.RIGHT, true)
	drone.apply_elemental_hit(FIRE, 40.0, false, Vector2.LEFT)
	assert_almost_eq(_hp(drone), 60.0, 0.001,
		"a frontal hit on the RAISED shield is blocked: Health is unchanged (0 damage)")


func test_blocked_frontal_hit_applies_no_slow() -> void:
	var drone := _make_drone(ICE, 60.0)
	drone.set_shield_for_test(Vector2.RIGHT, true)
	# An Ice hit with the slow flag, but BLOCKED -> the slow must not stick.
	drone.apply_elemental_hit(ICE, 10.0, true, Vector2.LEFT)
	assert_false(drone.is_slowed(),
		"a BLOCKED hit applies no Ice slow (the shield negated it entirely)")


func test_blocked_hit_does_not_trigger_death() -> void:
	var drone := _make_drone(ICE, 30.0)
	drone.set_shield_for_test(Vector2.RIGHT, true)
	# A would-be-lethal frontal hit, but blocked -> the drone survives.
	drone.apply_elemental_hit(FIRE, 1000.0, false, Vector2.LEFT)
	assert_false(drone.is_dying(),
		"a blocked hit never starts the death path (no Health was lost)")
	assert_null(_last_burst(), "no death burst spawns from a blocked hit")


# --- Punish: SAME frontal hit with the shield DOWN deals FULL damage ----------

func test_frontal_hit_with_shield_down_deals_full_matchup_damage() -> void:
	var drone := _make_drone(ICE, 100.0)
	# Shield faces RIGHT but is DOWN (wind-up): the same head-on shot now lands.
	drone.set_shield_for_test(Vector2.RIGHT, false)
	# Fire into ICE armor is super-effective (x1.5): 40 base -> 60 damage.
	drone.apply_elemental_hit(FIRE, 40.0, false, Vector2.LEFT)
	assert_almost_eq(_hp(drone), 40.0, 0.001,
		"with the shield DOWN the frontal shot lands full x1.5 matchup (100 - 60 = 40)")


# --- Bypass: a flank/behind hit lands FULL damage even with the shield UP ------

func test_flank_hit_with_shield_up_deals_full_damage() -> void:
	var drone := _make_drone(ICE, 100.0)
	# Shield faces RIGHT, UP. A shot into the BACK (travels +x, comes from -x).
	drone.set_shield_for_test(Vector2.RIGHT, true)
	drone.apply_elemental_hit(FIRE, 40.0, false, Vector2.RIGHT)
	assert_almost_eq(_hp(drone), 40.0, 0.001,
		"a hit into the unshielded BACK lands full matchup damage even with shield UP")


func test_oblique_flank_hit_with_shield_up_deals_full_damage() -> void:
	var drone := _make_drone(ICE, 100.0)
	drone.set_shield_for_test(Vector2.RIGHT, true)
	# Approaches from 90deg above (pure flank), outside any frontal arc.
	var approach := Vector2.UP
	drone.apply_elemental_hit(FIRE, 40.0, false, -approach)
	assert_almost_eq(_hp(drone), 40.0, 0.001,
		"a 90deg flank hit slips past the raised shield -> full matchup damage")


# --- shield_up_during / wind-up predicate ------------------------------------

func test_shield_is_down_during_attack_windup() -> void:
	assert_false(ShieldDrone.shield_up_during("DroneAttackState"),
		"the shield is DOWN during the Attack wind-up (the telegraphed punish window)")


func test_shield_is_up_during_patrol_and_chase() -> void:
	assert_true(ShieldDrone.shield_up_during("DronePatrolState"),
		"the shield is UP while patrolling")
	assert_true(ShieldDrone.shield_up_during("DroneChaseState"),
		"the shield is UP while chasing")


# --- Readable shield state seam ----------------------------------------------

func test_shield_up_state_is_queryable() -> void:
	var drone := _make_drone()
	drone.set_shield_for_test(Vector2.RIGHT, true)
	assert_true(drone.is_shield_up(), "the shield up/down state is readable")
	drone.set_shield_for_test(Vector2.RIGHT, false)
	assert_false(drone.is_shield_up(), "the shield reads as down after dropping")


# --- Regression: matchup / Ice slow / single-trigger death (unblocked path) ---

func test_matchup_multiplier_applies_when_unblocked() -> void:
	var drone := _make_drone(ICE, 100.0)
	drone.set_shield_for_test(Vector2.RIGHT, false)   # down -> shot lands
	# Fire into ICE armor is super-effective x1.5: 20 base -> 30 damage.
	drone.apply_elemental_hit(FIRE, 20.0, false, Vector2.LEFT)
	assert_almost_eq(_hp(drone), 70.0, 0.001,
		"Fire into the default Ice armor deals x1.5 when unblocked (100 - 30 = 70)")


func test_ice_slow_applies_when_unblocked() -> void:
	var drone := _make_drone(ICE, 100.0)
	drone.set_shield_for_test(Vector2.RIGHT, false)
	drone.apply_elemental_hit(ICE, 5.0, true, Vector2.LEFT)
	assert_true(drone.is_slowed(), "an unblocked Ice hit with the slow flag slows the drone")
	assert_almost_eq(drone.speed_multiplier(), 0.5, 0.001,
		"a slowed Shield Drone runs at the 0.5 control multiplier")


func test_lethal_unblocked_hit_triggers_single_death() -> void:
	var drone := _make_drone(ICE, 40.0)
	drone.set_shield_for_test(Vector2.RIGHT, false)
	drone.apply_elemental_hit(FIRE, 1000.0, false, Vector2.LEFT)   # lethal
	assert_true(drone.is_dying(), "reaching 0 HP starts the death (dissolve) path")
	var burst := _last_burst()
	assert_not_null(burst, "the death effect spawns a particle burst")
	# A second overkill hit must NOT replay the death effect.
	drone.apply_elemental_hit(FIRE, 1000.0, false, Vector2.LEFT)
	if burst != null:
		assert_eq(burst.burst_count, 1,
			"the death effect plays exactly once even under overkill")


func test_death_burst_tinted_by_armor_element() -> void:
	var drone := _make_drone(ICE, 30.0)
	drone.set_shield_for_test(Vector2.RIGHT, false)
	drone.apply_elemental_hit(FIRE, 1000.0, false, Vector2.LEFT)
	var burst := _last_burst()
	assert_not_null(burst)
	if burst != null:
		assert_eq(burst.burst_element, ICE,
			"the death burst is tinted by the drone's armor element (Ice)")
