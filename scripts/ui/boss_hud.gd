## DD-010 boss HUD: a BOSS HP BAR + current phase/armor readout for the Warden,
## shown alongside the existing player HP/element debug readout. Decoupled like the
## DebugHUD: it polls the Warden each frame and listens to `phase_changed`/`defeated`
## for the beat-driven bits (loose coupling — the HUD listens, the boss emits).
##
## The bar is a placeholder (two ColorRects: a track + a fill scaled by HP fraction),
## tinted to the CURRENT armor color so the player re-reads the element to swap to
## (game-design SKILL: readability). On defeat it shows a big 'VICTORY' label.
extends CanvasLayer

@export var boss_path: NodePath
@export var bar_fill_path: NodePath        # ColorRect whose width scales with HP
@export var bar_label_path: NodePath       # Label: "THE WARDEN — Phase N / ARMOR"
@export var victory_label_path: NodePath   # Label: hidden until victory

## Armor color language (matches the Warden/drone tints): Fire warm, Ice cold,
## Electricity arc. The fill is tinted so HP loss and the armor read share one bar.
const ARMOR_TINT := {
	SpellData.Element.FIRE: Color(0.85, 0.30, 0.20, 1.0),
	SpellData.Element.ICE: Color(0.35, 0.65, 0.95, 1.0),
	SpellData.Element.ELECTRICITY: Color(0.95, 0.85, 0.25, 1.0),
}
const _ELEMENT_NAMES := ["FIRE", "ICE", "ELECTRICITY", "ANTIMATTER"]

var _boss: Node
var _fill: ColorRect
var _label: Label
var _victory: Label
var _full_width := 0.0

func _ready() -> void:
	_boss = get_node_or_null(boss_path)
	_fill = get_node_or_null(bar_fill_path) as ColorRect
	_label = get_node_or_null(bar_label_path) as Label
	_victory = get_node_or_null(victory_label_path) as Label
	if _fill != null:
		_full_width = _fill.size.x
	if _victory != null:
		_victory.visible = false
	if _boss != null:
		if _boss.has_signal("phase_changed"):
			_boss.phase_changed.connect(_on_phase_changed)
		if _boss.has_signal("defeated"):
			_boss.defeated.connect(_on_defeated)
	_refresh()

func _process(_delta: float) -> void:
	if _boss != null:
		_refresh()

func _on_phase_changed(_new_phase: int) -> void:
	_refresh()

func _on_defeated() -> void:
	if _victory != null:
		_victory.visible = true
	_refresh()

func _refresh() -> void:
	if _boss == null:
		return
	var hp := 0.0
	var maxhp := 1.0
	# Poll via the boss accessors (decoupled): phase, armor, and HP through Health.
	var phase := 1
	if _boss.has_method("phase"):
		phase = _boss.phase()
	var armor := SpellData.Element.FIRE
	if _boss.has_method("armor_type"):
		armor = _boss.armor_type()
	var health := _boss.get_node_or_null("Health")
	if health != null:
		hp = health.current_health
		maxhp = maxf(health.max_health, 1.0)
	var frac: float = clampf(hp / maxhp, 0.0, 1.0)
	if _fill != null:
		_fill.size.x = _full_width * frac
		_fill.color = ARMOR_TINT.get(armor, Color.WHITE)
	if _label != null:
		var armor_name: String = _ELEMENT_NAMES[armor] if armor < _ELEMENT_NAMES.size() else "?"
		_label.text = "THE WARDEN — Phase %d   [%s armor]   HP %d/%d" % [
			phase, armor_name, int(hp), int(maxhp)]
