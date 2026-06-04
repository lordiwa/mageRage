## TASK-017 unit tests for the EmpireDrone DEATH effect wiring (live node + Health).
##
## On reaching 0 HP the drone plays an element-tinted dissolve/burst BEFORE removing
## itself (deferred free), wired to the Health `died` signal. The death path must run
## EXACTLY once (a `_dying` guard) even under overkill / a second `died` emission, so
## the effect never plays twice and the drone never double-frees. Non-lethal hits do
## NOT trigger the death effect, and matchup damage is unchanged.
##
## To stay headless + deterministic we inject a scene-free fake burst (records the
## element passed to burst()) as the drone's death_effect_scene, mirroring the
## muzzle-flash seam in test_muzzle_flash.gd. The actual free is deferred, so we
## assert the death PATH ran (guard flipped, burst spawned) rather than waiting on
## queue_free.
extends GutTest

const FIRE := SpellData.Element.FIRE
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


# Build a drone with a Health child + a ColorRect Sprite in code (no .tscn), so the
# death effect is exercised headlessly. A test-owned parent scopes spawned bursts.
var parent: Node2D


func before_each() -> void:
	parent = Node2D.new()
	add_child_autofree(parent)


func _make_drone(armor: int = FIRE, maxhp := 60.0) -> EmpireDrone:
	var drone := EmpireDrone.new()
	drone.armor_type = armor
	var health := Health.new()
	health.name = "Health"
	health.max_health = maxhp
	drone.add_child(health)
	var sprite := ColorRect.new()
	sprite.name = "Sprite"
	drone.add_child(sprite)
	var label := Label.new()
	label.name = "Label"
	drone.add_child(label)
	drone.death_effect_scene = _fake_burst_scene()
	# Spawn bursts into a test-owned parent (not the global tree) so they auto-free.
	drone.death_burst_parent = parent
	add_child_autofree(drone)        # _ready wires Health.died -> death path
	return drone


func _last_burst() -> FakeBurst:
	var found: FakeBurst = null
	for child in parent.get_children():
		if child is FakeBurst:
			found = child
	return found


# --- Wired to Health.died: a lethal hit plays the death effect ----------------

func test_lethal_hit_triggers_death_effect() -> void:
	var drone := _make_drone(FIRE, 40.0)
	# Ice is neutral vs Fire armor (x1.0): 100 overkills 40 -> 0 HP -> died.
	drone.apply_elemental_hit(ICE, 100.0, false)
	assert_true(drone.is_dying(), "reaching 0 HP starts the drone death (dissolve) path")
	assert_not_null(_last_burst(), "the death effect spawns a particle burst")


func test_non_lethal_hit_does_not_trigger_death() -> void:
	var drone := _make_drone(FIRE, 100.0)
	drone.apply_elemental_hit(ICE, 20.0, false)   # 100 -> 80, survives
	assert_false(drone.is_dying(), "a non-lethal hit does not start the death effect")
	assert_null(_last_burst(), "no death burst spawns while the drone is alive")


# --- Element-tinted: the burst carries the drone's ARMOR element --------------

func test_death_burst_is_tinted_by_armor_element() -> void:
	var drone := _make_drone(ICE, 30.0)
	drone.apply_elemental_hit(FIRE, 100.0, false)   # lethal (Fire neutral vs Ice x1.0)
	var burst := _last_burst()
	assert_not_null(burst, "a death burst spawns")
	if burst != null:
		assert_eq(burst.burst_element, ICE,
			"the death burst is tinted by the drone's armor element, not the hit element")


func test_death_burst_uses_each_armor_element() -> void:
	var drone := _make_drone(ELEC, 30.0)
	drone.apply_elemental_hit(FIRE, 100.0, false)   # lethal (Fire neutral vs Elec x1.0)
	var burst := _last_burst()
	assert_not_null(burst)
	if burst != null:
		assert_eq(burst.burst_element, ELEC,
			"the death burst carries the actual armor element (Electricity)")


# --- Single-trigger at zero: overkill / re-emission plays the effect once -----

func test_death_effect_runs_exactly_once_on_overkill() -> void:
	var drone := _make_drone(FIRE, 40.0)
	drone.apply_elemental_hit(ICE, 100.0, false)   # lethal
	# A second hit after death must NOT re-run the death path or spawn a 2nd burst.
	drone.apply_elemental_hit(ICE, 100.0, false)
	var burst := _last_burst()
	assert_not_null(burst, "a burst spawned on death")
	if burst != null:
		assert_eq(burst.burst_count, 1,
			"the death burst plays exactly once even under overkill")


func test_re_emitting_died_does_not_double_run() -> void:
	var drone := _make_drone(FIRE, 40.0)
	var health := drone.get_node("Health") as Health
	drone.apply_elemental_hit(ICE, 100.0, false)   # lethal -> died -> _dying guard set
	var first := _last_burst()
	assert_not_null(first)
	# Force a second `died` emission (defensive: chain/overkill paths) -> guarded.
	health.died.emit()
	var after := _last_burst()
	if after != null:
		assert_eq(after.burst_count, 1,
			"a re-emitted `died` is ignored once the drone is already dying")


# --- The fade is PRESERVED: the per-frame tint tick no longer clobbers alpha ---
# Deterministic regression guard for the MEDIUM finding: _update_tint() (run every
# physics frame) used to rewrite the sprite color at alpha 1.0, negating the fade
# half of the dissolve. We trigger death (sets the `_dying` latch), then SIMULATE the
# dissolve tween mid-fade by hand (alpha 0.4) and tick _physics_process several times.
# If the guard works the alpha stays < 1.0; without it the tick would reset it to 1.0.
# No wall-clock await / no tween / no HitStop dependence -> zero timing flakiness.

func test_tint_tick_preserves_dissolve_alpha_while_dying() -> void:
	var drone := _make_drone(FIRE, 60.0)
	var sprite := drone.get_node("Sprite") as ColorRect
	drone.apply_elemental_hit(ICE, 1000.0, false)   # lethal -> _dying latch set
	assert_true(drone.is_dying(), "the death path has started (dissolve in progress)")
	# Stand in for the dissolve tween having faded the sprite partway.
	sprite.color.a = 0.4
	# The per-frame tint tick that used to overwrite the color at full alpha.
	for _i in range(5):
		drone._physics_process(0.016)
	assert_lt(sprite.color.a, 1.0,
		"the tint tick does NOT reset the faded alpha while dying (the fade survives)")
	assert_almost_eq(sprite.color.a, 0.4, 0.001,
		"the dissolve alpha is left exactly as the tween set it")


# --- Regression: matchup damage is unchanged by the death wiring --------------

func test_matchup_damage_still_applies_on_a_hit() -> void:
	var drone := _make_drone(FIRE, 100.0)
	# Electricity vs Fire armor is super-effective (x1.5): 20 base -> 30 damage.
	drone.apply_elemental_hit(ELEC, 20.0, false)
	var health := drone.get_node("Health") as Health
	assert_almost_eq(health.current_health, 70.0, 0.001,
		"Electricity into Fire armor still deals x1.5 (100 - 30 = 70)")
