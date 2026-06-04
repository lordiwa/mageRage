## TASK-010 unit tests for HitStop.duration_for (pure scheduling decision).
##
## The freeze duration must be a sane positive real-time value, capped so even a
## super-effective hit stays snappy, and scale (weakly) with DD-006 effectiveness
## so a stronger hit lingers a touch longer than a resisted one.
##
## HitStop is an autoload; the static is called via the script's class file so the
## pure math is tested without engaging the running singleton / Engine.time_scale.
extends GutTest

const HitStopScript := preload("res://scripts/juice/hit_stop.gd")


func test_neutral_duration_is_positive() -> void:
	assert_gt(HitStopScript.duration_for(1.0), 0.0,
		"a neutral hit produces a positive freeze duration")


func test_duration_is_capped() -> void:
	assert_lte(HitStopScript.duration_for(99.0), HitStopScript.MAX_DURATION,
		"even an extreme effectiveness stays within the snappy cap")


func test_stronger_hit_lingers_at_least_as_long() -> void:
	var resisted := HitStopScript.duration_for(0.5)
	var neutral := HitStopScript.duration_for(1.0)
	var sup := HitStopScript.duration_for(1.5)
	assert_lte(resisted, neutral,
		"a resisted hit freezes no longer than a neutral one")
	assert_lte(neutral, sup,
		"a super-effective hit freezes at least as long as a neutral one")


func test_duration_never_collapses_to_zero() -> void:
	# Even a degenerate low effectiveness must still freeze a perceptible sliver.
	assert_gt(HitStopScript.duration_for(0.0), 0.0,
		"duration stays positive even for zero effectiveness")
