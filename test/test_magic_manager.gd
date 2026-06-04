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
## A real Node2D cast origin. cast_primary/cast_secondary type their origin as
## Node2D, so passing the GutTest (a Node) is a PARSE error that silently skips the
## whole file — use this instead.
var origin: Node2D


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

	origin = Node2D.new()
	add_child_autofree(origin)   # a real Node2D origin for cast_primary/secondary


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


# --- TASK-015 can_afford predicate (pure, drives the no-mana feedback) --------

func test_can_afford_true_when_mana_meets_cost() -> void:
	mana.current_mana = 20.0   # >= fire cost 15
	assert_true(mgr.can_afford(fire), "can_afford is true when mana >= the spell cost")


func test_can_afford_true_at_exact_cost() -> void:
	mana.current_mana = 15.0   # == fire cost 15
	assert_true(mgr.can_afford(fire), "can_afford is true at exactly the spell cost")


func test_can_afford_false_when_mana_below_cost() -> void:
	mana.current_mana = 5.0    # < fire cost 15
	assert_false(mgr.can_afford(fire), "can_afford is false when mana < the spell cost")


func test_can_afford_false_on_null_spell() -> void:
	mana.current_mana = 100.0
	assert_false(mgr.can_afford(null), "can_afford is false for a missing (null) spell")


func test_can_afford_false_on_null_mana() -> void:
	mgr.mana = null
	assert_false(mgr.can_afford(fire), "can_afford is false when there is no Mana component")


# --- TASK-015 cast_failed signal: insufficient mana ONLY ---------------------
# The HUD listens to cast_failed to flash the mana bar. It must fire ONLY when a
# real spell was attempted but rejected for insufficient mana — never on a
# successful cast, never when the slot is empty (no spell to fail).

func test_cast_failed_emitted_on_primary_insufficient_mana() -> void:
	mana.current_mana = 5.0   # < fire (primary) cost 15
	watch_signals(mgr)
	var ok := mgr.cast_primary(origin, Vector2.RIGHT)
	assert_false(ok, "the cast is rejected (no projectile) when mana is too low")
	assert_signal_emitted(mgr, "cast_failed",
		"a primary cast rejected for low mana emits cast_failed")


func test_cast_failed_emitted_on_secondary_insufficient_mana() -> void:
	mana.current_mana = 5.0   # < ice (secondary) cost 12
	watch_signals(mgr)
	var ok := mgr.cast_secondary(origin, Vector2.RIGHT)
	assert_false(ok, "the secondary cast is rejected when mana is too low")
	assert_signal_emitted(mgr, "cast_failed",
		"a secondary cast rejected for low mana emits cast_failed")


func test_cast_failed_not_emitted_on_successful_cast() -> void:
	# Plenty of mana: try_cast succeeds (spends mana). cast_failed must stay quiet
	# even though no projectile spawns here (fire.tres has no projectile in-test).
	mana.current_mana = 100.0
	watch_signals(mgr)
	mgr.cast_primary(origin, Vector2.RIGHT)
	assert_signal_not_emitted(mgr, "cast_failed",
		"an affordable cast must NOT emit cast_failed (it paid; the slot fired)")
	assert_eq(mana.current_mana, 85.0,
		"an affordable cast still spends mana (no regression to the spend path)")


func test_cast_failed_not_emitted_when_slot_empty() -> void:
	# An empty primary slot is a missing spell, not a mana failure — stay silent.
	mgr.primary = null
	mana.current_mana = 100.0
	watch_signals(mgr)
	var ok := mgr.cast_primary(origin, Vector2.RIGHT)
	assert_false(ok, "an empty slot cast spawns nothing")
	assert_signal_not_emitted(mgr, "cast_failed",
		"an empty slot is not a low-mana failure; cast_failed must not fire")
