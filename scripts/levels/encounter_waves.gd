## TASK-021 EncounterWaves — the DATA design for the encounter room's three waves.
##
## This is the single source of truth shared by the live spawner (`encounter.gd`)
## and the unit test (`test_wave_controller.gd`): the controller spawns from it, the
## test asserts the DD-004 composition guarantee (every wave mixes >=2 armor types)
## against it. Because both read the SAME data, the "no single-element-dominated
## wave" property is genuinely tested, not duplicated.
##
## Each wave is an Array of entry Dictionaries:
##   { "scene": String (res:// path), "armor_type": SpellData.Element, "position": Vector2 }
##
## Design (ramp-then-rest; armor element enum FIRE=0, ICE=1, ELECTRICITY=2; matchup:
## FIRE armor weak to ELECTRICITY, ICE weak to FIRE, ELECTRICITY weak to ICE):
##   Wave 1 (teach/light): a FIRE drone + an ICE drone — forces Electricity vs Fire.
##   Wave 2 (pressure):    the Charger (FIRE, weak Electricity) + a Shield Drone
##                         (ICE, weak Fire) — two different weaknesses at once.
##   Wave 3 (kit test):    a SwarmGroup (FIRE swarmlings — Electricity chain clears
##                         them) + an ELECTRICITY drone (weak Ice) — Electricity for
##                         the swarm, Ice for the drone.
class_name EncounterWaves extends RefCounted

const DRONE := "res://scenes/empire_drone.tscn"
const CHARGER := "res://scenes/charger.tscn"
const SHIELD := "res://scenes/shield_drone.tscn"
const SWARM := "res://scenes/swarm_group.tscn"

const FIRE := SpellData.Element.FIRE
const ICE := SpellData.Element.ICE
const ELEC := SpellData.Element.ELECTRICITY

## The bounded wave list. Floor sits at y ~= 320 (see encounter.tscn); grounded
## enemies (Charger / Swarm) spawn near the floor, flying drones a bit higher.
const WAVES: Array = [
	# Wave 1 — teach: one Fire-armored, one Ice-armored flying drone (2 distinct).
	[
		{ "scene": DRONE, "armor_type": FIRE, "position": Vector2(820, 200) },
		{ "scene": DRONE, "armor_type": ICE,  "position": Vector2(1040, 160) },
	],
	# Wave 2 — pressure: grounded Charger (Fire) + Shield Drone (Ice) — two weaknesses.
	[
		{ "scene": CHARGER, "armor_type": FIRE, "position": Vector2(980, 290) },
		{ "scene": SHIELD,  "armor_type": ICE,  "position": Vector2(760, 180) },
	],
	# Wave 3 — kit test: Fire swarm (Electricity chain) + Electricity drone (weak Ice).
	[
		{ "scene": SWARM, "armor_type": FIRE, "position": Vector2(900, 300) },
		{ "scene": DRONE, "armor_type": ELEC, "position": Vector2(1080, 170) },
	],
]


## Collect the armor types of one wave (an Array of entry dicts) — used by the
## composition-guarantee test and by readability tooling.
static func armor_types_of(wave: Array) -> Array:
	var out: Array = []
	for entry in wave:
		out.append(entry.get("armor_type", -1))
	return out
