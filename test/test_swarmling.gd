## TASK-019 unit tests for the Swarmling node — a lightweight FLOATING low-HP drone
## that reuses the combat kit (Health / ElementMatchup / SlowEffect / the
## apply_elemental_hit juice bundle + element-tinted single-trigger death) and lives
## in the `enemies` group so the Electricity CHAIN can arc to it.
##
## Pure matchup / slow / chain math is covered elsewhere (test_element_matchup,
## test_slow_effect, test_projectile_chain); here we exercise the node wiring that
## needs a live node + Health child, mirroring test_charger.gd's bare-node pattern.
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


var parent: Node2D


func before_each() -> void:
	parent = Node2D.new()
	add_child_autofree(parent)


func _fake_burst_scene() -> PackedScene:
	var ps := PackedScene.new()
	ps.pack(FakeBurst.new())
	return ps


# Build a bare Swarmling with a Health child + a ColorRect Sprite in code (no .tscn)
# so its behavior is testable headlessly.
func _make_swarmling(armor: int = FIRE, maxhp := 20.0) -> Swarmling:
	var s := Swarmling.new()
	s.armor_type = armor
	var health := Health.new()
	health.name = "Health"
	health.max_health = maxhp
	s.add_child(health)
	var sprite := ColorRect.new()
	sprite.name = "Sprite"
	s.add_child(sprite)
	s.death_effect_scene = _fake_burst_scene()
	s.death_burst_parent = parent
	add_child_autofree(s)
	return s


func _hp(s: Swarmling) -> float:
	return (s.get_node("Health") as Health).current_health


# --- Identity: floating enemy on the Enemies layer, in the group --------------

func test_swarmling_is_on_enemies_layer() -> void:
	var s := _make_swarmling()
	assert_true(s.get_collision_layer_value(3),
		"a Swarmling is on the Enemies layer (3) so player magic + the chain can hit it")


func test_swarmling_is_floating_not_grounded() -> void:
	var s := _make_swarmling()
	assert_eq(s.motion_mode, CharacterBody2D.MOTION_MODE_FLOATING,
		"a Swarmling is a FLYING drone (gravity off), like the EmpireDrone")


func test_swarmling_is_in_enemies_group() -> void:
	var s := _make_swarmling()
	assert_true(s.is_in_group("enemies"),
		"a Swarmling joins the `enemies` group so the Electricity chain arcs to it")


func test_swarmling_defaults_to_fire_armor() -> void:
	var s := _make_swarmling()
	assert_eq(s.armor_type, FIRE,
		"a Swarmling is FIRE-armored by default -> Electricity is its 1.5x weak point")


# --- Combat: matchup, slow, single-trigger death (reuse / regression) ---------

func test_electricity_is_super_effective_into_fire_armor() -> void:
	# Electricity vs Fire armor = WEAK (x1.5): the showcase weak point.
	var s := _make_swarmling(FIRE, 100.0)
	s.apply_elemental_hit(ELEC, 10.0, false)
	assert_almost_eq(_hp(s), 85.0, 0.001,
		"Electricity into Fire armor deals 1.5x (10 -> 15 damage)")


func test_fire_into_fire_armor_resists() -> void:
	var s := _make_swarmling(FIRE, 100.0)
	s.apply_elemental_hit(FIRE, 10.0, false)
	assert_almost_eq(_hp(s), 95.0, 0.001,
		"Fire into Fire armor RESISTS (x0.5 -> 5 damage)")


func test_ice_hit_applies_slow() -> void:
	var s := _make_swarmling(FIRE, 100.0)
	assert_false(s.is_slowed(), "starts unslowed")
	s.apply_elemental_hit(ICE, 10.0, true)
	assert_true(s.is_slowed(), "an Ice hit (slow=true) slows the Swarmling (DD-004)")


func test_death_effect_triggers_once_on_overkill() -> void:
	var s := _make_swarmling(FIRE, 20.0)
	# Overkill: a single big Electricity hit (x1.5) far exceeds 20 HP.
	s.apply_elemental_hit(ELEC, 1000.0, false)
	assert_true(s.is_dying(), "a lethal hit starts the death effect")
	# A second hit (e.g. a chain arc landing the same frame) must not replay it.
	s.apply_elemental_hit(ELEC, 1000.0, false)
	var bursts := 0
	for child in parent.get_children():
		if child is FakeBurst and child.burst_count > 0:
			bursts += 1
	assert_eq(bursts, 1, "the death burst fires exactly once (single-trigger)")
