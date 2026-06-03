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
