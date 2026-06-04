## TASK-026 Sector 01 — the connected greybox spine of Milestone M1 "Fuga del Sector".
##
## This is deliberately a THIN level controller: the geometry, the reused Player, the
## seeded enemies and the placeholder markers all live in sector_01.tscn. The script's
## only job is to give later tickets (and tests) named, typed accessors for the spine
## anchors so they don't depend on scene-tree spelunking:
##   - PlayerSpawn   : where the hero starts (snapped on _ready so a moved marker wins).
##   - ElementalGate : TASK-027 hooks the elemental-environment gate here.
##   - AntiMagicZone : TASK-028 hooks the flight-suppression field here.
##   - BossRoom / BossRoomTrigger : TASK-029 (Warden) hooks the boss arena + entry trigger.
##
## DD-011: the hero arrives with flight already available (the reused Player scene
## pre-unlocks every movement verb) — this ticket gates NO movement ability.
class_name Sector01 extends Node2D

## The spine is one connected left-to-right corridor; these are its ordered anchors.
@onready var _player: Node2D = get_node_or_null("Player")
@onready var _player_spawn: Marker2D = get_node_or_null("PlayerSpawn")


func _ready() -> void:
	# Snap the hero to the spawn marker so the designer can reposition PlayerSpawn in
	# the editor and the hero follows, and so the spawn/respawn anchor is the marker.
	if _player != null and _player_spawn != null:
		_player.global_position = _player_spawn.global_position
		if _player.has_method("record_spawn"):
			_player.record_spawn()


## TASK-027 anchor (read-only accessor).
func elemental_gate() -> Node2D:
	return get_node_or_null("ElementalGate") as Node2D


## TASK-028 anchor (read-only accessor).
func anti_magic_zone() -> Node2D:
	return get_node_or_null("AntiMagicZone") as Node2D


## TASK-029 anchor: the boss-room entry trigger (Area2D that masks the Player layer).
func boss_room_trigger() -> Area2D:
	return get_node_or_null("BossRoomTrigger") as Area2D
