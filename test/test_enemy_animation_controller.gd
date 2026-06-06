## TASK-056 unit tests for EnemyAnimationController.select_animation() + flip_h.
##
## The selection function is PURE (no scene, no nodes): it takes the current FSM
## state name, the enemy velocity, an `attacking` one-shot flag, and a `hurt`
## one-shot flag, and returns the animation name to play. It must understand BOTH
## the drone state names (DronePatrolState / DroneChaseState / DroneAttackState)
## and the charger state names (ChargerPatrolState / ChargerChaseState /
## ChargerWindUpState / ChargerChargeState / ChargerRecoveryState), with a safe
## "idle" default for unknown / future states.
##
## Mapping (per TASK-056):
##   hurt (highest priority)                 -> "hurt"
##   attacking (drone cast one-shot)         -> "attack"
##   DronePatrolState                        -> "idle"
##   DroneChaseState                         -> "walk"
##   DroneAttackState                        -> "attack"
##   ChargerPatrolState                      -> "idle"
##   ChargerChaseState                       -> "walk"
##   ChargerWindUpState                      -> "windup"
##   ChargerChargeState                      -> "charge"
##   ChargerRecoveryState                    -> "idle"  (fallback, no recovery anim)
##   unknown                                 -> "idle"  (safe default)
##
## Also verifies the flip_h rule: facing < 0 -> flip_h true, facing >= 0 -> false
## (east frames face right natively; flip for left).
extends GutTest


func _sel(state: String, velocity: Vector2, attacking: bool, hurt: bool) -> String:
	return EnemyAnimationController.select_animation(state, velocity, attacking, hurt)


## ---- drone states -----------------------------------------------------------

func test_drone_patrol_maps_to_idle() -> void:
	assert_eq(_sel("DronePatrolState", Vector2.ZERO, false, false), "idle",
		"DronePatrolState -> idle (loop)")


func test_drone_chase_maps_to_walk() -> void:
	assert_eq(_sel("DroneChaseState", Vector2(90.0, 0.0), false, false), "walk",
		"DroneChaseState -> walk (loop)")


func test_drone_attack_state_maps_to_attack() -> void:
	assert_eq(_sel("DroneAttackState", Vector2.ZERO, false, false), "attack",
		"DroneAttackState -> attack (the cast pose)")


## ---- warden (boss) states (TASK-058) ----------------------------------------

func test_warden_patrol_maps_to_idle() -> void:
	assert_eq(_sel("WardenPatrolState", Vector2.ZERO, false, false), "idle",
		"WardenPatrolState -> idle (loop)")


func test_warden_chase_maps_to_walk() -> void:
	assert_eq(_sel("WardenChaseState", Vector2(60.0, 0.0), false, false), "walk",
		"WardenChaseState -> walk (loop)")


func test_warden_attack_state_maps_to_attack() -> void:
	assert_eq(_sel("WardenAttackState", Vector2.ZERO, false, false), "attack",
		"WardenAttackState -> attack (one-shot wind-up/fire pose)")


func test_warden_hurt_overrides_state() -> void:
	assert_eq(_sel("WardenChaseState", Vector2(60.0, 0.0), false, true), "hurt",
		"hurt overrides the warden movement state -> hurt (a landed hit is loudest)")


func test_warden_attacking_flag_overrides_movement() -> void:
	assert_eq(_sel("WardenChaseState", Vector2(60.0, 0.0), true, false), "attack",
		"the attacking one-shot flag overrides walk -> attack for the warden too")


## ---- charger states ---------------------------------------------------------

func test_charger_patrol_maps_to_idle() -> void:
	assert_eq(_sel("ChargerPatrolState", Vector2.ZERO, false, false), "idle",
		"ChargerPatrolState -> idle")


func test_charger_chase_maps_to_walk() -> void:
	assert_eq(_sel("ChargerChaseState", Vector2(110.0, 0.0), false, false), "walk",
		"ChargerChaseState -> walk")


func test_charger_windup_maps_to_windup() -> void:
	assert_eq(_sel("ChargerWindUpState", Vector2.ZERO, false, false), "windup",
		"ChargerWindUpState -> windup (the telegraph tell)")


func test_charger_charge_maps_to_charge() -> void:
	assert_eq(_sel("ChargerChargeState", Vector2(420.0, 0.0), false, false), "charge",
		"ChargerChargeState -> charge (the lunge)")


func test_charger_recovery_falls_back_to_idle() -> void:
	assert_eq(_sel("ChargerRecoveryState", Vector2.ZERO, false, false), "idle",
		"ChargerRecoveryState -> idle (no dedicated recovery anim; documented fallback)")


## ---- hurt override (highest priority) ---------------------------------------

func test_hurt_overrides_drone_patrol() -> void:
	assert_eq(_sel("DronePatrolState", Vector2.ZERO, false, true), "hurt",
		"hurt overrides idle -> hurt")


func test_hurt_overrides_drone_chase() -> void:
	assert_eq(_sel("DroneChaseState", Vector2(90.0, 0.0), false, true), "hurt",
		"hurt overrides walk -> hurt")


func test_hurt_overrides_charger_charge() -> void:
	assert_eq(_sel("ChargerChargeState", Vector2(420.0, 0.0), false, true), "hurt",
		"hurt overrides charge -> hurt (a landed hit is the loudest beat)")


func test_hurt_takes_priority_over_attacking() -> void:
	# If both hurt and attacking are set, hurt wins.
	assert_eq(_sel("DroneAttackState", Vector2.ZERO, true, true), "hurt",
		"hurt takes priority over attacking when both are true")


## ---- attacking one-shot override --------------------------------------------

func test_attacking_overrides_idle() -> void:
	assert_eq(_sel("DronePatrolState", Vector2.ZERO, true, false), "attack",
		"attacking one-shot overrides idle -> attack")


func test_attacking_overrides_walk() -> void:
	assert_eq(_sel("DroneChaseState", Vector2(90.0, 0.0), true, false), "attack",
		"attacking one-shot overrides walk -> attack")


## ---- unknown / future state fallback ----------------------------------------

func test_unknown_state_falls_back_to_idle() -> void:
	assert_eq(_sel("SomeFutureState", Vector2.ZERO, false, false), "idle",
		"an unknown/future state falls back to idle (safe default)")


func test_empty_state_falls_back_to_idle() -> void:
	assert_eq(_sel("", Vector2.ZERO, false, false), "idle",
		"an empty state name falls back to idle (safe default)")


## ---- flip_h rule ------------------------------------------------------------

func test_flip_h_false_when_facing_positive() -> void:
	assert_false(EnemyAnimationController.facing_to_flip_h(1.0),
		"facing=+1 -> flip_h false (east frames face right natively)")


func test_flip_h_true_when_facing_negative() -> void:
	assert_true(EnemyAnimationController.facing_to_flip_h(-1.0),
		"facing=-1 -> flip_h true (east frames flipped for leftward facing)")


func test_flip_h_false_when_facing_zero() -> void:
	assert_false(EnemyAnimationController.facing_to_flip_h(0.0),
		"facing=0 -> flip_h false (neutral defaults to east)")
