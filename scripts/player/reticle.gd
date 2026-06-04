## Twin-stick crosshair ("mira"). A purely cosmetic Node2D the Player positions
## each frame (orbiting at AIM_RADIUS for stick aim, or snapped to the cursor for
## mouse aim). Draws a simple ring + cross in the project's flat-color aesthetic.
##
## Drawing-only: it owns no aim logic — the Player computes the aim vector and
## sets this node's position/global_position.
class_name Reticle extends Node2D

## Gold to echo the FacingMark accent (Color(1, 0.85, 0.3)).
const COLOR := Color(1, 0.85, 0.3, 0.9)
const RADIUS := 7.0          # ring radius
const GAP := 3.0             # inner gap of the cross arms
const ARM := 6.0             # outer reach of the cross arms
const THICKNESS := 2.0

func _draw() -> void:
	# Ring.
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, COLOR, THICKNESS, true)
	# Four cross arms (gap in the middle so the center stays open).
	draw_line(Vector2(GAP, 0), Vector2(ARM, 0), COLOR, THICKNESS, true)
	draw_line(Vector2(-GAP, 0), Vector2(-ARM, 0), COLOR, THICKNESS, true)
	draw_line(Vector2(0, GAP), Vector2(0, ARM), COLOR, THICKNESS, true)
	draw_line(Vector2(0, -GAP), Vector2(0, -ARM), COLOR, THICKNESS, true)
