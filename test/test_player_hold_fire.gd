## TASK-038 hold-to-fire WIRING on the Player (headless, no physics).
##
## The player must drive CONTINUOUS fire while a trigger is HELD (not one shot per
## press): every frame it reads Input.is_action_pressed("cast_primary"/"...secondary")
## through the InputGate seam (deterministic in headless tests) and asks the
## MagicManager to try-cast that slot with the frame `delta`, preserving the
## existing assisted-aim / origin pipeline. A duck-typed manager double records the
## held calls so we can assert the wiring without spawning projectiles.
##
## InputGate hygiene (memory gut-flake-await/Input): drive the HELD read through
## InputGate.set_test_override(); after_each clears the overrides AND releases input.
extends GutTest

var player: Player


## A duck-typed MagicManager stand-in: records each held try-cast call (held flag +
## delta) and the slot, and exposes the no-arg API the player's other paths touch.
class FakeMagic:
	extends Node
	var primary_calls: Array = []     # [{held:bool, delta:float, aim:Vector2}]
	var secondary_calls: Array = []
	var selected: Array[int] = []

	func try_cast_primary_held(_origin: Node2D, aim: Vector2, held: bool, delta: float) -> bool:
		primary_calls.append({"held": held, "delta": delta, "aim": aim})
		return held

	func try_cast_secondary_held(_origin: Node2D, aim: Vector2, held: bool, delta: float) -> bool:
		secondary_calls.append({"held": held, "delta": delta, "aim": aim})
		return held

	func select(index: int) -> void:
		selected.append(index)


func before_each() -> void:
	player = Player.new()
	var fake := FakeMagic.new()
	fake.name = "MagicManager"
	player.add_child(fake)
	add_child_autofree(player)   # _ready resolves _magic via @onready node name


func after_each() -> void:
	# InputGate hygiene: drop overrides so a held edge never leaks into later tests.
	InputGate.clear_test_overrides()
	Input.action_release("cast_primary")
	Input.action_release("cast_secondary")


func _magic() -> FakeMagic:
	return player.get_node("MagicManager") as FakeMagic


# --- the player calls the manager's HELD try-cast each frame -----------------

func test_held_primary_passes_held_true_and_delta_to_manager() -> void:
	InputGate.set_test_override("cast_primary", true)
	player.process_magic_for_test(0.05)
	var calls := _magic().primary_calls
	assert_eq(calls.size(), 1, "one primary held try-cast per processed frame")
	assert_true(calls[0]["held"], "a held primary trigger passes held=true to the manager")
	assert_almost_eq(calls[0]["delta"], 0.05, 0.0001, "the frame delta reaches the cadence gate")


func test_released_primary_passes_held_false() -> void:
	InputGate.set_test_override("cast_primary", false)
	player.process_magic_for_test(0.05)
	var calls := _magic().primary_calls
	assert_eq(calls.size(), 1, "the manager is still ticked each frame (delta advances)")
	assert_false(calls[0]["held"], "a released primary trigger passes held=false (no fire)")


func test_held_secondary_passes_held_true() -> void:
	InputGate.set_test_override("cast_secondary", true)
	player.process_magic_for_test(0.05)
	var calls := _magic().secondary_calls
	assert_eq(calls.size(), 1, "one secondary held try-cast per processed frame")
	assert_true(calls[0]["held"], "a held secondary trigger passes held=true to the manager")


func test_holding_both_triggers_drives_both_slots() -> void:
	InputGate.set_test_override("cast_primary", true)
	InputGate.set_test_override("cast_secondary", true)
	player.process_magic_for_test(0.05)
	assert_true(_magic().primary_calls[0]["held"], "both held: primary slot driven")
	assert_true(_magic().secondary_calls[0]["held"], "both held: secondary slot driven")


func test_held_cast_uses_the_assisted_aim() -> void:
	# The held path must keep the DD-012 assisted-aim pipeline (cast_aim()).
	InputGate.set_test_override("cast_primary", true)
	player.set_aim_for_test(Vector2.UP, Player.AimDevice.PAD)
	player.process_magic_for_test(0.05)
	var aim: Vector2 = _magic().primary_calls[0]["aim"]
	assert_almost_eq(aim.angle(), Vector2.UP.angle(), 0.001,
		"the held cast is fired along the assisted cast_aim() direction")


func test_continuous_fire_across_many_held_frames() -> void:
	# Hold across 5 frames: the manager is asked to try-cast on EVERY frame (cadence
	# gating lives in the manager, not the input edge) -- proving it's no longer
	# one-shot-per-press.
	InputGate.set_test_override("cast_primary", true)
	for _i in range(5):
		player.process_magic_for_test(0.02)
	assert_eq(_magic().primary_calls.size(), 5,
		"a HELD trigger drives a try-cast every frame (continuous, not one-per-press)")
