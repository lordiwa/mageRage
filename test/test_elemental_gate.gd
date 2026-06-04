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


## World-space vertical span [top_y, bottom_y] of the gate's Blocker collision shape.
func _blocker_world_span(gate: ElementalGate) -> Array:
	var shape_node := gate.get_node_or_null("Blocker/Col") as CollisionShape2D
	assert_not_null(shape_node, "the gate has a Blocker collision shape")
	var rect := shape_node.shape as RectangleShape2D
	assert_not_null(rect, "the Blocker uses a RectangleShape2D")
	var center_y := shape_node.global_position.y
	var half := rect.size.y * 0.5
	return [center_y - half, center_y + half]


func test_sealed_blocker_spans_the_full_corridor_height() -> void:
	# REGRESSION GUARD (review HIGH): a flight-capable hero must NOT be able to fly
	# over/under the sealed gate. The sector corridor runs from the ceiling bottom
	# (world y = -288) to the floor top (world y = 328) — ~616px. Placed at the
	# sector's gate origin (world y = 228), the Blocker must cover that corridor
	# leaving only a tiny residual gap (< 60px; the player capsule is ~40px tall) so
	# flight cannot slip past while the gate is sealed.
	const CEIL_BOTTOM := -288.0
	const FLOOR_TOP := 328.0
	const MAX_GAP := 60.0
	var gate := _make_gate(SpellData.Element.ICE)
	gate.global_position = Vector2(1300, 228)  # match the sector_01 placement
	await get_tree().process_frame
	var span: Array = _blocker_world_span(gate)
	var top_y: float = span[0]
	var bottom_y: float = span[1]
	# The clear gaps above the blocker and below it must each be smaller than the
	# player's height so a flying hero cannot thread either gap.
	var gap_above: float = top_y - CEIL_BOTTOM
	var gap_below: float = FLOOR_TOP - bottom_y
	assert_lt(gap_above, MAX_GAP,
		"the sealed gate leaves < %dpx clear above it (flight can't fly over)" % int(MAX_GAP))
	assert_lt(gap_below, MAX_GAP,
		"the sealed gate leaves < %dpx clear below it (flight can't slip under)" % int(MAX_GAP))


func test_hitbox_stays_strikable_at_player_height() -> void:
	# The taller blocker must not move the Hitbox out of the projectile's path: the
	# Hitbox still straddles player height (around the gate origin) so an ice shot
	# fired at the hero's level strikes it.
	var gate := _make_gate(SpellData.Element.ICE)
	gate.global_position = Vector2(1300, 228)
	await get_tree().process_frame
	var hit := gate.get_node_or_null("Hitbox/Col") as CollisionShape2D
	assert_not_null(hit, "the Hitbox has a collision shape")
	var rect := hit.shape as RectangleShape2D
	assert_not_null(rect, "the Hitbox uses a RectangleShape2D")
	var center_y := hit.global_position.y
	var half := rect.size.y * 0.5
	# Player spawns/flies around world y ~288 (spawn) up through the corridor; the
	# Hitbox must overlap that band, i.e. extend below the gate origin toward the floor.
	assert_gt(center_y + half, 300.0,
		"the Hitbox reaches down to ~player height so a level shot can strike it")


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
