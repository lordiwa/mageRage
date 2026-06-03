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

## Damage multiplier for a spell of `spell_element` hitting `armor_type`.
static func multiplier(spell_element: int, armor_type: int) -> float:
	if spell_element == armor_type:
		return RESIST
	if _COUNTER.get(armor_type, -1) == spell_element:
		return WEAK
	return NEUTRAL

## Convenience: base damage scaled by the matchup multiplier.
static func apply(base: float, spell_element: int, armor_type: int) -> float:
	return base * multiplier(spell_element, armor_type)
