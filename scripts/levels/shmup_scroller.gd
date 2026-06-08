## Auto-scroll camera for the shoot-em-up mode (TASK-065, DD-014).
##
## A Camera2D that advances CONSTANTLY to the right at SCROLL_SPEED — the classic
## horizontal-shmup constraint: the world scrolls past while the hero is clamped into the
## visible frame (the clamp lives in the level controller, fed by visible_world_rect() +
## the pure clamp_point_to_rect() helper). Scoped entirely to shmup_01.tscn; the sectors keep
## their player-mounted, limit-clamped Camera2D untouched.
##
## The advance is exposed as advance(delta) (NOT buried in _physics_process) so the scroll is
## UNIT-TESTABLE DETERMINISTICALLY — no reliance on real frames (the GUT flake footgun). The
## node calls advance(delta) itself each physics tick in game; tests call it directly.
class_name ShmupScroller extends Camera2D

## Constant rightward scroll speed (px/s). A named, tunable foundation constant — the shmup
## pace knob. Deliberately below FlightState.FLY_SPEED (260) so the hero keeps authority to
## maneuver WITHIN the advancing frame rather than being pinned to the right wall. Tuning of
## the exact feel (and the win-distance) is TASK-067.
const SCROLL_SPEED := 180.0


func _physics_process(delta: float) -> void:
	advance(delta)


## Advance the camera one physics tick: carry it rightward by SCROLL_SPEED * delta. ONLY x
## moves (the horizontal-shmup constraint). Pure side-effect on global_position so a test can
## call it directly and assert the exact displacement with no frames.
func advance(delta: float) -> void:
	global_position.x += SCROLL_SPEED * delta


## The camera's visible world rect — the box the level controller clamps the player into.
## Derived from the viewport size and the camera zoom (NOT magic numbers): the visible world
## span is viewport_size / zoom, centered on the camera position (our scene uses the default
## drag-center anchor, so the camera sits at the rect center). Carries the player rightward
## as the camera advances.
func visible_world_rect() -> Rect2:
	var view_size: Vector2 = get_viewport_rect().size
	# zoom MAGNIFIES, so the visible world span is the viewport size divided by the zoom.
	var world_size := view_size / zoom
	var top_left := global_position - world_size * 0.5
	return Rect2(top_left, world_size)


## Pure helper: clamp `point` to lie inside `rect`, component-wise. A point past any edge is
## pulled exactly to that edge; an inside point is unchanged. Used to carry the player with
## the advancing frame without letting it leave the screen. Static + frame-free so it is
## trivially unit-testable.
static func clamp_point_to_rect(point: Vector2, rect: Rect2) -> Vector2:
	return Vector2(
		clampf(point.x, rect.position.x, rect.position.x + rect.size.x),
		clampf(point.y, rect.position.y, rect.position.y + rect.size.y),
	)
