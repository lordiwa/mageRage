# FSM States — Full Implementations (Mage Rage movement)

Read this when implementing or reviewing a concrete movement state. It assumes the
`StateMachine` and `EstadoBase` from `SKILL.md` Workflow 1. States are `Node` children
of the `StateMachine`; each has `@export var player: CharacterBody2D` wired in the
editor. Progression follows the LORE-BIBLE "movement = mastery" table:
None → Fire (Leap) → Ice (Glide) → Electricity (Flight).

`player.abilities` is a `Dictionary` like `{"fire": true, "ice": true}` populated as
the hero absorbs each element. Transitions to advanced states are gated on it.

---

## Why nodes, not booleans (the anti-pattern compared)

The spaghetti the GDD forbids:

```gdscript
# ANTI-PATTERN — do NOT do this
func _physics_process(delta):
    if is_flying:
        # ...50 lines...
    elif is_gliding:
        if Input.is_action_pressed("fly") and has_electricity:
            is_gliding = false; is_flying = true   # combinatorial flag soup
        # ...
    elif is_jumping:
        # ...
    else: # walking
        # ...
```

Every new ability multiplies the flag combinations and every branch must know about
every other. The node FSM isolates each state's logic and centralizes transitions, so
adding `FlightState` touches only that node plus one guarded transition.

---

## MoveState (grounded: run, fall, initiate jump)

```gdscript
# scripts/fsm/states/move_state.gd
class_name MoveState extends EstadoBase

const SPEED := 220.0
const COYOTE_TIME := 0.10
var _coyote := 0.0

func enter() -> void:
    _coyote = COYOTE_TIME

func physics_update(delta: float) -> void:
    if not player.is_on_floor():
        player.velocity += player.get_gravity() * delta
        _coyote -= delta
    else:
        _coyote = COYOTE_TIME

    var dir := Input.get_axis("move_left", "move_right")
    player.velocity.x = dir * SPEED
    player.move_and_slide()

    # Jump unlocked by Fire (GDD: Fuego -> Salto/Dash)
    if player.abilities.has("fire") \
            and Input.is_action_just_pressed("jump") and _coyote > 0.0:
        transition_to("JumpState")
```

---

## JumpState (airborne after a jump; may glide or fly if unlocked)

```gdscript
# scripts/fsm/states/jump_state.gd
class_name JumpState extends EstadoBase

const SPEED := 220.0
const JUMP_VELOCITY := -380.0

func enter() -> void:
    player.velocity.y = JUMP_VELOCITY        # apply the impulse on entry

func physics_update(delta: float) -> void:
    player.velocity += player.get_gravity() * delta
    var dir := Input.get_axis("move_left", "move_right")
    player.velocity.x = dir * SPEED
    player.move_and_slide()

    # Ice unlock -> hold to glide while descending
    if player.abilities.has("ice") \
            and player.velocity.y > 0.0 and Input.is_action_pressed("glide"):
        transition_to("GlideState")

    # Electricity unlock -> full flight (GDD's definitive transition)
    if player.abilities.has("electricity") and Input.is_action_just_pressed("fly"):
        transition_to("FlightState")

    if player.is_on_floor():
        transition_to("MoveState")
```

---

## GlideState (Ice: slowed descent, long arcs)

```gdscript
# scripts/fsm/states/glide_state.gd
class_name GlideState extends EstadoBase

const SPEED := 240.0
const MAX_FALL := 60.0                        # clamp descent for hang-time

func physics_update(delta: float) -> void:
    player.velocity += player.get_gravity() * delta
    player.velocity.y = minf(player.velocity.y, MAX_FALL)   # the glide feel

    var dir := Input.get_axis("move_left", "move_right")
    player.velocity.x = dir * SPEED
    player.move_and_slide()

    if not Input.is_action_pressed("glide"):
        transition_to("JumpState")
    if player.abilities.has("electricity") and Input.is_action_just_pressed("fly"):
        transition_to("FlightState")
    if player.is_on_floor():
        transition_to("MoveState")
```

---

## FlightState (Electricity: free 8-direction flight — the GDD's game-changer)

```gdscript
# scripts/fsm/states/flight_state.gd
class_name FlightState extends EstadoBase

const FLY_SPEED := 260.0

func enter() -> void:
    player.velocity = Vector2.ZERO            # gravity is ignored while flying

func physics_update(_delta: float) -> void:
    # No gravity: pure 8-directional control.
    var input := Vector2(
        Input.get_axis("move_left", "move_right"),
        Input.get_axis("move_up", "move_down")
    ).limit_length(1.0)
    player.velocity = input * FLY_SPEED
    player.move_and_slide()

    # Exit flight -> fall back to grounded handling.
    if Input.is_action_just_pressed("fly"):
        transition_to("JumpState")
```

Per GDD/LORE, `FlightState` only becomes reachable once Electricity is absorbed —
the guards in `JumpState`/`GlideState` enforce that; `FlightState` itself needs no
"am I unlocked?" flag. Adding the Antimatter ultimate later is a new state + one
guarded transition, not a rewrite.

## Testability

Because states are nodes with plain methods, FSM transition routing is unit-testable
without rendering: instantiate a `StateMachine` with stub `EstadoBase` children, emit
`transition_requested`, and assert `current_state` changed (and that stale requests
from a non-current state are ignored). See `references/gut-testing.md`.
