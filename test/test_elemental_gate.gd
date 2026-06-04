## TASK-027 unit tests for the reusable elemental-on-environment gate
## (scenes/elemental_gate.tscn + scripts/levels/elemental_gate.gd, ElementalGate).
##
## DD-011 (gate elemental-entorno): a sealed route that opens ONLY when the player
## applies the CORRECT element to an environment object (freeze / burn / energize).
## Wrong element does nothing; correct element OPENS the route PERSISTENTLY. The
## gate is color-coded per DD-003 (Fire=red, Ice=blue, Electricity=yellow).
##
## These tests drive the gate via its clean API (`apply_element`) so they are
## deterministic and need no live projectile physics — no `await physics_frame`,
## so they cannot poison later input-edge tests (known GUT cross-script flake).
extends GutTest

const GATE := preload("res://scenes/elemental_gate.tscn")


## Instance a gate, parent it (auto-freed), and configure which element opens it.
func _make_gate(required: int) -> ElementalGate:
	var gate := GATE.instantiate() as ElementalGate
	gate.required_element = required
	add_child_autofree(gate)
	return gate


func test_gate_is_closed_by_default() -> void:
	var gate := _make_gate(SpellData.Element.ICE)
	assert_false(gate.is_open(), "a fresh gate is sealed/closed by default")


func test_blocking_collision_is_active_while_closed() -> void:
	# Criterion 4: the blocking collision exists and is enabled while sealed, so the
	# player physically cannot pass.
	var gate := _make_gate(SpellData.Element.ICE)
	assert_true(gate.is_blocking(), "a closed gate blocks the route (collision active)")


func test_wrong_element_leaves_gate_sealed() -> void:
	# Criterion 3: WRONG element does nothing — the route stays sealed.
	var gate := _make_gate(SpellData.Element.ICE)
	gate.apply_element(SpellData.Element.FIRE)
	assert_false(gate.is_open(), "the wrong element (Fire) does not open an Ice gate")
	gate.apply_element(SpellData.Element.ELECTRICITY)
	assert_false(gate.is_open(), "the wrong element (Electricity) does not open an Ice gate")
	assert_true(gate.is_blocking(), "after wrong elements the gate still blocks the route")


func test_correct_element_opens_the_gate() -> void:
	# Criterion 3: CORRECT element opens the route.
	var gate := _make_gate(SpellData.Element.ICE)
	gate.apply_element(SpellData.Element.ICE)
	assert_true(gate.is_open(), "the correct element (Ice) opens the gate")


func test_opening_removes_the_blocking_collision_so_player_can_pass() -> void:
	# Criterion 4: once open the blocking collision is gone/disabled -> passage.
	var gate := _make_gate(SpellData.Element.ICE)
	assert_true(gate.is_blocking(), "blocks before opening")
	gate.apply_element(SpellData.Element.ICE)
	assert_false(gate.is_blocking(), "the opened gate no longer blocks the route")


func test_open_state_persists_across_further_hits() -> void:
	# Criterion 3: the opened state PERSISTS — a later wrong element cannot re-seal it.
	var gate := _make_gate(SpellData.Element.ICE)
	gate.apply_element(SpellData.Element.ICE)
	assert_true(gate.is_open(), "opened by the correct element")
	gate.apply_element(SpellData.Element.FIRE)
	gate.apply_element(SpellData.Element.ELECTRICITY)
	assert_true(gate.is_open(), "the open state persists; wrong elements cannot re-seal it")
	assert_false(gate.is_blocking(), "still passable after later wrong hits")


func test_gate_emits_opened_signal_once() -> void:
	# Decoupling (godot-game-dev §6 signals): the gate announces opening exactly once,
	# so level logic / VFX can react without polling.
	var gate := _make_gate(SpellData.Element.FIRE)
	watch_signals(gate)
	gate.apply_element(SpellData.Element.FIRE)
	assert_signal_emitted(gate, "opened", "opening emits the 'opened' signal")
	# A redundant correct hit on an already-open gate does not re-emit.
	gate.apply_element(SpellData.Element.FIRE)
	assert_signal_emit_count(gate, "opened", 1, "the opened signal fires exactly once")


func test_gate_is_color_coded_per_dd003_fire_red() -> void:
	# DD-003: Fire = red. The gate's visual tint reads warm/red (red channel dominant).
	var gate := _make_gate(SpellData.Element.FIRE)
	var col := gate.gate_color()
	assert_gt(col.r, col.b, "a Fire gate reads red (red channel dominates blue)")
	assert_gt(col.r, col.g, "a Fire gate reads red (red channel dominates green)")


func test_gate_is_color_coded_per_dd003_ice_blue() -> void:
	# DD-003: Ice = blue. Blue channel dominant.
	var gate := _make_gate(SpellData.Element.ICE)
	var col := gate.gate_color()
	assert_gt(col.b, col.r, "an Ice gate reads blue (blue channel dominates red)")


func test_gate_is_color_coded_per_dd003_electricity_yellow() -> void:
	# DD-003: Electricity = yellow (high red+green, low blue).
	var gate := _make_gate(SpellData.Element.ELECTRICITY)
	var col := gate.gate_color()
	assert_gt(col.r, col.b, "an Electricity gate reads yellow (red+green high, blue low)")
	assert_gt(col.g, col.b, "an Electricity gate reads yellow (green dominates blue)")


func test_projectile_hit_path_routes_to_apply_element() -> void:
	# The in-game application: a player projectile that strikes the gate calls
	# `apply_elemental_hit(element, ...)` (the same method drones expose), which the
	# gate forwards to `apply_element`. Correct element via that path opens the gate.
	var gate := _make_gate(SpellData.Element.ICE)
	assert_true(gate.has_method("apply_elemental_hit"),
		"the gate exposes apply_elemental_hit so the existing projectile hits it")
	# Wrong element via the projectile path: still sealed.
	gate.apply_elemental_hit(SpellData.Element.FIRE, 10.0, false, Vector2.RIGHT)
	assert_false(gate.is_open(), "wrong element via the projectile path keeps it sealed")
	# Correct element via the projectile path: opens.
	gate.apply_elemental_hit(SpellData.Element.ICE, 10.0, false, Vector2.RIGHT)
	assert_true(gate.is_open(), "correct element via the projectile path opens the gate")


func test_hittable_area_is_on_enemies_layer_so_player_magic_reaches_it() -> void:
	# Reuse the existing projectile (masks Enemies layer 3 only): the gate's hittable
	# Area2D must sit on layer 3 so a player shot's area/body callback finds it.
	var gate := _make_gate(SpellData.Element.ICE)
	var hit := gate.get_node_or_null("Hitbox") as Area2D
	assert_not_null(hit, "the gate has a Hitbox Area2D the projectile can strike")
	assert_true(hit.get_collision_layer_value(3),
		"the Hitbox is on the Enemies layer (3) so the player projectile detects it")


func test_interaction_label_describes_freeze_burn_energize() -> void:
	# Criterion 2: configurable for which interaction it represents. The default
	# interaction tracks the required element's fiction (Ice->freeze etc.).
	var ice := _make_gate(SpellData.Element.ICE)
	assert_eq(ice.interaction, ElementalGate.Interaction.FREEZE,
		"an Ice gate defaults to the FREEZE interaction")
	var fire := _make_gate(SpellData.Element.FIRE)
	assert_eq(fire.interaction, ElementalGate.Interaction.BURN,
		"a Fire gate defaults to the BURN interaction")
	var elec := _make_gate(SpellData.Element.ELECTRICITY)
	assert_eq(elec.interaction, ElementalGate.Interaction.ENERGIZE,
		"an Electricity gate defaults to the ENERGIZE interaction")
