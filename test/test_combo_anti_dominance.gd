## TASK-040 (DD-013) FIX HIGH-1 invariant: dedicated single-element swapping must
## NEVER be worse (on damage-per-mana) than mashing both triggers for a combo.
##
## The combo's job is UTILITY / flexibility (AoE, chain+slow, burst-vs-slowed, not
## needing to read the armor) — NOT raw efficiency. So for EVERY armor type, the BEST
## correct single shot's dmg-per-mana must be >= the BEST combo's dmg-per-mana. If a
## combo ever out-efficiencies the right single, the micro swap loop collapses (the
## reviewer's HIGH-1). This test pins the tuning so it can never silently drift.
##
## Combo damage resolves THROUGH its base elements (mean matchup, DD-006); combo mana
## is the SUM of its two constituent single costs (the in-game combo_mana_cost for the
## canonical pair). Numbers come from the shipped .tres so this guards real data.
extends GutTest

const FIRE := SpellData.Element.FIRE
const ICE := SpellData.Element.ICE
const ELEC := SpellData.Element.ELECTRICITY

const FIRE_PATH := "res://resources/spells/firebolt.tres"
const ICE_PATH := "res://resources/spells/ice_shard.tres"
const LIGHTNING_PATH := "res://resources/spells/lightning.tres"
const STEAM_PATH := "res://resources/spells/combo_steam.tres"
const PLASMA_PATH := "res://resources/spells/combo_plasma.tres"
const FROSTARC_PATH := "res://resources/spells/combo_frostarc.tres"

var _fire: SpellData
var _ice: SpellData
var _lightning: SpellData
var _steam: SpellData
var _plasma: SpellData
var _frostarc: SpellData


func before_all() -> void:
	_fire = load(FIRE_PATH) as SpellData
	_ice = load(ICE_PATH) as SpellData
	_lightning = load(LIGHTNING_PATH) as SpellData
	_steam = load(STEAM_PATH) as SpellData
	_plasma = load(PLASMA_PATH) as SpellData
	_frostarc = load(FROSTARC_PATH) as SpellData


## A single's dmg-per-mana vs an armor: base * matchup(element, armor) / cost.
func _single_dpm(spell: SpellData, armor: int) -> float:
	return spell.damage * ElementMatchup.multiplier(spell.element, armor) / spell.mana_cost


## A combo's dmg-per-mana vs an armor. Damage routes through the derived (mean) combo
## matchup; mana is the SUM of the two CONSTITUENT single costs (the in-game cost of
## firing that combo from the canonical equipped pair).
func _combo_dpm(combo: SpellData, cost_a: float, cost_b: float, armor: int) -> float:
	return combo.damage * ElementMatchup.multiplier(combo.element, armor) / (cost_a + cost_b)


## The best (max) dmg-per-mana a correctly-swapping player can get from a single shot
## vs this armor (they pick the optimal element).
func _best_single_dpm(armor: int) -> float:
	return maxf(maxf(_single_dpm(_fire, armor), _single_dpm(_ice, armor)),
		_single_dpm(_lightning, armor))


## The best (max) dmg-per-mana any combo achieves vs this armor.
func _best_combo_dpm(armor: int) -> float:
	var steam := _combo_dpm(_steam, _fire.mana_cost, _ice.mana_cost, armor)
	var plasma := _combo_dpm(_plasma, _fire.mana_cost, _lightning.mana_cost, armor)
	var frost := _combo_dpm(_frostarc, _ice.mana_cost, _lightning.mana_cost, armor)
	return maxf(maxf(steam, plasma), frost)


# --- THE invariant: swapping is never worse than comboing on efficiency ------

func test_best_single_dpm_beats_best_combo_dpm_for_every_armor() -> void:
	for armor in [FIRE, ICE, ELEC]:
		var best_single := _best_single_dpm(armor)
		var best_combo := _best_combo_dpm(armor)
		assert_gte(best_single, best_combo,
			("vs armor %d: best correct single (%.3f dmg/mana) must be >= best combo "
			+ "(%.3f dmg/mana) — swapping is never worse than mashing both")
			% [armor, best_single, best_combo])


func test_each_individual_combo_is_no_more_efficient_than_the_best_single() -> void:
	# Stronger: no single combo, vs any armor, out-efficiencies the best correct single.
	var combos := {
		"STEAM": [_steam, _fire.mana_cost, _ice.mana_cost],
		"PLASMA": [_plasma, _fire.mana_cost, _lightning.mana_cost],
		"FROSTARC": [_frostarc, _ice.mana_cost, _lightning.mana_cost],
	}
	for armor in [FIRE, ICE, ELEC]:
		var best_single := _best_single_dpm(armor)
		for name in combos:
			var c: Array = combos[name]
			var dpm := _combo_dpm(c[0], c[1], c[2], armor)
			assert_gte(best_single, dpm,
				"%s vs armor %d (%.3f dmg/mana) <= best single (%.3f)"
				% [name, armor, dpm, best_single])


# --- combos still cost strictly more mana than a single (anti-dominance) -----

func test_each_combo_costs_more_than_either_constituent_single() -> void:
	assert_gt(_fire.mana_cost + _ice.mana_cost, _fire.mana_cost,
		"STEAM costs more than a Fire single")
	assert_gt(_fire.mana_cost + _ice.mana_cost, _ice.mana_cost,
		"STEAM costs more than an Ice single")
	assert_gt(_fire.mana_cost + _lightning.mana_cost, _lightning.mana_cost,
		"PLASMA costs more than a Lightning single")
