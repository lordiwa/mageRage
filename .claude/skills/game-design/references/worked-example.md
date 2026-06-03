# Worked Example — One Ability & One Boss Through the Checklist

> Loaded on demand from [`../SKILL.md`](../SKILL.md). Two model specs that run the
> **feature-vetting checklist** end-to-end. Numbers are illustrative tuning knobs,
> not canon. Canon: `docs/GDD.md`, `docs/LORE-BIBLE.md`. Implementation handoff:
> [`../../godot-game-dev/SKILL.md`](../../godot-game-dev/SKILL.md).

---

## Example 1 — Ability: "Cryo-Lance" (an Ice spell)

A focused, piercing ice projectile that briefly **freezes mechanical systems** it
hits (halts a drone's movement / locks a valve), distinct from a damage spell. It
exists to make Ice's *control* identity tactile and to feed Ice's traversal verb
(glide) thematically (slowed descent = slowed systems).

### Design intent

- **Fiction (LORE-BIBLE §3):** Ice = control, defense, slowing mechanical
  systems. Cryo-Lance *stops* a thing rather than melting it (Fire's job).
- **Micro role:** vs. fast/agile Empire drones (armor weak to Ice), the player
  swaps to Ice, lances one, and gets a control window — a real RPS read.
- **Anti-dominance:** single-target and pierce-limited, so it is *not* the answer
  to grouped enemies (that's Electricity's chain) or armored brutes (Fire). Keeps
  elements near-equal in optimal play.

### Filled checklist

```
FEATURE: Cryo-Lance (Ice projectile spell)
ONE-LINE: Pierce an enemy and freeze its mechanical systems for ~1.5s.

--- GATE A: PILLARS (need >=1 "serves") ---
[x] Jailer-was-protector  : neutral — note: no tonal conflict.
[x] Weapon-chooses-target : serves — note: control (stop, don't destroy) echoes
    the creation-not-only-destruction duality at the micro scale.
[x] Flight=freedom&doom   : neutral — note: ties to Ice's glide verb thematically.
    >> One "serves", zero "VIOLATES" -> PASS.

--- GATE B: CORE-LOOP LAYER (need >=1, steals from none) ---
[x] Micro  : serves — note: rewards swapping to Ice vs. fast drones; freeze window
    is a second-to-second decision.
[x] Minute : serves — note: enables Coolant-sector control puzzles (freeze a valve
    to pass).
[ ] Macro  : n/a — note: not a permanent unlock itself; rides the Ice macro beat.
    >> Two "serves", no "steals" -> PASS.

--- GATE C: CANON CONSISTENCY ---
[x] Contradicts GDD?         : no — GDD section 3 names Ice as "detiene/ralentiza".
[x] Contradicts LORE-BIBLE?  : no — section 3 Ice = control/slowing.
[x] Tone severe/tragic/cosmic: yes — clinical, cold, no quip. PASS.

--- GATE D: TEACHES / REWARDS A VERB ---
[x] Verb taught/rewarded: Ice element + the swap-to-Ice read; sets up glide theme.
[x] Gate taught before tested: yes — first Coolant room uses Cryo-Lance on a lone
    valve with no enemies before any combo freeze puzzle.
[x] Preserves RPS read (no dominant element): yes — single-target, weak vs. groups
    and brutes by design.

--- IMPLEMENTATION HANDOFF (godot-game-dev) ---
[x] Maps to: SpellData element=ICE, a projectile .tres; freeze = a status the hit
    applies on Enemy-layer bodies (collision layer 4 PlayerMagic masks 3 Enemies).
[x] Data-driven: yes — new fire_bolt-style .tres; freeze duration an @export field.
[x] Test plan: GUT pure-logic — assert element==ICE, freeze_duration>0, pierce
    count; assert it applies "frozen" to a stub enemy and clears after duration.

VERDICT: SHIP — serves micro+minute, on-canon, reinforces Ice identity without
becoming dominant.
```

### Notes for the developer

Add `freeze_duration: float` and `pierce_count: int` to `SpellData` (or a small
`IceSpellData` extension) so it stays data-driven (godot-game-dev section 2).
Freeze should *halt* an enemy FSM/movement, not deal extra damage — the fiction is
*stop*, not *kill*.

---

## Example 2 — Boss: "The Coolant Warden" (Ice-trial graduation boss)

The boss at the end of Trial 2 (Coolant sectors). Its arena **demands the glide
verb** the player just earned — the "movement = mastery" graduation moment for Ice.

### Design intent

- **Pillar 1 (jailer-was-protector):** the Warden reads as a *grief-stricken
  guardian* of the coolant core, not a sadist — it floods the arena to "preserve"
  the sector, tragic not cruel.
- **Pillar 3 (flight=freedom&doom):** beating it, the player feels the glide
  mastery click — and the beacon flares (negative loop: heavier Empire units
  appear afterward).
- **Pacing:** hard ramp; followed by a quiet rest beat (a safe overlook where the
  player simply enjoys gliding) before Trial 3.

### Fight shape

- Arena has rising coolant/hazard floor; **only gliding across updrafts keeps you
  safe** — it tests the verb under pressure (taught earlier, tested now).
- Warden armor is weak to **Fire** (melt its coolant plating) but its adds are
  fast drones weak to **Ice** and linked relays weak to **Electricity** — forcing
  *mid-fight element swaps*, preserving the RPS read at boss scale.
- Telegraphed wind-ups on every heavy attack; difficulty is mechanical (read +
  swap + glide), not a bullet-sponge HP bar.

### Filled checklist

```
FEATURE: The Coolant Warden (Ice-trial boss)
ONE-LINE: Glide-gated arena boss that forces Fire/Ice/Elec swapping; graduates
the glide verb.

--- GATE A: PILLARS ---
[x] Jailer-was-protector  : serves — tragic guardian, floods to "preserve".
[x] Weapon-chooses-target : neutral.
[x] Flight=freedom&doom   : serves — glide-mastery reveal + beacon flare after.
    >> PASS.

--- GATE B: CORE-LOOP LAYER ---
[x] Micro  : serves — constant element-swap reads + glide timing.
[x] Minute : serves — the climactic mid-size goal of the Coolant sector.
[x] Macro  : serves — graduates the glide verb; opens post-Ice routes.
    >> PASS.

--- GATE C: CANON CONSISTENCY ---
[x] Contradicts GDD?         : no — GDD section 2 "destruir jefes mecanicos";
    section 4 escalation after power gain.
[x] Contradicts LORE-BIBLE?  : no — section 10 Trial 2 ICE / Coolant / gains glide.
[x] Tone severe/tragic/cosmic: yes — grief-stricken guardian, no levity. PASS.

--- GATE D: TEACHES / REWARDS A VERB ---
[x] Verb tested: glide (movement) + Ice/Fire/Elec swap (combat).
[x] Gate taught before tested: yes — glide taught in earlier Coolant rooms; the
    boss is the test.
[x] Preserves RPS read: yes — three armor types in one fight force swapping; no
    single element wins.

--- IMPLEMENTATION HANDOFF (godot-game-dev) ---
[x] Maps to: boss as a scene with its own FSM (EstadoBase pattern); adds/relays on
    Enemy layer 3; updrafts as Environment/Area2D; player uses GlideState.
[x] Data-driven: boss attack spells as SpellData .tres; armor weaknesses as data.
[x] Test plan: GUT pure-logic on phase transitions and armor-weakness resolution;
    smoke test the glide-over-hazard arena manually.

VERDICT: SHIP — serves all three pillars/loops, on-canon, is the glide
graduation, and keeps the RPS alive at boss scale.
```

### Notes for the developer

Build the boss FSM with the same `EstadoBase` node pattern as the player
(godot-game-dev section 1): `IdleState` -> `SlamState` -> `FloodState` ->
`EnrageState`. Drive its attacks from `SpellData` `.tres` so balance is editor-
tunable. The post-fight beacon flare is the hook that spawns heavier Empire units
in subsequent rooms (negative feedback loop, gated on this milestone — not on the
player's deaths).
