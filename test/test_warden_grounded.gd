## TASK-059 tests: the Warden is a GROUNDED HEAVY TANK (gravity + horizontal-only
## pursuit), no longer a FLOATING flier.
##
## Mirrors the Charger grounded idiom (test_charger_states / charger.gd):
##   - the boss exposes a gravity_vector() (the project default down-vector) and runs
##     in MOTION_MODE_GROUNDED so move_and_slide + is_on_floor rest it on the floor;
##   - WardenChaseState applies gravity each step (gains DOWNWARD velocity over a tick)
##     so it never floats while pursuing;
##   - WardenChaseState pursues HORIZONTALLY ONLY: against a target placed directly
##     ABOVE the boss it adds NO upward/vertical pursuit component (gravity owns y);
##   - WardenPatrolState and the WardenAttackState telegraph hold also apply gravity
##     so the boss never floats while idle / winding up.
##
## State nodes are instanced standalone and driven via physics_update(delta) by hand
## (no StateMachine, no input edges) so the suite stays deterministic and cannot
## poison later input-edge tests.
extends GutTest

const FIRE := SpellData.Element.FIRE


# Build a bare Warden (Health child) with a settable target, pinned so only manual
# physics_update calls advance state (the live node's autonomous _physics_process /
# CharacterBody2D internal ticks are frozen — CI-determinism parity with the Charger
# state tests).
func _make_warden() -> Warden:
	var boss := Warden.new()
	boss.max_health = 300.0
	var health := Health.new()
	health.name = "Health"
	health.max_health = 300.0
	boss.add_child(health)
	add_child_autofree(boss)
	boss.set_physics_process(false)
	boss.set_physics_process_internal(false)
	boss.set_process(false)
	return boss


func _set_target(boss: Warden, pos: Vector2) -> void:
	var t := Node2D.new()
	t.global_position = pos
	add_child_autofree(t)
	boss.target = t


func _make_state(script_path: String, boss: Warden, node_name: String) -> Node:
	var script: GDScript = load(script_path)
	var state: Node = script.new()
	state.name = node_name
	state.player = boss
	add_child_autofree(state)
	return state


# --- GROUNDED: gravity convention reused (project default), GROUNDED motion mode ---

func test_warden_is_grounded_motion_mode() -> void:
	var boss := _make_warden()
	assert_eq(boss.motion_mode, CharacterBody2D.MOTION_MODE_GROUNDED,
		"the Warden runs GROUNDED (heavy tank), not FLOATING (no flight)")


func test_warden_exposes_project_gravity_vector() -> void:
	var boss := _make_warden()
	assert_true(boss.has_method("gravity_vector"),
		"the Warden exposes gravity_vector() for the FSM states to apply")
	# Reuse the project convention (get_gravity, like the player/charger) — a real
	# downward pull, not an invented value.
	assert_eq(boss.gravity_vector(), boss.get_gravity(),
		"gravity_vector() reuses the project gravity convention (get_gravity)")
	assert_gt(boss.gravity_vector().y, 0.0,
		"the project gravity pulls the boss DOWN (positive y)")


# --- CHASE applies gravity (gains downward velocity), never floats ----------------

func test_chase_applies_gravity_downward() -> void:
	var boss := _make_warden()
	boss.global_position = Vector2.ZERO
	_set_target(boss, Vector2(500, 0))   # to the right, in aggro range, far enough to chase
	boss.velocity = Vector2.ZERO
	var chase := _make_state(
		"res://scripts/enemies/states/warden_chase_state.gd", boss, "WardenChaseState")
	chase.physics_update(0.016)
	assert_gt(boss.velocity.y, 0.0,
		"under gravity the chasing Warden gains DOWNWARD velocity (it does not float)")


# --- CHASE is HORIZONTAL-ONLY: a target ABOVE adds NO upward pursuit --------------

func test_chase_target_above_yields_no_upward_pursuit() -> void:
	var boss := _make_warden()
	boss.global_position = Vector2.ZERO
	# Target directly ABOVE the boss (negative y). A flier would steer UP; the grounded
	# tank must NOT — gravity owns y, so velocity.y stays >= 0 (down only).
	_set_target(boss, Vector2(0, -500))
	boss.velocity = Vector2.ZERO
	var chase := _make_state(
		"res://scripts/enemies/states/warden_chase_state.gd", boss, "WardenChaseState")
	chase.physics_update(0.016)
	assert_true(boss.velocity.y >= 0.0,
		"a target ABOVE adds NO upward pursuit (velocity.y stays >= 0; horizontal-only)")


func test_chase_pursues_horizontally_toward_target() -> void:
	var boss := _make_warden()
	boss.global_position = Vector2.ZERO
	_set_target(boss, Vector2(500, -500))   # up-right: only the x sign should drive pursuit
	boss.velocity = Vector2.ZERO
	var chase := _make_state(
		"res://scripts/enemies/states/warden_chase_state.gd", boss, "WardenChaseState")
	chase.physics_update(0.016)
	assert_gt(boss.velocity.x, 0.0,
		"a target to the RIGHT drives positive horizontal pursuit")
	assert_true(boss.velocity.y >= 0.0,
		"the up component is dropped — pursuit is horizontal-only even toward an up-right target")


func test_chase_horizontal_speed_honors_ice_slow() -> void:
	var boss := _make_warden()
	boss.global_position = Vector2.ZERO
	_set_target(boss, Vector2(500, 0))
	boss.apply_elemental_hit(FIRE, 0.0, true)   # set the DD-009 slow flag (no damage)
	boss.velocity = Vector2.ZERO
	var chase := _make_state(
		"res://scripts/enemies/states/warden_chase_state.gd", boss, "WardenChaseState")
	chase.physics_update(0.016)
	# Slowed horizontal speed is half the pre-slow CHASE_SPEED (the DD-009 control window).
	var chase_speed: float = chase.get("CHASE_SPEED")
	assert_almost_eq(boss.velocity.x, chase_speed * 0.5, 0.001,
		"a slowed Warden chases at half horizontal speed (DD-009 Ice control)")


# --- PATROL applies gravity (never floats while idle) -----------------------------

func test_patrol_applies_gravity_downward() -> void:
	var boss := _make_warden()
	boss.global_position = Vector2.ZERO
	boss.spawn_position = Vector2.ZERO
	# No target in aggro -> stays patrolling and just settles under gravity.
	boss.velocity = Vector2.ZERO
	var patrol := _make_state(
		"res://scripts/enemies/states/warden_patrol_state.gd", boss, "WardenPatrolState")
	patrol.physics_update(0.016)
	assert_gt(boss.velocity.y, 0.0,
		"the idle/patrol Warden settles under gravity (gains downward velocity, never floats)")


# --- ATTACK telegraph hold applies gravity (never floats while winding up) --------

func test_attack_telegraph_hold_applies_gravity() -> void:
	var boss := _make_warden()
	boss.global_position = Vector2.ZERO
	_set_target(boss, Vector2(100, 0))
	var attack := _make_state(
		"res://scripts/enemies/states/warden_attack_state.gd", boss, "WardenAttackState")
	attack.enter()       # holds horizontally still + begins the telegraph
	boss.velocity = Vector2.ZERO
	attack.physics_update(0.016)
	assert_gt(boss.velocity.y, 0.0,
		"the Warden settles under gravity during the attack telegraph hold (never floats)")
	assert_almost_eq(boss.velocity.x, 0.0, 0.001,
		"the telegraph hold keeps the boss horizontally still (no x drift while winding up)")
