## TASK-014 combat readability: the SINGLE SOURCE OF TRUTH for how a player
## projectile looks per element. Pure, static, scene-free so it unit-tests as
## data: SpellData.Element -> { "color": Color, "shape": int }.
##
## Game-design doctrine "Readable VFX over noise": a shot must telegraph its
## element at a glance in BOTH color and silhouette, so each element maps to a
## distinct tint AND a distinct polygon shape. The tints reuse the established
## element color language (matching scripts/juice/impact_spark.gd ELEMENT_TINT and
## the drone armor tints) so a shot and its impact read as one element. An unknown
## / out-of-range element falls back to a safe DEFAULT style.
class_name ProjectileStyle extends RefCounted

# --- Element color language (must match impact_spark.gd ELEMENT_TINT) ---------
const FIRE_COLOR := Color(1.0, 0.55, 0.20, 1.0)         # warm orange
const ICE_COLOR := Color(0.45, 0.80, 1.0, 1.0)          # cold cyan
const ELECTRICITY_COLOR := Color(1.0, 0.95, 0.35, 1.0)  # arc yellow
const ANTIMATTER_COLOR := Color(0.75, 0.35, 1.0, 1.0)   # violet
const DEFAULT_COLOR := Color(1.0, 1.0, 1.0, 1.0)        # safe fallback (white)

# --- TASK-040 / DD-013 dual-cast COMBO readouts -------------------------------
# Each blended combo reads as its OWN distinct thing, never as a base element.
# Kept legible (clearly tinted, clearly apart from Fire/Ice/Electricity).
const STEAM_COLOR := Color(1.0, 0.95, 0.92, 1.0)        # white-hot (Fire+Ice shatter)
const PLASMA_COLOR := Color(0.95, 0.30, 0.90, 1.0)      # violet/magenta (Fire+Elec)
const FROSTARC_COLOR := Color(0.70, 0.98, 1.0, 1.0)     # cyan-white (Ice+Elec)

# --- Silhouette ids. Each element gets its own readable shape. ---------------
enum {
	SHAPE_DEFAULT,      # neutral diamond (fallback)
	SHAPE_FIRE,         # warm rounded teardrop bolt
	SHAPE_ICE,          # angular shard
	SHAPE_ELECTRICITY,  # jagged arc bolt
	SHAPE_ANTIMATTER,   # pinched star/void
	SHAPE_STEAM,        # DD-013 combo: blooming burst (Fire+Ice thermal shock)
	SHAPE_PLASMA,       # DD-013 combo: spiked orb (Fire+Elec overload)
	SHAPE_FROSTARC,     # DD-013 combo: forked arc (Ice+Elec superconductor)
}
const DEFAULT_SHAPE := SHAPE_DEFAULT

const _STYLES := {
	SpellData.Element.FIRE: {"color": FIRE_COLOR, "shape": SHAPE_FIRE},
	SpellData.Element.ICE: {"color": ICE_COLOR, "shape": SHAPE_ICE},
	SpellData.Element.ELECTRICITY: {"color": ELECTRICITY_COLOR, "shape": SHAPE_ELECTRICITY},
	SpellData.Element.ANTIMATTER: {"color": ANTIMATTER_COLOR, "shape": SHAPE_ANTIMATTER},
	# DD-013 combos reuse the same element-keyed style table.
	SpellData.Element.STEAM: {"color": STEAM_COLOR, "shape": SHAPE_STEAM},
	SpellData.Element.PLASMA: {"color": PLASMA_COLOR, "shape": SHAPE_PLASMA},
	SpellData.Element.FROSTARC: {"color": FROSTARC_COLOR, "shape": SHAPE_FROSTARC},
}


## Pure: map a SpellData.Element to its { "color": Color, "shape": int } style.
## Unknown / out-of-range elements return the safe default style.
static func for_element(element: int) -> Dictionary:
	return _STYLES.get(element, {"color": DEFAULT_COLOR, "shape": DEFAULT_SHAPE})


## Pure: the local-space polygon (PackedVector2Array) for a shape id. The shot
## travels along +X (rotation faces the aim), so silhouettes point right. Sized to
## roughly the r=6 collision circle. Placeholder primitives, no external art.
static func polygon_for(shape: int) -> PackedVector2Array:
	match shape:
		SHAPE_FIRE:
			# Rounded teardrop bolt: blunt tail, tapering point ahead.
			return PackedVector2Array([
				Vector2(8, 0), Vector2(2, 5), Vector2(-5, 4),
				Vector2(-7, 0), Vector2(-5, -4), Vector2(2, -5),
			])
		SHAPE_ICE:
			# Angular shard: long pointed crystal.
			return PackedVector2Array([
				Vector2(9, 0), Vector2(0, 4), Vector2(-6, 2),
				Vector2(-6, -2), Vector2(0, -4),
			])
		SHAPE_ELECTRICITY:
			# Jagged arc bolt: zig-zag lightning silhouette.
			return PackedVector2Array([
				Vector2(9, -1), Vector2(1, 2), Vector2(4, 4),
				Vector2(-7, 1), Vector2(0, -2), Vector2(-3, -4),
			])
		SHAPE_ANTIMATTER:
			# Pinched four-point star / void mote.
			return PackedVector2Array([
				Vector2(7, 0), Vector2(2, 2), Vector2(0, 6),
				Vector2(-2, 2), Vector2(-6, 0), Vector2(-2, -2),
				Vector2(0, -6), Vector2(2, -2),
			])
		SHAPE_STEAM:
			# DD-013 STEAM: a blooming, rounded burst (heavy thermal-shock head).
			return PackedVector2Array([
				Vector2(8, 0), Vector2(4, 5), Vector2(-2, 6),
				Vector2(-7, 2), Vector2(-7, -2), Vector2(-2, -6), Vector2(4, -5),
			])
		SHAPE_PLASMA:
			# DD-013 PLASMA: a spiked orb (explosive overload arc).
			return PackedVector2Array([
				Vector2(8, 0), Vector2(3, 3), Vector2(4, 6),
				Vector2(-2, 3), Vector2(-7, 0), Vector2(-2, -3),
				Vector2(4, -6), Vector2(3, -3),
			])
		SHAPE_FROSTARC:
			# DD-013 FROSTARC: a forked arc (chilled superconductor bolt).
			return PackedVector2Array([
				Vector2(9, 1), Vector2(2, 3), Vector2(5, 5),
				Vector2(-6, 2), Vector2(-2, 0), Vector2(-6, -2),
				Vector2(5, -5), Vector2(2, -3),
			])
		_:
			# Neutral diamond fallback.
			return PackedVector2Array([
				Vector2(6, 0), Vector2(0, 6), Vector2(-6, 0), Vector2(0, -6),
			])
