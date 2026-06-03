---
name: game-design
description: >-
  Load when designing or speccing ANY Mage Rage gameplay: a new ability/spell,
  enemy, level/room, progression gate, boss, difficulty tuning, faction beat, or
  when evaluating whether a proposed feature fits the GDD. This is the DESIGN
  doctrine (what to build and why), not engine code — pair it with
  .claude/skills/godot-game-dev/SKILL.md for the HOW. Use it to keep every
  gameplay choice consistent with the three GDD pillars, the layered core loop,
  the metroidvania genre, and the tragic/cosmic canon in docs/LORE-BIBLE.md.
---

# Mage Rage — Game Design Doctrine (Team Training Skill)

> Genre: 2D side-scroller / metroidvania action-platformer. Tone: **tragic,
> cosmic, severe** (LORE-BIBLE §0). This skill is the **filter** the team runs
> design decisions through so they stay on-pillar, on-loop, on-canon. The canon
> is `docs/GDD.md` + `docs/LORE-BIBLE.md` — **never contradict them.** When a
> claim here is an established design principle vs. a Mage-Rage judgment call,
> it is labeled `[principle]` or `[judgment]`. Implementation patterns live in
> [`../godot-game-dev/SKILL.md`](../godot-game-dev/SKILL.md).

## When to Use This Skill

Load before writing any gameplay spec or ability/enemy/room/boss design, before
tuning difficulty, before adding a new system, or whenever someone asks "should
we build X?" If the task is *what to build and why it fits Mage Rage*, this skill
governs. If the task is *how to build it in Godot*, hand off to
`godot-game-dev`. The two are meant to be read together: every design decision
below names the Godot construct (`SpellData` element, FSM state, collision
layer) it eventually becomes.

## The Three Pillars (the primary filter)

From GDD §1. **Every feature must visibly serve at least one. A feature that
serves none is cut, no matter how cool.** `[judgment: this "serves a pillar or
it's cut" rule is our team stance, not a universal law]`

1. **The jailer was the protector.** The Empire is an *amnesiac quarantine*, not
   cartoon evil. → Enemy/faction design must carry tragic ambiguity: drones that
   read as desperate guardians, environmental storytelling that the prison once
   protected. Never write the Empire as gleefully cruel.
2. **The weapon decides its own target.** The hero is engineered to destroy yet
   *chooses* to sacrifice himself against the Ancient Ones. → Player agency and
   the creation/destruction duality should surface in mechanics (the antimatter
   ultimate *embodies* the choice), not just cutscenes.
3. **Flight is freedom and doom.** Movement mastery *is* the plot escalation —
   each new traversal verb rings the beacon louder. → Every traversal unlock
   should be staged as a triumph that *also* raises the threat (negative
   feedback loop, below). Flight is the apex of both.

**Tone guard `[principle]`:** when pillar and spectacle conflict, prioritize
theme (LORE-BIBLE §0 rule 5). Severe, not edgy; hopeful at terrible cost.

## The Layered Core Loop (the second filter)

From GDD §2 — three nested loops. **A feature should strengthen at least one
layer and not corrode the others.** `[principle: layered/nested loops are
standard core-loop design]`

| Layer | Span | What the player does | A feature here is good if… |
|---|---|---|---|
| **Micro** | second-to-second | Run, dodge, swap Fire/Ice/Electricity vs. armor type | it sharpens moment-to-moment readability & decision-making |
| **Minute** | minute-to-minute | Clear sectors, solve mobility puzzles, kill mini-bosses | it gives a satisfying mid-size goal + reward beat |
| **Macro** | hour-to-hour | Absorb a new element → unlock movement verb → open the map | it deepens permanent progression and the "movement = mastery" reveal |

**Failure mode to reject:** a feature that serves *no* layer (pure decoration
with no loop role) or one that *steals* from a layer (e.g. an auto-aim that kills
the micro element-swap decision). Name the layer(s) in every spec.

## Metroidvania Progression (ability-gated traversal)

Mage Rage's macro loop *is* lock-and-key metroidvania design. `[principle: this
is the GMTK "Boss Keys" / Metroid lineage]` Each absorbed element is a **key**
that permanently unlocks a **movement verb**, which is the key to a class of
locks. Map it explicitly — this table is the design contract and it mirrors the
LORE-BIBLE "movement = mastery" table and the FSM in `godot-game-dev`:

| Element (key) | Movement verb | FSM state | Route types it unlocks (locks) |
|---|---|---|---|
| **Fire** | Leap / explosive dash | `JumpState` | Gaps too wide to walk; breakable/ignitable barriers; first vertical reach |
| **Ice** | Glide / hang-time | `GlideState` | Long horizontal chasms; descents needing controlled float; frozen-platform puzzles |
| **Electricity** | Levitation / true flight | `FlightState` | Vertical shafts, ceilings, open-air sectors — the game becomes an aerial side-scroller |
| **Antimatter** | Ultimate (all elements at once) | charge/release state | Climactic, not a traversal gate — the build-and-release climax |

**Lock-and-key rules `[principle]`:**
- **Teach the gate before you test it.** First use of each verb is in a safe,
  low-stakes room that *teaches* the verb; only later rooms *test* it under
  pressure. The Fire trial teaches the leap before any spike pit demands it.
- **A lock should read as a lock.** The player must recognize "I can't pass this
  yet" so a returned visit feels earned, not arbitrary. Use clear visual
  vocabulary (e.g. updrafts only flight can ride; ice-only frozen valves).
- **Intentional backtracking, not busywork.** New verbs should reframe *already
  seen* spaces (the player remembers the unreachable ledge in the Foundry).
  Reward the return with a shortcut, secret, or lore, never a dull fetch.
- **Map legibility.** Keep a legible map; gate-types should be visually coded so
  players can plan returns. `[judgment: exact map UI TBD]`
- **Dependency-graph the critical path** before building rooms: lay out
  locks (squares), keys (diamonds), bosses (circles) and confirm the player can
  always reach the next key with verbs they already have. (GMTK "Boss Keys"
  dependency-graph method.)

## Elemental Combat Design

GDD §3 + LORE-BIBLE §3. Fire/Ice/Electricity are an armor-matchup
rock-paper-scissors at the micro layer; map each to a `SpellData.element`.

- **Matchup, not damage-race `[principle]`.** Each enemy armor type is *weak* to
  one element and *resists/neutral* to others, so the player swaps to read the
  threat. Tie each enemy's weakness to the element's fiction: Fire =
  aggression/melt, Ice = stop mechanical systems, Electricity = chain-arc
  between linked automata.
- **Avoid one dominant element `[principle]`.** The classic failure is a single
  element that beats everything ("Poor, Predictable Rock"). Counter it: (a) no
  element is best against >~40% of enemies in a sector; (b) some encounters mix
  armor types so the player *swaps mid-fight*; (c) Electricity's chain damage is
  great vs. groups but weak single-target, etc. Keep options near-equal in
  optimal play.
- **Readability & telegraphing `[principle]`.** Enemy armor type must be visible
  at a glance (color/silhouette/VFX) and enemy attacks must telegraph with a
  wind-up the player can react to. If the player can't tell *which* element to
  swap to before the hit lands, the RPS layer is dead.
- **Mixing/combos `[judgment]`.** Encourage on-the-fly swapping and, where it
  fits, element mixing (e.g. Ice-then-Fire shatter). Keep this data-driven via
  `SpellData` `.tres` variants, not bespoke scripts (see `godot-game-dev` §2).
- **Antimatter is not in the RPS.** It is the ultimate (below), deliberately
  *above* the matchup economy.

## Feedback Loops (lore-justified difficulty)

GDD §4. Two loops, both **diegetic** — the difficulty system *is* the story.

- **Negative loop = the Empire escalates.** The more power you unleash, the
  harder the Empire's countermeasures. This is dynamic difficulty / rubber-
  banding **done as narrative**, which sidesteps the usual DDA pitfall.
  `[principle]` DDA's known failure mode is the player *noticing* and feeling
  cheated ("dying eases it up, so my win wasn't earned"). Our defense: make the
  escalation **legible and earned** — it ramps with *permanent progression*
  (new element absorbed), not with the player's recent deaths, and it's framed
  in-fiction (heavier drone classes deploy). Tie ramps to milestones, not to a
  hidden "you're struggling" signal. **Do not** secretly weaken enemies after
  deaths — it corrodes the severe tone and the earned-victory feel.
- **Positive macro tension = galactic powers drawn in.** As power grows, the
  Androids / Reptilians / Ancient Ones are slowly *foreshadowed* in the
  backdrop (codex, sky, distant signals), building dread toward the sacrifice.
  This loop has no rubber-band; it only ratchets up. It pays off the "power that
  grows calls something worse" theme.

## Pacing, Difficulty Curve & Boss Progression

`[principle: tension-and-release pacing is standard]` The macro spine:

```
mechanical mini-bosses (teach a verb under pressure)
  → Trial 1: FIRE   (Foundries)   → leap
  → Trial 2: ICE    (Coolant)     → glide
  → Trial 3: ELEC   (The Grid)    → flight
  → Empire core / "apparent victory" boss
  → Revelation beat (rest + tonal pivot)
  → Final Ascent → the Sacrifice (climax)
```

- **Ramp then rest.** Intensity should sawtooth, not climb monotonically: a hard
  sector earns a quiet, low-threat "rest beat" (exploration, lore, a safe room
  to enjoy the new verb) before the next ramp. The Revelation is the big rest /
  tonal pivot before the final climb.
- **Each trial boss is a verb's graduation.** Its arena *demands* the verb you
  just earned (Ice-trial boss arena punishes anyone who can't glide). This is a
  "movement = mastery" reveal moment — stage it as triumph + threat (the beacon
  flares brighter).
- **Difficulty source = mechanics, not stat inflation `[judgment]`.** Prefer
  enemies that demand the right element/verb over bullet-sponge HP. Hits should
  telegraph; deaths should read as *fair* (the severe tone needs the player to
  blame themselves, not the game).

## The Antimatter Ultimate (the climax mechanic)

LORE-BIBLE §4 + GDD §3. A **chargeable build-and-release** power: charge by
fighting, release to briefly wield all elements at once and *embody* the
creation/destruction seam. `[judgment: most numbers below are open tuning knobs]`

- **Earned and rare.** Charge accrues from skilled combat (landing correct-
  element hits, surviving danger), not idle time. It should fire seldom enough
  that each use feels like a story beat, not a cooldown. Rarity = power fantasy.
- **Risk/reward.** Consider a meaningful build-up cost or vulnerability window so
  release is a *decision*, not a free "win button." Releasing at the wrong
  moment should be a real mistake.
- **Diegetic foreshadow of the ending.** The ultimate is a *rehearsal* of the
  final Sacrifice — the player briefly becomes the antimatter-reality reaction
  that, at the climax, he becomes permanently and fatally. Design the VFX/feel
  so the ending reads as "the ultimate, but total and final."
- **Above the RPS.** It ignores armor matchups by design — that's its fantasy —
  so it must be rare enough not to flatten the element economy.

## Game Feel / Juice

`[principle: Swink, *Game Feel*; Nijman, "The Art of Screenshake"]` Feel is how
the fantasy lands in the hands. Mage Rage's feel rules:

- **Movement feel first.** Coyote time + jump buffering (already implemented in
  `godot-game-dev` §4) are non-negotiable for the leap→glide→flight progression.
  Each new verb must *feel* distinct (weighty leap, floaty glide, free flight).
- **Hit-stop & impact.** Brief hit-stop (freeze a few frames on a solid hit)
  sells weight; pair with knockback and a hit flash so the correct-element hit
  *reads* as correct.
- **Screen shake — sparingly.** Big shake for the antimatter ultimate and boss
  blows; almost none for routine hits. Overused shake numbs the climax and hurts
  readability. Reserve the loudest feel for the rarest, most thematic moments.
- **Readable VFX over noise.** Element color language must stay legible in chaos
  (Fire warm, Ice cold, Electricity arc, Antimatter = the "impossible" color).
  Juice must never bury the RPS read.
- **Camera.** Lead the camera toward motion/aim; widen on flight; tighten and
  punctuate the ultimate. `[judgment]`

## Level / Space Design (the industrial prison)

`[principle + judgment]` The prison is a vertical, industrial labyrinth that
*teaches itself*.

- **Rooms are mobility puzzles built around the current verb set.** Foundry
  rooms test leaps; Coolant rooms test glides; Grid rooms open into flight
  space. Use the environment (updrafts, coolant gates, charged rails) so each
  verb has signature terrain.
- **Guide with sightlines & framing.** Use light, silhouette, and converging
  lines to point the player toward the next objective and tease the unreachable
  (a flight-only ledge seen long before flight). Affordances should read without
  text.
- **Sell the quarantine.** Environmental storytelling should carry pillar 1 — the
  prison once *protected*; show abandoned guardian iconography, the glyph wall as
  scripture. Severe, sacred, sad.
- **Build on the Environment collision layer** (layer 1) and `TileMapLayer`
  terrains per `godot-game-dev` §3 & §5.

## The Feature-Vetting Checklist (most important deliverable)

Copy-paste this into any ability/enemy/room/boss/system spec and fill it in.
**A feature should score ≥1 in each of the four required gates. Any single
"FAIL" gate is a strong signal to cut or redesign.** `[judgment: thresholds are
our team convention]`

```
FEATURE: <name>
ONE-LINE: <what the player does / experiences>

--- GATE A: PILLARS (need ≥1 "serves") ---
[ ] Jailer-was-protector  : serves / neutral / VIOLATES — note:
[ ] Weapon-chooses-target : serves / neutral / VIOLATES — note:
[ ] Flight=freedom&doom   : serves / neutral / VIOLATES — note:
    >> Any "VIOLATES" = FAIL (cut or redesign).
    >> Zero "serves" = FAIL (serves no pillar).

--- GATE B: CORE-LOOP LAYER (need ≥1, and steals from none) ---
[ ] Micro  (sec-to-sec readability/decisions): serves / steals / n/a — note:
[ ] Minute (sector goal + reward beat)       : serves / steals / n/a — note:
[ ] Macro  (permanent progression/map)       : serves / steals / n/a — note:
    >> Zero "serves" = FAIL. Any "steals" = redesign that interaction.

--- GATE C: CANON CONSISTENCY (need "consistent") ---
[ ] Contradicts GDD?         : no / YES — where:
[ ] Contradicts LORE-BIBLE?  : no / YES — where:
[ ] Tone severe/tragic/cosmic: yes / NO (too lighthearted/edgy) — note:
    >> Any "YES contradiction" or tone "NO" = FAIL.

--- GATE D: TEACHES / REWARDS A VERB (need "yes") ---
[ ] Which verb/element does it teach, test, or reward?  : <Fire/Ice/Elec/Antimatter/leap/glide/flight/swap>
[ ] If it gates traversal: is the gate taught before tested? : yes / no
[ ] If combat: does it preserve the RPS read (no dominant element)? : yes / no / n/a
    >> Teaches/tests/rewards no verb AND isn't a deliberate rest beat = FAIL.

--- IMPLEMENTATION HANDOFF (godot-game-dev) ---
[ ] Maps to: SpellData element / FSM state / collision layer / TileMapLayer? — which:
[ ] Data-driven where possible (.tres, not bespoke script)? : yes / no
[ ] Test plan (GUT pure-logic where applicable): <note>

VERDICT: SHIP / REDESIGN / CUT  — reason:
```

A fully worked pass of this checklist (one ability *and* one boss, end-to-end)
lives in [`references/worked-example.md`](references/worked-example.md) — read it
when you need a model spec.

## Best Practices

- **Do** name the pillar(s) and loop layer(s) a feature serves in its first
  paragraph — *because* a feature that can't name them serves none.
- **Do** teach a verb in a safe room before testing it under pressure — *because*
  untaught gates read as unfair, killing the severe-but-fair tone.
- **Do** tie difficulty ramps to permanent progression milestones, not to recent
  deaths — *because* visible rubber-banding makes wins feel unearned (DDA's core
  pitfall).
- **Do** keep every element near-equal in optimal play — *because* one dominant
  element collapses the micro-loop RPS into Predictable Rock.
- **Do** reserve the loudest juice (shake, hit-stop) for the rarest beats —
  *because* overuse numbs the climax and buries readability.
- **Don't** write the Empire as gleeful villains — *because* it breaks pillar 1
  (the jailer was the protector).
- **Don't** add a "win button" the player can spam — *because* the antimatter
  ultimate's power fantasy depends on rarity and risk.
- **Don't** ship decoration with no loop role — *because* it dilutes pacing and
  spends build effort that a loop-serving feature needs.
- **Don't** let VFX/juice obscure enemy armor type or attack telegraphs —
  *because* the combat is a *read*, not a spectacle.

## Common Pitfalls

- **Cool feature, no pillar/layer** → fails Gate A or B; cut or reframe. Symptom:
  the spec describes spectacle but can't say *why the player cares* second-to-
  second or what it permanently changes.
- **Dominant element** → playtest shows one element handles everything; the swap
  decision evaporates. Fix: rebalance armor weaknesses; add mixed-armor
  encounters; differentiate single-target vs. group roles.
- **Visible rubber-banding** → players notice difficulty sagging after deaths and
  feel cheated. Fix: gate escalation on milestones, frame it in-fiction, never
  secretly nerf enemies post-death.
- **Untaught gate** → players hit a lock with no idea it's a lock or how to open
  it. Fix: teach-before-test rooms; clear visual lock vocabulary.
- **Backtracking as busywork** → returns are dull fetch trips. Fix: reframe known
  spaces with the new verb; pay returns with shortcuts/secrets/lore.
- **Shake everywhere** → the climax has nothing left to escalate to, and combat
  reads as mush. Fix: budget juice; loudest = rarest + most thematic.
- **Ultimate as cooldown** → fired constantly, it flattens the element economy
  and the ending's foreshadow. Fix: charge from skill, make release a risk
  decision, keep it rare.
- **Tone drift to "edgy/quippy"** → breaks LORE-BIBLE §0. Fix: severe, tragic,
  hopeful-at-a-cost; theme over spectacle.

## Verification

Design work is verified by **review against this skill**, then playtest:

1. **Checklist pass (required):** the spec includes a filled feature-vetting
   checklist with a SHIP verdict and no FAIL gates. The Reviewer can re-run it.
2. **Canon diff:** confirm zero contradictions with `docs/GDD.md` and
   `docs/LORE-BIBLE.md`. Cite the section a design beat draws on.
3. **Loop trace:** state, in one sentence each, what the feature does to the
   micro / minute / macro loop.
4. **Implementation traceability:** the spec names its `godot-game-dev`
   construct(s) so the Developer can build it idiomatically.
5. **Playtest read (when built):** can a fresh player (a) tell which element to
   swap to before the hit, (b) recognize a lock as a lock, (c) feel the new verb
   as distinct? If not, the design — not just the code — needs another pass.

## References

Heavy/optional material lives in `references/` and is **not** loaded by default —
read it only when a section above points to it.

- [`references/worked-example.md`](references/worked-example.md) — one ability
  ("Cryo-Lance" Ice spell) and one boss ("The Coolant Warden", Ice trial) taken
  end-to-end through the feature-vetting checklist, as a model spec.

## Provenance

- **Authored by:** Researcher subagent on behalf of ticket `TASK-004`.
- **Grounding — canon:** `docs/GDD.md` (§1 pillars, §2 loop, §3 mechanics, §4
  feedback loops), `docs/LORE-BIBLE.md` (§0 tone, §3 energies, §4 movement=mastery,
  §6 powers, §9 ending, §11 themes), `.claude/skills/godot-game-dev/SKILL.md`.
- **Primary design sources (principles are principled, not factual — judgment
  calls are labeled `[judgment]` inline):**
  - GMTK "Boss Keys" — metroidvania world / lock-and-key / dependency graphs:
    <https://www.youtube.com/watch?v=nn2MXwplMZA> (Super Metroid),
    <https://www.patreon.com/posts/how-i-make-graph-20631617> (dependency-graph method)
  - Steve Swink, *Game Feel: A Game Designer's Guide to Virtual Sensation*:
    <https://books.google.com/books/about/Game_Feel.html?id=i9GfunWcB-oC>
  - Jan Willem Nijman (Vlambeer), "The Art of Screenshake":
    <https://www.youtube.com/watch?v=AJdEqssNZ-U>
  - Dynamic difficulty adjustment / rubber-banding pitfalls:
    <https://www.gamedeveloper.com/design/game-changers-dynamic-difficulty>,
    <https://www.gamedeveloper.com/design/more-than-meets-the-eye-the-secrets-of-dynamic-difficulty-adjustment>
  - Elemental / tactical rock-paper-scissors, avoiding dominant strategy:
    <https://tvtropes.org/pmwiki/pmwiki.php/Main/ElementalRockPaperScissors>,
    <https://tvtropes.org/pmwiki/pmwiki.php/Main/TacticalRockPaperScissors>
- **Last verified:** 2026-06-02.
