## Sector 02 — the connected greybox spine of Milestone M2, built in two passes.
##
## Modeled verbatim on Sector01 (the proven M1 spine): a THIN level controller whose
## geometry, the reused Player and the placed components all live in sector_02.tscn.
## The script's job is to give named, typed accessors for the spine anchors so tests
## don't depend on scene-tree spelunking, and to own the boss/victory state:
##   - PlayerSpawn   : where the hero starts (snapped on _ready so a moved marker wins;
##     the DD-009 respawn anchor).
##   - ElementalGate : the real FIRE ElementalGate (DD-003 red / BURN), full-height
##     across the corridor like sector_01's ICE gate (DD-011 — no flyable gap).
##   - AntiMagicZone : the real ELECTRICITY AntiMagicZone (DD-008 flight verb), which
##     suppresses FlightState until purged, with a barrier above the jump apex.
##   - CombatPocket  : a floor-space region marker (mixed-armor enemies seeded near it).
##   - BossRoom / BossRoomTrigger : the boss-approach anchors copied from sector_01; the
##     trigger starts the encounter (waking the dormant Warden), `defeated` -> victory.
##   - Backdrop      : the reusable T1 ParallaxBackdrop instanced behind the playfield.
##
## T2 (TASK-034) laid the LAYOUT + parallax. T3 (TASK-035) adds the gate/zone/enemy/boss
## WIRING + HUDs, copying sector_01's controller signal plumbing verbatim.
##
## DD-011: the hero arrives with flight already available (the reused Player scene
## pre-unlocks every movement verb) — this sector gates NO movement ability, and the
## corridor keeps Sector01's flight-safe metrics (ceiling y=-288 / floor y=+328) so the
## reused full-height gate/zone stay flight-verified.
class_name Sector02 extends Node2D

## The spine is one connected left-to-right corridor; these are its ordered anchors.
@onready var _player: Node2D = get_node_or_null("Player")
@onready var _player_spawn: Marker2D = get_node_or_null("PlayerSpawn")

## Boss/victory state (copied from Sector01). `_encounter_started` latches the Warden
## fight ON the first time the hero enters the boss-room trigger (idempotent — re-entry
## is a no-op). `_victory` latches the SECTOR win when the reused Warden emits `defeated`,
## closing the M2 loop (spawn -> FIRE gate -> ELEC purge+fly -> boss -> victory).
var _encounter_started := false
var _victory := false

## Emitted once when the hero reaches the boss room and the Warden encounter begins.
signal encounter_started
## Emitted once when the Warden is defeated and the SECTOR victory state is reached.
signal sector_victory


func _ready() -> void:
	# Snap the hero to the spawn marker so the designer can reposition PlayerSpawn in
	# the editor and the hero follows, and so the spawn/respawn anchor is the marker.
	if _player != null and _player_spawn != null:
		_player.global_position = _player_spawn.global_position
		if _player.has_method("record_spawn"):
			_player.record_spawn()
	# Arm the boss-room entry trigger and listen for the Warden's defeat so the sector —
	# not the arena — owns the victory state (copied verbatim from Sector01).
	var trigger := boss_room_trigger()
	if trigger != null and not trigger.body_entered.is_connected(_on_boss_room_entered):
		trigger.body_entered.connect(_on_boss_room_entered)
	var boss := warden()
	if boss != null and not boss.defeated.is_connected(_on_warden_defeated):
		boss.defeated.connect(_on_warden_defeated)


## Anchor: the placed FIRE ElementalGate (named "ElementalGate"). Kept as the historical
## `elemental_gate_marker()` accessor name so existing callers/tests resolve unchanged.
func elemental_gate_marker() -> Node2D:
	return get_node_or_null("ElementalGate") as Node2D


## Anchor: the placed ElementalGate as its typed component (read-only accessor).
func elemental_gate() -> ElementalGate:
	return get_node_or_null("ElementalGate") as ElementalGate


## Anchor: the placed ELECTRICITY AntiMagicZone (named "AntiMagicZone"). Kept as the
## historical `anti_magic_zone_marker()` accessor name so existing callers resolve.
func anti_magic_zone_marker() -> Node2D:
	return get_node_or_null("AntiMagicZone") as Node2D


## Anchor: the placed AntiMagicZone as its typed component (read-only accessor).
func anti_magic_zone() -> AntiMagicZone:
	return get_node_or_null("AntiMagicZone") as AntiMagicZone


## Anchor: the floor-space combat pocket region near which enemies are seeded.
func combat_pocket() -> Marker2D:
	return get_node_or_null("CombatPocket") as Marker2D


## Anchor: the boss-room region marker (the boss arena anchor).
func boss_room() -> Node2D:
	return get_node_or_null("BossRoom") as Node2D


## Anchor: the boss-room entry trigger (Area2D that masks the Player layer), copied
## from sector_01 so the reused reachability test retargets cleanly.
func boss_room_trigger() -> Area2D:
	return get_node_or_null("BossRoomTrigger") as Area2D


## Anchor: the reused DD-010 Warden, instanced dormant in the boss room.
func warden() -> Warden:
	return get_node_or_null("Warden") as Warden


## The reusable T1 depth backdrop (parallax_background.tscn) instanced behind the level.
func parallax_backdrop() -> ParallaxBackdrop:
	return get_node_or_null("Backdrop") as ParallaxBackdrop


## True once the hero has reached the boss room and the Warden encounter has begun.
func is_encounter_started() -> bool:
	return _encounter_started


## True once the Warden is defeated — the SECTOR victory state.
func is_victory() -> bool:
	return _victory


## Boss-room trigger handler (copied from Sector01). Starts the Warden encounter exactly
## ONCE, only when the HERO enters; idempotent — re-entry after the fight has begun is a
## no-op so the boss is never re-activated.
func _on_boss_room_entered(body: Node) -> void:
	if _encounter_started:
		return
	if not (body != null and body.is_in_group("player")):
		return
	start_boss_encounter()


## Begin the Warden fight: latch the started state, wake the dormant boss, and announce
## it. Public + idempotent so a test can start the encounter deterministically.
func start_boss_encounter() -> void:
	if _encounter_started:
		return
	_encounter_started = true
	var boss := warden()
	if boss != null and boss.has_method("activate"):
		boss.activate()
	encounter_started.emit()


## The Warden reached 0 HP (its DD-010 `defeated` signal): latch the SECTOR victory state
## once and announce it — the win belongs to the sector.
func _on_warden_defeated() -> void:
	if _victory:
		return
	_victory = true
	sector_victory.emit()
