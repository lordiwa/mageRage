## TASK-028 — reusable anti-magic flight-suppression zone (DD-011 zona anti-magia).
##
## An Empire techno-magic DAMPENING FIELD: while the hero stands inside an un-purged
## field its FlightState is DISABLED (the double-jump -> flight transition is gated
## out in the FSM). This gates a VERTICAL/aerial route the player would otherwise just
## fly over. The player RESTORES flight by PURGING the field with the CORRECT element —
## shooting the field's power Emitter with that element. Purging PERSISTENTLY lifts the
## suppression for this zone; outside the zone (or after purge) flight works exactly as
## before (DD-008 unaffected elsewhere).
##
## Element choice (DEFAULT = ELECTRICITY, per DD-006/DD-003): flight itself is the
## Electricity-gated verb (DD-008), so an Empire field engineered to CANCEL the prison-
## er's flight reads as an anti-electric dampener that you short-circuit by feeding it
## its own element — Electricity = yellow (DD-003). Configurable via @export.
##
## Composition (godot-game-dev §6): a small self-contained scene dropped into a level.
##   - Field  (Area2D, masks Player layer 2): detects the hero BODY entering/exiting and
##     toggles `player.set_flight_suppressed(true/false)` — the clean flag the FSM reads.
##   - Emitter (Area2D, Enemies layer 3): the power node a PLAYER projectile strikes. The
##     existing projectile masks Enemies (3) only and calls `apply_elemental_hit`, so the
##     zone reuses that path with ZERO projectile changes — it forwards to `purge`. Its
##     hit-shape is deliberately offset DOWN-LEFT (Col position ~(-120, 120) in the scene)
##     so the strikable volume sits at the hero's ground/jump height on the field's
##     approach side — a level-height shot reaches it before the hero is at the barrier.
##   - Barrier (StaticBody2D, Environment layer 1): an in-zone obstruction rising from the
##     floor higher than the jump apex, so the gated route genuinely REQUIRES flight (a
##     grounded/jumping/dashing hero can't clear it; once purged the hero flies over).
##
## The clean `purge(elem)` / `is_suppressing()` API is what tests drive directly (no
## projectile physics) AND what the live projectile-hit path calls — one code path.
class_name AntiMagicZone extends Node2D

## Emitted exactly once, when the correct element first purges the field. Level logic /
## VFX listen instead of polling (signals-to-decouple).
signal purged

## Which element PURGES this field (Fire/Ice/Electricity). ANTIMATTER is not a purge key.
## Default Electricity (the flight-gating element, DD-008) — yellow per DD-003.
@export var purge_element: SpellData.Element = SpellData.Element.ELECTRICITY

## --- DD-003 element color language (matches ElementalGate / ProjectileStyle) -------
## Fire=red, Ice=blue, Electricity=yellow (Antimatter=violet for completeness).
const ELEMENT_COLOR := {
	SpellData.Element.FIRE: Color(0.85, 0.18, 0.15, 1.0),         # red
	SpellData.Element.ICE: Color(0.20, 0.45, 0.95, 1.0),          # blue
	SpellData.Element.ELECTRICITY: Color(0.95, 0.88, 0.20, 1.0),  # yellow
	SpellData.Element.ANTIMATTER: Color(0.65, 0.25, 0.95, 1.0),   # violet
}
const DEFAULT_COLOR := Color(0.7, 0.7, 0.7, 1.0)

## Field alphas: a live (suppressing) field reads as a visible haze; a purged field
## fades to near-transparent (the dampener is dead, the route is clear).
const _ALPHA_LIVE := 0.18
const _ALPHA_PURGED := 0.05

## True while the field still suppresses flight. Latched false once purged (criterion 3).
var _suppressing := true

## Bodies currently inside the field (so a purge-while-inside can immediately clear the
## suppression flag on everyone standing in it).
var _bodies_inside: Array = []

@onready var _field: Area2D = get_node_or_null("Field")
@onready var _vis: ColorRect = get_node_or_null("FieldVis")


func _ready() -> void:
	# Collision layers/masks are authored ONCE in anti_magic_zone.tscn (single source of
	# truth): the Field masks Player (2); the Emitter sits on Enemies (3); the Barrier on
	# Environment (1). We do not re-assign them here.
	if _field != null:
		if not _field.body_entered.is_connected(_on_body_entered):
			_field.body_entered.connect(_on_body_entered)
		if not _field.body_exited.is_connected(_on_body_exited):
			_field.body_exited.connect(_on_body_exited)
	_apply_visual()


## Pure-ish: the DD-003 color for this field's purge element (drives the visual and is
## asserted by the readability tests).
func field_color() -> Color:
	return ELEMENT_COLOR.get(purge_element, DEFAULT_COLOR)


## True while the field suppresses flight (the hero can't fly inside it). False once
## purged. Synchronous/deterministic — the FSM and tests read this, not a physics frame.
func is_suppressing() -> bool:
	return _suppressing


## THE purge API. Wrong element -> ignored (resist blip); correct element -> lift
## suppression PERSISTENTLY and immediately restore any body still standing inside.
## Safe to call repeatedly; only the first correct hit purges/emits.
func purge(elem: int) -> void:
	if not _suppressing:
		return
	if elem != purge_element:
		_resist_blip()
		return
	_do_purge()


## The in-game projectile-hit entry point: the player projectile calls this (the same
## method drones / the elemental gate expose) on contact; we only care about the element.
## Forwards to the single `purge` code path so tests and live hits behave identically.
func apply_elemental_hit(
	element: int, _damage: float, _applies_slow: bool, _hit_dir: Vector2
) -> void:
	purge(element)


## A body entered the field: if still live, flag it flight-suppressed (the FSM reads the
## flag and gates out the double-jump -> flight). Null-guarded for non-player bodies.
func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if not _bodies_inside.has(body):
		_bodies_inside.append(body)
	if _suppressing and body.has_method("set_flight_suppressed"):
		body.set_flight_suppressed(true)


## A body left the field: clear its suppression flag so flight works outside the zone.
func _on_body_exited(body: Node) -> void:
	if body == null:
		return
	_bodies_inside.erase(body)
	if body.has_method("set_flight_suppressed"):
		body.set_flight_suppressed(false)


## Purge: latch suppression off, free the standing bodies, fade the visual, announce once.
func _do_purge() -> void:
	_suppressing = false
	for body in _bodies_inside:
		if body != null and body.has_method("set_flight_suppressed"):
			body.set_flight_suppressed(false)
	_apply_visual()
	purged.emit()


## Placeholder "resist" feedback for a wrong element (no state change). Kept null-safe
## and side-effect-free for headless tests.
func _resist_blip() -> void:
	pass


## Color-code the field per DD-003. Live = visible haze in the element hue; purged =
## the same hue, nearly transparent (the dampener is dead, the route is clear).
func _apply_visual() -> void:
	if _vis == null:
		return
	var col := field_color()
	var alpha := _ALPHA_LIVE if _suppressing else _ALPHA_PURGED
	_vis.color = Color(col.r, col.g, col.b, alpha)
