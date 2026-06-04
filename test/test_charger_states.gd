## TASK-018 unit tests for the Charger FSM STATE transitions (live state nodes).
##
## The pure timing/sign math is in test_charger_ai.gd; here we build each state node,
## point its `player` at a bare Charger with a fake target, drive physics_update, and
## assert the requested transition (watching the EstadoBase.transition_requested
## signal). This proves the wiring: Patrol stays put when not aggro / -> Chase when
## aggro; Chase -> WindUp in range; WindUp -> Charge after the telegraph; Charge ->
## Recovery after the lunge duration; Recovery -> Chase after the stagger window.
extends GutTest

const FIRE := SpellData.Element.FIRE


# Build a bare Charger (Health + Sprite) with a settable target. No StateMachine —
# we instance individual state nodes and call their physics_update directly.
func _make_charger() -> Charger:
	var charger := Charger.new()
	charger.armor_type = FIRE
	var health := Health.new()
	health.name = "Health"
	health.max_health = 80.0
	charger.add_child(health)
	var sprite := ColorRect.new()
	sprite.name = "Sprite"
	charger.add_child(sprite)
	add_child_autofree(charger)
	return charger


func _set_target(charger: Charger, pos: Vector2) -> void:
	var t := Node2D.new()
	t.global_position = pos
	add_child_autofree(t)
	charger.target = t


# Build a state node of `script_path`, wire it to the charger, register it under a
# name (so transition routing can find it), and return it.
func _make_state(script_path: String, charger: Charger, node_name: String) -> Node:
	var script: GDScript = load(script_path)
	var state: Node = script.new()
	state.name = node_name
	state.player = charger
	add_child_autofree(state)
	return state


# --- PATROL ------------------------------------------------------------------

func test_patrol_stays_when_player_far() -> void:
	var charger := _make_charger()
	_set_target(charger, Vector2(5000, 0))
	var patrol := _make_state(
		"res://scripts/enemies/states/charger_patrol_state.gd", charger, "ChargerPatrolState")
	watch_signals(patrol)
	patrol.physics_update(0.016)
	assert_signal_not_emitted(patrol, "transition_requested",
		"a distant player keeps the Charger patrolling (no transition)")


func test_patrol_chases_when_player_in_aggro() -> void:
	var charger := _make_charger()
	_set_target(charger, Vector2(60, 0))
	var patrol := _make_state(
		"res://scripts/enemies/states/charger_patrol_state.gd", charger, "ChargerPatrolState")
	watch_signals(patrol)
	patrol.physics_update(0.016)
	assert_signal_emitted_with_parameters(patrol, "transition_requested",
		[patrol, "ChargerChaseState"],
		"a player in aggro range transitions Patrol -> Chase")


# --- CHASE -------------------------------------------------------------------

func test_chase_returns_to_patrol_when_player_leaves() -> void:
	var charger := _make_charger()
	_set_target(charger, Vector2(5000, 0))
	var chase := _make_state(
		"res://scripts/enemies/states/charger_chase_state.gd", charger, "ChargerChaseState")
	watch_signals(chase)
	chase.physics_update(0.016)
	assert_signal_emitted_with_parameters(chase, "transition_requested",
		[chase, "ChargerPatrolState"],
		"the player leaving aggro range drops Chase -> Patrol")


func test_chase_winds_up_when_player_in_attack_range() -> void:
	var charger := _make_charger()
	_set_target(charger, Vector2(40, 0))   # close enough to commit to the charge
	var chase := _make_state(
		"res://scripts/enemies/states/charger_chase_state.gd", charger, "ChargerChaseState")
	watch_signals(chase)
	chase.physics_update(0.016)
	assert_signal_emitted_with_parameters(chase, "transition_requested",
		[chase, "ChargerWindUpState"],
		"a player in attack range commits the Charger to the wind-up telegraph")


# --- WIND-UP -----------------------------------------------------------------

func test_windup_holds_then_charges_after_telegraph() -> void:
	var charger := _make_charger()
	_set_target(charger, Vector2(40, 0))
	var windup := _make_state(
		"res://scripts/enemies/states/charger_windup_state.gd", charger, "ChargerWindUpState")
	windup.enter()
	watch_signals(windup)
	# Partway through the wind-up: no charge yet (mandatory telegraph, DD-001).
	windup.physics_update(0.05)
	assert_signal_not_emitted(windup, "transition_requested",
		"the Charger does NOT lunge partway through the wind-up (fair telegraph)")
	# Advance well past the full wind-up.
	windup.physics_update(5.0)
	assert_signal_emitted_with_parameters(windup, "transition_requested",
		[windup, "ChargerChargeState"],
		"once the wind-up telegraph elapses the Charger transitions to Charge")


func test_windup_locks_lunge_direction_on_enter() -> void:
	var charger := _make_charger()
	charger.global_position = Vector2(100, 0)
	_set_target(charger, Vector2(400, 0))   # player to the RIGHT at wind-up start
	var windup := _make_state(
		"res://scripts/enemies/states/charger_windup_state.gd", charger, "ChargerWindUpState")
	windup.enter()   # locks the lunge toward the player
	assert_eq(charger.lunge_direction_sign(), 1.0,
		"entering the wind-up LOCKS the lunge toward the player (right -> +1)")


# --- CHARGE ------------------------------------------------------------------

func test_charge_recovers_after_lunge_duration() -> void:
	var charger := _make_charger()
	_set_target(charger, Vector2(40, 0))
	charger.lock_lunge_toward(Vector2(400, 0))
	var charge := _make_state(
		"res://scripts/enemies/states/charger_charge_state.gd", charger, "ChargerChargeState")
	charge.enter()
	watch_signals(charge)
	# Mid-lunge: still charging.
	charge.physics_update(0.05)
	assert_signal_not_emitted(charge, "transition_requested",
		"the Charger is still lunging partway through the fixed charge duration")
	# Past the full lunge duration -> Recovery.
	charge.physics_update(5.0)
	assert_signal_emitted_with_parameters(charge, "transition_requested",
		[charge, "ChargerRecoveryState"],
		"after the fixed lunge duration the Charger enters Recovery (exposed)")


# --- RECOVERY ----------------------------------------------------------------

func test_recovery_returns_to_chase_after_stagger() -> void:
	var charger := _make_charger()
	_set_target(charger, Vector2(40, 0))
	var recovery := _make_state(
		"res://scripts/enemies/states/charger_recovery_state.gd", charger, "ChargerRecoveryState")
	recovery.enter()
	watch_signals(recovery)
	# Mid-stagger: cannot act yet (exposed window still open).
	recovery.physics_update(0.05)
	assert_signal_not_emitted(recovery, "transition_requested",
		"during recovery the Charger cannot act (exposed/staggered window)")
	# Past the stagger window -> back to Chase.
	recovery.physics_update(5.0)
	assert_signal_emitted_with_parameters(recovery, "transition_requested",
		[recovery, "ChargerChaseState"],
		"after the stagger window the Charger recovers back to Chase")
