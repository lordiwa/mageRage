## TASK-067 shmup WIN/LOSE banner — the minimal HUD feedback for the auto-scroll shmup
## (levels/shmup_01.tscn). Mirrors boss_hud.gd's victory-label pattern: two Labels (a VICTORY
## banner and a DEFEAT/RETRY banner) that start HIDDEN and are toggled visible by the Shmup01
## controller's shmup_victory / shmup_defeat signals (decoupled — the controller emits, the
## banner shows). Greybox/simple by design (TASK-067 owns the loop, not the art).
##
## The defeat banner is a BRIEF flash (the hero respawns at the start and the loop continues),
## so it auto-hides after DEFEAT_SHOW_TIME; the victory banner is terminal and stays up.
class_name ShmupBanner extends CanvasLayer

## How long (s) the brief defeat/retry banner stays up before auto-hiding (the loop continues).
const DEFEAT_SHOW_TIME := 1.5

@export var victory_label_path: NodePath
@export var defeat_label_path: NodePath

var _victory: Label
var _defeat: Label
var _defeat_timer := 0.0


func _ready() -> void:
	_victory = get_node_or_null(victory_label_path) as Label
	_defeat = get_node_or_null(defeat_label_path) as Label
	if _victory != null:
		_victory.visible = false
	if _defeat != null:
		_defeat.visible = false
	set_process(false)


## shmup_victory handler: show the (terminal) VICTORY banner.
func show_victory() -> void:
	if _victory != null:
		_victory.visible = true


## shmup_defeat handler: flash the brief DEFEAT/RETRY banner, then auto-hide it (the hero has
## already respawned at the start; the loop continues).
func show_defeat() -> void:
	if _defeat == null:
		return
	_defeat.visible = true
	_defeat_timer = DEFEAT_SHOW_TIME
	set_process(true)


func _process(delta: float) -> void:
	if _defeat_timer <= 0.0:
		return
	_defeat_timer -= delta
	if _defeat_timer <= 0.0:
		if _defeat != null:
			_defeat.visible = false
		set_process(false)


## True while the VICTORY banner is shown (test/HUD read).
func is_victory_shown() -> bool:
	return _victory != null and _victory.visible


## True while the DEFEAT banner is shown (test/HUD read).
func is_defeat_shown() -> bool:
	return _defeat != null and _defeat.visible
