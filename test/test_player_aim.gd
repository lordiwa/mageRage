## Twin-stick aiming logic on the Player (pure, headless — no rendered scene).
##
## Covers the aim math (`aim_from_point`), the NONE-device fallback to
## `Vector2(facing, 0)`, last-aim persistence, `is_aiming()`, and facing being
## driven by horizontal aim but NOT by pure-vertical aim. The Player's combat /
## muzzle children are optional (null-guarded), so a bare Player.new() works.
extends GutTest

var player: Player


func before_each() -> void:
	player = Player.new()
	add_child_autofree(player)   # _ready: collision setup + record_spawn


func test_aim_from_point_points_up() -> void:
	var aim := player.aim_from_point(Vector2.ZERO, Vector2(0, -10))
	assert_almost_eq(aim.x, 0.0, 0.001, "straight-up aim has no x")
	assert_almost_eq(aim.y, -1.0, 0.001, "straight-up aim normalizes to Vector2.UP")


func test_aim_from_point_normalizes_diagonal() -> void:
	var aim := player.aim_from_point(Vector2.ZERO, Vector2(10, 10))
	var s := sqrt(0.5)
	assert_almost_eq(aim.x, s, 0.001, "diagonal aim x normalizes")
	assert_almost_eq(aim.y, s, 0.001, "diagonal aim y normalizes")
	assert_almost_eq(aim.length(), 1.0, 0.001, "aim_from_point returns a unit vector")


func test_aim_from_point_degenerate_falls_back_to_facing() -> void:
	# Same origin and target => zero vector; fall back to the facing direction.
	player.facing = 1.0
	var right := player.aim_from_point(Vector2(5, 5), Vector2(5, 5))
	assert_almost_eq(right.x, 1.0, 0.001, "degenerate aim falls back to facing +1 -> right")
	assert_almost_eq(right.y, 0.0, 0.001)
	player.facing = -1.0
	var left := player.aim_from_point(Vector2(5, 5), Vector2(5, 5))
	assert_almost_eq(left.x, -1.0, 0.001, "degenerate aim falls back to facing -1 -> left")


func test_aim_direction_defaults_to_facing_when_device_none() -> void:
	# Before any aim input (_aim_device == NONE) keyboard-only casting behaves
	# like today: aim follows facing.
	player.facing = 1.0
	var right := player.aim_direction()
	assert_almost_eq(right.x, 1.0, 0.001, "NONE device + facing +1 aims right")
	assert_almost_eq(right.y, 0.0, 0.001)

	player.facing = -1.0
	var left := player.aim_direction()
	assert_almost_eq(left.x, -1.0, 0.001, "NONE device + facing -1 aims left")


func test_is_aiming_false_until_a_device_is_used() -> void:
	assert_false(player.is_aiming(), "no aim device used yet => not aiming")


func test_last_aim_persists_with_no_new_input() -> void:
	# Simulate an active device with a remembered aim, then no new input: the
	# previous aim must persist (do not snap back to facing).
	player.set_aim_for_test(Vector2(0, -1), Player.AimDevice.PAD)
	# No gamepad/mouse input present in the headless run, so aim_direction()
	# should return the remembered vector.
	var kept := player.aim_direction()
	assert_almost_eq(kept.x, 0.0, 0.001, "persisted aim keeps x")
	assert_almost_eq(kept.y, -1.0, 0.001, "persisted aim keeps y (no snap-back to facing)")
	assert_true(player.is_aiming(), "an active device keeps is_aiming() true")


func test_horizontal_aim_drives_facing() -> void:
	# A horizontal aim while a device is active flips facing accordingly.
	player.facing = 1.0
	player.set_aim_for_test(Vector2.LEFT, Player.AimDevice.PAD)
	player.apply_aim_to_facing()
	assert_eq(player.facing, -1.0, "aiming left sets facing to -1")

	player.set_aim_for_test(Vector2.RIGHT, Player.AimDevice.PAD)
	player.apply_aim_to_facing()
	assert_eq(player.facing, 1.0, "aiming right sets facing to +1")


func test_vertical_aim_does_not_flip_facing() -> void:
	# Pure up/down aim must NOT disturb facing (no x to read sign from).
	player.facing = 1.0
	player.set_aim_for_test(Vector2.UP, Player.AimDevice.PAD)
	player.apply_aim_to_facing()
	assert_eq(player.facing, 1.0, "straight-up aim leaves facing +1 unchanged")

	player.facing = -1.0
	player.set_aim_for_test(Vector2.DOWN, Player.AimDevice.PAD)
	player.apply_aim_to_facing()
	assert_eq(player.facing, -1.0, "straight-down aim leaves facing -1 unchanged")


func test_facing_unchanged_when_not_aiming() -> void:
	# With no device (NONE), apply_aim_to_facing() must not touch facing even if
	# _aim happens to be horizontal.
	player.facing = 1.0
	player.set_aim_for_test(Vector2.LEFT, Player.AimDevice.NONE)
	player.apply_aim_to_facing()
	assert_eq(player.facing, 1.0, "not aiming => FSM owns facing, aim must not flip it")
