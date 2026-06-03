## Unit tests for MagicManager equip/cycle/cast selection (pure logic).
##
## The manager holds three SpellData (Fire/Ice/Electricity), exposes equip-by-index
## (element_1/2/3) and cycle, and casting checks+spends mana via an injected Mana
## component. To stay headless, casting is split: try_cast() validates mana and
## spends, returning the SpellData to spawn (or null if it couldn't pay / no spell).
## The actual projectile spawn (scene work) is exercised in the integration smoke
## run, not here.
extends GutTest

var mgr: MagicManager
var mana: Mana
var fire: SpellData
var ice: SpellData
var lightning: SpellData


func before_each() -> void:
	fire = SpellData.new()
	fire.display_name = "Firebolt"
	fire.element = SpellData.Element.FIRE
	fire.damage = 30.0
	fire.mana_cost = 15.0

	ice = SpellData.new()
	ice.display_name = "Ice Shard"
	ice.element = SpellData.Element.ICE
	ice.damage = 18.0
	ice.mana_cost = 12.0

	lightning = SpellData.new()
	lightning.display_name = "Lightning"
	lightning.element = SpellData.Element.ELECTRICITY
	lightning.damage = 12.0
	lightning.mana_cost = 10.0

	mana = Mana.new()
	mana.max_mana = 100.0
	add_child_autofree(mana)

	mgr = MagicManager.new()
	mgr.spells = [fire, ice, lightning]
	mgr.mana = mana
	add_child_autofree(mgr)   # _ready equips slot 0


func test_defaults_to_first_spell() -> void:
	assert_eq(mgr.equipped, fire, "first spell should be equipped on ready")


func test_equip_selects_correct_slot() -> void:
	mgr.equip(1)
	assert_eq(mgr.equipped, ice, "equip(1) selects the Ice spell")
	mgr.equip(2)
	assert_eq(mgr.equipped, lightning, "equip(2) selects the Lightning spell")
	mgr.equip(0)
	assert_eq(mgr.equipped, fire, "equip(0) selects the Fire spell")


func test_equip_out_of_range_is_ignored() -> void:
	mgr.equip(0)
	mgr.equip(99)
	assert_eq(mgr.equipped, fire, "an out-of-range slot must not change the equip")


func test_cycle_advances_and_wraps() -> void:
	assert_eq(mgr.equipped, fire)
	mgr.cycle()
	assert_eq(mgr.equipped, ice, "cycle advances to the next spell")
	mgr.cycle()
	assert_eq(mgr.equipped, lightning)
	mgr.cycle()
	assert_eq(mgr.equipped, fire, "cycle wraps around to the first spell")


func test_equipped_element_reports_current() -> void:
	mgr.equip(2)
	assert_eq(mgr.equipped_element(), SpellData.Element.ELECTRICITY,
		"equipped_element reflects the current spell's element")


func test_try_cast_spends_equipped_cost_and_returns_spell() -> void:
	mana.current_mana = 100.0
	mgr.equip(0)   # Fire, cost 15
	var spell := mgr.try_cast()
	assert_eq(spell, fire, "a successful cast returns the equipped spell")
	assert_eq(mana.current_mana, 85.0, "cast spends the equipped spell's mana cost")


func test_try_cast_fails_when_mana_too_low() -> void:
	mana.current_mana = 5.0
	mgr.equip(0)   # Fire, cost 15 > 5
	var spell := mgr.try_cast()
	assert_null(spell, "cast must fail (return null) when mana < cost")
	assert_eq(mana.current_mana, 5.0, "a failed cast must not spend mana")


func test_try_cast_uses_currently_equipped_element_cost() -> void:
	mana.current_mana = 100.0
	mgr.equip(2)   # Lightning, cost 10
	var spell := mgr.try_cast()
	assert_eq(spell.element, SpellData.Element.ELECTRICITY)
	assert_eq(mana.current_mana, 90.0,
		"cast must use the equipped spell's cost, not another slot's")
