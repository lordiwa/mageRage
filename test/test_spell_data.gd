## Unit tests for the SpellData resource definitions (.tres) reflecting DD-004
## element identities: Fire = single-target burst (highest per-hit damage), Ice =
## control/slow flag, Electricity = chain multi-target (lower per-hit, can chain).
extends GutTest

const FIRE_PATH := "res://resources/spells/firebolt.tres"
const ICE_PATH := "res://resources/spells/ice_shard.tres"
const LIGHTNING_PATH := "res://resources/spells/lightning.tres"


func _load(path: String) -> SpellData:
	return load(path) as SpellData


func test_firebolt_is_fire_with_positive_cost_and_damage() -> void:
	var s := _load(FIRE_PATH)
	assert_not_null(s, "firebolt.tres should load as SpellData")
	assert_eq(s.element, SpellData.Element.FIRE)
	assert_gt(s.damage, 0.0)
	assert_gt(s.mana_cost, 0.0)


func test_ice_shard_is_ice_and_applies_slow() -> void:
	var s := _load(ICE_PATH)
	assert_eq(s.element, SpellData.Element.ICE)
	assert_true(s.applies_slow, "DD-004: Ice is control -> applies a slow flag")


func test_lightning_is_electricity_and_chains() -> void:
	var s := _load(LIGHTNING_PATH)
	assert_eq(s.element, SpellData.Element.ELECTRICITY)
	assert_gt(s.max_targets, 1,
		"DD-004: Electricity is multi-target -> hits more than one")


func test_fire_has_highest_single_hit_damage() -> void:
	# DD-004 identity: Fire = burst single-target, Electricity = lower per-hit.
	var fire := _load(FIRE_PATH)
	var ice := _load(ICE_PATH)
	var lightning := _load(LIGHTNING_PATH)
	assert_gt(fire.damage, lightning.damage,
		"Fire's per-hit damage should exceed Electricity's (chain trade-off)")
	assert_gt(fire.damage, ice.damage,
		"Fire is the single-target burst -> highest per-hit damage")


func test_all_spells_carry_a_projectile_scene() -> void:
	for path in [FIRE_PATH, ICE_PATH, LIGHTNING_PATH]:
		var s := _load(path)
		assert_not_null(s.projectile, "%s should reference a projectile scene" % path)


# --- TASK-038 per-element fire rate (hold-to-fire cadence) -------------------
# DD-004 identity: Fire fastest, Electricity medium, Ice slowest. Each SpellData
# carries its own `fire_interval` (seconds between held shots) so cadence is
# data-driven (NO per-element constants in scripts).

func test_spell_data_exposes_a_positive_fire_interval_default() -> void:
	var s := SpellData.new()
	assert_gt(s.fire_interval, 0.0,
		"SpellData exposes a fire_interval that defaults to a positive value")


func test_each_spell_has_a_positive_fire_interval() -> void:
	for path in [FIRE_PATH, ICE_PATH, LIGHTNING_PATH]:
		var s := _load(path)
		assert_gt(s.fire_interval, 0.0,
			"%s should define a positive fire_interval" % path)


func test_fire_interval_ordering_fire_fastest_ice_slowest() -> void:
	# DD-004: Fire fastest (smallest interval) < Electricity < Ice slowest.
	var fire := _load(FIRE_PATH)
	var ice := _load(ICE_PATH)
	var lightning := _load(LIGHTNING_PATH)
	assert_lt(fire.fire_interval, lightning.fire_interval,
		"Fire fires faster than Electricity (shorter interval)")
	assert_lt(lightning.fire_interval, ice.fire_interval,
		"Electricity fires faster than Ice (shorter interval)")


func test_fire_interval_provisional_values() -> void:
	# Provisional, tunable: Fire 0.18 / Electricity 0.28 / Ice 0.40.
	assert_almost_eq(_load(FIRE_PATH).fire_interval, 0.18, 0.0001)
	assert_almost_eq(_load(LIGHTNING_PATH).fire_interval, 0.28, 0.0001)
	assert_almost_eq(_load(ICE_PATH).fire_interval, 0.40, 0.0001)
