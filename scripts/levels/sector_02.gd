## TASK-034 (M2 T2) Sector 02 — the LAYOUT + parallax greybox spine of Milestone M2.
##
## Modeled verbatim on Sector01 (the proven M1 spine): a THIN level controller whose
## geometry, the reused Player and the placeholder anchors all live in sector_02.tscn.
## The script's only job is to give the FOLLOW-UP ticket (T3) named, typed accessors for
## the spine anchors so it doesn't depend on scene-tree spelunking:
##   - PlayerSpawn   : where the hero starts (snapped on _ready so a moved marker wins).
##   - ElementalGate : a MARKER only (T3 drops the real ElementalGate instance here).
##   - AntiMagicZone : a MARKER only (T3 drops the real AntiMagicZone instance here).
##   - CombatPocket  : a floor-space region marker (T3 seeds enemies here).
##   - BossRoom / BossRoomTrigger : the boss-approach anchors copied from sector_01
##     (T3 instances the Warden + wires the encounter/victory signals here).
##   - Backdrop      : the reusable T1 ParallaxBackdrop instanced behind the playfield.
##
## SCOPE (M2 T2): this is LAYOUT + controller + parallax instance ONLY. The gate / zone
## / enemy / boss WIRING is the NEXT ticket (T3). To match Sector01's pure-layout duty,
## this controller does ONLY the spawn snap — it connects NO dangling boss/victory
## signals (there is no Warden to listen to yet), so nothing errors at load.
##
## DD-011: the hero arrives with flight already available (the reused Player scene
## pre-unlocks every movement verb) — this ticket gates NO movement ability, and the
## corridor keeps Sector01's flight-safe metrics (ceiling y=-288 / floor y=+328).
class_name Sector02 extends Node2D

## The spine is one connected left-to-right corridor; these are its ordered anchors.
@onready var _player: Node2D = get_node_or_null("Player")
@onready var _player_spawn: Marker2D = get_node_or_null("PlayerSpawn")


func _ready() -> void:
	# Snap the hero to the spawn marker so the designer can reposition PlayerSpawn in
	# the editor and the hero follows, and so the spawn/respawn anchor is the marker.
	# (Sector01's pure-layout behavior; boss/victory wiring is T3, not here.)
	if _player != null and _player_spawn != null:
		_player.global_position = _player_spawn.global_position
		if _player.has_method("record_spawn"):
			_player.record_spawn()


## T3 anchor: where the elemental-environment gate will be placed (MARKER only here).
func elemental_gate_marker() -> Marker2D:
	return get_node_or_null("ElementalGate") as Marker2D


## T3 anchor: where the anti-magic flight-suppression zone will be placed (MARKER only).
func anti_magic_zone_marker() -> Marker2D:
	return get_node_or_null("AntiMagicZone") as Marker2D


## T3 anchor: the floor-space combat pocket region where enemies will be seeded.
func combat_pocket() -> Marker2D:
	return get_node_or_null("CombatPocket") as Marker2D


## T3 anchor: the boss-room region marker (the boss arena anchor).
func boss_room() -> Node2D:
	return get_node_or_null("BossRoom") as Node2D


## T3 anchor: the boss-room entry trigger (Area2D that masks the Player layer), copied
## from sector_01 so T3's reused reachability test retargets cleanly.
func boss_room_trigger() -> Area2D:
	return get_node_or_null("BossRoomTrigger") as Area2D


## The reusable T1 depth backdrop (parallax_background.tscn) instanced behind the level.
func parallax_backdrop() -> ParallaxBackdrop:
	return get_node_or_null("Backdrop") as ParallaxBackdrop
