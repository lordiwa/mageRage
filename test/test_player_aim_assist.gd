## DD-012 aim-assist WIRING on the Player (headless, no physics, no Input).
##
## Criterion 2/3/4: the assist is wired into the cast aim via the cast_aim() seam
## (which cast_primary/cast_secondary use), it reads live enemies from the
## "enemies" group, it leaves the raw _aim (movement/facing) untouched, manual aim
## outside the cone is respected, and the cone/range are @export tunables (so
## setting the cone to 0 disables the assist). No await / no physics frame — the
## Player's combat children are optional, so a bare Player.new() exercises the
## pure wiring deterministically.
extends GutTest

var player: Player


# A minimal Node2D placed in the "enemies" group at a world position, so
# Player._gather_enemy_positions() picks it up exactly like a real drone.
func _spawn_enemy(at: Vector2) -> Node2D:
	var e := Node2D.new()
	e.global_position = at
	e.add_to_group("enemies")
	add_child_autofree(e)
	return e


func before_each() -> void:
	player = Player.new()
	add_child_autofree(player)
	player.global_position = Vector2.ZERO


# --- Criterion 2: cast aim biases toward a roughly-aimed-at enemy ------------

func test_cast_aim_biases_toward_enemy_in_cone() -> void:
	# Enemy just off the aim (5deg, inside the inner cone) and in range: the cast
	# aim snaps onto it while the raw _aim stays put.
	_spawn_enemy(Vector2.RIGHT.rotated(deg_to_rad(5.0)) * 200.0)
	player.set_aim_for_test(Vector2.RIGHT, Player.AimDevice.PAD)
	var cast := player.cast_aim()
	assert_almost_eq(cast.angle(), deg_to_rad(5.0), 0.01,
		"cast_aim() biases toward an enemy inside the cone+range")


func test_raw_aim_untouched_by_assist() -> void:
	# The assist must NOT mutate _aim (movement / facing read the raw manual aim).
	_spawn_enemy(Vector2.RIGHT.rotated(deg_to_rad(5.0)) * 200.0)
	player.set_aim_for_test(Vector2.RIGHT, Player.AimDevice.PAD)
	var _cast := player.cast_aim()
	assert_almost_eq(player._aim.angle(), 0.0, 0.001,
		"the raw _aim is left untouched by the assist")


# --- Criterion 2: manual aim outside the cone is respected ------------------

func test_manual_aim_outside_cone_respected() -> void:
	# Enemy at 45deg, well outside the 20deg cone: the player is deliberately
	# aiming elsewhere, so the cast aim equals the raw aim (no pull).
	_spawn_enemy(Vector2.RIGHT.rotated(deg_to_rad(45.0)) * 200.0)
	player.set_aim_for_test(Vector2.RIGHT, Player.AimDevice.PAD)
	var cast := player.cast_aim()
	assert_almost_eq(cast.angle(), 0.0, 0.001,
		"an enemy outside the cone does not pull the cast aim (manual aim respected)")


func test_no_enemies_cast_aim_equals_raw() -> void:
	player.set_aim_for_test(Vector2.UP, Player.AimDevice.PAD)
	var cast := player.cast_aim()
	assert_almost_eq(cast.angle(), Vector2.UP.angle(), 0.001,
		"with no enemies the cast aim equals the raw aim")


# --- Criterion 4: cone is a tunable that can disable the assist --------------

func test_zero_cone_disables_assist() -> void:
	# A would-be-assisted enemy is present, but a 0 outer cone disables the assist.
	_spawn_enemy(Vector2.RIGHT.rotated(deg_to_rad(5.0)) * 200.0)
	player.aim_assist_cone_deg = 0.0
	player.set_aim_for_test(Vector2.RIGHT, Player.AimDevice.PAD)
	var cast := player.cast_aim()
	assert_almost_eq(cast.angle(), 0.0, 0.001,
		"setting the outer cone to 0 disables the assist (raw aim returned)")


func test_assist_tunables_exist_with_provisional_defaults() -> void:
	# Criterion 4: named @export tunables, not buried magic numbers.
	assert_eq(player.aim_assist_cone_deg, 20.0, "outer cone default (DD-012 provisional)")
	assert_eq(player.aim_assist_inner_cone_deg, 8.0, "inner cone default (DD-012 provisional)")
	assert_eq(player.aim_assist_range, 400.0, "range default (DD-012 provisional)")


# --- Criterion 3: the reticle reflects the assisted direction ---------------

func test_reticle_reflects_assisted_direction() -> void:
	# Give the Player a Reticle child, aim at +X with an enemy inside the inner
	# cone, then drive the reticle update with the assisted aim (as _process does).
	# The orbiting reticle (PAD aim) must sit along the ASSISTED direction, not the
	# raw aim -- so the crosshair shows where the magnetized shot will go (DD-012).
	var reticle := Reticle.new()
	reticle.name = "Reticle"
	player.add_child(reticle)
	# _reticle is wired via @onready at _ready(), which already ran when the bare
	# Player was added in before_each(); assign the child the update reads from.
	player._reticle = reticle
	_spawn_enemy(Vector2.RIGHT.rotated(deg_to_rad(5.0)) * 200.0)
	player.set_aim_for_test(Vector2.RIGHT, Player.AimDevice.PAD)

	var assisted := player.cast_aim()
	player._update_reticle(assisted)

	# Local orbit position points along the assisted aim, not the raw +X.
	assert_almost_eq(reticle.position.angle(), deg_to_rad(5.0), 0.01,
		"the reticle orbits along the assisted aim direction")
	assert_almost_ne(reticle.position.angle(), 0.0, 0.01,
		"the reticle is NOT left on the raw (unassisted) +X aim")
