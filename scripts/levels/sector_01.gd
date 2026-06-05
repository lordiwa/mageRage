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

## TASK-029 boss/victory state. `_encounter_started` latches the Warden fight ON the
## first time the hero enters the boss-room trigger (idempotent — re-entry is a no-op).
## `_victory` latches the SECTOR win when the reused DD-010 Warden emits `defeated`,
## closing the M1 loop (start -> gates -> boss -> victory) in this single sector build.
var _encounter_started := false
var _victory := false

## Emitted once when the hero reaches the boss room and the Warden encounter begins —
## lets the HUD / future tickets react with loose coupling.
signal encounter_started
## Emitted once when the Warden is defeated and the SECTOR victory state is reached.
signal sector_victory

## TASK-045: this sector's camera clamp (playfield bounds). The shared player scene carries
## NO limits (so encounter/arena/test_level stay unclamped); each real sector sets them at
## runtime. Horizontal = corridor inner faces (WallLeft inner x=0, WallRight at x=4232 →
## inner x=4200 — NARROWER than sector_02); vertical = the ceiling/floor body centers
## (y=-320 / y=+360), a band that keeps the view inside the widened backstop with no void.
const CAM_LIMIT_LEFT := 0
const CAM_LIMIT_TOP := -320
const CAM_LIMIT_RIGHT := 4200
const CAM_LIMIT_BOTTOM := 360


func _ready() -> void:
	# Snap the hero to the spawn marker so the designer can reposition PlayerSpawn in
	# the editor and the hero follows, and so the spawn/respawn anchor is the marker.
	if _player != null and _player_spawn != null:
		_player.global_position = _player_spawn.global_position
		if _player.has_method("record_spawn"):
			_player.record_spawn()
	# TASK-045: clamp THIS sector's camera to its playfield so the freely-flying hero's
	# view never exits the backdrops into void. Applied per-level (NOT on the shared player
	# scene) so non-sector levels that reuse the player keep their unclamped camera.
	_apply_camera_limits()
	# TASK-029: arm the boss-room entry trigger and listen for the Warden's defeat so
	# the sector — not the arena — owns the victory state.
	var trigger := boss_room_trigger()
	if trigger != null and not trigger.body_entered.is_connected(_on_boss_room_entered):
		trigger.body_entered.connect(_on_boss_room_entered)
	var boss := warden()
	if boss != null and not boss.defeated.is_connected(_on_warden_defeated):
		boss.defeated.connect(_on_warden_defeated)


## TASK-045: clamp the hero's Camera2D to this sector's playfield bounds. Guarded so it is
## a no-op if the player or its camera is absent. Idempotent (safe to call once on ready).
func _apply_camera_limits() -> void:
	if _player == null:
		return
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = CAM_LIMIT_LEFT
	cam.limit_top = CAM_LIMIT_TOP
	cam.limit_right = CAM_LIMIT_RIGHT
	cam.limit_bottom = CAM_LIMIT_BOTTOM


## TASK-027 anchor (read-only accessor).
func elemental_gate() -> Node2D:
	return get_node_or_null("ElementalGate") as Node2D


## TASK-028 anchor (read-only accessor).
func anti_magic_zone() -> Node2D:
	return get_node_or_null("AntiMagicZone") as Node2D


## TASK-029 anchor: the boss-room entry trigger (Area2D that masks the Player layer).
func boss_room_trigger() -> Area2D:
	return get_node_or_null("BossRoomTrigger") as Area2D


## TASK-029 anchor: the reused DD-010 Warden, instanced dormant in the boss room.
func warden() -> Warden:
	return get_node_or_null("Warden") as Warden


## True once the hero has reached the boss room and the Warden encounter has begun.
## Named distinctly from the `encounter_started` signal (GDScript shares the namespace).
func is_encounter_started() -> bool:
	return _encounter_started


## True once the Warden is defeated — the SECTOR victory state (criterion 2).
func is_victory() -> bool:
	return _victory


## TASK-029 boss-room trigger handler. Starts the Warden encounter exactly ONCE, and
## only when the HERO enters (the trigger already masks the Player layer; the group
## check guards against any stray body). Idempotent: re-entry after the fight has begun
## is a no-op so the boss is never re-activated or re-telegraphed.
func _on_boss_room_entered(body: Node) -> void:
	if _encounter_started:
		return
	if not (body != null and body.is_in_group("player")):
		return
	start_boss_encounter()


## Begin the Warden fight: latch the started state, wake the dormant boss (it now
## chases/telegraphs/fires), and announce it. Public + idempotent so a test (or future
## scripted trigger) can start the encounter deterministically without a physics walk.
func start_boss_encounter() -> void:
	if _encounter_started:
		return
	_encounter_started = true
	var boss := warden()
	if boss != null and boss.has_method("activate"):
		boss.activate()
	encounter_started.emit()


## The Warden reached 0 HP (its DD-010 `defeated` signal): latch the SECTOR victory
## state once and announce it — the win belongs to the sector, not the arena.
func _on_warden_defeated() -> void:
	if _victory:
		return
	_victory = true
	sector_victory.emit()
