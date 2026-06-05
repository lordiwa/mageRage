@tool
extends SceneTree

## Build resources/hero/hero_frames.tres (SpriteFrames) from the committed
## assets/sprites/hero/ PNGs (EAST frames only). Reproducible: re-running
## produces the same output from the same source PNGs.
##
## Animation mapping (per TASK-052 design decisions):
##   idle   — "shifts_weight" breath (9f, loop, 8 fps)
##   walk   — "Walking" (4f, loop, 8 fps)
##   jump   — "Two-Footed_Jump" rising frames f0..f2 (3f, no loop, 8 fps)
##   fall   — "Two-Footed_Jump" descending frames f4..f6 (3f, no loop, 8 fps)
##            [f3 is the apex; rising frames show upward motion; descending show
##             the downward arc — this gives good visual split at apex]
##   flight — "bald_fighter_hover" (9f, loop, 8 fps)
##   attack — "attack" one-shot (9f, no loop, 12 fps)
##   hurt   — "takedamage" one-shot (9f, no loop, 10 fps)
##
## Gaps:
##   glide  — no dedicated anim; AnimationController falls back to "fall"
##   death  — no dedicated anim; player holds last hurt frame on respawn
##
## Run headless:
##   Godot --headless --path <repo> -s res://tools/build_hero_frames.gd

const OUT_PATH := "res://resources/hero/hero_frames.tres"
const HERO_BASE := "res://assets/sprites/hero"


func _add_frames(sf: SpriteFrames, anim: String, folder: String,
		frame_indices: Array, fps: float, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for i in frame_indices:
		var path := "%s/%s/frame_%s.png" % [HERO_BASE, folder, str(i).pad_zeros(3)]
		var tex: Texture2D = load(path)
		if tex == null:
			push_error("Missing texture: %s" % path)
			quit(1)
			return
		sf.add_frame(anim, tex)


func _init() -> void:
	var sf := SpriteFrames.new()

	# Remove default "default" animation that Godot inserts.
	if sf.has_animation("default"):
		sf.remove_animation("default")

	# idle: 9 frames, loop, 8 fps
	_add_frames(sf, "idle", "idle", [0,1,2,3,4,5,6,7,8], 8.0, true)

	# walk: 4 frames, loop, 8 fps
	_add_frames(sf, "walk", "walk", [0,1,2,3], 8.0, true)

	# jump: rising frames 0-2 from the jump strip, no loop, 8 fps
	_add_frames(sf, "jump", "jump", [0,1,2], 8.0, false)

	# fall: descending frames 4-6 from the jump strip, no loop, 8 fps
	# (frame 3 is the apex; frames 4-6 show the arc of descent)
	_add_frames(sf, "fall", "jump", [4,5,6], 8.0, false)

	# flight: 9 frames, loop, 8 fps (suspended mid-air hover aura)
	_add_frames(sf, "flight", "flight", [0,1,2,3,4,5,6,7,8], 8.0, true)

	# attack: 9 frames, no loop, 12 fps (cyan burst one-shot)
	_add_frames(sf, "attack", "attack", [0,1,2,3,4,5,6,7,8], 12.0, false)

	# hurt: 9 frames, no loop, 10 fps (takedamage one-shot)
	_add_frames(sf, "hurt", "hurt", [0,1,2,3,4,5,6,7,8], 10.0, false)

	# Ensure output directory exists.
	var dir := DirAccess.open("res://resources")
	if dir == null:
		DirAccess.make_dir_absolute("res://resources/hero")
	else:
		if not dir.dir_exists("hero"):
			dir.make_dir("hero")

	var err := ResourceSaver.save(sf, OUT_PATH)
	if err != OK:
		push_error("ResourceSaver.save() failed: %d" % err)
		quit(1)
		return
	var anim_list := sf.get_animation_names()
	print("BUILT %s with animations: %s" % [OUT_PATH, ", ".join(anim_list)])
	quit(0)
