## TASK-010 hit-feedback: color/size coding for floating damage numbers, driven
## off the DD-006 effectiveness multiplier so the number REINFORCES armor
## readability (game-design SKILL: "Juice must never bury the RPS read" — here it
## actively serves it).
##
## DD-006 multipliers are 0.5 (resisted) / 1.0 (neutral) / 1.5 (weak / super-
## effective). We bucket on the multiplier so the player learns the matchup from
## the feel of the hit:
##   - resisted     (<= 0.75): dim grey,  smaller  -> "that barely worked, swap"
##   - neutral      (~ 1.0)  : white,      normal
##   - super (weak) (>= 1.25): bright orange, larger -> "yes — correct element"
##
## Pure, static, table-free thresholds so the three tiers map to DISTINCT colors
## and scales and can be unit-tested with no scene.
class_name DamageStyle extends RefCounted

const RESISTED_THRESHOLD := 0.75
const SUPER_THRESHOLD := 1.25

const RESISTED_COLOR := Color(0.6, 0.6, 0.6, 1.0)     # dim grey
const NEUTRAL_COLOR := Color(1.0, 1.0, 1.0, 1.0)      # white
const SUPER_COLOR := Color(1.0, 0.55, 0.15, 1.0)      # bright orange/red

const RESISTED_SCALE := 0.8
const NEUTRAL_SCALE := 1.0
const SUPER_SCALE := 1.4


## Pure: map a DD-006 effectiveness multiplier to a {color, scale} style.
## Returns a Dictionary { "color": Color, "scale": float }.
static func for_effectiveness(mult: float) -> Dictionary:
	if mult <= RESISTED_THRESHOLD:
		return {"color": RESISTED_COLOR, "scale": RESISTED_SCALE}
	if mult >= SUPER_THRESHOLD:
		return {"color": SUPER_COLOR, "scale": SUPER_SCALE}
	return {"color": NEUTRAL_COLOR, "scale": NEUTRAL_SCALE}
