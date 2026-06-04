## DD-010 unit tests for WardenPhases — pure phase/armor/pattern/fan helpers (no scene).
##
## The Warden mini-boss routes ALL phase selection and fan-volley geometry through
## these static helpers so every threshold and angle is fair/deterministic (DD-001)
## and can never drift. Covered: HP->phase banding at the 66% / 33% thresholds (the
## exact DD-010 boundary cases), armor element per phase (DD-006 RPS), the per-phase
## attack pattern id, the phase weakness element, and the fan-volley directions
## (count, symmetry, angles, normalization).
extends GutTest

const FIRE := SpellData.Element.FIRE
const ICE := SpellData.Element.ICE
const ELEC := SpellData.Element.ELECTRICITY

const MAXHP := 300.0


# --- phase_for_hp: DD-010 thresholds 66% and 33% -----------------------------
# Bands: P1 = 100..>66, P2 = <=66..>33, P3 = <=33..0.

func test_phase_for_full_hp_is_one() -> void:
	assert_eq(WardenPhases.phase_for_hp(MAXHP, MAXHP), 1,
		"100% HP -> Phase 1")


func test_phase_for_67_percent_is_one() -> void:
	# 67% is above the 66% threshold -> still Phase 1.
	assert_eq(WardenPhases.phase_for_hp(0.67 * MAXHP, MAXHP), 1,
		"67% HP -> Phase 1 (above the 66% line)")


func test_phase_for_66_percent_is_two() -> void:
	# Exactly 66% is at/below the threshold -> Phase 2 (DD-010 band is "66-33").
	assert_eq(WardenPhases.phase_for_hp(0.66 * MAXHP, MAXHP), 2,
		"66% HP -> Phase 2 (at the threshold)")


func test_phase_for_34_percent_is_two() -> void:
	assert_eq(WardenPhases.phase_for_hp(0.34 * MAXHP, MAXHP), 2,
		"34% HP -> Phase 2 (above the 33% line)")


func test_phase_for_33_percent_is_three() -> void:
	assert_eq(WardenPhases.phase_for_hp(0.33 * MAXHP, MAXHP), 3,
		"33% HP -> Phase 3 (at the threshold)")


func test_phase_for_1_percent_is_three() -> void:
	assert_eq(WardenPhases.phase_for_hp(0.01 * MAXHP, MAXHP), 3,
		"1% HP -> Phase 3")


func test_phase_for_zero_hp_is_three() -> void:
	assert_eq(WardenPhases.phase_for_hp(0.0, MAXHP), 3,
		"0% HP -> Phase 3 (final phase before death)")


func test_phase_for_zero_max_defaults_to_one() -> void:
	# Guard: a non-positive max must not divide by zero; default to Phase 1.
	assert_eq(WardenPhases.phase_for_hp(0.0, 0.0), 1,
		"zero max HP -> Phase 1 (no division by zero)")


# --- armor_for_phase: P1 Fire, P2 Ice, P3 Electricity (DD-010 + DD-006) ------

func test_armor_phase1_is_fire() -> void:
	assert_eq(WardenPhases.armor_for_phase(1), FIRE,
		"Phase 1 armor is Fire")


func test_armor_phase2_is_ice() -> void:
	assert_eq(WardenPhases.armor_for_phase(2), ICE,
		"Phase 2 armor is Ice")


func test_armor_phase3_is_electricity() -> void:
	assert_eq(WardenPhases.armor_for_phase(3), ELEC,
		"Phase 3 armor is Electricity")


# --- weakness_for_phase: the element each armor is WEAK to (DD-006 counter) ---

func test_weakness_phase1_is_electricity() -> void:
	assert_eq(WardenPhases.weakness_for_phase(1), ELEC,
		"Phase 1 (Fire armor) is weak to Electricity")


func test_weakness_phase2_is_fire() -> void:
	assert_eq(WardenPhases.weakness_for_phase(2), FIRE,
		"Phase 2 (Ice armor) is weak to Fire")


func test_weakness_phase3_is_ice() -> void:
	assert_eq(WardenPhases.weakness_for_phase(3), ICE,
		"Phase 3 (Electric armor) is weak to Ice")


# --- pattern_for_phase: AIMED / FAN / SWEEP ----------------------------------

func test_pattern_phase1_is_aimed() -> void:
	assert_eq(WardenPhases.pattern_for_phase(1), WardenPhases.Pattern.AIMED,
		"Phase 1 pattern is the heavy aimed shot")


func test_pattern_phase2_is_fan() -> void:
	assert_eq(WardenPhases.pattern_for_phase(2), WardenPhases.Pattern.FAN,
		"Phase 2 pattern is the 3-projectile fan")


func test_pattern_phase3_is_sweep() -> void:
	assert_eq(WardenPhases.pattern_for_phase(3), WardenPhases.Pattern.SWEEP,
		"Phase 3 pattern is the faster sweep")


# --- ElementMatchup weakness per phase armor (DD-010 x1.5 weak) ---------------

func test_matchup_electricity_into_phase1_armor_is_weak() -> void:
	var armor := WardenPhases.armor_for_phase(1)   # Fire
	assert_eq(ElementMatchup.multiplier(ELEC, armor), 1.5,
		"P1 Fire armor takes x1.5 from Electricity")


func test_matchup_fire_into_phase2_armor_is_weak() -> void:
	var armor := WardenPhases.armor_for_phase(2)   # Ice
	assert_eq(ElementMatchup.multiplier(FIRE, armor), 1.5,
		"P2 Ice armor takes x1.5 from Fire")


func test_matchup_ice_into_phase3_armor_is_weak() -> void:
	var armor := WardenPhases.armor_for_phase(3)   # Electricity
	assert_eq(ElementMatchup.multiplier(ICE, armor), 1.5,
		"P3 Electric armor takes x1.5 from Ice")


# --- fan_directions: count, symmetry, angles, normalization ------------------

func test_fan_returns_requested_count() -> void:
	var dirs := WardenPhases.fan_directions(Vector2.RIGHT, 3, 0.7)
	assert_eq(dirs.size(), 3,
		"a fan of 3 returns exactly 3 directions")


func test_fan_directions_are_normalized() -> void:
	var dirs := WardenPhases.fan_directions(Vector2(3, 4), 5, 1.0)  # un-normalized aim
	for d in dirs:
		assert_almost_eq(d.length(), 1.0, 0.0001,
			"every fan direction is a unit vector")


func test_fan_is_symmetric_around_aim() -> void:
	# Aim straight up; a symmetric fan's average direction equals the aim.
	var aim := Vector2.UP
	var dirs := WardenPhases.fan_directions(aim, 3, 0.6)
	var sum := Vector2.ZERO
	for d in dirs:
		sum += d
	var avg := sum.normalized()
	assert_almost_eq(avg.x, aim.x, 0.0001, "symmetric fan averages to the aim (x)")
	assert_almost_eq(avg.y, aim.y, 0.0001, "symmetric fan averages to the aim (y)")


func test_fan_outermost_shots_match_half_spread() -> void:
	# The two outer shots sit at -spread/2 and +spread/2 from the aim.
	var aim := Vector2.RIGHT
	var spread := 0.8
	var dirs := WardenPhases.fan_directions(aim, 3, spread)
	var first_angle := aim.angle_to(dirs[0])
	var last_angle := aim.angle_to(dirs[dirs.size() - 1])
	assert_almost_eq(first_angle, -spread * 0.5, 0.0001,
		"first shot is at -spread/2 from aim")
	assert_almost_eq(last_angle, spread * 0.5, 0.0001,
		"last shot is at +spread/2 from aim")


func test_fan_middle_shot_aligns_with_aim() -> void:
	# An odd-count fan has a center shot straight along the aim.
	var aim := Vector2.RIGHT
	var dirs := WardenPhases.fan_directions(aim, 3, 0.8)
	var mid: Vector2 = dirs[1]
	assert_almost_eq(aim.angle_to(mid), 0.0, 0.0001,
		"the center shot of a 3-fan is aligned with the aim")


func test_fan_single_shot_follows_aim() -> void:
	var aim := Vector2.UP
	var dirs := WardenPhases.fan_directions(aim, 1, 0.8)
	assert_eq(dirs.size(), 1, "a single-shot fan returns one direction")
	assert_almost_eq(aim.angle_to(dirs[0]), 0.0, 0.0001,
		"a single shot fires straight along the aim")


func test_fan_zero_count_returns_empty() -> void:
	var dirs := WardenPhases.fan_directions(Vector2.RIGHT, 0, 0.8)
	assert_eq(dirs.size(), 0, "a fan of 0 returns no directions")


func test_fan_zero_aim_defaults_to_right() -> void:
	# A zero aim must not NaN; it defaults to RIGHT.
	var dirs := WardenPhases.fan_directions(Vector2.ZERO, 1, 0.0)
	assert_almost_eq(dirs[0].x, 1.0, 0.0001, "zero aim defaults to RIGHT (x)")
	assert_almost_eq(dirs[0].y, 0.0, 0.0001, "zero aim defaults to RIGHT (y)")
