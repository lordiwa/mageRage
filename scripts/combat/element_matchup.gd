## DD-006 element-vs-armor matchup (binding, docs/DECISIONES-DISENO.md).
##
## A drone armored in element X RESISTS X (x0.5) and is WEAK to its counter
## (x1.5); the third element is NEUTRAL (x1.0). Counter cycle:
## Electricity -> Fire -> Ice -> Electricity (the element that BEATS an armor is
## the one whose counter that armor is). Pure, static, table-driven so all 9
## (spell element x armor) pairs are trivially unit-testable and can never drift.
class_name ElementMatchup extends RefCounted

const RESIST := 0.5
const NEUTRAL := 1.0
const WEAK := 1.5

# For each armor type, the spell element it is WEAK to (takes x1.5 from).
# Fire armor weak to Electricity; Ice armor weak to Fire; Elec armor weak to Ice.
const _COUNTER := {
	SpellData.Element.FIRE: SpellData.Element.ELECTRICITY,
	SpellData.Element.ICE: SpellData.Element.FIRE,
	SpellData.Element.ELECTRICITY: SpellData.Element.ICE,
}

## TASK-040 / DD-013: a dual-cast COMBO is NOT its own matchup entry — it resolves
## its armor multiplier THROUGH its two BASE elements (the constituents that formed
## it). This keeps combos firmly INSIDE the DD-006 RPS (resisted/bonused like any
## element; never above it — that is reserved for Antimatter). The decomposition is
## pure, deterministic and commutative.
const _COMBO_COMPONENTS := {
	SpellData.Element.STEAM: [SpellData.Element.FIRE, SpellData.Element.ICE],
	SpellData.Element.PLASMA: [SpellData.Element.FIRE, SpellData.Element.ELECTRICITY],
	SpellData.Element.FROSTARC: [SpellData.Element.ICE, SpellData.Element.ELECTRICITY],
}

## The base element(s) an element resolves to for matchup: a combo -> its two
## constituents; a base element -> just itself. Pure and order-stable.
static func combo_components(element: int) -> Array:
	return _COMBO_COMPONENTS.get(element, [element])

## Damage multiplier for a spell of `spell_element` hitting `armor_type`.
## A combo element returns the MEAN of its two base-element multipliers (safer than
## max: it can never exceed the larger base mult, so a combo never beats a perfectly
## correct single's x1.5 weakness bonus). Base elements use the plain DD-006 table.
static func multiplier(spell_element: int, armor_type: int) -> float:
	var components := combo_components(spell_element)
	if components.size() > 1:
		var total := 0.0
		for base in components:
			total += _base_multiplier(base, armor_type)
		return total / float(components.size())
	return _base_multiplier(spell_element, armor_type)

## The plain DD-006 single-element multiplier (no combo derivation).
static func _base_multiplier(spell_element: int, armor_type: int) -> float:
	if spell_element == armor_type:
		return RESIST
	if _COUNTER.get(armor_type, -1) == spell_element:
		return WEAK
	return NEUTRAL

## Convenience: base damage scaled by the matchup multiplier.
static func apply(base: float, spell_element: int, armor_type: int) -> float:
	return base * multiplier(spell_element, armor_type)
