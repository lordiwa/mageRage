## TASK-021 unit tests for WaveController — the PURE, scene-free wave-sequencing
## helper that drives the encounter room (Sala de encuentro).
##
## The controller owns NO nodes: it only tracks which wave is current, decides when
## a wave is CLEARED (all its enemies dead/freed), and gates advancing to the next
## wave behind a REST delay (doctrine: ramp-then-rest). It is bounded — it never
## advances past the last wave, and reports completion when every wave is cleared.
##
## It also owns the composition-guarantee helpers (distinct_armor_count /
## wave_is_mixed) so the DD-004 "no single-element-dominated wave" property is
## data-testable against the real encounter wave design (EncounterWaves.WAVES).
extends GutTest

const FIRE := SpellData.Element.FIRE
const ICE := SpellData.Element.ICE
const ELEC := SpellData.Element.ELECTRICITY


func _make(total := 3) -> WaveController:
	var wc := WaveController.new()
	wc.total_waves = total
	return wc


# --- is_wave_cleared ----------------------------------------------------------

func test_wave_cleared_when_zero_alive() -> void:
	var wc := _make()
	assert_true(wc.is_wave_cleared(0),
		"a wave is cleared once no enemies remain alive")


func test_wave_not_cleared_with_survivors() -> void:
	var wc := _make()
	assert_false(wc.is_wave_cleared(1),
		"a wave is not cleared while any enemy is alive")
	assert_false(wc.is_wave_cleared(5),
		"still not cleared with several survivors")


func test_wave_cleared_is_safe_for_negative() -> void:
	var wc := _make()
	# Defensive: a bad/negative count must not read as "not cleared".
	assert_true(wc.is_wave_cleared(-1),
		"a non-positive alive count is treated as cleared")


# --- should_advance: only when cleared AND rest elapsed -----------------------

func test_should_not_advance_while_enemies_alive() -> void:
	var wc := _make()
	assert_false(wc.should_advance(2, 10.0, 1.0),
		"never advance while enemies are alive, even past the rest delay")


func test_should_not_advance_before_rest_delay() -> void:
	var wc := _make()
	assert_false(wc.should_advance(0, 0.5, 1.0),
		"cleared but rest beat not finished -> hold (ramp-then-rest)")


func test_should_advance_when_cleared_and_rested() -> void:
	var wc := _make()
	assert_true(wc.should_advance(0, 1.0, 1.0),
		"cleared AND rest elapsed >= delay -> advance (inclusive boundary)")
	assert_true(wc.should_advance(0, 2.0, 1.0),
		"stays advance-able once well past the rest delay")


func test_should_not_advance_when_already_complete() -> void:
	var wc := _make(2)
	wc.advance()   # -> index 1 (last)
	wc.advance()   # -> index 2 (complete; bounded, see below)
	assert_false(wc.should_advance(0, 99.0, 1.0),
		"a fully-cleared encounter never advances again")


# --- advance + bounded + is_complete -----------------------------------------

func test_advance_increments_index() -> void:
	var wc := _make(3)
	assert_eq(wc.current_index, 0, "starts on the first wave")
	wc.advance()
	assert_eq(wc.current_index, 1, "advance moves to the next wave")


func test_advance_is_bounded_at_total() -> void:
	var wc := _make(3)
	wc.advance()
	wc.advance()
	wc.advance()
	wc.advance()   # extra advance past the end must clamp, not overflow
	assert_eq(wc.current_index, 3,
		"index never exceeds total_waves (bounded; clamps at the end)")


func test_is_complete_only_at_end() -> void:
	var wc := _make(3)
	assert_false(wc.is_complete(), "not complete on wave 0 of 3")
	wc.advance()
	assert_false(wc.is_complete(), "not complete on wave 1 of 3")
	wc.advance()
	assert_false(wc.is_complete(), "not complete on wave 2 of 3 (last live wave)")
	wc.advance()
	assert_true(wc.is_complete(), "complete once advanced past the last wave")


func test_current_index_valid_while_running() -> void:
	var wc := _make(3)
	assert_true(wc.has_current_wave(), "wave 0 is a real wave")
	wc.advance(); wc.advance(); wc.advance()
	assert_false(wc.has_current_wave(),
		"no current wave once the encounter is complete")


# --- Composition guarantee: distinct_armor_count / wave_is_mixed --------------

func test_distinct_armor_count_counts_unique_types() -> void:
	var wc := _make()
	assert_eq(wc.distinct_armor_count([FIRE, FIRE, FIRE]), 1,
		"all-same armor -> 1 distinct type")
	assert_eq(wc.distinct_armor_count([FIRE, ICE]), 2,
		"two different armors -> 2 distinct types")
	assert_eq(wc.distinct_armor_count([FIRE, ICE, ELEC, ICE]), 3,
		"three different armors (with a dup) -> 3 distinct types")


func test_distinct_armor_count_empty_safe() -> void:
	var wc := _make()
	assert_eq(wc.distinct_armor_count([]), 0,
		"empty armor list -> 0 distinct types (null/empty safe)")


func test_wave_is_mixed_requires_two_distinct() -> void:
	var wc := _make()
	assert_false(wc.wave_is_mixed([FIRE]), "a single armor is not mixed")
	assert_false(wc.wave_is_mixed([FIRE, FIRE]), "two of the same armor is not mixed")
	assert_true(wc.wave_is_mixed([FIRE, ICE]), ">=2 distinct armors is mixed")
	assert_true(wc.wave_is_mixed([FIRE, ICE, ELEC]), "three distinct armors is mixed")


# --- DD-004: EVERY designed wave mixes armor (no single-element dominance) -----

func test_every_designed_wave_is_mixed() -> void:
	var wc := _make()
	var waves: Array = EncounterWaves.WAVES
	assert_gt(waves.size(), 0, "the encounter has at least one designed wave")
	for i in range(waves.size()):
		var armors := EncounterWaves.armor_types_of(waves[i])
		assert_true(wc.wave_is_mixed(armors),
			"wave %d mixes >=2 distinct armor types (DD-004 anti-dominance); got %s"
				% [i + 1, str(armors)])


func test_designed_wave_count_is_at_least_three() -> void:
	# The milestone capstone designs ~3 ramping waves.
	assert_gte(EncounterWaves.WAVES.size(), 3,
		"at least three designed waves (ramp-then-rest across the fight)")


func test_each_wave_has_at_least_one_entry() -> void:
	for i in range(EncounterWaves.WAVES.size()):
		var w: Array = EncounterWaves.WAVES[i]
		assert_gt(w.size(), 0, "wave %d spawns at least one enemy" % [i + 1])


func test_each_wave_entry_points_at_a_real_scene() -> void:
	# The data is wired to actual enemy scenes (so the live controller can spawn them).
	for i in range(EncounterWaves.WAVES.size()):
		for entry in EncounterWaves.WAVES[i]:
			assert_true(entry.has("scene"), "entry declares a scene path")
			assert_true(ResourceLoader.exists(entry["scene"]),
				"wave %d entry scene exists: %s" % [i + 1, entry.get("scene", "?")])
			assert_true(entry.has("armor_type"), "entry declares an armor_type")
			assert_true(entry.has("position"), "entry declares a spawn position")
