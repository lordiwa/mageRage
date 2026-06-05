## TASK-052 unit tests for AnimationController.select_animation() and flip_h logic.
##
## The selection function is pure (no scene, no nodes): takes the current FSM
## state name, velocity, on_floor flag, casting flag, and hurt flag and returns
## the animation name string to play. All branches exercised here so implementation
## regressions surface immediately.
##
## Also verifies the flip_h rule: facing < 0 -> flip_h true, facing >= 0 -> false.
extends GutTest


## ---- helpers ----------------------------------------------------------------

## Calls AnimationController.select_animation as a static call (pure function).
## Uses the class once it is implemented.
func _sel(state: String, velocity: Vector2, on_floor: bool,
		casting: bool, hurt: bool) -> String:
	return AnimationController.select_animation(state, velocity, on_floor, casting, hurt)


## ---- idle / walk (MoveState) ------------------------------------------------

func test_move_idle_when_on_floor_and_standing_still() -> void:
	var anim := _sel("MoveState", Vector2(0.0, 0.0), true, false, false)
	assert_eq(anim, "idle",
		"MoveState + on_floor + |vel.x|~0 -> idle")


func test_move_idle_when_velocity_below_walk_threshold() -> void:
	# A very small horizontal speed (jitter) must not trigger walk.
	var anim := _sel("MoveState", Vector2(2.0, 0.0), true, false, false)
	assert_eq(anim, "idle",
		"MoveState + on_floor + tiny vel.x -> idle (not walk)")


func test_move_walk_when_on_floor_and_moving() -> void:
	var anim := _sel("MoveState", Vector2(100.0, 0.0), true, false, false)
	assert_eq(anim, "walk",
		"MoveState + on_floor + |vel.x|>threshold -> walk")


func test_move_walk_negative_velocity() -> void:
	var anim := _sel("MoveState", Vector2(-120.0, 0.0), true, false, false)
	assert_eq(anim, "walk",
		"MoveState + on_floor + moving left -> walk (not flip concern here)")


func test_move_idle_when_airborne_no_horizontal() -> void:
	# MoveState while briefly airborne (coyote) with no horizontal -> idle fallback.
	var anim := _sel("MoveState", Vector2(0.0, 10.0), false, false, false)
	assert_eq(anim, "idle",
		"MoveState + airborne + still -> idle fallback")


## ---- jump / fall (JumpState) ------------------------------------------------

func test_jump_state_rising_gives_jump_anim() -> void:
	# vel.y < 0 means going up.
	var anim := _sel("JumpState", Vector2(0.0, -200.0), false, false, false)
	assert_eq(anim, "jump",
		"JumpState + vel.y<0 (rising) -> jump")


func test_jump_state_descending_gives_fall_anim() -> void:
	# vel.y > 0 means going down.
	var anim := _sel("JumpState", Vector2(0.0, 200.0), false, false, false)
	assert_eq(anim, "fall",
		"JumpState + vel.y>0 (descending) -> fall")


func test_jump_state_at_apex_gives_jump_anim() -> void:
	# vel.y == 0 is the apex: treat as still-rising / jump.
	var anim := _sel("JumpState", Vector2(0.0, 0.0), false, false, false)
	assert_eq(anim, "jump",
		"JumpState + vel.y==0 (apex) -> jump")


## ---- glide (GlideState) - documented fallback -------------------------------

func test_glide_state_falls_back_to_fall() -> void:
	# GlideState has no dedicated animation; documented fallback to "fall".
	var anim := _sel("GlideState", Vector2(0.0, 50.0), false, false, false)
	assert_eq(anim, "fall",
		"GlideState -> fall fallback (gap documented: no dedicated glide anim)")


## ---- flight (FlightState) ---------------------------------------------------

func test_flight_state_gives_flight_anim() -> void:
	var anim := _sel("FlightState", Vector2(0.0, 0.0), false, false, false)
	assert_eq(anim, "flight",
		"FlightState -> flight (hover aura)")


func test_flight_state_moving_still_flight() -> void:
	var anim := _sel("FlightState", Vector2(80.0, -30.0), false, false, false)
	assert_eq(anim, "flight",
		"FlightState + moving velocity -> still flight anim")


## ---- casting override (any state) ------------------------------------------

func test_casting_overrides_idle_to_attack() -> void:
	var anim := _sel("MoveState", Vector2(0.0, 0.0), true, true, false)
	assert_eq(anim, "attack",
		"casting=true overrides idle -> attack one-shot")


func test_casting_overrides_walk_to_attack() -> void:
	var anim := _sel("MoveState", Vector2(100.0, 0.0), true, true, false)
	assert_eq(anim, "attack",
		"casting=true overrides walk -> attack one-shot")


func test_casting_overrides_jump_to_attack() -> void:
	var anim := _sel("JumpState", Vector2(0.0, -200.0), false, true, false)
	assert_eq(anim, "attack",
		"casting=true overrides jump -> attack one-shot")


func test_casting_overrides_flight_to_attack() -> void:
	var anim := _sel("FlightState", Vector2(0.0, 0.0), false, true, false)
	assert_eq(anim, "attack",
		"casting=true overrides flight -> attack one-shot")


## ---- hurt override (any state, highest priority) ----------------------------

func test_hurt_overrides_idle_to_hurt() -> void:
	var anim := _sel("MoveState", Vector2(0.0, 0.0), true, false, true)
	assert_eq(anim, "hurt",
		"hurt=true overrides idle -> hurt")


func test_hurt_overrides_walk_to_hurt() -> void:
	var anim := _sel("MoveState", Vector2(100.0, 0.0), true, false, true)
	assert_eq(anim, "hurt",
		"hurt=true overrides walk -> hurt")


func test_hurt_overrides_flight_to_hurt() -> void:
	var anim := _sel("FlightState", Vector2(0.0, 0.0), false, false, true)
	assert_eq(anim, "hurt",
		"hurt=true overrides flight -> hurt")


func test_hurt_takes_priority_over_casting() -> void:
	# If somehow both hurt and casting are active, hurt wins (landed hit is loudest).
	var anim := _sel("MoveState", Vector2(0.0, 0.0), true, true, true)
	assert_eq(anim, "hurt",
		"hurt takes priority over casting when both are true")


## ---- flip_h rule ------------------------------------------------------------

func test_flip_h_false_when_facing_positive() -> void:
	assert_false(
		AnimationController.facing_to_flip_h(1.0),
		"facing=+1 -> flip_h false (east frames face right natively)")


func test_flip_h_true_when_facing_negative() -> void:
	assert_true(
		AnimationController.facing_to_flip_h(-1.0),
		"facing=-1 -> flip_h true (east frames flipped for leftward facing)")


func test_flip_h_false_when_facing_zero() -> void:
	# Edge case: facing=0 treated as non-left.
	assert_false(
		AnimationController.facing_to_flip_h(0.0),
		"facing=0 -> flip_h false (neutral defaults to east)")


## ---- unknown state fallback -------------------------------------------------

func test_unknown_state_falls_back_to_idle() -> void:
	var anim := _sel("UnknownState", Vector2(0.0, 0.0), true, false, false)
	assert_eq(anim, "idle",
		"an unknown/future state falls back to idle (safe default)")
