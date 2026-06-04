## Unit tests for the DD-008 MagicManager 2-slot loadout (pure logic).
##
## The manager holds three SpellData (Fire/Ice/Electricity) and a PRIMARY +
## SECONDARY element loadout. select(index) promotes that element to primary and
## demotes the previous primary to secondary (a last-two-distinct stack;
## re-selecting the current primary is a no-op). Casting checks+spends mana via an
## injected Mana component. To stay headless, casting is split: try_cast_primary()/
## try_cast_secondary() validate mana and spend, returning the SpellData to spawn
## (or null if it couldn't pay / no spell). The actual projectile spawn (scene
## work) is exercised in the integration smoke run, not here.
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


func test_loadout_defaults_to_first_two_distinct_spells() -> void:
	assert_eq(mgr.primary, fire, "primary defaults to the first spell")
	assert_eq(mgr.secondary, ice, "secondary defaults to the second spell")


func test_select_promotes_to_primary_and_demotes_prior_primary() -> void:
	# Start: primary=fire, secondary=ice. Selecting electricity makes it primary
	# and pushes fire (the old primary) down to secondary.
	mgr.select(2)   # electricity
	assert_eq(mgr.primary, lightning, "selected element becomes primary")
	assert_eq(mgr.secondary, fire, "the previous primary is demoted to secondary")


func test_select_keeps_last_two_distinct_stack() -> void:
	# fire/ice -> select ice (already in loadout as secondary): ice promotes to
	# primary, fire demotes to secondary (swap the two).
	mgr.select(1)   # ice
	assert_eq(mgr.primary, ice, "selecting the secondary promotes it to primary")
	assert_eq(mgr.secondary, fire, "and the old primary becomes secondary")
	# Now select electricity: it becomes primary, ice demotes; fire is forgotten.
	mgr.select(2)   # electricity
	assert_eq(mgr.primary, lightning)
	assert_eq(mgr.secondary, ice, "only the last two distinct elements are kept")


func test_select_current_primary_is_noop() -> void:
	# primary=fire, secondary=ice; re-pressing fire changes nothing.
	mgr.select(0)   # fire (already primary)
	assert_eq(mgr.primary, fire, "re-selecting the current primary keeps it primary")
	assert_eq(mgr.secondary, ice, "and does NOT disturb the secondary")


func test_select_out_of_range_is_ignored() -> void:
	mgr.select(99)
	assert_eq(mgr.primary, fire, "an out-of-range index must not change the loadout")
	assert_eq(mgr.secondary, ice)


func test_try_cast_primary_spends_primary_cost_and_returns_spell() -> void:
	mana.current_mana = 100.0
	# primary = fire (cost 15)
	var spell := mgr.try_cast_primary()
	assert_eq(spell, fire, "cast_primary returns the primary slot's spell")
	assert_eq(mana.current_mana, 85.0, "cast_primary spends the primary's mana cost")


func test_try_cast_secondary_spends_secondary_cost_and_returns_spell() -> void:
	mana.current_mana = 100.0
	# secondary = ice (cost 12)
	var spell := mgr.try_cast_secondary()
	assert_eq(spell, ice, "cast_secondary returns the secondary slot's spell")
	assert_eq(mana.current_mana, 88.0, "cast_secondary spends the secondary's mana cost")


func test_cast_primary_and_secondary_fire_distinct_slots() -> void:
	# After promoting electricity, primary=electricity, secondary=fire. Each cast
	# fires its own slot's element.
	mgr.select(2)   # electricity -> primary, fire -> secondary
	mana.current_mana = 100.0
	var p := mgr.try_cast_primary()
	assert_eq(p.element, SpellData.Element.ELECTRICITY, "primary fires electricity")
	var s := mgr.try_cast_secondary()
	assert_eq(s.element, SpellData.Element.FIRE, "secondary fires fire")


func test_try_cast_primary_fails_when_mana_too_low() -> void:
	mana.current_mana = 5.0   # < fire cost 15
	var spell := mgr.try_cast_primary()
	assert_null(spell, "cast_primary must fail (return null) when mana < cost")
	assert_eq(mana.current_mana, 5.0, "a failed cast must not spend mana")


func test_try_cast_secondary_fails_when_mana_too_low() -> void:
	mana.current_mana = 5.0   # < ice cost 12
	var spell := mgr.try_cast_secondary()
	assert_null(spell, "cast_secondary must fail (return null) when mana < cost")
	assert_eq(mana.current_mana, 5.0, "a failed cast must not spend mana")
