## TASK-040 / DD-013 DUAL-CAST ELEMENT MIXING — the PURE, deterministic combo map.
##
## Pressing BOTH triggers fires ONE blended COMBO projectile combining the two
## equipped elements. This helper is the single source of truth for "(element_a,
## element_b) -> what fires". It mirrors AimAssist: a PURE function of its inputs —
## no RNG, no node lookups, no hidden state — so the same pair always yields the
## same combo (DD-001 determinism). The MagicManager calls combo_for() to decide
## what the dual-trigger spawns; the projectile/ShotType/ProjectileStyle systems are
## reused unchanged (combos are data-driven via SpellData .tres, NOT bespoke code).
##
## Mapping (ANTIMATTER excluded — it is the separate DD-002 ultimate):
##   Fire + Ice         = STEAM   (heavy single-target burst; Ice-then-Fire shatter)
##   Fire + Electricity = PLASMA  (explosive arc + small AoE)
##   Ice  + Electricity = FROSTARC (chilled chain that slows multiple targets)
##   same element both slots   = EMPOWERED single (~1.5x), NOT a combo projectile
##   ANTIMATTER in either slot = NONE (no blend) -> a plain single shot
## COMMUTATIVE: combo_for(a, b) == combo_for(b, a).
class_name ComboTable extends RefCounted

## What a dual-trigger resolves to:
##   KIND_COMBO     -> `spell` is the blended combo SpellData to spawn (one shot).
##   KIND_EMPOWERED -> same element both slots: fire ONE empowered single, no combo.
##   KIND_NONE      -> no blend (Antimatter / unknown): the normal single shots run.
enum {KIND_NONE, KIND_COMBO, KIND_EMPOWERED}

## DD-013 anti-dominance: a same-element dual-trigger fires ONE bigger shot (~1.5x),
## never two identical projectiles. Provisional / tunable.
const EMPOWERED_MULTIPLIER := 1.5

## The 3 combo SpellData .tres, loaded once and cached (the data-driven combos).
const _STEAM_PATH := "res://resources/spells/combo_steam.tres"
const _PLASMA_PATH := "res://resources/spells/combo_plasma.tres"
const _FROSTARC_PATH := "res://resources/spells/combo_frostarc.tres"

static var _cache: Dictionary = {}


## Lightweight result record (RefCounted so it carries no scene/lifetime baggage).
class ComboResult:
	extends RefCounted
	var kind: int = ComboTable.KIND_NONE
	var spell: SpellData = null     # non-null only when kind == KIND_COMBO

	func _init(p_kind: int, p_spell: SpellData = null) -> void:
		kind = p_kind
		spell = p_spell


## Pure mapping: resolve the two equipped elements to a combo / empowered / none.
## Commutative and deterministic. ANTIMATTER in either slot never blends.
static func combo_for(element_a: int, element_b: int) -> ComboResult:
	# Antimatter is above the RPS and is its own ultimate — it never mixes.
	if element_a == SpellData.Element.ANTIMATTER \
			or element_b == SpellData.Element.ANTIMATTER:
		return ComboResult.new(KIND_NONE)
	# Same element both slots -> one EMPOWERED single, not a blended combo.
	if element_a == element_b:
		return ComboResult.new(KIND_EMPOWERED)
	# Order-independent key so Fire+Ice == Ice+Fire.
	var key := _pair_key(element_a, element_b)
	var path: String = _COMBO_PATHS.get(key, "")
	if path == "":
		return ComboResult.new(KIND_NONE)   # any unmapped real pair: no blend
	return ComboResult.new(KIND_COMBO, _load_combo(path))


## The combo SpellData for a pair, or null when the pair does not blend. Convenience
## over combo_for() for callers that only want the spell.
static func combo_spell(element_a: int, element_b: int) -> SpellData:
	var r := combo_for(element_a, element_b)
	return r.spell


# --- internals ---------------------------------------------------------------

## Order-independent pair key (min,max) so the map is commutative by construction.
static func _pair_key(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))

## (min,max base element) -> combo .tres path. Built once as a constant so the
## mapping is data, not branching logic.
const _COMBO_PATHS := {
	Vector2i(SpellData.Element.FIRE, SpellData.Element.ICE): _STEAM_PATH,
	Vector2i(SpellData.Element.FIRE, SpellData.Element.ELECTRICITY): _PLASMA_PATH,
	Vector2i(SpellData.Element.ICE, SpellData.Element.ELECTRICITY): _FROSTARC_PATH,
}


## Load (and cache) a combo SpellData. Cached so repeated dual-triggers return the
## IDENTICAL resource instance (cheap, and the determinism tests rely on identity).
static func _load_combo(path: String) -> SpellData:
	if _cache.has(path):
		return _cache[path]
	var spell := load(path) as SpellData
	_cache[path] = spell
	return spell
