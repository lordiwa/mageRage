## TASK-028 unit tests for the reusable anti-magic flight-suppression zone
## (scenes/anti_magic_zone.tscn + scripts/levels/anti_magic_zone.gd, AntiMagicZone).
##
## DD-011 (zona anti-magia que anula el vuelo): an Empire dampening field where the
## hero's FlightState is DISABLED while inside, gating an aerial route the player would
## otherwise just fly over. The player RESTORES flight by PURGING the field with the
## CORRECT element (reusing the projectile hit path, like TASK-027's gate). Purging
## PERSISTENTLY lifts suppression for that zone. Color-coded per DD-003.
##
## Two layers of coverage:
##   A. The zone component in isolation, driven via its clean API (purge / is_suppressing
##      / set_player_suppressed-on-overlap) — deterministic, no input edges.
##   B. The FSM integration: a FakePlayer whose `is_flight_suppressed()` flag is set
##      blocks the double-jump -> FlightState transition (driven via the InputGate edge
##      seam); cleared, flight is allowed exactly as before (DD-008 unaffected).
extends GutTest

const ZONE := preload("res://scenes/anti_magic_zone.tscn")


func after_each() -> void:
	# Drop any InputGate edge overrides so they never leak across tests / into the game.
	InputGate.clear_test_overrides()


## Instance a zone, parent it (auto-freed), and configure its purge element.
func _make_zone(purge_element: int) -> AntiMagicZone:
	var zone := ZONE.instantiate() as AntiMagicZone
	zone.purge_element = purge_element
	add_child_autofree(zone)
	return zone


# --- A. Zone component behavior (criteria 1/2/3) ----------------------------

func test_zone_suppresses_by_default() -> void:
	# Criterion 2: a fresh, un-purged zone is actively suppressing flight.
	var zone := _make_zone(SpellData.Element.ELECTRICITY)
	assert_true(zone.is_suppressing(),
		"a fresh anti-magic zone suppresses flight until purged")


func test_wrong_element_does_not_purge() -> void:
	# Criterion 3: the WRONG element does nothing — the field keeps suppressing.
	var zone := _make_zone(SpellData.Element.ELECTRICITY)
	zone.purge(SpellData.Element.FIRE)
	assert_true(zone.is_suppressing(), "the wrong element (Fire) does not purge the field")
	zone.purge(SpellData.Element.ICE)
	assert_true(zone.is_suppressing(), "the wrong element (Ice) does not purge the field")


func test_correct_element_purges_the_field() -> void:
	# Criterion 3: the CORRECT element purges -> suppression lifts.
	var zone := _make_zone(SpellData.Element.ELECTRICITY)
	zone.purge(SpellData.Element.ELECTRICITY)
	assert_false(zone.is_suppressing(), "the correct element purges the field")


func test_purge_persists_across_further_hits() -> void:
	# Criterion 3: purge is PERSISTENT — a later wrong element cannot re-arm it.
	var zone := _make_zone(SpellData.Element.ELECTRICITY)
	zone.purge(SpellData.Element.ELECTRICITY)
	assert_false(zone.is_suppressing(), "purged by the correct element")
	zone.purge(SpellData.Element.FIRE)
	zone.purge(SpellData.Element.ICE)
	assert_false(zone.is_suppressing(),
		"purge persists; later wrong elements cannot re-arm the field")


func test_zone_emits_purged_signal_once() -> void:
	# Decoupling (godot-game-dev signals): the zone announces purge exactly once.
	var zone := _make_zone(SpellData.Element.ELECTRICITY)
	watch_signals(zone)
	zone.purge(SpellData.Element.ELECTRICITY)
	assert_signal_emitted(zone, "purged", "purging emits the 'purged' signal")
	zone.purge(SpellData.Element.ELECTRICITY)
	assert_signal_emit_count(zone, "purged", 1, "the purged signal fires exactly once")


func test_projectile_hit_path_routes_to_purge() -> void:
	# In-game application: a player projectile that strikes the emitter calls
	# `apply_elemental_hit(element, ...)` (the same method drones/gate expose), which the
	# zone forwards to `purge`. Correct element via that path lifts suppression.
	var zone := _make_zone(SpellData.Element.ELECTRICITY)
	assert_true(zone.has_method("apply_elemental_hit"),
		"the zone exposes apply_elemental_hit so the existing projectile strikes it")
	zone.apply_elemental_hit(SpellData.Element.FIRE, 10.0, false, Vector2.RIGHT)
	assert_true(zone.is_suppressing(), "wrong element via the projectile path keeps it suppressing")
	zone.apply_elemental_hit(SpellData.Element.ELECTRICITY, 10.0, false, Vector2.RIGHT)
	assert_false(zone.is_suppressing(), "correct element via the projectile path purges the field")


func test_emitter_is_on_enemies_layer_so_player_magic_reaches_it() -> void:
	# Reuse the existing projectile (masks Enemies layer 3 only): the purge emitter's
	# hittable Area2D must sit on layer 3 so a player shot's callback finds it.
	var zone := _make_zone(SpellData.Element.ELECTRICITY)
	var emitter := zone.get_node_or_null("Emitter") as Area2D
	assert_not_null(emitter, "the zone has an Emitter Area2D the projectile can strike")
	assert_true(emitter.get_collision_layer_value(3),
		"the Emitter is on the Enemies layer (3) so the player projectile detects it")


func test_field_area_masks_the_player_layer() -> void:
	# The dampening field is an Area2D that detects the player BODY entering/exiting so
	# it can toggle suppression on the hero. It must mask the Player layer (2).
	var zone := _make_zone(SpellData.Element.ELECTRICITY)
	var field := zone.get_node_or_null("Field") as Area2D
	assert_not_null(field, "the zone has a Field Area2D that detects the player body")
	assert_true(field.get_collision_mask_value(2),
		"the Field masks the Player layer (2) so it detects the hero entering")


# --- A. Player overlap drives suppression flag (criterion 2) ----------------

func test_entering_unpurged_zone_suppresses_the_player() -> void:
	# When a flight-capable body enters the un-purged field, the zone flags the player
	# as flight-suppressed (the FSM later reads that flag).
	var zone := _make_zone(SpellData.Element.ELECTRICITY)
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	zone._on_body_entered(fake)
	assert_true(fake.is_flight_suppressed(),
		"entering the un-purged field suppresses the player's flight")


func test_leaving_zone_restores_the_player() -> void:
	# Leaving the field clears the suppression flag (flight works outside).
	var zone := _make_zone(SpellData.Element.ELECTRICITY)
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	zone._on_body_entered(fake)
	assert_true(fake.is_flight_suppressed(), "suppressed while inside")
	zone._on_body_exited(fake)
	assert_false(fake.is_flight_suppressed(), "leaving the field restores flight")


func test_entering_purged_zone_does_not_suppress() -> void:
	# Criterion 3: after purge, entering the (now-dead) field does NOT suppress flight.
	var zone := _make_zone(SpellData.Element.ELECTRICITY)
	zone.purge(SpellData.Element.ELECTRICITY)
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	zone._on_body_entered(fake)
	assert_false(fake.is_flight_suppressed(),
		"a purged field does not suppress a player who enters it")


func test_purging_while_inside_immediately_restores_the_player() -> void:
	# Criterion 3: purging WHILE the hero stands inside lifts suppression on the spot
	# (the player doesn't have to leave and re-enter to fly).
	var zone := _make_zone(SpellData.Element.ELECTRICITY)
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	zone._on_body_entered(fake)
	assert_true(fake.is_flight_suppressed(), "suppressed on entry")
	zone.purge(SpellData.Element.ELECTRICITY)
	assert_false(fake.is_flight_suppressed(),
		"purging while inside restores the standing player's flight immediately")


# --- A. DD-003 color coding -------------------------------------------------

func test_zone_is_color_coded_per_dd003_electricity_yellow() -> void:
	# DD-003: Electricity = yellow (red+green high, blue low).
	var zone := _make_zone(SpellData.Element.ELECTRICITY)
	var col := zone.field_color()
	assert_gt(col.r, col.b, "an Electricity field reads yellow (red dominates blue)")
	assert_gt(col.g, col.b, "an Electricity field reads yellow (green dominates blue)")


func test_zone_is_color_coded_per_dd003_ice_blue() -> void:
	# DD-003: Ice = blue. Configurable per @export.
	var zone := _make_zone(SpellData.Element.ICE)
	var col := zone.field_color()
	assert_gt(col.b, col.r, "an Ice field reads blue (blue dominates red)")


# --- B. FSM integration: suppression blocks the double-jump -> flight ---------

func _make_state(state_script: GDScript, fake: FakePlayer) -> EstadoBase:
	var st: EstadoBase = state_script.new()
	st.player = fake
	add_child_autofree(st)
	return st


func _airborne_double_jump_ready(suppressed: bool) -> FakePlayer:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "electricity": true}
	fake.on_floor = false
	fake.velocity = Vector2(0, -100)
	fake.jump_count = 1                       # the first (ground) jump already fired
	fake.set_flight_suppressed(suppressed)
	return fake


func test_jump_to_flight_blocked_while_suppressed() -> void:
	# Criterion 2: inside an un-purged zone (suppressed) the double-jump must NOT enter
	# FlightState, even with electricity + a genuine second jump edge.
	var fake := _airborne_double_jump_ready(true)
	var st := _make_state(JumpState, fake)
	InputGate.set_test_override("jump", true)   # the double-jump edge
	watch_signals(st)
	st.physics_update(0.016)
	assert_signal_not_emitted(st, "transition_requested")


func test_jump_to_flight_allowed_when_not_suppressed() -> void:
	# Criterion 2: OUTSIDE the zone (not suppressed) the exact same double-jump enters
	# FlightState — DD-008 is unaffected everywhere else.
	var fake := _airborne_double_jump_ready(false)
	var st := _make_state(JumpState, fake)
	InputGate.set_test_override("jump", true)
	watch_signals(st)
	st.physics_update(0.016)
	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "FlightState"])


func test_jump_to_flight_restored_after_clearing_suppression() -> void:
	# Criterion 3: once the field is purged the player's flag clears and the SAME
	# double-jump that was blocked now enters FlightState.
	var fake := _airborne_double_jump_ready(true)
	var st := _make_state(JumpState, fake)
	# Blocked while suppressed.
	InputGate.set_test_override("jump", true)
	watch_signals(st)
	st.physics_update(0.016)
	assert_signal_not_emitted(st, "transition_requested")
	# Purge lifts the flag; the next double-jump edge now flies.
	fake.set_flight_suppressed(false)
	InputGate.set_test_override("jump", true)
	st.physics_update(0.016)
	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "FlightState"])


func test_glide_to_flight_blocked_while_suppressed() -> void:
	# The glide -> flight double-jump path is gated by suppression too (the zone covers
	# the whole flight kit, not just JumpState).
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "ice": true, "electricity": true}
	fake.on_floor = false
	fake.velocity = Vector2(0, 30)
	fake.jump_count = 1
	fake.set_flight_suppressed(true)
	var st := _make_state(GlideState, fake)
	Input.action_press("glide")               # stay in glide (held, deterministic)
	InputGate.set_test_override("jump", true)
	watch_signals(st)
	st.physics_update(0.016)
	assert_signal_not_emitted(st, "transition_requested")
	Input.action_release("glide")


func test_glide_to_flight_allowed_when_not_suppressed() -> void:
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"fire": true, "ice": true, "electricity": true}
	fake.on_floor = false
	fake.velocity = Vector2(0, 30)
	fake.jump_count = 1
	fake.set_flight_suppressed(false)
	var st := _make_state(GlideState, fake)
	Input.action_press("glide")
	InputGate.set_test_override("jump", true)
	watch_signals(st)
	st.physics_update(0.016)
	assert_signal_emitted_with_parameters(
		st, "transition_requested", [st, "FlightState"])
	Input.action_release("glide")


# --- B. FSM integration: SUSTAINED flight is dropped inside an un-purged zone --
# REGRESSION (review HIGH): gating only the ENTRY edge let a hero who was ALREADY
# FLYING on entry sustain flight straight through an un-purged field (skipping the
# purge). FlightState must re-read the flag and drop the hero out the moment the
# field suppresses, so they fall and become grounded inside the zone.

func test_active_flight_drops_out_when_suppressed_mid_flight() -> void:
	# Criterion 2 ("cannot enter OR sustain FlightState"): an already-flying hero whose
	# field becomes suppressing must be forced out of FlightState (no landing needed).
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false                 # airborne, NOT on the floor
	fake.set_flight_suppressed(true)      # flew into an un-purged field
	var st := _make_state(FlightState, fake)
	st.enter()
	watch_signals(st)
	st.physics_update(0.016)
	# It must request a transition OUT of flight (to a grounded-falling state), not
	# silently keep flying through the field.
	assert_signal_emitted(st, "transition_requested",
		"a suppressed active flight requests a transition out (cannot sustain flight)")
	assert_false(_requested_to(st, "FlightState"),
		"the suppressed flight does not stay in / re-request FlightState")


func test_active_flight_continues_when_not_suppressed() -> void:
	# DD-008 preserved: outside a zone (flag false) an airborne hero keeps flying —
	# FlightState only exits on landing, exactly as before.
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false
	fake.set_flight_suppressed(false)
	var st := _make_state(FlightState, fake)
	st.enter()
	watch_signals(st)
	st.physics_update(0.016)
	assert_signal_not_emitted(st, "transition_requested",
		"unsuppressed airborne flight is sustained (no forced exit) — DD-008 unaffected")


# Helper: did `st` request a transition to `target` on its watched signal?
func _requested_to(st: EstadoBase, target: String) -> bool:
	var calls: int = get_signal_emit_count(st, "transition_requested")
	for i in range(calls):
		var params: Array = get_signal_parameters(st, "transition_requested", i)
		if params != null and params.size() >= 2 and params[1] == target:
			return true
	return false


# --- End-to-end: a real zone forces a flying body out, until purged ----------

func test_real_zone_forces_a_flying_body_out_until_purged() -> void:
	# REGRESSION (review HIGH), no entry-edge involved: an ALREADY-FLYING hero who is
	# flagged by a real un-purged zone is forced out of FlightState (can't coast over the
	# barrier). After purging the zone, the flag clears and the same airborne hero
	# sustains flight. Exercises the zone->flag->FlightState path end-to-end (not geometry).
	var zone := _make_zone(SpellData.Element.ELECTRICITY)
	var fake := FakePlayer.new()
	add_child_autofree(fake)
	fake.abilities = {"electricity": true}
	fake.on_floor = false                 # airborne the whole time
	# The hero flies into the un-purged field -> flagged suppressed.
	zone._on_body_entered(fake)
	assert_true(fake.is_flight_suppressed(), "flying into the un-purged field suppresses the hero")
	var st := _make_state(FlightState, fake)
	st.enter()
	watch_signals(st)
	st.physics_update(0.016)
	assert_signal_emitted(st, "transition_requested",
		"the un-purged field forces the flying hero out of FlightState (no coast-over)")
	assert_false(_requested_to(st, "FlightState"), "it does not re-request flight while suppressed")
	# Purge the field while the hero is still inside -> flag clears -> flight sustains.
	zone.purge(SpellData.Element.ELECTRICITY)
	assert_false(fake.is_flight_suppressed(), "purge lifts the standing hero's suppression")
	var st2 := _make_state(FlightState, fake)
	st2.enter()
	watch_signals(st2)
	st2.physics_update(0.016)
	assert_signal_not_emitted(st2, "transition_requested",
		"after purge the airborne hero sustains flight over the barrier")
