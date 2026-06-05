## TASK-015 player game HUD: a readable, in-game player status overlay that
## replaces the debug-text status (the DebugHUD stays as a separate, toggleable
## dev overlay). Shows:
##   - an HP bar (track + fill ColorRect scaled by hp/max),
##   - a MANA bar (same pattern) with low-mana warning tint and a no-mana flash,
##   - a LOADOUT indicator: PRIMARY (prominent swatch + label) + SECONDARY
##     (smaller), each tinted with the element color language and named.
##
## Decoupled exactly like boss_hud.gd: this CanvasLayer POLLS the player accessors
## (player_hp/max_player_hp/current_mana/max_mana/primary_spell/secondary_spell)
## each frame and LISTENS to the MagicManager's loadout_changed + cast_failed
## signals. The player exposes; the HUD reads. Nothing reaches up the tree.
##
## All readability math lives in pure STATIC helpers (fill_fraction, element_color,
## element_label, is_low_mana) so it unit-tests headless without a rendered scene.
## Colors come from ProjectileStyle — the ONE element color language source of
## truth (shared with the projectile + impact juice) — never re-typed here.
class_name PlayerHUD extends CanvasLayer

## Below this mana fraction the bar shows the distinct low-mana warning tint/pulse.
const LOW_MANA_THRESHOLD := 0.25

## Bar fill colors (HP green, mana cyan) — bar chrome, distinct from the element
## color language used for the loadout swatches.
const HP_COLOR := Color(0.30, 0.80, 0.35, 1.0)
const MANA_COLOR := Color(0.35, 0.70, 0.95, 1.0)
const MANA_LOW_COLOR := Color(0.95, 0.45, 0.30, 1.0)   # warning tint when low/empty

const _ELEMENT_NAMES := ["FIRE", "ICE", "ELECTRICITY", "ANTIMATTER"]
const _EMPTY_LABEL := "—"

# --- TASK-039 trigger->element binding ---------------------------------------
# Playtest feedback: the player couldn't tell WHICH TRIGGER fires WHICH element.
# Each loadout slot now shows an explicit trigger glyph next to its element
# swatch+label. The canonical DD-008 scheme is RT = PRIMARY, LT = SECONDARY. The
# glyph TEXT is a pure function of the SLOT (static, element-independent); only the
# slot's element name + color change on loadout_changed. The glyph is tinted to the
# element color too so the binding reads at a glance without burying the HP/Mana read.

## Trigger glyph for the PRIMARY slot (right trigger).
const PRIMARY_TRIGGER := "RT"
## Trigger glyph for the SECONDARY slot (left trigger).
const SECONDARY_TRIGGER := "LT"

# --- TASK-016 damage feedback ------------------------------------------------

## Player-damage color language: damage reads RED (distinct from the element
## tints and the bar chrome). A border gradient/framed ColorRect tinted with this.
const VIGNETTE_COLOR := Color(0.85, 0.12, 0.12, 1.0)

## Vignette peak-alpha band. The flash is bright enough to read but capped well
## below opaque so it NEVER obscures the playfield (DD-009: feedback is fair).
const VIGNETTE_MIN_PEAK := 0.18
const VIGNETTE_MAX_PEAK := 0.55

## How quickly the red edge vignette flash fades back to nothing (seconds).
const VIGNETTE_DURATION := 0.35

## How long the hit-direction indicator lingers before fading (seconds).
const INDICATOR_DURATION := 0.45

@export var player_path: NodePath
@export var magic_manager_path: NodePath        # for loadout_changed + cast_failed

@export var hp_fill_path: NodePath              # ColorRect, width scales with HP
@export var hp_label_path: NodePath             # Label "HP 80/100"
@export var mana_fill_path: NodePath            # ColorRect, width scales with mana
@export var mana_label_path: NodePath           # Label "MANA 60/100"

@export var primary_swatch_path: NodePath       # ColorRect: prominent primary tint
@export var primary_label_path: NodePath        # Label: primary element name
@export var secondary_swatch_path: NodePath     # ColorRect: smaller secondary tint
@export var secondary_label_path: NodePath      # Label: secondary element name

## TASK-039 per-slot trigger glyph Labels (optional; the HUD degrades gracefully if
## a level omits them). PRIMARY shows "RT", SECONDARY shows "LT" — which trigger
## fires that slot. Static text per slot; tinted live to the slot's element color.
@export var primary_trigger_label_path: NodePath    # Label: "RT" (primary trigger)
@export var secondary_trigger_label_path: NodePath  # Label: "LT" (secondary trigger)

## TASK-016 damage feedback widgets (all optional; the HUD degrades gracefully if
## a level omits them). Vignette = a full-screen RED edge frame (low/zero center
## alpha) that flashes and fades. Indicator = an arrow pivot that rotates toward
## the hit source and fades. Both use modulate-alpha + mouse_filter ignore so they
## never block the playfield.
@export var vignette_path: NodePath             # Control/TextureRect: red edge frame
@export var indicator_pivot_path: NodePath      # Control: rotated toward -hit_dir

var _player: Node
var _magic: Node
var _hp_fill: ColorRect
var _hp_label: Label
var _mana_fill: ColorRect
var _mana_label: Label
var _primary_swatch: ColorRect
var _primary_label: Label
var _secondary_swatch: ColorRect
var _secondary_label: Label
var _primary_trigger_label: Label
var _secondary_trigger_label: Label

var _vignette: CanvasItem
var _indicator_pivot: CanvasItem

## Cached flash tweens. Rapid successive hits kill the in-flight tween before
## starting a new one so fades don't fight and never leave a stuck-opaque state.
var _vignette_tween: Tween
var _indicator_tween: Tween

var _hp_full_width := 0.0
var _mana_full_width := 0.0

## Margin (px) keeping the edge-anchored indicator off the very screen border.
const INDICATOR_EDGE_MARGIN := 56.0

# --- Pure static helpers (unit-tested headless) ------------------------------

## Bar-fill ratio shared by the HP and mana bars: clampf(current/max, 0, 1).
## Zero-or-negative max is safe (returns 0.0 — an empty bar, never a div-by-zero).
static func fill_fraction(current: float, maximum: float) -> float:
	if maximum <= 0.0:
		return 0.0
	return clampf(current / maximum, 0.0, 1.0)

## Loadout swatch tint for an element, from the shared element color language
## (ProjectileStyle). An empty/unknown slot (e.g. -1) gets the safe default color.
static func element_color(element: int) -> Color:
	return ProjectileStyle.for_element(element)["color"]

## Readable element name (FIRE/ICE/ELECTRICITY/ANTIMATTER). An empty/unknown slot
## shows the em-dash placeholder.
static func element_label(element: int) -> String:
	if element < 0 or element >= _ELEMENT_NAMES.size():
		return _EMPTY_LABEL
	return _ELEMENT_NAMES[element]

## Low-mana warning predicate: strictly below the threshold fraction.
static func is_low_mana(fraction: float) -> bool:
	return fraction < LOW_MANA_THRESHOLD

## TASK-039: the trigger glyph that fires a loadout SLOT (RT for PRIMARY, LT for
## SECONDARY — the DD-008 scheme). Pure function of the slot id so the binding is
## unit-testable headless. An unknown slot yields "" (no glyph; safe default).
static func trigger_label(slot: int) -> String:
	match slot:
		MagicManager.SLOT_PRIMARY:
			return PRIMARY_TRIGGER
		MagicManager.SLOT_SECONDARY:
			return SECONDARY_TRIGGER
		_:
			return ""

# --- TASK-016: damage-feedback pure math (unit-tested headless) --------------

## Red edge-vignette alpha at time `t` into a flash of length `duration`, starting
## at `peak`. A linear fade to 0 by the end (a quick flash, monotonic). Clamped so
## it never goes negative or past the peak; a zero/negative duration is safe
## (returns 0 — no flash, never a divide-by-zero).
static func vignette_alpha(t: float, duration: float, peak: float) -> float:
	if duration <= 0.0:
		return 0.0
	var k := clampf(t / duration, 0.0, 1.0)
	return peak * (1.0 - k)

## The vignette PEAK alpha for a hit of `amount` against `max_hp`: bigger hits
## flash brighter. Scaled by the damage fraction and clamped into the readable
## [MIN..MAX] band so a tiny hit still registers and a lethal hit never blacks out
## the screen. A zero/negative max_hp is safe (falls back to the minimum peak).
static func intensity_for(amount: float, max_hp: float) -> float:
	if max_hp <= 0.0:
		return VIGNETTE_MIN_PEAK
	var frac := clampf(amount / max_hp, 0.0, 1.0)
	return clampf(lerpf(VIGNETTE_MIN_PEAK, VIGNETTE_MAX_PEAK, frac),
		VIGNETTE_MIN_PEAK, VIGNETTE_MAX_PEAK)

## The hit-direction indicator angle (radians) for a projectile whose TRAVEL
## direction is `hit_dir`. The arrow points back toward the SOURCE of the hit, i.e.
## along -hit_dir. Input need not be normalized (angle() ignores magnitude).
static func indicator_angle(hit_dir: Vector2) -> float:
	return (-hit_dir).angle()

## Whether to draw the directional arrow for this hit. A ZERO direction (unknown
## source, e.g. a legacy one-arg hit) shows the vignette only — no arrow.
static func should_show_indicator(hit_dir: Vector2) -> bool:
	return hit_dir != Vector2.ZERO

## Screen-edge anchor (viewport pixel coords, origin top-left) for the hit
## indicator: a point on the inset rectangle (`viewport_size` shrunk by `margin`
## on all sides) lying in the SOURCE direction of the hit (-hit_dir), so the
## indicator reads as "the hit came from over there". The source ray is cast from
## the screen center out to whichever inset edge it strikes first. A ZERO hit_dir
## is safe: it returns the exact center (no direction to project). The travel
## direction need not be normalized.
static func indicator_edge_position(hit_dir: Vector2, viewport_size: Vector2,
		margin: float) -> Vector2:
	var center := viewport_size * 0.5
	if hit_dir == Vector2.ZERO:
		return center
	# Source direction = back toward where the hit came from.
	var src := (-hit_dir).normalized()
	# Half-extents of the inset rectangle the indicator rides on.
	var half_x := maxf(center.x - margin, 0.0)
	var half_y := maxf(center.y - margin, 0.0)
	# Scale the unit source ray so the dominant axis saturates to its half-extent
	# (the ray exits through the nearest edge). Guard tiny components.
	var scale := INF
	if absf(src.x) > 0.00001:
		scale = minf(scale, half_x / absf(src.x))
	if absf(src.y) > 0.00001:
		scale = minf(scale, half_y / absf(src.y))
	if scale == INF:
		return center
	return center + src * scale

# --- Lifecycle ---------------------------------------------------------------

func _ready() -> void:
	_player = get_node_or_null(player_path)
	_magic = get_node_or_null(magic_manager_path)
	_hp_fill = get_node_or_null(hp_fill_path) as ColorRect
	_hp_label = get_node_or_null(hp_label_path) as Label
	_mana_fill = get_node_or_null(mana_fill_path) as ColorRect
	_mana_label = get_node_or_null(mana_label_path) as Label
	_primary_swatch = get_node_or_null(primary_swatch_path) as ColorRect
	_primary_label = get_node_or_null(primary_label_path) as Label
	_secondary_swatch = get_node_or_null(secondary_swatch_path) as ColorRect
	_secondary_label = get_node_or_null(secondary_label_path) as Label
	_primary_trigger_label = get_node_or_null(primary_trigger_label_path) as Label
	_secondary_trigger_label = get_node_or_null(secondary_trigger_label_path) as Label
	_vignette = get_node_or_null(vignette_path) as CanvasItem
	_indicator_pivot = get_node_or_null(indicator_pivot_path) as CanvasItem
	# TASK-016: start the feedback widgets hidden (alpha 0); they flash on damage.
	if _vignette != null:
		_set_alpha(_vignette, 0.0)
	if _indicator_pivot != null:
		_set_alpha(_indicator_pivot, 0.0)
	# Listen for the player's damage signal (decoupled; the player emits, we draw).
	if _player != null and _player.has_signal("damaged"):
		_player.damaged.connect(_on_player_damaged)
	if _hp_fill != null:
		_hp_full_width = _hp_fill.size.x
	if _mana_fill != null:
		_mana_full_width = _mana_fill.size.x
	if _magic != null:
		if _magic.has_signal("loadout_changed"):
			_magic.loadout_changed.connect(_on_loadout_changed)
		if _magic.has_signal("cast_failed"):
			_magic.cast_failed.connect(_on_cast_failed)
	_refresh_loadout()
	_refresh_bars()

func _process(_delta: float) -> void:
	# HP/mana change continuously; poll the bars (loadout is signal-driven but we
	# also seed it on _ready in case the manager emitted before this HUD readied).
	if _player != null:
		_refresh_bars()

# --- Bars --------------------------------------------------------------------

func _refresh_bars() -> void:
	if _player == null:
		return
	if _player.has_method("player_hp"):
		var hp_frac := fill_fraction(_player.player_hp(), _player.max_player_hp())
		if _hp_fill != null:
			_hp_fill.size.x = _hp_full_width * hp_frac
			_hp_fill.color = HP_COLOR
		if _hp_label != null:
			_hp_label.text = "HP %d/%d" % [int(_player.player_hp()), int(_player.max_player_hp())]
	if _player.has_method("current_mana"):
		var mana_frac := fill_fraction(_player.current_mana(), _player.max_mana())
		if _mana_fill != null:
			_mana_fill.size.x = _mana_full_width * mana_frac
			# Low-mana state is visually distinct (warning tint) unless a flash is
			# mid-tween (the tween owns the color until it finishes).
			if not _mana_flashing:
				_mana_fill.color = MANA_LOW_COLOR if is_low_mana(mana_frac) else MANA_COLOR
		if _mana_label != null:
			_mana_label.text = "MANA %d/%d" % [int(_player.current_mana()), int(_player.max_mana())]

# --- Loadout indicator -------------------------------------------------------

func _on_loadout_changed(_primary: SpellData, _secondary: SpellData) -> void:
	_refresh_loadout()

func _refresh_loadout() -> void:
	var primary_el := _slot_element("primary_spell")
	var secondary_el := _slot_element("secondary_spell")
	if _primary_swatch != null:
		_primary_swatch.color = element_color(primary_el)
	if _primary_label != null:
		_primary_label.text = element_label(primary_el)
	if _secondary_swatch != null:
		_secondary_swatch.color = element_color(secondary_el)
	if _secondary_label != null:
		_secondary_label.text = element_label(secondary_el)
	# TASK-039: the trigger glyph TEXT is static per slot (RT/LT — which trigger
	# fires it), but its tint tracks the slot's current element so the trigger and
	# its element read as one binding. An empty slot falls back to the default tint.
	if _primary_trigger_label != null:
		_primary_trigger_label.text = trigger_label(MagicManager.SLOT_PRIMARY)
		_primary_trigger_label.modulate = element_color(primary_el)
	if _secondary_trigger_label != null:
		_secondary_trigger_label.text = trigger_label(MagicManager.SLOT_SECONDARY)
		_secondary_trigger_label.modulate = element_color(secondary_el)

## The element id of a player loadout slot accessor, or -1 (empty) when missing.
func _slot_element(accessor: String) -> int:
	if _player == null or not _player.has_method(accessor):
		return -1
	var spell = _player.call(accessor)
	return spell.element if spell != null else -1

# --- No-mana feedback --------------------------------------------------------

var _mana_flashing := false

## Brief mana-bar flash on a rejected (insufficient-mana) cast so the failure
## reads. A short tween pulses the fill to the warning color and back; while it
## runs the per-frame low-mana tint defers to the tween.
func _on_cast_failed(_slot: int) -> void:
	if _mana_fill == null:
		return
	_mana_flashing = true
	var t := create_tween()
	_mana_fill.color = MANA_LOW_COLOR
	t.tween_property(_mana_fill, "color", MANA_LOW_COLOR.lightened(0.4), 0.08)
	t.tween_property(_mana_fill, "color", MANA_LOW_COLOR, 0.10)
	t.tween_callback(func() -> void: _mana_flashing = false)

# --- TASK-016: damage feedback (red vignette + hit-direction indicator) -------

## On a LANDED player hit (the player's `damaged` signal): flash the red edge
## vignette (peak scaled by damage, quick fade) and, if the hit source is known,
## point a brief directional indicator back toward it (-hit_dir). Both fade via a
## modulate-alpha tween so the playfield is never blocked (DD-009: fair feedback).
func _on_player_damaged(amount: float, hit_dir: Vector2) -> void:
	_flash_vignette(amount)
	if should_show_indicator(hit_dir):
		_flash_indicator(hit_dir)

func _flash_vignette(amount: float) -> void:
	if _vignette == null:
		return
	var max_hp := 100.0
	if _player != null and _player.has_method("max_player_hp"):
		max_hp = _player.max_player_hp()
	var peak := intensity_for(amount, max_hp)
	# A ColorRect carries its own red via .color; a TextureRect (radial gradient)
	# carries the red in its texture, so its modulate stays WHITE and we drive the
	# flash purely through modulate alpha (the gradient keeps the center clear).
	if _vignette is ColorRect:
		(_vignette as ColorRect).color = VIGNETTE_COLOR
	else:
		_vignette.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_set_alpha(_vignette, peak)
	# Kill any in-flight fade so rapid hits don't spawn fighting tweens, then run a
	# fresh quick monotonic fade to 0 over the vignette duration.
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_vignette_tween = create_tween()
	_vignette_tween.tween_method(func(a: float) -> void: _set_alpha(_vignette, a),
		peak, 0.0, VIGNETTE_DURATION)

func _flash_indicator(hit_dir: Vector2) -> void:
	if _indicator_pivot == null:
		return
	# Orient the indicator toward the source, AND anchor it on the screen edge in
	# that source direction so it reads as "the hit came from over there".
	var vp := _viewport_size()
	var edge := indicator_edge_position(hit_dir, vp, INDICATOR_EDGE_MARGIN)
	if _indicator_pivot is Control:
		var ctrl := _indicator_pivot as Control
		ctrl.rotation = indicator_angle(hit_dir)
		# Center the control's pivot on the edge anchor (offset by half its size).
		ctrl.position = edge - ctrl.size * 0.5
	elif _indicator_pivot is Node2D:
		var n2d := _indicator_pivot as Node2D
		n2d.rotation = indicator_angle(hit_dir)
		n2d.position = edge
	_set_alpha(_indicator_pivot, 1.0)
	# Tween hygiene: kill the previous fade before re-creating (no fighting tweens).
	if _indicator_tween != null and _indicator_tween.is_valid():
		_indicator_tween.kill()
	_indicator_tween = create_tween()
	_indicator_tween.tween_method(func(a: float) -> void: _set_alpha(_indicator_pivot, a),
		1.0, 0.0, INDICATOR_DURATION)

## Current viewport size in pixels (for edge-anchoring the indicator). Falls back
## to a sane default if no viewport is available (e.g. headless construction).
func _viewport_size() -> Vector2:
	var vp := get_viewport()
	if vp != null:
		return vp.get_visible_rect().size
	return Vector2(1280.0, 720.0)

## Set a CanvasItem's modulate alpha without disturbing its RGB. Keeps the feedback
## as a transparency overlay (never opaque -> never blocks the play space).
func _set_alpha(item: CanvasItem, alpha: float) -> void:
	if item == null:
		return
	var c := item.modulate
	c.a = clampf(alpha, 0.0, 1.0)
	item.modulate = c
