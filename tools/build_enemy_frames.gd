@tool
extends SceneTree

## TASK-056: Build the SpriteFrames resources for the 3 sector_02 combat enemies
## from the committed assets/sprites/enemies/ PNGs (EAST frames only; west via
## flip_h at runtime, mirroring the hero pipeline TASK-052). Reproducible:
## re-running produces the same output from the same source PNGs.
##
## Outputs:
##   res://resources/enemies/empire_drone_frames.tres
##   res://resources/enemies/shield_drone_frames.tres
##   res://resources/enemies/charger_frames.tres
##
## Per-animation frame counts (from disk):
##   empire_drone / shield_drone: idle 4, walk 6, attack 6, hurt 6
##   charger:                     idle 4, walk 6, windup 5, charge 6, hurt 6
##
## Loop flags + fps (fps are a sensible first pass; fine-tuning is a later DIRECT
## playtest tweak per the ticket):
##   idle   — loop, 6 fps   (ambient breathing)
##   walk   — loop, 8 fps   (locomotion)
##   attack — one-shot, 12 fps  (drone cast pose)
##   hurt   — one-shot, 10 fps  (taking-punch reaction)
##   windup — one-shot, 8 fps   (charger telegraph tell)
##   charge — one-shot, 10 fps  (charger lunge)
##
## Run headless:
##   Godot --headless --path <repo> -s res://tools/build_enemy_frames.gd

const OUT_DIR := "res://resources/enemies"
const BASE := "res://assets/sprites/enemies"

## anim -> [frame_count, fps, loop]
const DRONE_MAP := {
	"idle": [4, 6.0, true],
	"walk": [6, 8.0, true],
	"attack": [6, 12.0, false],
	"hurt": [6, 10.0, false],
}

const CHARGER_MAP := {
	"idle": [4, 6.0, true],
	"walk": [6, 8.0, true],
	"windup": [5, 8.0, false],
	"charge": [6, 10.0, false],
	"hurt": [6, 10.0, false],
}


func _build_one(enemy: String, anim_map: Dictionary) -> int:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for anim in anim_map:
		var spec: Array = anim_map[anim]
		var count: int = spec[0]
		var fps: float = spec[1]
		var loop: bool = spec[2]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, fps)
		sf.set_animation_loop(anim, loop)
		for i in range(count):
			var path := "%s/%s/%s/frame_%s.png" % [BASE, enemy, anim, str(i).pad_zeros(3)]
			var tex: Texture2D = load(path)
			if tex == null:
				push_error("Missing texture: %s" % path)
				return ERR_FILE_NOT_FOUND
			sf.add_frame(anim, tex)
	var out_path := "%s/%s_frames.tres" % [OUT_DIR, enemy]
	var err := ResourceSaver.save(sf, out_path)
	if err != OK:
		push_error("ResourceSaver.save() failed for %s: %d" % [out_path, err])
		return err
	print("BUILT %s with animations: %s" % [out_path, ", ".join(sf.get_animation_names())])
	return OK


func _init() -> void:
	# Ensure the output directory exists.
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUT_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var jobs := {
		"empire_drone": DRONE_MAP,
		"shield_drone": DRONE_MAP,
		"charger": CHARGER_MAP,
	}
	for enemy in jobs:
		var err := _build_one(enemy, jobs[enemy])
		if err != OK:
			quit(1)
			return
	quit(0)
