## DD-009 unit tests for player damage / i-frames / respawn (no rendered scene).
##
## The player gains a Health (~100); the enemy projectile damages it; a hit opens
## ~0.8s of i-frames during which further damage is blocked (no control stun);
## death triggers a respawn at the recorded start position with full health.
## Determinist and fair (DD-001). These exercise the Player node's combat methods
## directly with a Health child injected (the scene wires the same child).
extends GutTest

var player: Player
var health: Health


func before_each() -> void:
	player = Player.new()
	# The scene authors a Health child named "Health"; mirror it here.
	health = Health.new()
	health.name = "Health"
	health.max_health = 100.0
	player.add_child(health)
	add_child_autofree(player)   # _ready runs: collision setup + spawn recorded
	player.global_position = Vector2(64, 256)
	player.record_spawn()        # capture the start position for respawn


func test_player_starts_at_full_health() -> void:
	assert_eq(player.player_hp(), 100.0, "player seeds to full HP")
	assert_eq(player.max_player_hp(), 100.0, "max HP exposed for the HUD")


func test_take_damage_reduces_hp() -> void:
	player.take_player_damage(25.0)
	assert_eq(player.player_hp(), 75.0, "taking damage reduces player HP")


func test_iframes_block_damage_while_active() -> void:
	player.take_player_damage(25.0)        # opens i-frames
	assert_eq(player.player_hp(), 75.0)
	player.take_player_damage(25.0)        # should be blocked by i-frames
	assert_eq(player.player_hp(), 75.0,
		"a second hit during i-frames deals no damage")


func test_damage_lands_again_after_iframes_expire() -> void:
	player.take_player_damage(25.0)
	player.tick_iframes(0.9)               # past the ~0.8s window
	player.take_player_damage(25.0)
	assert_eq(player.player_hp(), 50.0,
		"damage lands again once i-frames have expired")


func test_taking_a_hit_makes_player_invulnerable() -> void:
	assert_false(player.is_invulnerable(), "not invulnerable before being hit")
	player.take_player_damage(10.0)
	assert_true(player.is_invulnerable(), "i-frames active right after a hit")


func test_death_triggers_respawn_full_hp_and_position() -> void:
	# Move the player away from spawn, then kill it.
	player.global_position = Vector2(1200, -200)
	player.take_player_damage(100.0)       # lethal
	assert_eq(player.player_hp(), 100.0,
		"respawn restores full HP")
	assert_eq(player.global_position, Vector2(64, 256),
		"respawn resets position to the recorded spawn")
	assert_false(player.is_invulnerable(),
		"a fresh respawn is not stuck in i-frames")


func test_respawn_clears_dead_state_and_can_take_damage_again() -> void:
	player.take_player_damage(100.0)       # death -> respawn
	player.tick_iframes(1.0)               # clear any post-respawn i-frames
	player.take_player_damage(30.0)
	assert_eq(player.player_hp(), 70.0,
		"the respawned player is alive and can take damage again")
