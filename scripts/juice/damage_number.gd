## TASK-010 hit-feedback: a floating damage number. A Label that spawns at the
## drone, floats up while fading (tween), then frees itself. Color/size are coded
## by DD-006 effectiveness via the pure DamageStyle.for_effectiveness(), so the
## number reinforces the armor read (game-design SKILL: juice serves the RPS).
##
## PLACEHOLDER text only (default font); no art/audio assets.
extends Label

const FLOAT_HEIGHT := 28.0     # px the number drifts upward
const LIFETIME := 0.6          # seconds before it frees


## Spawn-time setup: set the text from the damage, style by effectiveness.
## `effectiveness` is the DD-006 multiplier (0.5 / 1.0 / 1.5).
func setup(amount: float, effectiveness: float) -> void:
	text = str(int(round(amount)))
	var style := DamageStyle.for_effectiveness(effectiveness)
	modulate = style["color"]
	var s: float = style["scale"]
	scale = Vector2(s, s)
	# Center-ish anchoring for the placeholder label.
	pivot_offset = size * 0.5


func _ready() -> void:
	var start := position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", start + Vector2(0, -FLOAT_HEIGHT), LIFETIME)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME)
	tween.chain().tween_callback(queue_free)
