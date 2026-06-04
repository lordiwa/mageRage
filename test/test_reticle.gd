## Reticle positioning math + cast-direction wiring (headless).
##
## - reticle_local_position(aim) orbits the player: aim * AIM_RADIUS.
## - Integration: a fake MagicManager records the (origin, direction) of casts.
##   We set the player's aim to a DIAGONAL and trigger a cast; the recorded
##   direction must equal `_aim`, proving the wiring uses the aim vector and not
##   the old horizontal `Vector2(facing, 0)`.
extends GutTest

var player: Player
var fake_magic: Node


## A drop-in MagicManager double named "MagicManager" so the Player's
## @onready `_magic` lookup finds it on _ready. Extends the real MagicManager so
## the Player's typed `@onready var _magic: MagicManager` assignment is valid (a
## plain Node fake tripped a "Trying to assign value of type '' to a variable of
## type 'magic_manager.gd'" engine error at player.gd:52). The inherited _ready is
## harmless here (empty `spells` -> null loadout); we only override the cast hooks
## to record direction. Records the last cast direction.
class FakeMagicManager:
	extends MagicManager
	var last_primary_dir := Vector2.ZERO
	var last_secondary_dir := Vector2.ZERO
	var last_origin: Node2D = null
	var primary_casts := 0

	func cast_primary(origin: Node2D, direction: Vector2) -> bool:
		last_origin = origin
		last_primary_dir = direction
		primary_casts += 1
		return true

	func cast_secondary(origin: Node2D, direction: Vector2) -> bool:
		last_origin = origin
		last_secondary_dir = direction
		return true

	# Player._process_magic also regenerates mana / selects elements via these on
	# the manager? No — those go through Mana (absent here) and the manager's
	# select(); provide a no-op select so element-key polling can't crash.
	func select(_index: int) -> void:
		pass


func before_each() -> void:
	player = Player.new()
	# Inject the fake BEFORE add_child so the Player's _ready @onready resolves it.
	fake_magic = FakeMagicManager.new()
	fake_magic.name = "MagicManager"
	player.add_child(fake_magic)
	add_child_autofree(player)


func test_reticle_local_position_orbits_at_radius() -> void:
	var up := player.reticle_local_position(Vector2.UP)
	assert_almost_eq(up.x, 0.0, 0.001)
	assert_almost_eq(up.y, -Player.AIM_RADIUS, 0.001,
		"reticle orbits straight up at AIM_RADIUS")

	var right := player.reticle_local_position(Vector2.RIGHT)
	assert_almost_eq(right.x, Player.AIM_RADIUS, 0.001,
		"reticle orbits right at AIM_RADIUS")

	# Diagonal unit aim lands on the orbit circle at AIM_RADIUS.
	var diag := player.reticle_local_position(Vector2(1, 1).normalized())
	assert_almost_eq(diag.length(), Player.AIM_RADIUS, 0.001,
		"reticle stays on the orbit circle for diagonal aim")


func test_cast_uses_aim_vector_not_horizontal_facing() -> void:
	# Diagonal aim with an active device; facing is +1 (would be Vector2(1,0)
	# under the old behavior). The recorded cast direction must be the diagonal.
	var diagonal := Vector2(1, -1).normalized()
	player.facing = 1.0
	player.set_aim_for_test(diagonal, Player.AimDevice.PAD)
	player.cast_primary_for_test()

	assert_eq(fake_magic.primary_casts, 1, "primary cast fired once")
	assert_almost_eq(fake_magic.last_primary_dir.x, diagonal.x, 0.001,
		"cast direction x equals the aim vector, not facing")
	assert_almost_eq(fake_magic.last_primary_dir.y, diagonal.y, 0.001,
		"cast direction y equals the aim vector (vertical component preserved)")
