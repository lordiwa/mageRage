## TASK-018 unit tests for ChargerAi pure decision helpers (no rendered scene).
##
## The Charger FSM (Patrol -> Chase -> WindUp -> Charge -> Recovery) routes every
## transition through these static helpers so the thresholds are fair/deterministic
## (DD-001 — the player can always understand and dodge the charge) and can never
## drift. Covered: the charge-phase elapsed gates (wind-up -> charge, charge ->
## recovery, recovery -> chase), the EXPOSED/vulnerable predicate + its bonus-damage
## multiplier, and the locked horizontal lunge direction (sign toward the player).
extends GutTest


# --- Charge-phase elapsed gates (reuse-friendly >= timing, like DroneAi) ------

func test_windup_not_elapsed_mid_telegraph() -> void:
	# Reuses DroneAi.telegraph_elapsed semantics: not done partway through.
	assert_false(ChargerAi.windup_elapsed(0.2, 0.5),
		"the lunge does not fire partway through the wind-up telegraph")


func test_windup_elapsed_at_end() -> void:
	assert_true(ChargerAi.windup_elapsed(0.5, 0.5),
		"the lunge fires once the full wind-up has elapsed (>=)")


func test_charge_not_elapsed_mid_lunge() -> void:
	assert_false(ChargerAi.charge_elapsed(0.15, 0.35),
		"the lunge is still going partway through its fixed duration")


func test_charge_elapsed_at_end() -> void:
	assert_true(ChargerAi.charge_elapsed(0.35, 0.35),
		"the lunge ends (-> Recovery) once its fixed duration has elapsed (>=)")


func test_recovery_not_elapsed_mid_stagger() -> void:
	assert_false(ChargerAi.recovery_elapsed(0.3, 0.7),
		"the stagger/recovery window has not finished partway through")


func test_recovery_elapsed_at_end() -> void:
	assert_true(ChargerAi.recovery_elapsed(0.7, 0.7),
		"recovery ends (-> Chase) once the stagger window has elapsed (>=)")


# --- EXPOSED / extra-vulnerable predicate ------------------------------------
# The core is exposed during the RECOVERY phase (read-and-punish payoff). The
# phase is identified by the active state node's name (lower-cased), so the
# predicate is a pure string check that the live FSM and tests share.

func test_exposed_true_during_recovery() -> void:
	assert_true(ChargerAi.is_exposed_phase("ChargerRecoveryState"),
		"the Charger's core is EXPOSED during the recovery/stagger window")


func test_exposed_false_during_patrol() -> void:
	assert_false(ChargerAi.is_exposed_phase("ChargerPatrolState"),
		"the Charger is NOT extra-vulnerable while patrolling")


func test_exposed_false_during_chase() -> void:
	assert_false(ChargerAi.is_exposed_phase("ChargerChaseState"),
		"the Charger is NOT extra-vulnerable while chasing")


func test_exposed_false_during_windup() -> void:
	assert_false(ChargerAi.is_exposed_phase("ChargerWindUpState"),
		"the Charger is NOT extra-vulnerable during the wind-up telegraph")


func test_exposed_predicate_is_case_insensitive() -> void:
	# The FSM stores state names lower-cased; the predicate must agree.
	assert_true(ChargerAi.is_exposed_phase("chargerrecoverystate"),
		"the exposed predicate matches the lower-cased state name too")


# --- Exposed bonus-damage multiplier -----------------------------------------

func test_exposed_multiplier_is_bonus_when_exposed() -> void:
	assert_gt(ChargerAi.exposed_multiplier(true), 1.0,
		"an exposed Charger takes BONUS damage (multiplier > 1.0)")


func test_exposed_multiplier_is_one_when_not_exposed() -> void:
	assert_almost_eq(ChargerAi.exposed_multiplier(false), 1.0, 0.0001,
		"a guarded (non-exposed) Charger takes normal damage (x1.0)")


# --- Locked horizontal lunge direction (sign toward the player) --------------
# The lunge is a HORIZONTAL ground charge: only the x sign matters, locked at
# wind-up start so it cannot re-home mid-charge (fair, dodgeable).

func test_lunge_sign_points_right_when_player_is_right() -> void:
	assert_eq(ChargerAi.lunge_sign(Vector2(100, 0), Vector2(300, 50)), 1.0,
		"player to the right -> lunge sign is +1 (charge right)")


func test_lunge_sign_points_left_when_player_is_left() -> void:
	assert_eq(ChargerAi.lunge_sign(Vector2(300, 0), Vector2(100, -50)), -1.0,
		"player to the left -> lunge sign is -1 (charge left)")


func test_lunge_sign_ignores_vertical() -> void:
	# A player directly above/below (same x) must not yield a vertical lunge; the
	# charge is horizontal, so default to a deterministic +1 (never zero/NaN).
	assert_eq(ChargerAi.lunge_sign(Vector2(100, 0), Vector2(100, 400)), 1.0,
		"a purely vertical offset still yields a horizontal lunge sign (default +1)")
