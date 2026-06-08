## TASK-067 shmup TUNING tests — the per-level SPEED + CADENCE overrides that make the
## auto-scroll shmup (levels/shmup_01.tscn) FEEL faster than the sectors, applied via
## SCOPED, named tunable seams that DEFAULT to the no-op value so sector_01/02 flight +
## combat are BYTE-IDENTICAL.
##
## Two independent seams, both defaulting to 1.0 (no-op):
##   1. Player.fly_speed_scale — FlightState multiplies its FLY_SPEED by this when computing
##      the free-flight velocity. Default 1.0 => velocity = input * FLY_SPEED (sectors
##      unchanged). The shmup controller sets it > 1.0 so the hero flies faster.
##   2. MagicManager.cadence_scale — the hold-to-fire interval is multiplied by this. < 1.0
##      => SHORTER interval => faster fire. Default 1.0 keeps the M2.1 per-element cadence
##      (Fire 0.18 / Elec 0.28 / Ice 0.40) byte-identical.
##
## Everything here is DETERMINISTIC + FRAME-FREE: FlightState velocity is driven via a
## FakePlayer + the InputGate-free Input axis isn't needed (we assert the velocity formula
## directly through the public seam), and the cadence is driven by calling the held-cast
## path with explicit deltas (no real frames).
extends GutTest

const FIRE_INTERVAL := 0.18


# --- 1. Fly-speed override seam (Player.fly_speed_scale) ----------------------

func test_fake_player_defaults_fly_speed_scale_to_one() -> void:
	# The shared seam: FakePlayer mirrors Player.fly_speed_scale, defaulting 1.0 so every
	# existing flight-velocity test is byte-identical (no-op multiplier).
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	assert_true("fly_speed_scale" in fake, "FakePlayer exposes a fly_speed_scale seam (mirrors Player)")
	assert_almost_eq(fake.fly_speed_scale, 1.0, 0.0001,
		"fly_speed_scale defaults to 1.0 (no-op; sector flight byte-identical)")


func test_default_scale_keeps_flight_velocity_byte_identical() -> void:
	# Default scale (1.0): the free-flight velocity is exactly input * FLY_SPEED — the
	# byte-identical sector behavior. Drive a full-right input through FlightState.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false
	# fly_speed_scale left at its 1.0 default.

	var st := FlightState.new()
	st.player = fake
	add_child_autofree(st)
	st.enter()
	# Hold full-right movement and step one physics frame.
	Input.action_press("move_right")
	st.physics_update(0.016)
	Input.action_release("move_right")

	assert_almost_eq(fake.velocity.x, FlightState.FLY_SPEED, 0.5,
		"with the default scale the flight velocity is input * FLY_SPEED (byte-identical)")


func test_shmup_scale_makes_flight_faster() -> void:
	# In the shmup the controller sets fly_speed_scale > 1.0, so the SAME full-right input
	# yields a velocity of FLY_SPEED * scale — strictly faster than the sector default.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false
	fake.fly_speed_scale = 1.5

	var st := FlightState.new()
	st.player = fake
	add_child_autofree(st)
	st.enter()
	Input.action_press("move_right")
	st.physics_update(0.016)
	Input.action_release("move_right")

	assert_almost_eq(fake.velocity.x, FlightState.FLY_SPEED * 1.5, 0.5,
		"the shmup scale multiplies the flight velocity (FLY_SPEED * scale)")
	assert_gt(fake.velocity.x, FlightState.FLY_SPEED,
		"the shmup hero flies strictly faster than the sector default")


func test_fly_speed_const_is_not_mutated_by_the_seam() -> void:
	# The shared FLY_SPEED const itself is never changed — the override is a per-player
	# multiplier, so the sectors (scale 1.0) keep the exact shared default.
	assert_almost_eq(FlightState.FLY_SPEED, 260.0, 0.0001,
		"the shared FlightState.FLY_SPEED const is untouched (260.0)")


# --- 2. Fire-cadence override seam (MagicManager.cadence_scale) ---------------

func _make_manager(scale: float) -> MagicManager:
	var fire := SpellData.new()
	fire.element = SpellData.Element.FIRE
	fire.mana_cost = 1.0
	fire.fire_interval = FIRE_INTERVAL
	var ice := SpellData.new()
	ice.element = SpellData.Element.ICE
	ice.mana_cost = 1.0
	ice.fire_interval = 0.40
	var mana := Mana.new()
	mana.max_mana = 1000.0
	mana.regen_per_second = 0.0
	add_child_autofree(mana)
	mana.current_mana = 1000.0
	var mgr := MagicManager.new()
	mgr.spells = [fire, ice]
	mgr.mana = mana
	mgr.cadence_scale = scale
	add_child_autofree(mgr)
	return mgr


## Hold a primary trigger over `seconds` in `step` ticks; return the shot count.
func _hold_primary(mgr: MagicManager, origin: Node2D, seconds: float, step: float) -> int:
	var shots := 0
	var t := 0.0
	while t < seconds - 0.000001:
		if mgr.try_cast_primary_held(origin, Vector2.RIGHT, true, step):
			shots += 1
		t += step
	return shots


func test_manager_defaults_cadence_scale_to_one() -> void:
	var mgr := _make_manager(1.0)
	assert_almost_eq(mgr.cadence_scale, 1.0, 0.0001,
		"MagicManager.cadence_scale defaults to 1.0 (no-op; sector cadence byte-identical)")


func test_default_scale_keeps_fire_cadence_byte_identical() -> void:
	# Default scale (1.0): the Fire (0.18) cadence is unchanged — over 1.0s it fires the
	# same M2.1 count as test_fire_cadence.gd asserts (5..7).
	var mgr := _make_manager(1.0)
	var origin := Node2D.new()
	add_child_autofree(origin)
	var shots := _hold_primary(mgr, origin, 1.0, 0.005)
	assert_between(shots, 5, 7,
		"with the default cadence_scale the Fire cadence is byte-identical (1.0s / 0.18s)")


func test_shmup_scale_fires_faster_than_default() -> void:
	# The shmup sets cadence_scale < 1.0 (shorter interval => faster fire). Over the SAME
	# 1.0s window the scaled manager fires strictly MORE shots than the default.
	var origin := Node2D.new()
	add_child_autofree(origin)
	var default_mgr := _make_manager(1.0)
	var shmup_mgr := _make_manager(0.5)
	var default_shots := _hold_primary(default_mgr, origin, 1.0, 0.005)
	var shmup_shots := _hold_primary(shmup_mgr, origin, 1.0, 0.005)
	assert_gt(shmup_shots, default_shots,
		"a cadence_scale < 1.0 fires faster (more shots in the same window)")


func test_fire_interval_data_is_not_mutated_by_the_seam() -> void:
	# The seam multiplies the interval at READ time; it never writes the SpellData
	# fire_interval, so the shared M2.1 data is untouched.
	var mgr := _make_manager(0.5)
	var fire: SpellData = mgr.spells[0]
	assert_almost_eq(fire.fire_interval, FIRE_INTERVAL, 0.0001,
		"the SpellData.fire_interval data is never mutated by the cadence seam")
