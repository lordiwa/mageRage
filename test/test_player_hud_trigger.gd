## TASK-039 (M2.1 combat-feel) trigger->element binding, RUNTIME instance tests.
##
## Playtest feedback: the player can't tell WHICH TRIGGER fires WHICH element. The
## HUD already shows a PRIMARY and SECONDARY element swatch+label; this ticket adds
## an explicit trigger glyph per slot (PRIMARY = "RT", SECONDARY = "LT") so the
## binding reads at a glance, and keeps the slot's element NAME + COLOR live on
## MagicManager.loadout_changed.
##
## Unlike the pure-helper suites, these tests INSTANCE the PlayerHUD CanvasLayer with
## real child nodes (trigger Labels, element Labels, swatch ColorRects) plus a fake
## player + fake MagicManager, then drive loadout_changed and assert:
##   - each slot exposes a trigger Label bound to the correct trigger TEXT (RT/LT);
##   - the slot's element NAME + COLOR reflect the current loadout and UPDATE live;
##   - colors come from ProjectileStyle (the single source of truth);
##   - the trigger glyph TEXT stays fixed across element swaps (it's per-slot).
## No pixel layout is asserted — only node presence + text + color + live update.
extends GutTest

const Hud := preload("res://scripts/ui/player_hud.gd")


# --- Fakes: a player exposing the loadout accessors + a manager emitting --------
# loadout_changed. The HUD reads the player's primary_spell()/secondary_spell() and
# re-reads them when the manager signals. We keep the fakes minimal: no casting,
# combat, or input logic (UI-only ticket).

class FakeMagic extends Node:
	signal loadout_changed(primary: SpellData, secondary: SpellData)
	func emit_loadout(primary: SpellData, secondary: SpellData) -> void:
		loadout_changed.emit(primary, secondary)


class FakeLoadoutPlayer extends Node:
	var primary: SpellData
	var secondary: SpellData
	func primary_spell() -> SpellData:
		return primary
	func secondary_spell() -> SpellData:
		return secondary


var _hud: PlayerHUD
var _player: FakeLoadoutPlayer
var _magic: FakeMagic


func _spell(element: int) -> SpellData:
	var s := SpellData.new()
	s.element = element
	return s


## Build a fully wired HUD: the loadout swatch/label nodes the existing feature uses
## PLUS the new per-slot trigger Labels, with a fake player + manager. Returns after
## _ready() so the HUD has connected loadout_changed and seeded its initial state.
func _build_hud(primary_el: int, secondary_el: int) -> void:
	_hud = Hud.new()
	_hud.name = "PlayerHUD"

	# Fake player + manager live UNDER the HUD so relative NodePaths are stable.
	_magic = FakeMagic.new()
	_magic.name = "MagicManager"
	_hud.add_child(_magic)

	_player = FakeLoadoutPlayer.new()
	_player.name = "Player"
	_player.primary = _spell(primary_el)
	_player.secondary = _spell(secondary_el)
	_hud.add_child(_player)

	# Existing loadout widgets.
	var primary_swatch := ColorRect.new()
	primary_swatch.name = "PrimarySwatch"
	_hud.add_child(primary_swatch)
	var primary_label := Label.new()
	primary_label.name = "PrimaryLabel"
	_hud.add_child(primary_label)
	var secondary_swatch := ColorRect.new()
	secondary_swatch.name = "SecondarySwatch"
	_hud.add_child(secondary_swatch)
	var secondary_label := Label.new()
	secondary_label.name = "SecondaryLabel"
	_hud.add_child(secondary_label)

	# New TASK-039 per-slot trigger glyph Labels.
	var primary_trigger := Label.new()
	primary_trigger.name = "PrimaryTrigger"
	_hud.add_child(primary_trigger)
	var secondary_trigger := Label.new()
	secondary_trigger.name = "SecondaryTrigger"
	_hud.add_child(secondary_trigger)

	_hud.player_path = NodePath("Player")
	_hud.magic_manager_path = NodePath("MagicManager")
	_hud.primary_swatch_path = NodePath("PrimarySwatch")
	_hud.primary_label_path = NodePath("PrimaryLabel")
	_hud.secondary_swatch_path = NodePath("SecondarySwatch")
	_hud.secondary_label_path = NodePath("SecondaryLabel")
	_hud.primary_trigger_label_path = NodePath("PrimaryTrigger")
	_hud.secondary_trigger_label_path = NodePath("SecondaryTrigger")

	add_child_autofree(_hud)


func _primary_trigger() -> Label:
	return _hud.get_node("PrimaryTrigger") as Label


func _secondary_trigger() -> Label:
	return _hud.get_node("SecondaryTrigger") as Label


func _primary_label() -> Label:
	return _hud.get_node("PrimaryLabel") as Label


func _secondary_label() -> Label:
	return _hud.get_node("SecondaryLabel") as Label


func _primary_swatch() -> ColorRect:
	return _hud.get_node("PrimarySwatch") as ColorRect


func _secondary_swatch() -> ColorRect:
	return _hud.get_node("SecondarySwatch") as ColorRect


# --- Trigger glyph is bound to the correct slot (RT=primary, LT=secondary) -----

func test_primary_slot_shows_rt_trigger() -> void:
	_build_hud(SpellData.Element.FIRE, SpellData.Element.ICE)
	assert_eq(_primary_trigger().text, "RT",
		"the PRIMARY slot's trigger label reads RT")


func test_secondary_slot_shows_lt_trigger() -> void:
	_build_hud(SpellData.Element.FIRE, SpellData.Element.ICE)
	assert_eq(_secondary_trigger().text, "LT",
		"the SECONDARY slot's trigger label reads LT")


# --- Element NAME reflects the loadout and updates live on loadout_changed ------

func test_element_names_seed_from_initial_loadout() -> void:
	_build_hud(SpellData.Element.FIRE, SpellData.Element.ICE)
	assert_eq(_primary_label().text, "FIRE",
		"the primary element label seeds from the initial loadout (FIRE)")
	assert_eq(_secondary_label().text, "ICE",
		"the secondary element label seeds from the initial loadout (ICE)")


func test_element_name_updates_on_loadout_changed() -> void:
	_build_hud(SpellData.Element.FIRE, SpellData.Element.ICE)
	# Swap to a new loadout: primary becomes ELECTRICITY, secondary FIRE.
	_player.primary = _spell(SpellData.Element.ELECTRICITY)
	_player.secondary = _spell(SpellData.Element.FIRE)
	_magic.emit_loadout(_player.primary, _player.secondary)
	assert_eq(_primary_label().text, "ELECTRICITY",
		"the primary element name updates live to the new loadout element")
	assert_eq(_secondary_label().text, "FIRE",
		"the secondary element name updates live to the new loadout element")


# --- The trigger glyph stays FIXED to its slot across element swaps -------------

func test_trigger_glyph_stays_with_slot_across_swap() -> void:
	_build_hud(SpellData.Element.FIRE, SpellData.Element.ICE)
	_player.primary = _spell(SpellData.Element.ELECTRICITY)
	_player.secondary = _spell(SpellData.Element.FIRE)
	_magic.emit_loadout(_player.primary, _player.secondary)
	assert_eq(_primary_trigger().text, "RT",
		"the primary trigger stays RT after an element swap (per-slot, not per-element)")
	assert_eq(_secondary_trigger().text, "LT",
		"the secondary trigger stays LT after an element swap")


# --- Color comes from ProjectileStyle and updates live -------------------------

func test_swatch_color_matches_projectile_style_initial() -> void:
	_build_hud(SpellData.Element.FIRE, SpellData.Element.ICE)
	assert_eq(_primary_swatch().color,
		ProjectileStyle.for_element(SpellData.Element.FIRE)["color"],
		"the primary swatch color is the ProjectileStyle Fire color")
	assert_eq(_secondary_swatch().color,
		ProjectileStyle.for_element(SpellData.Element.ICE)["color"],
		"the secondary swatch color is the ProjectileStyle Ice color")


func test_swatch_color_updates_on_loadout_changed() -> void:
	_build_hud(SpellData.Element.FIRE, SpellData.Element.ICE)
	_player.primary = _spell(SpellData.Element.ELECTRICITY)
	_player.secondary = _spell(SpellData.Element.FIRE)
	_magic.emit_loadout(_player.primary, _player.secondary)
	assert_eq(_primary_swatch().color,
		ProjectileStyle.for_element(SpellData.Element.ELECTRICITY)["color"],
		"the primary swatch color updates live to the new element's ProjectileStyle color")
	assert_eq(_secondary_swatch().color,
		ProjectileStyle.for_element(SpellData.Element.FIRE)["color"],
		"the secondary swatch color updates live to the new element's ProjectileStyle color")
