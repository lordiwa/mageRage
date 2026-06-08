## Unit tests for the shmup enemy spawner (scripts/levels/shmup_spawner.gd, ShmupSpawner) —
## the TASK-066 enemy stream for the auto-scroll shmup (levels/shmup_01.tscn).
##
## The spawner streams the EXISTING flying-drone enemies in from the RIGHT edge of the
## auto-scroll camera's visible rect on a DATA-DRIVEN, timed wave schedule; spawned enemies
## drift LEFTWARD relative to the world so they approach as the frame scrolls, and are
## released/recycled when they leave the LEFT edge or die.
##
## EVERYTHING here is DETERMINISTIC and FRAME-FREE (the GUT flake footgun + the ticket's
## explicit "do NOT rely on real frames / real enemy scenes" requirement):
##   - the camera rect comes from a tiny FAKE scroller (a fixed Rect2), not a real Camera2D;
##   - spawning goes through an INJECTED spawn callback (a spy) that records each
##     (enemy_type, position) and returns a FAKE enemy handle — no real enemy .tscn instanced;
##   - despawn goes through an INJECTED release callback (a spy) so we can count recycles;
##   - time is driven by calling update(delta) DIRECTLY, never through _physics_process.
##
## What it proves:
##   1. The y-pattern helper is pure + frame-free (LINE/SINE/TOP/BOTTOM map into the rect).
##   2. A wave emits exactly its `count` enemies over simulated time (spawn-count over time).
##   3. Spawned enemies start at/just past the RIGHT edge at the wave's y-pattern (position).
##   4. Enemies are released when off the LEFT edge OR dead (despawn/recycle via the seam).
##   5. The wave schedule is data-driven (editing the `waves` array changes the stream).
extends GutTest

const ShmupSpawnerScript := preload("res://scripts/levels/shmup_spawner.gd")


## A minimal stand-in for ShmupScroller: returns a FIXED visible world rect so the spawner's
## right-edge / y-pattern math is exercised with no real Camera2D / viewport / frames.
class FakeScroller:
	extends Node
	var rect := Rect2(0.0, 0.0, 1000.0, 600.0)

	func visible_world_rect() -> Rect2:
		return rect


## TASK-070: a MOVING stand-in for ShmupScroller — its visible_world_rect advances RIGHT by
## `dx_per_tick` every time the test bumps it (advance()), mirroring the real auto-scroll camera.
## The spawner reads this rect each update, so the test can prove FRAME-CARRY (the spawner must
## carry each live enemy right by the rect's per-tick x delta on top of its pattern step). The
## test advances this BEFORE each spawner.update() so the rect already moved this tick.
class MovingScroller:
	extends Node
	var rect := Rect2(0.0, 0.0, 1000.0, 600.0)
	var dx_per_tick := 9.0

	func advance() -> void:
		rect.position.x += dx_per_tick

	func visible_world_rect() -> Rect2:
		return rect


## A FAKE enemy handle the spawn-spy hands back: just a movable point with a death flag and an
## is_dead() predicate, so the spawner's despawn logic runs without instancing a real drone.
class FakeEnemy:
	extends Node2D
	var dead := false

	func is_dead() -> bool:
		return dead


## TASK-067: a REAL-DRONE-SHAPED fake. The real EmpireDrone/ShieldDrone is a CharacterBody2D
## ROOT whose is_dead() lives on a Health CHILD node (named "Health"), NOT on the root. This
## fake mirrors that shape (no is_dead() on the root; a Health child that reports dead) so the
## spawner's CORRECTED dead-release contract is exercised the way a real drone actually dies —
## the TASK-066 review MEDIUM (the old root-level is_dead() check was dead code for real drones).
class FakeHealthChild:
	extends Node
	var dead := false

	func is_dead() -> bool:
		return dead


class FakeDrone:
	extends Node2D
	# NO is_dead() on the root (just like the real CharacterBody2D drone). The death state
	# lives on the Health child added in _init so it mirrors the real scene tree.
	var health: FakeHealthChild

	func _init() -> void:
		health = FakeHealthChild.new()
		health.name = "Health"
		add_child(health)


## A spy that captures every spawn and hands back a FakeEnemy positioned where asked. Tests read
## `.spawns` (an Array of {type, position, enemy}) and `.released` (the recycled FakeEnemies).
class SpawnSpy:
	extends RefCounted
	var spawns: Array = []
	var released: Array = []
	## Where fake enemies are parented (an in-tree, auto-freed node) so they don't leak as
	## orphans. Set by the test before driving the spawner.
	var parent: Node

	func spawn(enemy_type: int, at: Vector2) -> Node2D:
		var e := FakeEnemy.new()
		if parent != null:
			parent.add_child(e)
		e.global_position = at
		spawns.append({"type": enemy_type, "position": at, "enemy": e})
		return e

	func release(enemy: Node2D) -> void:
		released.append(enemy)
		# Recycle: free the fake handle (mirrors the real deferred free) so it doesn't orphan.
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()


## Build a spawner wired to a fake scroller + a spawn spy, with a single explicit wave so the
## test owns the schedule. Auto-frees. `waves` overrides the default data-driven stream.
func _make_spawner(spy: SpawnSpy, scroller: FakeScroller, waves: Array) -> ShmupSpawner:
	# Parent fake enemies under the (in-tree, auto-freed) scroller so they don't leak as orphans.
	spy.parent = scroller
	var s := ShmupSpawnerScript.new() as ShmupSpawner
	s.set_scroller(scroller)
	s.spawn_callback = Callable(spy, "spawn")
	s.release_callback = Callable(spy, "release")
	s.waves = waves
	add_child_autofree(s)
	return s


# --- 1. Pure y-pattern helper (frame-free) -----------------------------------

func test_y_pattern_line_centers_in_the_rect() -> void:
	var rect := Rect2(0.0, 100.0, 1000.0, 600.0)
	# LINE: every enemy in the wave shares the rect's vertical center.
	var y := ShmupSpawner.y_for_pattern(ShmupSpawner.YPattern.LINE, rect, 0)
	assert_almost_eq(y, rect.position.y + rect.size.y * 0.5, 0.001,
		"LINE pattern places enemies at the vertical center of the rect")


func test_y_pattern_top_and_bottom_sit_inside_the_rect_edges() -> void:
	var rect := Rect2(0.0, 0.0, 1000.0, 600.0)
	var top := ShmupSpawner.y_for_pattern(ShmupSpawner.YPattern.TOP, rect, 0)
	var bottom := ShmupSpawner.y_for_pattern(ShmupSpawner.YPattern.BOTTOM, rect, 0)
	assert_between(top, rect.position.y, rect.get_center().y,
		"TOP pattern sits in the upper half of the rect (inside it)")
	assert_between(bottom, rect.get_center().y, rect.position.y + rect.size.y,
		"BOTTOM pattern sits in the lower half of the rect (inside it)")


func test_y_pattern_sine_stays_inside_the_rect_and_varies_by_index() -> void:
	var rect := Rect2(0.0, 0.0, 1000.0, 600.0)
	var y0 := ShmupSpawner.y_for_pattern(ShmupSpawner.YPattern.SINE, rect, 0)
	var y1 := ShmupSpawner.y_for_pattern(ShmupSpawner.YPattern.SINE, rect, 1)
	# Inside the rect.
	assert_between(y0, rect.position.y, rect.position.y + rect.size.y,
		"SINE y stays inside the rect (index 0)")
	assert_between(y1, rect.position.y, rect.position.y + rect.size.y,
		"SINE y stays inside the rect (index 1)")
	# Varies with the member index (a wave of sine enemies isn't a flat line).
	assert_ne(y0, y1, "SINE varies the y with the member index across the wave")


# --- 2. Spawn count over simulated time --------------------------------------

func test_wave_emits_exactly_its_count_over_time() -> void:
	var spy := SpawnSpy.new()
	var scroller := FakeScroller.new()
	add_child_autofree(scroller)
	# One wave: 4 enemies, 0.5s apart, starting at t=0.
	var waves := [
		{"enemy_type": 0, "count": 4, "spacing": 0.5, "y_pattern": ShmupSpawner.YPattern.LINE,
			"t_start": 0.0},
	]
	var spawner := _make_spawner(spy, scroller, waves)
	# Drive ~2.5s of simulated time in small ticks (deterministic, no real frames).
	for i in range(50):
		spawner.update(0.05)
	assert_eq(spy.spawns.size(), 4,
		"a wave of count=4 emits exactly 4 enemies over the simulated time")


func test_wave_respects_t_start_and_spacing_schedule() -> void:
	var spy := SpawnSpy.new()
	var scroller := FakeScroller.new()
	add_child_autofree(scroller)
	# One wave: 3 enemies, 1.0s apart, starting at t=1.0 (so first spawn near t=1.0).
	var waves := [
		{"enemy_type": 0, "count": 3, "spacing": 1.0, "y_pattern": ShmupSpawner.YPattern.LINE,
			"t_start": 1.0},
	]
	var spawner := _make_spawner(spy, scroller, waves)
	# At t=0.5 (before t_start) nothing has spawned.
	for i in range(10):
		spawner.update(0.05)
	assert_eq(spy.spawns.size(), 0, "no enemy spawns before the wave's t_start")
	# Advance to t≈1.2: the first enemy of the wave has spawned, not yet the second.
	for i in range(14):
		spawner.update(0.05)
	assert_eq(spy.spawns.size(), 1, "the first wave enemy spawns at/after t_start, before spacing")


# --- 3. Spawn position: right edge + y-pattern -------------------------------

func test_enemies_spawn_at_or_past_the_right_edge_of_the_camera_rect() -> void:
	var spy := SpawnSpy.new()
	var scroller := FakeScroller.new()
	scroller.rect = Rect2(200.0, 50.0, 800.0, 500.0)
	add_child_autofree(scroller)
	var waves := [
		{"enemy_type": 0, "count": 1, "spacing": 0.5, "y_pattern": ShmupSpawner.YPattern.LINE,
			"t_start": 0.0},
	]
	var spawner := _make_spawner(spy, scroller, waves)
	for i in range(5):
		spawner.update(0.05)
	assert_eq(spy.spawns.size(), 1, "the single enemy spawned")
	var right_edge := scroller.rect.position.x + scroller.rect.size.x
	var spawn_x: float = spy.spawns[0]["position"].x
	assert_gte(spawn_x, right_edge,
		"the enemy spawns AT or PAST the right edge of the camera rect (enters from the right)")


func test_enemies_spawn_at_the_waves_y_pattern() -> void:
	var spy := SpawnSpy.new()
	var scroller := FakeScroller.new()
	scroller.rect = Rect2(0.0, 0.0, 1000.0, 600.0)
	add_child_autofree(scroller)
	var waves := [
		{"enemy_type": 0, "count": 1, "spacing": 0.5, "y_pattern": ShmupSpawner.YPattern.TOP,
			"t_start": 0.0},
	]
	var spawner := _make_spawner(spy, scroller, waves)
	for i in range(5):
		spawner.update(0.05)
	assert_eq(spy.spawns.size(), 1, "the single enemy spawned")
	var expected_y := ShmupSpawner.y_for_pattern(ShmupSpawner.YPattern.TOP, scroller.rect, 0)
	assert_almost_eq(spy.spawns[0]["position"].y, expected_y, 0.001,
		"the enemy spawns at the wave's y-pattern (TOP) position")


# --- 4. Despawn / recycle ----------------------------------------------------

func test_enemy_off_the_left_edge_is_released() -> void:
	var spy := SpawnSpy.new()
	var scroller := FakeScroller.new()
	scroller.rect = Rect2(0.0, 0.0, 1000.0, 600.0)
	add_child_autofree(scroller)
	var waves := [
		{"enemy_type": 0, "count": 1, "spacing": 0.5, "y_pattern": ShmupSpawner.YPattern.LINE,
			"t_start": 0.0},
	]
	var spawner := _make_spawner(spy, scroller, waves)
	# Spawn the enemy.
	for i in range(5):
		spawner.update(0.05)
	assert_eq(spy.spawns.size(), 1, "the enemy spawned")
	var enemy: FakeEnemy = spy.spawns[0]["enemy"]
	# Shove it well past the LEFT edge of the rect.
	enemy.global_position.x = scroller.rect.position.x - 500.0
	spawner.update(0.05)
	assert_eq(spy.released.size(), 1, "an enemy past the LEFT edge is released/recycled")
	assert_eq(spy.released[0], enemy, "the released handle is the off-screen enemy")


func test_dead_enemy_is_released() -> void:
	var spy := SpawnSpy.new()
	var scroller := FakeScroller.new()
	add_child_autofree(scroller)
	var waves := [
		{"enemy_type": 0, "count": 1, "spacing": 0.5, "y_pattern": ShmupSpawner.YPattern.LINE,
			"t_start": 0.0},
	]
	var spawner := _make_spawner(spy, scroller, waves)
	for i in range(5):
		spawner.update(0.05)
	assert_eq(spy.spawns.size(), 1, "the enemy spawned")
	var enemy: FakeEnemy = spy.spawns[0]["enemy"]
	# Keep it on-screen but mark it dead.
	enemy.global_position = scroller.rect.get_center()
	enemy.dead = true
	spawner.update(0.05)
	assert_eq(spy.released.size(), 1, "a DEAD enemy is released/recycled")
	assert_eq(spy.released[0], enemy, "the released handle is the dead enemy")


func test_real_drone_shaped_dead_enemy_is_released_via_health_child() -> void:
	# TASK-067 (folds the TASK-066 review MEDIUM): the REAL drone is a CharacterBody2D root
	# whose is_dead() lives on a Health CHILD, not the root — so the spawner must query the
	# Health child to detect death. This drives a real-drone-shaped fake (no root is_dead();
	# a Health child reporting dead) and asserts it IS released, exercising the corrected
	# contract the way real drones actually die (the old root-level check was dead code).
	var scroller := FakeScroller.new()
	add_child_autofree(scroller)
	# Build a real-drone-shaped fake, on-screen, with its Health child marked dead.
	var drone := FakeDrone.new()
	scroller.add_child(drone)
	drone.global_position = scroller.rect.get_center()
	drone.health.dead = true
	# Sanity: the root has NO is_dead() (mirrors the real CharacterBody2D drone).
	assert_false(drone.has_method("is_dead"),
		"the real-drone-shaped fake has NO is_dead() on the root (death lives on the Health child)")

	# A spy whose spawn returns this exact drone, so the spawner tracks + sweeps it.
	var spy := SpawnSpy.new()
	spy.parent = scroller
	var spawner := ShmupSpawnerScript.new() as ShmupSpawner
	spawner.set_scroller(scroller)
	spawner.spawn_callback = func(_t: int, _at: Vector2) -> Node2D: return drone
	spawner.release_callback = Callable(spy, "release")
	spawner.waves = [
		{"enemy_type": 0, "count": 1, "spacing": 0.5, "y_pattern": ShmupSpawner.YPattern.LINE,
			"t_start": 0.0},
	]
	add_child_autofree(spawner)

	# Spawn it (it's tracked), then sweep: the Health-child death must release it.
	for i in range(3):
		spawner.update(0.05)
	assert_eq(spy.released.size(), 1,
		"a real-drone-shaped enemy whose Health CHILD reports dead IS released (corrected contract)")
	assert_eq(spy.released[0], drone, "the released handle is the dead real-drone-shaped enemy")


func test_a_released_enemy_is_not_released_twice() -> void:
	# Recycle discipline: once released, an enemy is dropped from the active set so a later
	# update can't release it again (no double-free / double-recycle).
	var spy := SpawnSpy.new()
	var scroller := FakeScroller.new()
	add_child_autofree(scroller)
	var waves := [
		{"enemy_type": 0, "count": 1, "spacing": 0.5, "y_pattern": ShmupSpawner.YPattern.LINE,
			"t_start": 0.0},
	]
	var spawner := _make_spawner(spy, scroller, waves)
	for i in range(5):
		spawner.update(0.05)
	var enemy: FakeEnemy = spy.spawns[0]["enemy"]
	enemy.dead = true
	spawner.update(0.05)
	spawner.update(0.05)
	assert_eq(spy.released.size(), 1, "a released enemy is never released a second time")


# --- 5. Data-driven stream ---------------------------------------------------

func test_the_wave_stream_is_data_driven() -> void:
	# Editing the `waves` array (the single data-driven definition) is all it takes to change
	# the stream: two waves of different counts emit count_a + count_b enemies total.
	var spy := SpawnSpy.new()
	var scroller := FakeScroller.new()
	add_child_autofree(scroller)
	var waves := [
		{"enemy_type": 0, "count": 2, "spacing": 0.3, "y_pattern": ShmupSpawner.YPattern.LINE,
			"t_start": 0.0},
		{"enemy_type": 1, "count": 3, "spacing": 0.3, "y_pattern": ShmupSpawner.YPattern.SINE,
			"t_start": 0.0},
	]
	var spawner := _make_spawner(spy, scroller, waves)
	for i in range(40):
		spawner.update(0.05)
	assert_eq(spy.spawns.size(), 5, "two data-driven waves emit count_a + count_b = 5 enemies")
	# The second wave carried its own enemy_type (1) through the seam.
	var types := {}
	for rec in spy.spawns:
		types[rec["type"]] = true
	assert_true(types.has(0) and types.has(1),
		"each wave's enemy_type flows through the spawn seam (data-driven composition)")


func test_default_waves_exist_so_the_level_has_a_stream() -> void:
	# Even with no override, the spawner ships a default data-driven stream (so wiring it into
	# the level yields enemies). Just assert the default is a non-empty, well-formed array.
	var spawner := ShmupSpawnerScript.new() as ShmupSpawner
	add_child_autofree(spawner)
	assert_gt(spawner.waves.size(), 0, "the spawner ships a default non-empty wave stream")
	var first: Dictionary = spawner.waves[0]
	assert_true(first.has("count") and first.has("spacing") and first.has("y_pattern"),
		"each default wave is the documented {enemy_type,count,spacing,y_pattern,t_start} shape")


# --- 6. TASK-069: per-wave MOTION pattern + enter-then-lock-on follow ---------

## A movable fake player whose live position the spawner reads for homing/dive/lock-on.
class FakePlayerNode:
	extends Node2D


func test_wave_motion_field_flows_through_and_defaults_to_straight() -> void:
	# A wave can name a MOTION pattern; with none given it defaults to STRAIGHT (the current
	# flat-drift baseline) so existing waves keep their behavior (data-driven, back-compatible).
	var spy := SpawnSpy.new()
	var scroller := FakeScroller.new()
	add_child_autofree(scroller)
	# Wave WITHOUT a motion field -> STRAIGHT default.
	var waves := [
		{"enemy_type": 0, "count": 1, "spacing": 0.5, "y_pattern": ShmupSpawner.YPattern.LINE,
			"t_start": 0.0},
	]
	var spawner := _make_spawner(spy, scroller, waves)
	for i in range(5):
		spawner.update(0.05)
	assert_eq(spy.spawns.size(), 1, "the enemy spawned")
	# The spawner records each active enemy's resolved motion; a missing field is STRAIGHT.
	assert_eq(spawner.motion_for(spy.spawns[0]["enemy"]), ShmupSpawner.MotionPattern.STRAIGHT,
		"a wave with no motion field defaults to STRAIGHT (back-compatible flat drift)")


func test_wave_can_select_a_homing_motion_pattern() -> void:
	# The wave dict carries a per-wave motion selecting one of the four patterns.
	var spy := SpawnSpy.new()
	var scroller := FakeScroller.new()
	add_child_autofree(scroller)
	var waves := [
		{"enemy_type": 0, "count": 1, "spacing": 0.5, "y_pattern": ShmupSpawner.YPattern.LINE,
			"t_start": 0.0, "motion": ShmupSpawner.MotionPattern.HOMING},
	]
	var spawner := _make_spawner(spy, scroller, waves)
	for i in range(5):
		spawner.update(0.05)
	assert_eq(spawner.motion_for(spy.spawns[0]["enemy"]), ShmupSpawner.MotionPattern.HOMING,
		"a wave's motion field selects the per-enemy movement pattern (data-driven)")


func test_straight_motion_drifts_the_enemy_leftward() -> void:
	# A STRAIGHT enemy's x decreases as the spawner advances it (the baseline drift, now
	# driven through the motion path rather than a hard-coded ENTRY_SPEED nudge).
	var spy := SpawnSpy.new()
	var scroller := FakeScroller.new()
	add_child_autofree(scroller)
	var waves := [
		{"enemy_type": 0, "count": 1, "spacing": 0.5, "y_pattern": ShmupSpawner.YPattern.LINE,
			"t_start": 0.0, "motion": ShmupSpawner.MotionPattern.STRAIGHT},
	]
	var spawner := _make_spawner(spy, scroller, waves)
	for i in range(3):
		spawner.update(0.05)
	var enemy: Node2D = spy.spawns[0]["enemy"]
	var x_after_spawn := enemy.global_position.x
	for i in range(10):
		spawner.update(0.05)
	assert_lt(enemy.global_position.x, x_after_spawn,
		"a STRAIGHT enemy drifts leftward as the spawner advances it")


func test_set_player_feeds_the_live_target_for_lock_on() -> void:
	# The spawner is fed the player (duck-typed, like set_scroller) so homing/dive/lock-on
	# can read the live position. Wiring assertion.
	var spawner := ShmupSpawnerScript.new() as ShmupSpawner
	add_child_autofree(spawner)
	assert_false(spawner.has_player(), "no player fed yet")
	var player := FakePlayerNode.new()
	add_child_autofree(player)
	spawner.set_player(player)
	assert_true(spawner.has_player(), "set_player wires the live target (like set_scroller)")


func test_homing_enemy_moves_toward_the_injected_player_after_lock_on() -> void:
	# End-to-end through the spawner: a HOMING enemy, after the entry-lock beat, closes the
	# distance to the LIVE injected player position over successive update ticks. The player
	# is parked off to one side so the enemy must steer, not just drift left into it.
	var spy := SpawnSpy.new()
	var scroller := FakeScroller.new()
	scroller.rect = Rect2(0.0, 0.0, 2000.0, 600.0)
	add_child_autofree(scroller)
	var player := FakePlayerNode.new()
	add_child_autofree(player)
	player.global_position = Vector2(800.0, 60.0)   # off to one side + high
	var waves := [
		{"enemy_type": 0, "count": 1, "spacing": 0.5, "y_pattern": ShmupSpawner.YPattern.BOTTOM,
			"t_start": 0.0, "motion": ShmupSpawner.MotionPattern.HOMING},
	]
	var spawner := _make_spawner(spy, scroller, waves)
	spawner.set_player(player)
	# Spawn it.
	for i in range(3):
		spawner.update(0.05)
	var enemy: Node2D = spy.spawns[0]["enemy"]
	var start_gap := enemy.global_position.distance_to(player.global_position)
	# Drive past the entry-lock beat + several lock-on ticks.
	for i in range(60):
		spawner.update(0.05)
	var end_gap := enemy.global_position.distance_to(player.global_position)
	assert_lt(end_gap, start_gap,
		"a HOMING enemy closes the distance to the injected live player after lock-on")


func test_homing_enemy_does_not_steer_before_the_entry_lock_delay() -> void:
	# Enter-then-lock-on through the spawner: during the entry beat a homing enemy slides in
	# on its entry (leftward) and does NOT yet close the vertical gap to the off-axis player.
	var spy := SpawnSpy.new()
	var scroller := FakeScroller.new()
	scroller.rect = Rect2(0.0, 0.0, 2000.0, 600.0)
	add_child_autofree(scroller)
	var player := FakePlayerNode.new()
	add_child_autofree(player)
	player.global_position = Vector2(800.0, 60.0)
	var waves := [
		{"enemy_type": 0, "count": 1, "spacing": 0.5, "y_pattern": ShmupSpawner.YPattern.BOTTOM,
			"t_start": 0.0, "motion": ShmupSpawner.MotionPattern.HOMING},
	]
	var spawner := _make_spawner(spy, scroller, waves)
	spawner.set_player(player)
	for i in range(2):
		spawner.update(0.05)
	var enemy: Node2D = spy.spawns[0]["enemy"]
	var y_at_spawn := enemy.global_position.y
	# Drive only PART of the entry-lock beat.
	var entry_steps := int(ShmupMotion.ENTRY_LOCK_DELAY / 0.05) - 2
	entry_steps = maxi(entry_steps, 1)
	for i in range(entry_steps):
		spawner.update(0.05)
	assert_almost_eq(enemy.global_position.y, y_at_spawn, 1.0,
		"BEFORE the entry-lock delay a homing enemy does NOT steer at the player (y unchanged)")
	assert_lt(enemy.global_position.x, scroller.rect.position.x + scroller.rect.size.x + 100.0,
		"during entry the enemy still slides in from the right (x decreasing)")


# --- 7. TASK-070: FRAME-CARRY + DWELL (moving scroller) -----------------------

## Build a spawner wired to a MOVING scroller + a spawn spy with an explicit wave. Auto-frees.
func _make_spawner_moving(spy: SpawnSpy, scroller: MovingScroller, waves: Array) -> ShmupSpawner:
	spy.parent = scroller
	var s := ShmupSpawnerScript.new() as ShmupSpawner
	s.set_scroller(scroller)
	s.spawn_callback = Callable(spy, "spawn")
	s.release_callback = Callable(spy, "release")
	s.waves = waves
	add_child_autofree(s)
	return s


func test_streamed_enemy_is_carried_right_with_the_advancing_frame() -> void:
	# FRAME-CARRY (non-tautological): with a scroller advancing right by dx each tick, a streamed
	# STRAIGHT enemy's WORLD x is carried right by ~dx on top of its (small) leftward pattern
	# step. Net per-tick x change is (dx - DRIFT_SPEED*delta) — POSITIVE here (dx dominates the
	# small cross-drift), so the enemy moves RIGHT in world. The PRE-change spawner (leftward-only,
	# no carry) would move it LEFT every tick, so this fails for the old behavior.
	var spy := SpawnSpy.new()
	var scroller := MovingScroller.new()
	scroller.rect = Rect2(0.0, 0.0, 1000.0, 600.0)
	scroller.dx_per_tick = 9.0   # 9 px/tick right; at 0.05s that's 180 px/s (the real scroll)
	add_child_autofree(scroller)
	var waves := [
		{"enemy_type": 0, "count": 1, "spacing": 0.5, "y_pattern": ShmupSpawner.YPattern.LINE,
			"t_start": 0.0, "motion": ShmupSpawner.MotionPattern.STRAIGHT},
	]
	var spawner := _make_spawner_moving(spy, scroller, waves)
	# Spawn the enemy (advance the rect before each update so the spawner sees a fresh delta).
	for i in range(2):
		scroller.advance()
		spawner.update(0.05)
	assert_eq(spy.spawns.size(), 1, "the enemy spawned")
	var enemy: Node2D = spy.spawns[0]["enemy"]
	var x_before := enemy.global_position.x
	# One more carried tick: the rect advances dx, the spawner must carry the enemy with it.
	scroller.advance()
	spawner.update(0.05)
	var x_after := enemy.global_position.x
	# The carry (dx=9) dominates the small leftward cross-drift, so net world x moved RIGHT.
	assert_gt(x_after, x_before,
		"a streamed enemy is carried RIGHT with the advancing frame (frame-carry beats the drift)")
	# And the carry is ~dx minus the small cross-drift (a few px), NOT a leftward-only step.
	assert_gt(x_after - x_before, scroller.dx_per_tick - 6.0,
		"the per-tick world carry is ~the frame's dx (relative motion = only the small cross-drift)")


func test_carried_enemy_dwells_far_longer_than_old_leftward_only_drift() -> void:
	# DWELL (non-tautological): a STRAIGHT enemy carried with the advancing frame survives MANY
	# more ticks before it exits the LEFT edge than the pre-change leftward-only drift would.
	# OLD behavior: enemy x decreases ~(DRIFT+relative-scroll) per tick and the left edge advances
	# right toward it -> released within a handful of ticks. NEW: the carry keeps it near the
	# frame, so only the tiny cross-drift erodes its lead -> it stays active far longer.
	var spy := SpawnSpy.new()
	var scroller := MovingScroller.new()
	scroller.rect = Rect2(0.0, 0.0, 1000.0, 600.0)
	scroller.dx_per_tick = 9.0
	add_child_autofree(scroller)
	var waves := [
		{"enemy_type": 0, "count": 1, "spacing": 0.5, "y_pattern": ShmupSpawner.YPattern.LINE,
			"t_start": 0.0, "motion": ShmupSpawner.MotionPattern.STRAIGHT},
	]
	var spawner := _make_spawner_moving(spy, scroller, waves)
	for i in range(2):
		scroller.advance()
		spawner.update(0.05)
	assert_eq(spy.spawns.size(), 1, "the enemy spawned")
	var enemy: Node2D = spy.spawns[0]["enemy"]
	# Drive 100 carried ticks (~5s). The OLD leftward-only enemy (no carry) would be long gone:
	# it crossed the ~1064px lead at ~250px/s relative in ~4.3s -> released well before 100 ticks.
	var still_active_at_100 := false
	for i in range(100):
		scroller.advance()
		spawner.update(0.05)
		if is_instance_valid(enemy) and enemy in spawner._active:
			still_active_at_100 = (i == 99)
	assert_true(still_active_at_100,
		"a frame-carried STRAIGHT enemy is STILL active after 100 ticks (it dwells; old drift exits)")
	assert_eq(spy.released.size(), 0,
		"the carried enemy has NOT been released within ~5s (dwell far exceeds the old ~4.6s)")


# --- 8. TASK-070: DENSITY + CONCURRENCY --------------------------------------

func test_default_waves_emit_many_more_enemies_spanning_the_level() -> void:
	# DENSITY: the reworked default wave table emits MANY more enemies (dozens, not 16) and its
	# last wave starts near the full ~36s level duration (LEVEL_LENGTH / SCROLL_SPEED), so the
	# back half of the level is no longer empty.
	var spawner := ShmupSpawnerScript.new() as ShmupSpawner
	add_child_autofree(spawner)
	var total := 0
	var last_t_start := 0.0
	for wave in spawner.waves:
		total += int(wave.get("count", 0))
		last_t_start = maxf(last_t_start, float(wave.get("t_start", 0.0)))
	assert_gte(total, 36,
		"the reworked default wave table emits MANY more enemies (>= 36, was 16)")
	# Level runs ~36s (LEVEL_LENGTH 6400 / SCROLL_SPEED 180 = ~35.5s); last wave starts late.
	var level_secs := Shmup01.LEVEL_LENGTH / ShmupScroller.SCROLL_SPEED
	assert_gte(last_t_start, level_secs * 0.7,
		"the last default wave starts in the BACK portion of the level (spans the full lane)")
	assert_lt(last_t_start, level_secs,
		"the last default wave still starts BEFORE the level ends")


func test_default_waves_keep_mixed_armor_and_mixed_motion() -> void:
	# Density must NOT collapse the variety: the default table still mixes BOTH armor types
	# (enemy_type 0 + 1) and multiple motion patterns (the enter-then-lock-on read is preserved).
	var spawner := ShmupSpawnerScript.new() as ShmupSpawner
	add_child_autofree(spawner)
	var types := {}
	var motions := {}
	for wave in spawner.waves:
		types[int(wave.get("enemy_type", 0))] = true
		motions[int(wave.get("motion", ShmupSpawner.MotionPattern.STRAIGHT))] = true
	assert_true(types.has(0) and types.has(1),
		"the default table mixes BOTH armor types (DD-006 element-swap read preserved)")
	assert_gte(motions.size(), 3,
		"the default table mixes >= 3 motion patterns (variety + enter-then-lock-on feel)")


func test_default_stream_puts_several_enemies_on_screen_at_once() -> void:
	# CONCURRENCY (non-tautological): drive the REAL default wave stream through time with the
	# moving scroller; at some tick several enemies (>= 4) are simultaneously active + inside the
	# visible rect. Pre-change (sparse waves + fast left-exit) only ever had ~1-2 at a time.
	var spy := SpawnSpy.new()
	var scroller := MovingScroller.new()
	scroller.rect = Rect2(0.0, 0.0, 1152.0, 648.0)   # a real-ish frame size
	scroller.dx_per_tick = 3.0   # 180 px/s at 1/60 dt
	add_child_autofree(scroller)
	var s := ShmupSpawnerScript.new() as ShmupSpawner
	spy.parent = scroller
	s.set_scroller(scroller)
	s.spawn_callback = Callable(spy, "spawn")
	s.release_callback = Callable(spy, "release")
	# Use the DEFAULT wave table (do NOT override s.waves) — this asserts the shipped density.
	add_child_autofree(s)
	var dt := 1.0 / 60.0
	var max_concurrent := 0
	# Drive the full level (~36s) and track peak simultaneous on-screen enemies.
	for i in range(60 * 38):
		scroller.advance()
		s.update(dt)
		var rect := scroller.visible_world_rect()
		var on_screen := 0
		for e in s._active:
			if e != null and is_instance_valid(e) and e is Node2D:
				var ex: float = (e as Node2D).global_position.x
				if ex >= rect.position.x and ex <= rect.position.x + rect.size.x:
					on_screen += 1
		max_concurrent = maxi(max_concurrent, on_screen)
	assert_gte(max_concurrent, 8,
		"the default stream puts >= 8 enemies on screen at once at peak (markedly fuller screen)")
