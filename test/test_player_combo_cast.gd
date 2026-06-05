## TASK-040 (DD-013) dual-cast COMBO wiring on the Player (headless, no physics).
##
## When BOTH triggers are held, the player routes through the manager's combo path
## FIRST. If a combo fires this frame, it SUPPRESSES the two single shots (you get
## ONE blended combo, not two singles). When only one trigger is held, behavior is
## exactly TASK-038 (singles at that element's interval) — no regression.
##
## A duck-typed manager double records the calls so we assert the wiring without
## spawning projectiles. InputGate hygiene (memory gut-flake-await/Input): drive the
## HELD reads through InputGate.set_test_override(); after_each clears + releases.
extends GutTest

var player: Player


## Duck-typed MagicManager stand-in. Records single + combo held calls. `combo_fires`
## controls whether the combo path reports a fired combo this frame.
class FakeMagic:
	extends Node
	var primary_calls: Array = []
	var secondary_calls: Array = []
	var combo_calls: Array = []     # [{p:bool, s:bool, delta:float, aim:Vector2}]
	var combo_fires := false        # when true, try_cast_combo_held reports a shot

	func try_cast_combo_held(
		_origin: Node2D, aim: Vector2, p_held: bool, s_held: bool, delta: float
	) -> Dictionary:
		combo_calls.append({"p": p_held, "s": s_held, "delta": delta, "aim": aim})
		var both := p_held and s_held
		var fired := combo_fires and both
		# MEDIUM: while BOTH are held the player is in combo MODE — singles are
		# suppressed every frame (you trade fast single fire for the slow combo
		# rhythm), not only on the frame a combo actually fires.
		return {"shot": fired, "kind": 0, "suppress_singles": both}

	func try_cast_primary_held(_origin: Node2D, aim: Vector2, held: bool, delta: float) -> bool:
		primary_calls.append({"held": held, "delta": delta, "aim": aim})
		return held

	func try_cast_secondary_held(_origin: Node2D, aim: Vector2, held: bool, delta: float) -> bool:
		secondary_calls.append({"held": held, "delta": delta, "aim": aim})
		return held

	func select(_index: int) -> void:
		pass


func before_each() -> void:
	player = Player.new()
	var fake := FakeMagic.new()
	fake.name = "MagicManager"
	player.add_child(fake)
	add_child_autofree(player)


func after_each() -> void:
	InputGate.clear_test_overrides()
	Input.action_release("cast_primary")
	Input.action_release("cast_secondary")


func _magic() -> FakeMagic:
	return player.get_node("MagicManager") as FakeMagic


# --- both triggers route through the combo path ------------------------------

func test_holding_both_triggers_calls_the_combo_path() -> void:
	InputGate.set_test_override("cast_primary", true)
	InputGate.set_test_override("cast_secondary", true)
	player.process_magic_for_test(0.05)
	var calls := _magic().combo_calls
	assert_eq(calls.size(), 1, "one combo try-cast per frame while both are held")
	assert_true(calls[0]["p"] and calls[0]["s"], "both-held flags reach the combo path")
	assert_almost_eq(calls[0]["delta"], 0.05, 0.0001, "the frame delta reaches the combo gate")


func test_a_fired_combo_suppresses_both_single_shots_that_frame() -> void:
	# When the combo actually fires, the two singles must NOT also fire (one blended
	# shot, not two singles).
	_magic().combo_fires = true
	InputGate.set_test_override("cast_primary", true)
	InputGate.set_test_override("cast_secondary", true)
	player.process_magic_for_test(0.05)
	# Singles are either not called, or called with held=false (suppressed) this frame.
	for c in _magic().primary_calls:
		assert_false(c["held"], "a fired combo suppresses the primary single shot")
	for c in _magic().secondary_calls:
		assert_false(c["held"], "a fired combo suppresses the secondary single shot")


func test_combo_mode_suppresses_in_between_singles_even_with_no_combo_this_frame() -> void:
	# MEDIUM fix: holding BOTH triggers commits to the combo rhythm. Even on a frame
	# where the (slow) combo cadence isn't ready yet, the player does NOT also get
	# full-rate singles in between — comboing TRADES single fire, it doesn't ADD to it.
	_magic().combo_fires = false
	InputGate.set_test_override("cast_primary", true)
	InputGate.set_test_override("cast_secondary", true)
	player.process_magic_for_test(0.05)
	for c in _magic().primary_calls:
		assert_false(c["held"],
			"combo mode (both held) suppresses the in-between primary single")
	for c in _magic().secondary_calls:
		assert_false(c["held"],
			"combo mode (both held) suppresses the in-between secondary single")


# --- single-trigger behavior is UNREGRESSED (TASK-038) -----------------------

func test_single_primary_still_fires_a_single_no_combo() -> void:
	InputGate.set_test_override("cast_primary", true)
	InputGate.set_test_override("cast_secondary", false)
	player.process_magic_for_test(0.05)
	assert_true(_magic().primary_calls[-1]["held"],
		"one trigger held still drives its single shot (TASK-038 unchanged)")
	# The combo path, if pinged, must report no combo for a single trigger.
	for c in _magic().combo_calls:
		assert_false(c["p"] and c["s"], "a single trigger never satisfies the dual-trigger")


func test_single_secondary_still_fires_a_single() -> void:
	InputGate.set_test_override("cast_primary", false)
	InputGate.set_test_override("cast_secondary", true)
	player.process_magic_for_test(0.05)
	assert_true(_magic().secondary_calls[-1]["held"],
		"the secondary single still fires when only it is held")


func test_combo_path_uses_the_assisted_aim() -> void:
	InputGate.set_test_override("cast_primary", true)
	InputGate.set_test_override("cast_secondary", true)
	player.set_aim_for_test(Vector2.UP, Player.AimDevice.PAD)
	player.process_magic_for_test(0.05)
	var aim: Vector2 = _magic().combo_calls[0]["aim"]
	assert_almost_eq(aim.angle(), Vector2.UP.angle(), 0.001,
		"the combo is fired along the DD-012 assisted cast_aim() direction")


func test_neither_trigger_held_fires_nothing() -> void:
	InputGate.set_test_override("cast_primary", false)
	InputGate.set_test_override("cast_secondary", false)
	player.process_magic_for_test(0.05)
	# Combo path may be ticked (delta keeps time) but with both flags false.
	for c in _magic().combo_calls:
		assert_false(c["p"] or c["s"], "no trigger held -> the combo never engages")
