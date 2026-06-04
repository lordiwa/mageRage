## TASK-016 unit tests: player-damage FEEDBACK signal path (no rendered scene).
##
## On a LANDED hit, take_player_damage must emit `damaged(amount, hit_dir)` exactly
## once so the PlayerHUD can flash the red vignette + hit-direction indicator. The
## signal must NOT fire on a blocked hit (i-frames active) or a non-hit (amount<=0).
## The new hit_dir param is OPTIONAL (defaults Vector2.ZERO) so every existing
## one-arg caller/fake keeps working unchanged.
extends GutTest

const HitStopScript := preload("res://scripts/juice/hit_stop.gd")
const PlayerScript := preload("res://scripts/player/player.gd")

var player: Player
var health: Health


func before_each() -> void:
	player = Player.new()
	health = Health.new()
	health.name = "Health"
	health.max_health = 100.0
	player.add_child(health)
	add_child_autofree(player)
	player.global_position = Vector2(64, 256)
	player.record_spawn()


# --- damaged signal fires once on a landed hit -------------------------------

func test_landed_hit_emits_damaged_once() -> void:
	watch_signals(player)
	var dir := Vector2(1, 0)
	player.take_player_damage(25.0, dir)
	assert_signal_emit_count(player, "damaged", 1,
		"a landed hit emits the damaged signal exactly once")


func test_damaged_signal_carries_amount_and_hit_dir() -> void:
	watch_signals(player)
	var dir := Vector2(1, 0)
	player.take_player_damage(25.0, dir)
	assert_signal_emitted_with_parameters(player, "damaged", [25.0, dir],
		"the damaged signal carries the amount and the hit direction")


# --- damaged signal is suppressed when no hit actually lands -----------------

func test_no_damaged_signal_while_invulnerable() -> void:
	player.take_player_damage(25.0, Vector2(1, 0))   # opens i-frames
	watch_signals(player)
	player.take_player_damage(25.0, Vector2(1, 0))   # blocked by i-frames
	assert_signal_emit_count(player, "damaged", 0,
		"a hit blocked by i-frames emits no damaged signal")


func test_no_damaged_signal_for_zero_damage() -> void:
	watch_signals(player)
	player.take_player_damage(0.0, Vector2(1, 0))
	assert_signal_emit_count(player, "damaged", 0,
		"a non-positive amount is not a hit and emits no signal")


# --- backward compatibility: one-arg call still works ------------------------

func test_one_arg_call_still_applies_damage() -> void:
	player.take_player_damage(25.0)
	assert_eq(player.player_hp(), 75.0,
		"the legacy one-arg take_player_damage still deals damage")


func test_one_arg_call_still_opens_iframes() -> void:
	player.take_player_damage(10.0)
	assert_true(player.is_invulnerable(),
		"the legacy one-arg take_player_damage still opens i-frames")


func test_one_arg_call_emits_damaged_with_zero_dir() -> void:
	watch_signals(player)
	player.take_player_damage(15.0)
	assert_signal_emitted_with_parameters(player, "damaged", [15.0, Vector2.ZERO],
		"a one-arg hit emits damaged with a ZERO hit direction (vignette-only)")


# --- subtle player hit-stop: gentler than an enemy super-effective hit -------

func test_player_hitstop_is_subtle() -> void:
	# DD: the player's on-hit freeze must be gentler than the loudest enemy juice
	# (a super-effective hit, freeze(1.5)) so the rarest beats stay the loudest.
	var player_freeze := HitStopScript.duration_for(PlayerScript.PLAYER_HITSTOP_EFFECTIVENESS)
	var super_effective := HitStopScript.duration_for(1.5)
	assert_lt(player_freeze, super_effective,
		"the player hit-stop is shorter than an enemy super-effective hit-stop")


func test_player_hitstop_effectiveness_is_gentle() -> void:
	assert_lte(PlayerScript.PLAYER_HITSTOP_EFFECTIVENESS, 1.0,
		"the player hit-stop effectiveness is at most a neutral hit (gentle)")
