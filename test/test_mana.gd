## Unit tests for the Mana component (pure logic, no rendered scene).
##
## Mana gates casting: can_afford(cost) is false when current < cost; a successful
## spend() subtracts and returns true; an unaffordable spend() is a no-op returning
## false. Regen tops mana back up over time, clamped at max.
extends GutTest

var mana: Mana


func before_each() -> void:
	mana = Mana.new()
	mana.max_mana = 100.0
	mana.regen_per_second = 10.0
	add_child_autofree(mana)   # _ready seeds current = max


func test_starts_full() -> void:
	assert_eq(mana.current_mana, 100.0, "mana seeds to max on ready")


func test_cannot_afford_when_below_cost() -> void:
	mana.current_mana = 4.0
	assert_false(mana.can_afford(5.0), "4 mana cannot afford a cost of 5")


func test_can_afford_when_equal_or_above() -> void:
	mana.current_mana = 5.0
	assert_true(mana.can_afford(5.0), "exactly enough mana can afford the cost")


func test_spend_subtracts_when_affordable() -> void:
	var ok := mana.spend(30.0)
	assert_true(ok, "spend returns true on success")
	assert_eq(mana.current_mana, 70.0, "spend subtracts the cost")


func test_spend_is_noop_when_unaffordable() -> void:
	mana.current_mana = 3.0
	var ok := mana.spend(5.0)
	assert_false(ok, "spend returns false when unaffordable")
	assert_eq(mana.current_mana, 3.0, "an unaffordable spend must not change mana")


func test_regen_tops_up_over_time() -> void:
	mana.current_mana = 50.0
	mana.regenerate(1.0)   # 10/s * 1s
	assert_eq(mana.current_mana, 60.0, "regen adds regen_per_second * delta")


func test_regen_clamps_at_max() -> void:
	mana.current_mana = 95.0
	mana.regenerate(1.0)   # would reach 105
	assert_eq(mana.current_mana, 100.0, "regen must clamp at max_mana")


func test_mana_changed_signal_on_spend() -> void:
	watch_signals(mana)
	mana.spend(20.0)
	assert_signal_emitted_with_parameters(mana, "mana_changed", [80.0, 100.0])
