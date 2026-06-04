## TASK-027 — reusable elemental-on-environment gate (DD-011 gate elemental-entorno).
##
## A sealed route the player CANNOT pass until they apply the CORRECT element to an
## environment object: freeze a coolant geyser with ICE into a platform, burn an
## obstruction with FIRE, or energize a dead lift/bridge with ELECTRICITY. The wrong
## element does nothing (a small "resist" blip); the correct element OPENS the route
## PERSISTENTLY — once open it cannot be re-sealed.
##
## Composition (godot-game-dev §6): this is a small self-contained scene dropped into
## a level. Two children carry the behavior:
##   - Blocker (StaticBody2D, Environment layer 1): the physical wall the player's
##     move_and_slide collides with while sealed; its CollisionShape is DISABLED on
##     open so the hero can pass.
##   - Hitbox (Area2D, Enemies layer 3): the surface a PLAYER projectile strikes. The
##     existing projectile masks Enemies (3) only and calls `apply_elemental_hit`, so
##     the gate reuses that path with ZERO projectile changes — it forwards the hit's
##     element to `apply_element`.
##
## Configurable via @export for which element opens it (DD-006 fiction) and which
## interaction it represents; color-coded per DD-003 (Fire=red, Ice=blue, Elec=yellow).
##
## The clean `apply_element(elem)` API is what tests drive directly (no projectile
## physics needed) AND what the projectile-hit path ultimately calls — one code path,
## deterministic tests.
class_name ElementalGate extends Node2D

## Emitted exactly once, when the correct element first opens the gate. Level logic /
## VFX listen instead of polling (signals-to-decouple).
signal opened

## The fiction of the elemental interaction (game-design SKILL: each gate "reads" as a
## lock with clear visual vocabulary). Defaults track the required element in _ready.
enum Interaction { FREEZE, BURN, ENERGIZE }

## Which element OPENS this gate (Fire/Ice/Electricity). ANTIMATTER is not a gate key.
@export var required_element: SpellData.Element = SpellData.Element.ICE

## Which interaction this gate represents. AUTO (-1 default sentinel) derives it from
## the required element (Ice->FREEZE, Fire->BURN, Electricity->ENERGIZE); set it
## explicitly in the inspector to override the fiction.
@export var interaction: Interaction = Interaction.FREEZE

## --- DD-003 element color language (matches ProjectileStyle / impact tints) -------
## Per DD-003 the gate VISUAL is the saturated element color so the lock reads at a
## glance; Fire=red, Ice=blue, Electricity=yellow. (Antimatter=violet for completeness.)
const ELEMENT_COLOR := {
	SpellData.Element.FIRE: Color(0.85, 0.18, 0.15, 1.0),         # red
	SpellData.Element.ICE: Color(0.20, 0.45, 0.95, 1.0),          # blue
	SpellData.Element.ELECTRICITY: Color(0.95, 0.88, 0.20, 1.0),  # yellow
	SpellData.Element.ANTIMATTER: Color(0.65, 0.25, 0.95, 1.0),   # violet
}
const DEFAULT_COLOR := Color(0.7, 0.7, 0.7, 1.0)

## Default interaction per element (the fiction). Editable override via @export.
const _DEFAULT_INTERACTION := {
	SpellData.Element.FIRE: Interaction.BURN,
	SpellData.Element.ICE: Interaction.FREEZE,
	SpellData.Element.ELECTRICITY: Interaction.ENERGIZE,
}

## True once opened; latched so the open state PERSISTS (criterion 3).
var _open := false

@onready var _blocker_shape: CollisionShape2D = get_node_or_null("Blocker/Col")
@onready var _vis: ColorRect = get_node_or_null("Vis")


func _ready() -> void:
	# Derive the interaction from the required element unless the designer overrode it
	# (an Ice gate keeps FREEZE — the enum default — but a Fire/Elec gate left at the
	# default FREEZE is corrected to its fiction so dropping a gate "just works").
	if interaction == Interaction.FREEZE and required_element != SpellData.Element.ICE:
		interaction = _DEFAULT_INTERACTION.get(required_element, Interaction.FREEZE)
	# Collision layers are authored ONCE in elemental_gate.tscn (single source of
	# truth): the Blocker is on Environment (layer 1) so the hero's move_and_slide
	# stops; the Hitbox is on Enemies (layer 3) so the existing player projectile
	# (masks 3 only) strikes it. We do not re-assign them here (LOW review fix).
	_apply_visual()


## Pure-ish: the DD-003 color for this gate's required element (drives the visual and
## is asserted by the readability tests).
func gate_color() -> Color:
	return ELEMENT_COLOR.get(required_element, DEFAULT_COLOR)


## True while the gate seals the route (closed). False once opened.
func is_open() -> bool:
	return _open


## True while the gate seals the route (the player cannot pass). Tied to the latched
## open state so it flips SYNCHRONOUSLY the instant the gate opens — the physical
## CollisionShape is freed in _open_gate (deferred, to stay safe mid-hit-callback),
## but passability is decided by the latched state, not by waiting a physics frame.
func is_blocking() -> bool:
	return not _open


## THE application API. Wrong element -> ignored (resist blip); correct element ->
## OPEN persistently. Safe to call repeatedly; only the first correct hit opens/emits.
func apply_element(elem: int) -> void:
	if _open:
		return
	if elem != required_element:
		_resist_blip()
		return
	_open_gate()


## The in-game projectile-hit entry point: the player projectile calls this (the same
## method drones expose) on contact; we only care about the element. Forwards to the
## single `apply_element` code path so tests and live hits behave identically.
func apply_elemental_hit(
	element: int, _damage: float, _applies_slow: bool, _hit_dir: Vector2
) -> void:
	apply_element(element)


## Open the route: free the blocking collision, switch the visual to the "opened"
## (freeze/burn/energize) state, latch persistence, and announce it once.
func _open_gate() -> void:
	_open = true
	if _blocker_shape != null:
		# Disable next idle so we never mutate physics state mid-callback (mid-hit).
		_blocker_shape.set_deferred("disabled", true)
	_apply_visual()
	opened.emit()


## Placeholder "resist" feedback for a wrong element (no state change). A brief tint
## pulse would go here; kept null-safe and side-effect-free for headless tests.
func _resist_blip() -> void:
	pass


## Color-code the gate per DD-003. Sealed = saturated, opaque element color (reads as a
## solid lock); opened = the same hue but faded/translucent (the route is cleared —
## frozen platform / burned-away obstruction / energized bridge).
func _apply_visual() -> void:
	if _vis == null:
		return
	var col := gate_color()
	if _open:
		_vis.color = Color(col.r, col.g, col.b, 0.22)
	else:
		_vis.color = Color(col.r, col.g, col.b, 0.85)
