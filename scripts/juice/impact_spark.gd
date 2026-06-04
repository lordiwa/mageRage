## TASK-010 hit-feedback: a one-shot impact spark burst at the contact point,
## tinted by the spell's element color so the hit stays readable in chaos
## (game-design SKILL: element color language — Fire warm, Ice cold, Elec arc).
## PLACEHOLDER CPUParticles2D (no art asset); emits once then frees.
extends CPUParticles2D

## Element color language, matching the drone armor tints for consistency.
const ELEMENT_TINT := {
	SpellData.Element.FIRE: Color(1.0, 0.55, 0.20, 1.0),
	SpellData.Element.ICE: Color(0.45, 0.80, 1.0, 1.0),
	SpellData.Element.ELECTRICITY: Color(1.0, 0.95, 0.35, 1.0),
	SpellData.Element.ANTIMATTER: Color(0.75, 0.35, 1.0, 1.0),
}


## Tint by the spell element and fire the one-shot burst. Frees after emitting.
func burst(element: int) -> void:
	color = ELEMENT_TINT.get(element, Color.WHITE)
	one_shot = true
	emitting = true
	# Free once the longest particle has lived out its lifetime.
	var ttl := lifetime + 0.1
	get_tree().create_timer(ttl).timeout.connect(queue_free)
