## TASK-017 unit tests for the Warden DEATH effect — a LOUDER version of the shared
## death beat, layered on top of the existing DD-010 victory flow WITHOUT breaking it.
##
## The boss must: keep emitting `defeated` exactly once (victory flow intact); play
## the element-tinted dissolve/burst tinted by its CURRENT phase armor; and NOT
## queue_free itself (the arena's victory state may need it alive). The death effect
## runs exactly once even if `died` re-emits.
extends GutTest

const ICE := SpellData.Element.ICE
const ELEC := SpellData.Element.ELECTRICITY


# A scene-free stand-in for the death burst: records burst(element) + count.
class FakeBurst:
	extends Node2D
	var burst_element := -999
	var burst_count := 0

	func burst(element: int) -> void:
		burst_element = element
		burst_count += 1


func _fake_burst_scene() -> PackedScene:
	var ps := PackedScene.new()
	ps.pack(FakeBurst.new())
	return ps


var parent: Node2D


func before_each() -> void:
	parent = Node2D.new()
	add_child_autofree(parent)


func _make_warden(maxhp := 40.0) -> Warden:
	var boss := Warden.new()
	boss.max_health = maxhp
	var health := Health.new()
	health.name = "Health"
	health.max_health = maxhp
	boss.add_child(health)
	var sprite := ColorRect.new()
	sprite.name = "Sprite"
	boss.add_child(sprite)
	boss.death_effect_scene = _fake_burst_scene()
	boss.death_burst_parent = parent
	add_child_autofree(boss)
	var target := Node2D.new()
	target.global_position = Vector2(100, 0)
	add_child_autofree(target)
	boss.target = target
	return boss


func _last_burst() -> FakeBurst:
	var found: FakeBurst = null
	for child in parent.get_children():
		if child is FakeBurst:
			found = child
	return found


# --- Victory flow stays intact: `defeated` still fires once -------------------

func test_lethal_hit_still_emits_defeated_once() -> void:
	var boss := _make_warden(40.0)
	watch_signals(boss)
	boss.apply_elemental_hit(ICE, 100.0, false)   # lethal (Ice neutral vs Fire)
	assert_true(boss.is_defeated(), "the boss is still defeated on a lethal hit")
	assert_signal_emit_count(boss, "defeated", 1,
		"the death effect does not disturb the single `defeated` emission")


# --- The death effect plays a burst tinted by the boss's CURRENT armor --------

func test_death_burst_is_tinted_by_current_phase_armor() -> void:
	var boss := _make_warden(40.0)
	# An overkill from full HP races through every phase to the final P3, so the
	# LIVE armor at death is Electricity. The burst tints with that current armor
	# (not the hit element, not a hardcoded one) — the death reads in-phase.
	boss.apply_elemental_hit(ICE, 100.0, false)   # lethal -> phase advances to 3
	assert_eq(boss.armor_type(), ELEC, "an overkill ends in the final phase (Electricity)")
	var burst := _last_burst()
	assert_not_null(burst, "a death burst spawns when the boss dies")
	if burst != null:
		assert_eq(burst.burst_element, ELEC,
			"the boss death burst is tinted by its current (final-phase) armor")


# --- The boss is NOT removed by the death effect (victory state owns it) ------

func test_boss_does_not_queue_free_on_death() -> void:
	var boss := _make_warden(40.0)
	boss.apply_elemental_hit(ICE, 100.0, false)   # lethal
	assert_false(boss.is_queued_for_deletion(),
		"the boss must NOT free itself on death — the victory state keeps it alive")


# --- Single-trigger: a re-emitted `died` does not replay the death effect -----

func test_death_effect_runs_once_under_overkill() -> void:
	var boss := _make_warden(40.0)
	boss.apply_elemental_hit(ICE, 100.0, false)   # lethal
	boss.apply_elemental_hit(ICE, 100.0, false)   # ignored (already won)
	var burst := _last_burst()
	assert_not_null(burst)
	if burst != null:
		assert_eq(burst.burst_count, 1,
			"the boss death burst plays exactly once")


# --- The fade is PRESERVED: the per-frame tint tick no longer clobbers alpha ---
# Deterministic regression guard for the MEDIUM finding: the boss _update_tint() runs
# every physics frame and rewrote the sprite color at alpha 1.0, negating the fade.
# We defeat the boss (sets the `_won` latch), SIMULATE the dissolve tween mid-fade by
# hand (alpha 0.4), then tick _physics_process several times. With the `_won` guard the
# alpha is preserved; without it the tick would reset it to 1.0. No wall-clock await /
# no tween / no HitStop dependence -> zero timing flakiness.

func test_tint_tick_preserves_dissolve_alpha_while_defeated() -> void:
	var boss := _make_warden(40.0)
	var sprite := boss.get_node("Sprite") as ColorRect
	boss.apply_elemental_hit(ICE, 100.0, false)   # lethal -> defeated -> _won latch set
	assert_true(boss.is_defeated(), "the boss death path has started (dissolve in progress)")
	# Stand in for the dissolve tween having faded the sprite partway.
	sprite.color.a = 0.4
	# The per-frame tint tick that used to overwrite the color at full alpha.
	for _i in range(5):
		boss._physics_process(0.016)
	assert_lt(sprite.color.a, 1.0,
		"the tint tick does NOT reset the faded alpha while defeated (the fade survives)")
	assert_almost_eq(sprite.color.a, 0.4, 0.001,
		"the dissolve alpha is left exactly as the tween set it")
