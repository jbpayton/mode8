# Retrospective queue (input for m8-newgame-plus)

## emberwake / M0 (2026-07-11)

### Gate + phase stats
- content gate: GREEN first-try for both specialist phases (systems, content). 0 repair rounds.
- completability: GREEN first-try; 1 benign orphan pattern (one-shot intro via blocked_by_flag excluded from monotone proof) — prover could learn the idiom.
- engine: 428/428 unit tests; 0 defects routed back post-delivery; conductor made 1 micro-edit (per-file evidence lines in run_tests.gd — gate-2 requirement the generated runner missed).
- balance: 1 violation caught (boss wipe 0.230 > 0.15), 1 data-patch round to green (0.090). Sim ran 3300 battles via the game engine; interpreter-vs-design-arithmetic agreement was exact on first contact.
- playtest: static green; rusher PASS (seed 1101, 1184 actions, 23 encounters 16W/7F, boss 23 turns, deterministic byte-identical incl. conductor rerun). Found PT-001 (real engine bug: phantom zero-count stacks + shop gold dupe) -> engine-smith fix + regression test (suite 430/430) -> rusher script repaired in 1 round-trip (2 cursor segments; battle events replayed identically). PT-002 deferred to M1 menu-wright.
- full persona-loop stat: 1 defect found by dynamic play that static analysis + 430 unit tests + 3300 sim battles all missed — personas earn their seat.

### RFC candidates surfaced by specialists (not yet filed)
1. stat-model needs a turn-order/speed role marker (engine bound it via project setting `m8/battle/speed_stat` — data, but engine-local).
2. map schema: npc → service binding (shopkeeper NPCs are flavor-only; services live in the pause menu — merchant NPCs should open the shop).
3. scene-registry: "ending" scene type missing (implemented but unregistered).
4. dialogue barks conditional on flags (village should react to flag.tyrant_down — loremaster craft rule currently unimplementable).

### Skill-edit candidates
- m8-engine-smith: engine contract §7 should require per-file summary lines in run_tests.gd output (the one thing the generated runner missed).
- m8-engine-smith: file-size rule (<300 lines) conflicted with the contract's fixed file list — battle.gd 586, algebra.gd 551. Either the rule allows contract-listed cores to exceed, or the contract should list battle/ and algebra/ as splittable modules.
- m8-menu-wright: menu spellcasting (usable_in: menu spells like mend) has no surfaced scene — pause-menu row list in engine-contract/scene work orders should include a Magic row when any menu-usable spell exists.
- m8-balancer: checkpoint authoring guidance could include "verify spike-kill margin vs. heal threshold" — the boss wipe was a heal-threshold jump, likely a recurring pattern.
- m8-conductor: briefing addenda worked well (systems→content→engine relay); formalize the "BINDING NOTES relay" step in the skill body.

### Thin-batteries audit
- No script deleted this cycle; none encoding judgment models have overtaken (all three are gate math / proof / harness).

### Cost notes (approximate, this build)
- 4 specialist sub-agents (systems 77k, content 127k, engine-core 281k, scenes 256k tokens) + rusher (pending) + conductor orchestration in main session.
