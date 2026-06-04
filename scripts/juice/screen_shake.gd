## TASK-010 hit-feedback: trauma-based screen shake on the Player's Camera2D.
##
## game-design SKILL "Game Feel / Juice": screen shake is reserved and SMALL for
## routine hits (loud shake is budgeted for the antimatter ultimate / boss blows).
## So `max_offset` here is deliberately tiny. The feel model is the standard
## trauma-squared shake (Nijman, "The Art of Screenshake"):
##   - `trauma` is clamped to [0, 1]; hits ADD trauma via add_trauma().
##   - offset magnitude = max_offset * trauma^2 (squared so small trauma is gentle).
##   - per-frame random direction (and a small optional rotation) so it reads as a
##     punch, not a slide; trauma DECAYS linearly to 0 over time each _process.
##
## The decay + offset-magnitude math is kept in STATIC pure functions
## (decay(), offset_magnitude()) so it is unit-testable with no rendered camera.
## Null-guards: this script attaches to a Camera2D but never hard-requires one to
## exist at runtime (the pure statics run anywhere).
class_name ScreenShake extends Node

## SMALL by design — routine hits should barely nudge the frame (juice budget).
@export var max_offset: float = 6.0
@export var max_roll: float = 0.05          # radians; tiny optional rotation
@export var decay_rate: float = 1.6         # trauma units lost per second

var trauma: float = 0.0

@onready var _camera: Camera2D = get_parent() as Camera2D


## Pure: linearly decay `trauma` by `rate * delta`, clamped so it never goes
## below 0 (and never above 1). Unit-tested without a scene.
static func decay(trauma_value: float, rate: float, delta: float) -> float:
	return clampf(trauma_value - rate * delta, 0.0, 1.0)


## Pure: trauma-squared offset magnitude. Squaring makes low trauma gentle and
## high trauma punchy; result is always >= 0 and scales with max_offset.
static func offset_magnitude(trauma_value: float, max_off: float) -> float:
	var t := clampf(trauma_value, 0.0, 1.0)
	return max_off * t * t


## Add trauma on a hit (clamped). Callers scale `amount` by damage/effectiveness.
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if trauma <= 0.0:
		if _camera != null:
			_camera.offset = Vector2.ZERO
			_camera.rotation = 0.0
		return
	trauma = decay(trauma, decay_rate, delta)
	if _camera == null:
		return
	var mag := offset_magnitude(trauma, max_offset)
	var angle := randf_range(0.0, TAU)
	_camera.offset = Vector2(cos(angle), sin(angle)) * mag
	_camera.rotation = max_roll * (trauma * trauma) * randf_range(-1.0, 1.0)
