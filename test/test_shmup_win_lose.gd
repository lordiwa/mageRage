## TASK-067 shmup WIN/LOSE tests — the win/lose loop for the auto-scroll shmup
## (levels/shmup_01.tscn + Shmup01).
##
##   WIN  : the auto-scroll camera travels a fixed LEVEL_LENGTH from its start; once the
##          camera's progress passes LEVEL_LENGTH the controller fires `shmup_victory`
##          (mirroring sector_02's `sector_victory`) exactly once and latches is_victory().
##   LOSE : the hero's HP reaching 0 REVIVES it in-frame and the loop continues. Player.respawn
##          (DD-009) puts the hero back at the recorded level-start x, but the auto-scroll
##          camera keeps advancing — so the very next per-frame clamp_player_to_view() snaps
##          the revived hero into the LIVE visible rect and the lane keeps scrolling. Brief
##          defeat feedback (shmup_defeat / has_died) fires.
##
## Win is driven DETERMINISTICALLY by advancing the scroller + calling the controller's
## progress check directly (no real frames). Lose is driven by dealing lethal damage to the
## player's Health, then STEPPING the controller's clamp so the in-frame revive is real.
extends GutTest

const SHMUP := preload("res://levels/shmup_01.tscn")


func _make_level() -> Node2D:
	var level := SHMUP.instantiate()
	add_child_autofree(level)
	await get_tree().process_frame
	return level


# --- WIN: reach LEVEL_LENGTH -> shmup_victory --------------------------------

func test_level_length_is_a_positive_finish_distance() -> void:
	# The finish marker is a named, tunable const measured from the scroller start.
	assert_gt(Shmup01.LEVEL_LENGTH, 0.0,
		"LEVEL_LENGTH is a positive finish distance (the fixed scroll length)")


func test_progress_is_zero_at_the_start() -> void:
	var level: Node2D = await _make_level()
	var shmup := level as Shmup01
	# progress() is travel from the captured start x. After the single settle frame the
	# auto-scroll camera has advanced a few px (SCROLL_SPEED * one delta) — far below the
	# finish line. Assert it is small + non-negative (not the full LEVEL_LENGTH).
	assert_between(shmup.progress(), -0.001, 30.0,
		"progress() reads ~0 (small + nonneg) at the level start, nowhere near the finish")
	assert_false(shmup.is_victory(), "no victory at the start")


func test_passing_level_length_fires_shmup_victory_once() -> void:
	var level: Node2D = await _make_level()
	var shmup := level as Shmup01
	watch_signals(shmup)
	var scroller := shmup.scroller()
	assert_not_null(scroller, "the scroller resolves")

	# Drive the camera PAST the finish line, then run the controller's progress check.
	scroller.global_position.x += Shmup01.LEVEL_LENGTH + 50.0
	shmup.check_progress()
	assert_true(shmup.is_victory(), "passing LEVEL_LENGTH latches the victory state")
	assert_signal_emitted(shmup, "shmup_victory",
		"reaching the finish fires the shmup_victory signal (mirrors sector_victory)")

	# Idempotent: a further check does NOT re-fire the signal.
	var before: int = get_signal_emit_count(shmup, "shmup_victory")
	shmup.check_progress()
	assert_eq(get_signal_emit_count(shmup, "shmup_victory"), before,
		"shmup_victory fires exactly once (latched, idempotent)")


func test_before_the_finish_no_victory() -> void:
	var level: Node2D = await _make_level()
	var shmup := level as Shmup01
	watch_signals(shmup)
	var scroller := shmup.scroller()
	# Advance only PART of the way.
	scroller.global_position.x += Shmup01.LEVEL_LENGTH * 0.5
	shmup.check_progress()
	assert_false(shmup.is_victory(), "halfway through the lane there is no victory yet")
	assert_signal_not_emitted(shmup, "shmup_victory", "shmup_victory does not fire before the finish")


# --- LOSE: HP -> 0 revives in-frame and the loop continues -------------------

func test_player_death_revives_in_frame_and_loop_continues() -> void:
	var level: Node2D = await _make_level()
	var shmup := level as Shmup01
	var player := level.get_node_or_null("Player") as Node2D
	var spawn := level.get_node_or_null("PlayerSpawn") as Marker2D
	var scroller := shmup.scroller()
	assert_not_null(player, "the Player resolves")
	assert_not_null(spawn, "PlayerSpawn resolves")
	assert_not_null(scroller, "the scroller resolves")
	watch_signals(shmup)

	# Drive the auto-scroll camera WELL PAST the start so the recorded level-start x is far
	# off the left edge of the live view. Respawn alone (Player.respawn -> spawn x) would
	# leave the hero stranded behind the frame; only the per-frame clamp can carry it in.
	scroller.global_position.x += Shmup01.LEVEL_LENGTH * 0.5
	var live_rect: Rect2 = scroller.visible_world_rect()
	assert_lt(spawn.global_position.x, live_rect.position.x,
		"the recorded level-start x is now BEHIND the left edge of the live view")

	# Move the hero somewhere in-frame (as if maneuvering), then deal lethal damage. This
	# drives take_player_damage -> Health.died -> Player.respawn (snap to the stale start x).
	player.global_position = live_rect.get_center()
	var health := player.get_node_or_null("Health") as Health
	assert_not_null(health, "the Player has a Health child (DD-009)")
	player.take_player_damage(health.max_health + 10.0)

	# After respawn (before any clamp) the hero is at the STALE start x — behind the frame.
	assert_almost_eq(player.global_position.x, spawn.global_position.x, 8.0,
		"Player.respawn snaps to the recorded start x (DD-009) — momentarily behind the frame")

	# STEP the controller's per-frame clamp: this is the seam that revives the hero IN-FRAME.
	shmup.clamp_player_to_view()

	# The hero is now INSIDE the live visible rect (clamped in from the stale start x), NOT
	# left stranded at the start. This FAILS for an implementation that respawns-and-stops.
	var p := player.global_position
	assert_true(live_rect.has_point(p),
		"after the per-frame clamp the revived hero is INSIDE the live scroll frame (in-frame revive)")
	assert_gt(p.x, spawn.global_position.x,
		"the clamp carried the hero forward off the stale start x into the live frame")

	# The loop continues: full health, not dead, and the defeat feedback fired.
	assert_false(health.is_dead(), "after revive the hero is alive again (full health)")
	assert_true(shmup.has_died(), "the controller recorded the death for defeat feedback")
	assert_signal_emitted(shmup, "shmup_defeat",
		"the in-frame revive still fires the brief defeat feedback")


func test_defeat_feedback_latches_on_death() -> void:
	# The controller observes the player's death and latches a defeat/retry state so the
	# minimal HUD banner can show. (The respawn keeps the loop going; the latch just
	# records that a death happened for feedback.)
	var level: Node2D = await _make_level()
	var shmup := level as Shmup01
	var player := level.get_node_or_null("Player") as Node2D
	var health := player.get_node_or_null("Health") as Health
	assert_false(shmup.has_died(), "no death recorded at the start")
	watch_signals(shmup)
	player.take_player_damage(health.max_health + 10.0)
	assert_true(shmup.has_died(), "the controller records the death for defeat feedback")
	assert_signal_emitted(shmup, "shmup_defeat", "a death fires the shmup_defeat feedback signal")
