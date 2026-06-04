## TASK-015 unit tests for the player game HUD pure logic (no rendered scene).
##
## The PlayerHUD is decoupled like boss_hud: it polls the player accessors and
## listens to MagicManager signals. Its readability math is pulled out into pure
## STATIC helpers so they unit-test headless without instancing the CanvasLayer:
##  - fill_fraction(current, max): the bar-fill ratio (clamped 0..1, zero-max safe)
##    shared by the HP and mana bars (mirrors boss_hud's frac math);
##  - element_color(element): the loadout swatch tint, sourced from the established
##    element color language (ProjectileStyle, the single source of truth) so the
##    HUD, projectile and impact all speak one language;
##  - element_label(element): FIRE/ICE/ELECTRICITY/ANTIMATTER, safe default "—";
##  - is_low_mana(fraction): the low-mana threshold predicate driving the warning
##    tint/pulse.
extends GutTest


# --- fill_fraction: HP + mana bar ratio, clamps, zero-max safe ----------------

func test_fill_fraction_half() -> void:
	assert_almost_eq(PlayerHUD.fill_fraction(50.0, 100.0), 0.5, 0.0001,
		"half-full HP/mana yields a 0.5 fill fraction")


func test_fill_fraction_full() -> void:
	assert_almost_eq(PlayerHUD.fill_fraction(100.0, 100.0), 1.0, 0.0001,
		"a full bar yields fraction 1.0")


func test_fill_fraction_empty() -> void:
	assert_almost_eq(PlayerHUD.fill_fraction(0.0, 100.0), 0.0, 0.0001,
		"an empty bar yields fraction 0.0")


func test_fill_fraction_clamps_above_one() -> void:
	assert_almost_eq(PlayerHUD.fill_fraction(150.0, 100.0), 1.0, 0.0001,
		"current above max clamps the fraction to 1.0 (no overflow bar)")


func test_fill_fraction_clamps_below_zero() -> void:
	assert_almost_eq(PlayerHUD.fill_fraction(-20.0, 100.0), 0.0, 0.0001,
		"negative current clamps the fraction to 0.0")


func test_fill_fraction_zero_max_is_safe() -> void:
	assert_eq(PlayerHUD.fill_fraction(50.0, 0.0), 0.0,
		"a zero max must not divide-by-zero; the fraction is 0.0")


func test_fill_fraction_negative_max_is_safe() -> void:
	assert_eq(PlayerHUD.fill_fraction(50.0, -10.0), 0.0,
		"a negative max is treated as empty (0.0), never a garbage ratio")


# --- element_color: loadout swatch tint (element color language) --------------

func test_element_color_matches_color_language_source_of_truth() -> void:
	# The loadout swatch must reuse the established element color language
	# (ProjectileStyle), not invent new values.
	assert_eq(PlayerHUD.element_color(SpellData.Element.FIRE),
		ProjectileStyle.FIRE_COLOR, "Fire swatch uses the shared Fire tint")
	assert_eq(PlayerHUD.element_color(SpellData.Element.ICE),
		ProjectileStyle.ICE_COLOR, "Ice swatch uses the shared Ice tint")
	assert_eq(PlayerHUD.element_color(SpellData.Element.ELECTRICITY),
		ProjectileStyle.ELECTRICITY_COLOR, "Electricity swatch uses the shared tint")
	assert_eq(PlayerHUD.element_color(SpellData.Element.ANTIMATTER),
		ProjectileStyle.ANTIMATTER_COLOR, "Antimatter swatch uses the shared tint")


func test_element_color_out_of_range_is_safe_default() -> void:
	assert_eq(PlayerHUD.element_color(-1), ProjectileStyle.DEFAULT_COLOR,
		"an empty/unknown slot uses the safe default color")


# --- element_label: readable element name + safe default ----------------------

func test_element_label_per_element() -> void:
	assert_eq(PlayerHUD.element_label(SpellData.Element.FIRE), "FIRE")
	assert_eq(PlayerHUD.element_label(SpellData.Element.ICE), "ICE")
	assert_eq(PlayerHUD.element_label(SpellData.Element.ELECTRICITY), "ELECTRICITY")
	assert_eq(PlayerHUD.element_label(SpellData.Element.ANTIMATTER), "ANTIMATTER")


func test_element_label_empty_slot_default() -> void:
	assert_eq(PlayerHUD.element_label(-1), "—",
		"an empty loadout slot shows the em-dash placeholder")


# --- is_low_mana: low-mana warning threshold ---------------------------------

func test_is_low_mana_true_below_threshold() -> void:
	assert_true(PlayerHUD.is_low_mana(0.10),
		"a mana fraction below the threshold is the low-mana state")


func test_is_low_mana_false_above_threshold() -> void:
	assert_false(PlayerHUD.is_low_mana(0.80),
		"a healthy mana fraction is not the low-mana state")


func test_is_low_mana_threshold_boundary() -> void:
	# At or above the threshold is NOT low; strictly below is low.
	assert_false(PlayerHUD.is_low_mana(PlayerHUD.LOW_MANA_THRESHOLD),
		"exactly at the threshold is not yet the low-mana state")
	assert_true(PlayerHUD.is_low_mana(PlayerHUD.LOW_MANA_THRESHOLD - 0.01),
		"just below the threshold is the low-mana state")
