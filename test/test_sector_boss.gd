## TASK-029 integration tests: the Warden as the END-OF-SECTOR boss in sector_01,
## and the SECTOR-level victory state that closes the M1 loop (start -> gates ->
## boss -> victory) in a SINGLE playthrough of levels/sector_01.tscn.
##
## This wires the EXISTING DD-010 Warden (phases, armor rotation, boss HP HUD,
## victory juice) into the connected sector as the final encounter. The unit tests
## here drive everything DETERMINISTICALLY (call the trigger handler, emit the
## Warden's `defeated` signal) — NO full physics playthrough is required, so they are
## fast and cannot poison the input-edge tests (DD wiring only):
##   1. reaching the boss room (a body entering BossRoomTrigger) starts the encounter
##      and ACTIVATES the reused Warden (reads its boss HP / phase via the boss node);
##   2. the trigger is IDEMPOTENT — a second body-enter does not re-start it;
##   3. the Warden is DORMANT until triggered (it does not chase/fire across the level);
##   4. defeating the Warden (its `defeated` signal / 0 HP) sets a SECTOR victory state
##      on the Sector01 controller (not just an arena-local victory);
##   5. the sector respawn point is the SECTOR spawn (DD-009), not the arena.
extends GutTest

const SECTOR := preload("res://levels/sector_01.tscn")


# Build the sector and let _ready run (snaps the hero to spawn, wires the boss).
func _make_sector() -> Sector01:
	var level := SECTOR.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	return level as Sector01


# --- The boss is reused, present, and DORMANT until the encounter starts -------

func test_sector_instances_the_reused_warden() -> void:
	# Criterion 1: the DD-010 Warden is reused AS-IS, instanced into the sector.
	var level := await _make_sector()
	var boss: Variant = level.warden()
	assert_not_null(boss, "the sector exposes the reused Warden via Sector01.warden()")
	assert_true(boss is Warden, "the placed boss is the reusable DD-010 Warden component")


func test_warden_starts_dormant_so_it_does_not_fire_across_the_level() -> void:
	# Criterion 3: instanced inactive — a dormant Warden must NOT engage (no aggro,
	# no attack) before the player reaches the boss room, so it can't shoot across the
	# whole sector while the hero is still traversing the gates.
	var level := await _make_sector()
	var boss := level.warden() as Warden
	assert_not_null(boss, "the Warden resolves")
	assert_true(boss.is_dormant(), "the Warden starts dormant (instanced inactive)")
	assert_false(boss.player_in_aggro_range(),
		"a dormant Warden is never in aggro range (it doesn't chase across the level)")
	assert_false(boss.can_attack(),
		"a dormant Warden never attacks (it doesn't fire across the level)")


# --- Reaching the boss room STARTS the encounter (activates the Warden) --------

func test_entering_the_trigger_starts_the_encounter_and_activates_the_warden() -> void:
	# Criterion 1: the player body entering BossRoomTrigger starts the Warden encounter.
	var level := await _make_sector()
	var boss := level.warden() as Warden
	assert_false(level.is_encounter_started(), "the encounter has not started yet")
	# Drive the trigger deterministically with the actual Player body (no physics walk).
	var player := level.get_node("Player")
	level.boss_room_trigger().body_entered.emit(player)
	assert_true(level.is_encounter_started(),
		"a body entering the boss-room trigger starts the Warden encounter")
	assert_false(boss.is_dormant(),
		"starting the encounter wakes the Warden (it is no longer dormant)")


func test_encounter_trigger_is_idempotent() -> void:
	# Criterion 1 (idempotent): re-entering the trigger must not re-start the encounter
	# (no double-activation, no re-emitted started state). We count the started signal.
	var level := await _make_sector()
	watch_signals(level)
	var player := level.get_node("Player")
	var trig := level.boss_room_trigger()
	trig.body_entered.emit(player)
	trig.body_entered.emit(player)        # second entry must be a no-op
	trig.body_entered.emit(player)
	assert_signal_emit_count(level, "encounter_started", 1,
		"the encounter starts exactly once no matter how many times the trigger fires")


func test_non_player_body_does_not_start_the_encounter() -> void:
	# Only the hero starts the fight: a stray non-player body entering the trigger
	# (defensive — the mask is Player-only, but guard the handler anyway) is ignored.
	var level := await _make_sector()
	var stray := StaticBody2D.new()
	add_child_autofree(stray)
	level.boss_room_trigger().body_entered.emit(stray)
	assert_false(level.is_encounter_started(),
		"a non-player body entering the trigger does not start the encounter")


# --- Defeating the Warden sets the SECTOR victory state ------------------------

func test_sector_starts_without_victory() -> void:
	var level := await _make_sector()
	assert_false(level.is_victory(),
		"the sector starts before victory (the boss is undefeated)")


func test_warden_defeat_sets_the_sector_victory_state() -> void:
	# Criterion 2: defeating the Warden (its DD-010 `defeated` signal / 0 HP) triggers
	# a SECTOR victory state on the Sector01 controller — reachable in one playthrough
	# (start -> gates -> boss -> victory). We start the encounter, then drive the boss
	# to defeat deterministically via its existing victory signal path.
	var level := await _make_sector()
	var boss := level.warden() as Warden
	# Reach the boss room first (the real loop order).
	level.boss_room_trigger().body_entered.emit(level.get_node("Player"))
	# Drive the Warden to 0 HP through its real death path (emits `defeated`).
	var health := boss.get_node("Health") as Health
	health.take_damage(health.max_health + 100.0)   # overkill -> died -> defeated
	assert_true(boss.is_defeated(), "the Warden is defeated at 0 HP")
	assert_true(level.is_victory(),
		"defeating the Warden sets the SECTOR victory state (sector-level, not arena-local)")


func test_sector_victory_emits_a_signal() -> void:
	# A decoupled `sector_victory` signal lets the HUD / future tickets react.
	var level := await _make_sector()
	watch_signals(level)
	var boss := level.warden() as Warden
	boss.defeated.emit()
	assert_signal_emitted(level, "sector_victory",
		"the sector emits `sector_victory` when the Warden is defeated")


# --- DD-009 respawn points at the SECTOR spawn, not the arena ------------------

func test_player_respawns_at_the_sector_spawn_not_the_arena() -> void:
	# Criterion 3 (DD-009): death during the run respawns the hero at the SECTOR spawn
	# point (PlayerSpawn), not at any arena origin. _ready records the spawn at the
	# sector marker; after we displace the hero and respawn, it returns THERE.
	var level := await _make_sector()
	var spawn := level.get_node("PlayerSpawn") as Marker2D
	var player := level.get_node("Player")
	# Walk the hero downrange (as if mid-run), then trigger a respawn.
	player.global_position = Vector2(3600, 80)
	player.respawn()
	assert_almost_eq(player.global_position.x, spawn.global_position.x, 8.0,
		"the hero respawns at the SECTOR spawn x (DD-009), not the arena")
	assert_almost_eq(player.global_position.y, spawn.global_position.y, 8.0,
		"the hero respawns at the SECTOR spawn y (DD-009), not the arena")


# --- The boss HP HUD is wired to the reused Warden (criterion 1) ---------------

func test_boss_hud_is_present_and_bound_to_the_warden() -> void:
	# Criterion 1: the boss HP HUD (DD-010) shows for the sector boss. The reused
	# BossHUD must resolve and bind to the placed Warden so HP/phase read on screen.
	var level := await _make_sector()
	var hud := level.get_node_or_null("BossHUD")
	assert_not_null(hud, "the sector reuses the DD-010 BossHUD")
	var boss: Variant = level.warden()
	# The HUD's bound boss is the placed Warden (decoupled poll target).
	assert_eq(hud.get("boss_path"), NodePath("../Warden"),
		"the boss HUD is bound to the placed Warden node")
	assert_not_null(boss, "the bound Warden resolves")
