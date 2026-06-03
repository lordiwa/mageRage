## Unit tests for the Health component (pure logic, no rendered scene).
##
## A Health node tracks current/max HP, takes damage clamped at 0, emits
## `health_changed` on every change and `died` exactly once when HP reaches 0.
extends GutTest

var hp: Health


func before_each() -> void:
	hp = Health.new()
	hp.max_health = 100.0
	add_child_autofree(hp)   # _ready seeds current = max


func test_starts_at_full() -> void:
	assert_eq(hp.current_health, 100.0, "current should seed to max on ready")
	assert_false(hp.is_dead(), "a freshly readied unit is alive")


func test_take_damage_subtracts() -> void:
	hp.take_damage(30.0)
	assert_eq(hp.current_health, 70.0, "damage subtracts from current")
	assert_false(hp.is_dead())


func test_take_damage_clamps_at_zero() -> void:
	hp.take_damage(250.0)
	assert_eq(hp.current_health, 0.0, "HP must clamp at 0, never go negative")


func test_dies_at_zero() -> void:
	hp.take_damage(100.0)
	assert_true(hp.is_dead(), "HP <= 0 means dead")


func test_died_signal_emits_once() -> void:
	watch_signals(hp)
	hp.take_damage(100.0)
	assert_signal_emitted(hp, "died", "died should fire when HP reaches 0")
	# A further hit on a corpse must not re-emit died.
	hp.take_damage(50.0)
	assert_signal_emit_count(hp, "died", 1,
		"died must fire exactly once, not on every post-death hit")


func test_health_changed_signal_emits_on_damage() -> void:
	watch_signals(hp)
	hp.take_damage(10.0)
	assert_signal_emitted_with_parameters(hp, "health_changed", [90.0, 100.0])


func test_negative_or_zero_damage_is_ignored() -> void:
	hp.take_damage(0.0)
	hp.take_damage(-5.0)
	assert_eq(hp.current_health, 100.0,
		"non-positive damage should not heal or change HP")
