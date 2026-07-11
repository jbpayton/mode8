# MODE 8 — An Autonomous RPG Studio
### Founding Specification v0.1 — *"Everything Mode 7 couldn't."*

> **Mission:** Prove that an agent system can take nothing but a human's initial thoughts and a design conversation, and produce a complete, great-looking, great-playing, great-story 2D HD RPG — with zero human labor between the conversation and the shipped game. And then prove the deeper thesis: that the system can make itself better at making games, so quality is a curve, not a ceiling.

You (the executing agent) are being handed this document as your founding charter. Your job is to build the studio, not a game. Games are the studio's output. Read this whole document before writing anything. Then follow the milestone plan at the bottom.

---

## 1. Core Theses (the load-bearing beliefs)

1. **The design conversation is the source code.** The durable artifact of any game is its Game Design Document (GDD) — a structured compilation of the human conversation. Everything else (engine code, content data, assets, builds) is regenerable build output. Treat `/src` and `/assets` as disposable; treat `/gdd` and `/decisions` as sacred.

2. **Fix the vocabulary, not the engine.** Do not build one grand engine. Presuppose an *ontology* — a schema language for what games are made of — and let agents build a small, game-specific engine per title. The ontology is versioned and evolves slowly; engines are cheap and bespoke.

3. **Content is data, not code.** Weapons, spells, classes, monsters, statuses, items, encounters: all of these are expressions in an **effect algebra** (Section 4), interpreted by a small runtime. This is what makes thousand-item armories and deep bestiaries safe to generate and possible to verify.

4. **Nothing ships unverified.** Every artifact class (code, content data, image asset, audio, narrative, build) has a programmatic verification gate. When a gate cannot be deterministic, it is a rubric-scored model judgment. When judgment fails, the failure is converted into a *repair instruction*, not a bare rejection.

5. **The system improves the system.** Every game build ends with a retrospective that mutates the skill library. Failure taxonomies, gate hit-rates, and judge disagreements are metrics; skills are the parameters they tune.

6. **Post-software: the studio is a session, not a program.** MODE 8 has no application, no orchestration framework, no long-lived codebase of its own. The entire studio is skills + a Claude Code session + a repo of files + pinned external appliances. Persistent code exists only as small, single-purpose scripts bundled inside skills, and only where determinism demands it (a gate must score bit-identically across runs; a sim must be cheap to run ten thousand times). Everything else — orchestration, judgment, glue, one-off transforms — is the agent working live, writing ephemeral code when needed and throwing it away. Every line of persisted logic is a bet *against* model progress; instructions and judgment are bets *on* it. Keep the batteries thin: just enough to make the loop repeatable, no more. As the models get better, this studio gets better for free.

---

## 2. System Architecture Overview

```
┌────────────────────────────────────────────────────────────┐
│  L6  DESIGN COMPILER    conversation → GDD → work orders   │
├────────────────────────────────────────────────────────────┤
│  L5  STUDIO ORCHESTRATOR   agent topology, task fan-out    │
├──────────────┬──────────────────────┬──────────────────────┤
│  L4 SYSTEMS  │  L4 CONTENT          │  L4 ASSETS           │
│  DSL + engine│  armory/bestiary/    │  diffusion pipeline  │
│  generation  │  spells/story/quests │  + gate cascade      │
├──────────────┴──────────────────────┴──────────────────────┤
│  L3  VERIFICATION    balance sim · playtester · asset QA   │
├────────────────────────────────────────────────────────────┤
│  L2  ONTOLOGY    effect algebra · stat model · scene types │
├────────────────────────────────────────────────────────────┤
│  L1  SUBSTRATE   Claude Code session · Godot · gen backend │
└────────────────────────────────────────────────────────────┘
```

### L1 Substrate (pinned, boring, containerized)
- **Runtime target:** Godot 4.x. Text-native scene/resource formats, headless CLI (`godot --headless`) for builds, test runs, and screenshot capture. GDScript for the generated engine.
- **Generation backend:** ComfyUI running headless as a pinned container appliance — workflows submitted as JSON via the `/prompt` API, results pulled via history/WebSocket. Node packs (including VNCCS and VNCCS-Utils) pinned to specific commits. Treat it as a frozen service; never touch its UI. The agent composes and rewrites workflow JSON directly; a small submit-and-fetch script bundled in `m8-atelier` is the only persistent client code. Migration path: any stage may later be driven a different way behind the same skill interface; the skill is the contract, the backend is a detail.
- **Runtime:** the Claude Code session itself. No orchestration package, no daemon, no framework. The agent runs bash, writes ephemeral code, drives the appliances, and spawns sub-agents. VRAM is the scarce resource: sequence generation and judging stages rather than co-loading; assume one consumer GPU.
- **Model endpoints:** a local OpenAI-compatible VLM endpoint (for judge tiers) plus the session's own frontier model for escalation and all agentic work. Endpoints and pins live in one config file at the repo root (`config.json`), read by skills.
- Everything reproducible: seeds, model hashes, workflow JSON, and configs pinned per asset in a manifest. Any asset regenerable from its spec.

### L2 Ontology (the fixed vocabulary — versioned, evolves by RFC only)
The schemas that all agents write against. Not a code library — a set of JSON Schema files plus markdown reference docs, living in `ontology/` at the repo root and mirrored into skill `references/`. Any agent can validate any content file against them with an ephemeral one-liner; nothing needs importing:
- **Effect algebra** (Section 4) — the combinator language for all game mechanics.
- **Stat model** — declared stats, derived-stat formulas, resource pools, growth curves.
- **Entity schemas** — Item, Weapon, Armor, Spell, Skill, Class, Monster, StatusEffect, Encounter, Character, Recruit event.
- **World schemas** — Map, Region, Town, Dungeon, Shop inventory, Treasure table.
- **Narrative schemas** — StoryGraph (nodes: scene / choice / battle / recruit / flag-gate), DialogueScript, Cutscene, VN interlude.
- **Scene-type registry** — the presentation vocabulary: overworld, battle (menu or grid), shop, status, party-builder, dialogue/VN, title, save/load. Every screen in every game is an instance of a registered scene type rendering a slice of game state.
- **Style bible schema** — palette, line weight, resolution rules, character proportions, tile grid, per-asset-class prompt scaffolds.

### L3 Verification (Section 6, 7, 8) — the moat. Build it with the same seriousness as generation.

### L4 Production layers — the agent-facing skills (Section 5).

### L5 Studio Orchestrator
Not a process — a Claude Code session following the `m8-conductor` skill. It reads the GDD, derives a task plan, and fans work out to specialist sub-agents (Task tool), each briefed with its domain skill. Task state, work orders, and completion records are plain files in the game repo (`games/<title>/plan/`), so any future session can resume the build cold. The schema layer is the contract that lets specialists work in parallel without breaking each other; the balance sim and integration build are the cross-domain tests.

### L6 Design Compiler
The skill that runs the human design conversation and compiles it into the GDD: genre selection, cast model, tone bible, world sketch, difficulty philosophy, scope (target hours), and the style bible. Ambiguities become explicit recorded decisions with rationale (the decision graph is a first-class artifact). After the conversation ends, no human input is required or requested.

---

## 3. Genre Configuration Matrix

Genre is a top-level GDD decision, not an engine fork. The same ontology and content pipeline serve all three launch genres:

| Axis | FF1-style | FF6/Chrono-style | Strategy RPG |
|---|---|---|---|
| Cast | player-built party | authored fixed cast | authored + recruitables |
| Party screen | party-builder scene at start | recruit events in story graph | barracks/roster scene |
| Battle spatial model | menu, rows | menu, rows, dual/triple techs as combo effects | grid: position, range, movement, AOE shapes, facing |
| Narrative weight | light frame story | heavy; VN interludes, character arcs | mission briefings + interludes |
| Content emphasis | classes & equipment breadth | character-specific mechanics | class trees, terrain, unit variety |

The battle interpreter is the main thing that swaps (target selectors resolve from menus vs. grid geometry); the effect algebra, content, and verification stack are shared. A fire spell is the same data in all three.

---

## 4. The Effect Algebra (keystone — implement first, RFC any change)

A small combinator language. All mechanics are expressions in it; the per-game engine implements an interpreter for it. Starting primitive set (extend by RFC, never fork per-game):

**Values**
`const(n)` · `stat(ref, of=source|target)` · `dice(NdM+K)` · `formula(expr)` — expr is a sandboxed arithmetic DSL over stats, level, flags · `scaling(curve_id, level)`

**Target selectors**
`self` · `single(side)` · `all(side)` · `row(side, which)` · `random(side, n)` · `lowest(stat, side)` · `dead(side)` — and for SRPG: `radius(n)` · `line(n)` · `cone(n)` · `cell` · `adjacent`

**Triggers**
`on_use` · `on_hit` · `on_crit` · `on_kill` · `on_damage_taken` · `on_turn_start` · `on_turn_end` · `on_equip` (passive) · `on_battle_start` · `on_hp_below(pct)` · `aura(range)` (SRPG)

**Effects**
`damage(value, element, type=physical|magical|fixed)` · `heal(value)` · `apply_status(id, duration, potency, chance)` · `cure_status(ids)` · `modify_stat(stat, op, value, duration)` · `resource(pool, delta)` · `revive(pct)` · `summon(entity, duration)` · `move(pattern)` / `knockback(n)` (SRPG) · `steal(table)` · `scan` · `flee` · `transform(entity)` · `set_flag(id)`

**Modifiers**
`element(id)` · `accuracy(base)` · `crit(rate, mult)` · `variance(pct)` · `pierce(defense_pct)` · `conditional(predicate, effect)` — predicates over target status, element affinity, HP thresholds, flags, terrain (SRPG)

**Costs & constraints**
`mp(n)` · `hp(n)` · `item(id)` · `charge(turns)` · `cooldown(turns)` · `row_lock` · `range(min,max)` · `class_lock(ids)` · `once_per_battle`

**Composition**
`seq(e1, e2, …)` · `choice(weighted list)` · `repeat(n, e)` · `branch(predicate, then, else)` · `combo(participants, e)` (dual/triple techs)

**Element & status systems** are declared per-game in the GDD (element wheel with affinities/weaknesses; status registry with stacking rules) — the algebra references them by id.

Design test: FF6's relic economy, Chrono Trigger's combo techs, and a Tactics-style height/range battle should all be expressible without new primitives. If they aren't, the RFC process fixes the algebra, once, for all games.

---

## 5. The Skill Library (what you will actually author)

Author each as a proper Claude Code skill: `SKILL.md` with pushy, trigger-rich description; body <500 lines; `scripts/` for deterministic operations; `references/` for schema docs and exemplars; `assets/` for templates. Progressive disclosure: metadata always loaded, body on trigger, references on demand. Skills that spawn sub-agents must include the sub-agent's briefing template in `references/`.

**The thin-batteries rule (Thesis 6 applied):** the skills ARE the system — there is no software underneath them. A script earns a place in `scripts/` only if it passes one of two tests: (a) *determinism* — the operation must produce bit-identical results across runs and sessions (gate math, embedding thresholds, sim harness, manifest hashing), or (b) *economy* — it runs thousands of times per build and re-deriving it live would be wasteful (the Monte Carlo battle loop, the ComfyUI submit/fetch call). Everything failing both tests is done live by the agent with ephemeral code or plain judgment, and improves automatically as models do. When a retrospective finds a script encoding judgment a model can now make better, the script gets deleted, not improved.

**Meta**
- `m8-conductor` — reads GDD, builds task DAG, spawns specialists, tracks completion, runs integration builds.
- `m8-design-compiler` — runs the human design conversation; emits GDD + style bible + decision log.
- `m8-newgame-plus` — post-build analysis; proposes skill edits and ontology RFCs; each build cycle is a new run that carries everything learned forward (Section 9).

**Systems**
- `m8-systems-designer` — owns the game's stat model, element wheel, status registry, growth curves; emits the game's DSL profile (which primitives are active, formulas).
- `m8-engine-smith` — generates the Godot project: effect-algebra interpreter, battle interpreter for the chosen spatial model, scene-type implementations, save/load, input map. Every generated module ships with GDScript unit tests, runnable headless.
- `m8-menu-wright` — implements scene types against the registry: shops, status, inventory, party-builder, dialogue/VN player. Menus are the connective tissue; this skill owns UX conventions (cursor memory, cancel semantics, controller+keyboard).

**Content** (each fans out to sub-agents for depth; all emit DSL data, never code)
- `m8-armory` — weapons/armor/accessories at scale: names, lore lines, stat blocks, effect expressions, sprite prompts, shop/treasure placement, tier tags.
- `m8-spellbook` — spells & techniques: per-class lists, elemental coverage, learn curves, animation specs.
- `m8-bestiary` — monsters: stat blocks, AI behavior scripts (as effect-algebra policies), drop/steal tables, palette-swap families, boss mechanics, sprite prompts.
- `m8-classweaver` — classes/jobs: stat growths, ability trees, equipment permissions, promotion paths.
- `m8-loremaster` — story graph, character sheets & arcs, dialogue, VN interludes, sidequests, flags. Owns tone-bible enforcement.
- `m8-cartographer` — world map, region layouts, town/dungeon tilemap specs, encounter tables, treasure placement, pacing of the difficulty curve across geography.

**Assets**
- `m8-atelier` — the generation pipeline client: character sheets (VNCCS-recipe staged conditioning: base → clothes → emotions → poses), monster art, tilesets, portraits, battle backgrounds, UI chrome, item icons. Owns the style bible's enforcement and the manifest (seed/model/workflow pinning).
- `m8-asset-warden` — the gate cascade (Section 6). Every image passes through it; owns the repair loop.
- `m8-soundsmith` — (stub at v1) music/SFX slots with placeholder generation; interface defined now, models later.

**Verification**
- `m8-balancer` — the Monte Carlo battle simulator and its analyses (Section 7).
- `m8-playtester` — autonomous play (Section 8).
- `m8-build-warden` — headless build, unit tests, lint, schema validation, save/load round-trip tests, integration smoke test.

---

## 6. Asset Pipeline & Gate Cascade

Generation is staged conditioning (mine VNCCS's recipes: pose-skeleton ControlNet guidance, face-detect refinement passes, identity-preserving edit models, background removal to alpha). Verification is a cascade, cheapest first; a failure at any tier produces a structured *defect report*:

**Tier 1 — deterministic geometry (ms):** alpha QA (single connected component, no islands, no edge halos), sheet registration (feet baseline, centroid drift, bbox variance across frames), palette conformance (histogram distance vs. style bible), scale conformance (character px height vs. spec), file/format checks.

**Tier 2 — measured semantics (s):** re-run pose estimation on outputs, keypoint deviation vs. conditioning skeleton (did ControlNet obey?); identity via embedding similarity of masked crops against the character's canonical reference embedding (set at character-approval time); style embedding distance vs. style-bible anchors.

**Tier 3 — VLM judge (rubric-scored, reference images in context):** anatomy defects (hands, joints), style drift, expression correctness vs. spec, and the in-game readability test — downscale to actual render size and judge silhouette legibility. Local VLM first; escalate low-confidence or disagreeing scores to frontier model.

**Tier 4 — in-engine differential:** load into headless Godot, render in situ (on the tile grid, in the battle scene), screenshot, judge in context. Animation cycles rendered to GIF and judged as *motion* (plus optical-flow smoothness metrics between frames).

**Repair loop:** defect reports compile to targeted edit instructions (masked inpaint / instruction-edit on the failing region) — edit models converge where re-rolls random-walk. Generate N candidates → gates → judge ranks → winner, or ≤K repair rounds → reseed → after R reseeds, escalate to the retrospective queue as a systemic failure (bad prompt scaffold, bad style bible entry) rather than looping forever.

**Animation strategy:** generate cycles as single-canvas sheets (model attends to all frames at once); keyframe+interpolate as the fallback. Walk (4-dir), idle, attack, cast, hit, KO as the v1 cycle set.

---

## 7. Balance Simulation (`m8-balancer`)

Because all mechanics are interpretable data, balance is computable without play:
- **Battle Monte Carlo:** simulate ≥10k battles per progression checkpoint (party composition and gear sampled from what's plausibly available at that point) vs. the encounter tables for that region.
- **Checks (all thresholds set in the GDD's difficulty philosophy):**
  - TTK curves within band per region; boss fights within their own band.
  - Party wipe-rate within band (challenge without grind-walls); grind-wall detection = wipe-rate only fixable by leveling beyond expected curve.
  - **Dominated-content detection:** no item strictly worse than a cheaper same-tier item; no item that trivializes its tier; every spell/class has a niche (usage rate in optimal-policy sims above floor).
  - Damage/stat monotonicity across tiers; economy sanity (gold income vs. shop prices along the expected path).
  - Class/character viability spread (no dead party members in optimal play).
- **Output:** balance report + *auto-patches* — the balancer may propose stat-block edits (data patches, never code) which re-run the sim; unresolvable conflicts route back to the owning content skill with the report attached.

---

## 8. Autonomous Playtesting (`m8-playtester`)

Two complementary modes:
- **Static completability:** compile the story graph + flag system + item gates into a reachability analysis. Prove the ending is reachable from a new save; prove no flag combination soft-locks; prove every required item/recruit has an obtainable path; find unreachable content (authored but orphaned = defect).
- **Dynamic personas:** agents drive headless Godot via injected inputs (expose a debug input/state API in the generated engine — `m8-engine-smith` requirement). Personas: *rusher* (critical path, minimum grind), *completionist* (all sidequests/chests), *chaos monkey* (menu fuzzing, cancel-spam, save/load at hostile moments). Each run logs state traces; screenshots sampled at scene transitions for VLM QA (UI overlap, missing assets, text overflow); crashes and stuck-states (no state change in N inputs) are defects with full repro traces.
- **Fun proxies (v1, honest about limits):** pacing metrics (fight/story/menu time ratios vs. GDD targets), choice significance (do branches change state?), reward cadence. True "fun" verification is a research frontier — instrument now, improve via retrospectives.

---

## 9. New Game Plus — The Self-Improvement Loop (`m8-newgame-plus`)

After every game build (and every milestone):
1. Collect metrics: gate hit-rates by tier and defect class, repair-round distributions, judge escalation and disagreement rates, sim balance-patch counts by content domain, playtester defect taxonomy, token/time cost per artifact class.
2. Diagnose: which skill produced the most defects per artifact? Which prompts/scaffolds correlate with Tier-3 failures? Which ontology gaps forced workarounds?
3. Mutate: propose concrete skill edits (SKILL.md diffs, new reference exemplars drawn from this build's best outputs, script fixes) and ontology RFCs. Apply skill edits on a branch; A/B the edited skill against the incumbent on a fixed test battery before merging. Skills are versioned; the library's eval battery grows every cycle.
4. Report: one markdown retrospective per build in `/retrospectives`, human-readable, because the human governs intent and vocabulary even when they touch nothing else.

This is the "better at making the system better" mandate made mechanical. Treat the skill library as the model weights of the studio.

---

## 10. Repository Layout

```
mode8/
├── SPEC.md                  # this document
├── config.json              # endpoints, model pins, GPU policy
├── ontology/                # L2: JSON Schemas + effect algebra docs + RFCS.md
├── skills/                  # the skill library — this IS the system (the studio's weights)
│   └── m8-*/                #   SKILL.md + references/ + scripts/ (thin-batteries rule)
│                            #   e.g. m8-asset-warden/scripts/ holds the gate math;
│                            #   m8-balancer/scripts/ holds the sim harness
├── appliances/              # pinned containers (comfyui/, godot/) — driven, not written
├── games/<title>/
│   ├── gdd/                 # source of truth: GDD, style bible, decision log
│   ├── plan/                # conductor task state — any session can resume cold
│   ├── content/             # DSL data: armory, bestiary, spells, story graph…
│   ├── assets/              # build output + manifests (regenerable)
│   ├── src/                 # generated Godot project (regenerable)
│   └── reports/             # balance, playtest, gate stats
└── retrospectives/
```

---

## 11. Milestone Plan (each milestone = a shippable proof)

**M0 — Walking Skeleton (prove the loop end-to-end, ugly on purpose).**
Ontology v0 + effect algebra interpreter with unit tests. Design-compiler stub emits a fixed micro-GDD: one town, one 3-floor dungeon, 3 monsters + 1 boss, 5 items, 4 spells, 2 classes, menu battle, save/load, an ending. Placeholder art (colored rects + generated portraits, no gates). Build runs headless; static completability passes; one rusher persona finishes it. **Exit test: a fresh Claude Code session given only "build the game in `games/<title>/`" produces a completable build with zero human edits.**

**M1 — The Atelier.** Full asset pipeline + gate cascade + repair loop replaces placeholders: character sheets with 4-dir walk cycles, monster art, one tileset, portraits, UI chrome, item icons — all style-bible conformant, all manifest-pinned. Exit: M0's game, regenerated, looks like a real HD-2D game; gate stats reported.

**M2 — Depth.** Content skills at scale with balance sim: 150+ items, 60+ monsters (families + palette logic), 30+ spells, 4+ classes, 8–12 hour curve, shops/treasure/economy. Exit: balance report green; dominated-content count = 0; a completionist persona finishes.

**M3 — Story.** Loremaster + menu-wright full VN interlude system; fixed-cast game with recruit events, character arcs, sidequests, flag-gated branches. Exit: static analysis proves all branches sound; VLM narrative-coherence rubric passes on sampled scene chains.

**M4 — Genre Proof.** Three GDDs, one pipeline: an FF1-style party-builder game, an FF6-style fixed-cast game, and a grid SRPG (battle interpreter swap). Exit: all three build, verify, and complete with no per-game skill forks — only GDD differences.

**M5 — The Flywheel.** Retrospective skill operating across ≥3 build cycles with measured improvement (defect rates down, repair rounds down, judge escalations down) from skill mutations alone. Exit: a documented before/after on the same GDD.

**M6 — The Real One.** A full design conversation with the human → an original ~15-hour RPG, shipped. The proof.

---

## 12. Ground Rules for the Executing Agent

- Schema changes are RFCs in `ontology/RFCS.md` with rationale — never silent edits. Content agents may not extend the algebra; they file RFCs.
- Every generated code module ships with tests runnable headless; every asset ships with its manifest; every judgment ships with its rubric score and inputs (auditable).
- Honor the thin-batteries rule: before persisting any script, state which test it passes (determinism or economy) in a comment at the top. Scripts that pass neither get done live and discarded. Retrospectives audit `scripts/` for judgment that models have overtaken — delete, don't refactor.
- All durable state is files in the repo. A fresh Claude Code session pointed at the repo with the skills installed must be able to resume any build from `games/<title>/plan/` with no other context.
- Prefer boring, pinned, reproducible over clever. One consumer GPU is the budget assumption; degrade gracefully (smaller quants, staged loading) rather than assuming a cluster.
- When blocked by a genuine ambiguity in this spec, make the call, record it in the decision log with rationale, and continue. Do not stall awaiting human input — that defeats the thesis.
- Milestones are sequential gates: do not start M(n+1) until M(n)'s exit test passes, re-run from a fresh session to prove resumability.

*Dream big, verify everything, and let the retrospectives make next month's studio embarrassed by this month's.*
