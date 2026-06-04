## TASK-022 unit tests: the SHOT TYPE is data-driven in SpellData and set per
## element in the .tres definition files, making "each element has a shot type in
## the definition files" literally true (DD-004 identities):
##   firebolt  = SINGLE  (Fire, high damage, stops on first hit)
##   ice_shard = PIERCE  (Ice, passes through, applies_slow, max_targets > 1)
##   lightning = CHAIN   (Electricity, redirects to nearest unhit, max_targets 3)
extends GutTest

const FIRE_PATH := "res://resources/spells/firebolt.tres"
const ICE_PATH := "res://resources/spells/ice_shard.tres"
const LIGHTNING_PATH := "res://resources/spells/lightning.tres"


func _load(path: String) -> SpellData:
	return load(path) as SpellData


func test_shot_type_enum_exists_with_three_members() -> void:
	# The enum is the data contract: SINGLE / PIERCE / CHAIN.
	assert_eq(SpellData.ShotType.SINGLE, 0, "SINGLE is the first/default shot type")
	# Distinct values:
	var vals := [SpellData.ShotType.SINGLE, SpellData.ShotType.PIERCE,
		SpellData.ShotType.CHAIN]
	var seen := {}
	for v in vals:
		seen[v] = true
	assert_eq(seen.size(), 3, "three distinct shot types")


func test_default_shot_type_is_single() -> void:
	# Backward-compat: a bare SpellData (older callers/tests) defaults to SINGLE.
	var s := SpellData.new()
	assert_eq(s.shot_type, SpellData.ShotType.SINGLE,
		"a SpellData built without a shot_type defaults to SINGLE")


func test_firebolt_is_single() -> void:
	var s := _load(FIRE_PATH)
	assert_eq(s.shot_type, SpellData.ShotType.SINGLE,
		"Fire = single-target burst")


func test_ice_shard_is_pierce_and_can_pierce_multiple() -> void:
	var s := _load(ICE_PATH)
	assert_eq(s.shot_type, SpellData.ShotType.PIERCE, "Ice = pierce")
	assert_gt(s.max_targets, 1, "Ice pierces more than one enemy")
	assert_true(s.applies_slow, "Ice still applies a slow on each pierced hit")


func test_lightning_is_chain_with_three_targets() -> void:
	var s := _load(LIGHTNING_PATH)
	assert_eq(s.shot_type, SpellData.ShotType.CHAIN, "Electricity = chain")
	assert_eq(s.max_targets, 3, "Electricity chains up to 3 enemies")


func test_chain_radius_is_positive() -> void:
	var s := _load(LIGHTNING_PATH)
	assert_gt(s.chain_radius, 0.0, "the chain reach radius is a positive distance")
