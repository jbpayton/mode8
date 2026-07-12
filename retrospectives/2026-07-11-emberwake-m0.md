# Retrospective — Emberwake / M0 (2026-07-11)

First build of the studio. M0 exit test **passed**: a fresh session given only *"build the game in games/emberwake/"* resumed from files, re-ran every gate, and reproduced all evidence bit-for-bit with zero human edits (commit `e22195f`).

## What the build cost
- 6 specialist sub-agent runs: systems 77k, content 127k, engine-core 281k, scenes 256k, rusher 369k(+repair), cold-resume proof 63k tokens; conductor orchestration in the main session. Wall time ≈ one working day, largely serialized on the engine and playtest phases.
- 0 human interventions between GDD stub and shipped build.

## What worked (keep doing)
- **The verification stack caught real defects at every layer it was designed for.** Balance sim: boss over-lethality (23% wipe → data patch → 9%) invisible to unit tests. Rusher persona: a shared-reference inventory bug enabling a gold dupe (PT-001) invisible to static analysis, 430 unit tests, *and* 3300 sim battles. Static prover: green first-try — because content agents ran it as a self-check before returning.
- **One-interpreter architecture (D-008) paid off immediately**: the sim caught gameplay-semantics bugs while integration-testing the real engine; interpreter output matched the systems designer's hand arithmetic exactly on first contact.
- **Work orders as files** (plan/orders/) + binding-notes relay between phases gave specialists everything with zero conversational context; the cold-resume proof confirmed the whole build is reconstructible from the repo alone.
- **RFC discipline held under pressure**: two expressiveness gaps became accepted clarifications (RFC-001/002) instead of silent forks; content agents hit zero walls after that.

## What broke (and what changed because of it)
| Finding | Change applied this cycle |
|---|---|
| PT-001: battle item consumption bypassed zero-erase; shop sell ignored remove_item's return (gold dupe) | engine fix + regression test (suite 428→430); defect pattern noted for engine-smith exemplars |
| Smoke-gate evidence had no repro command (cold session had to guess the seed) | m8-build-warden rule: every evidence file embeds its exact repro |
| simulate.py clobbered the hand-appended patch log on re-runs | script now preserves the `## Patch log` section |
| Stale gate evidence at wrap (428/428 committed after the suite became 430) | m8-conductor wrap rule: refresh any gate evidence predating a later repair |
| Generated test runner lacked per-file proof lines | engine contract §7 now requires `test_x.gd: n/n` lines |

## Proposed, not yet applied (need adjudication or their milestone)
- **RFC candidates** (in `ontology/RFCS.md` terms, drafts to file at M1 kickoff): stat-model role marker for turn-order stat; map-schema npc→service binding; scene-registry `ending` type; flag-conditional dialogue barks.
- m8-menu-wright M1: Magic row in pause menu when any `usable_in: menu` spell exists (PT-002).
- m8-balancer: checkpoint guidance on spike-kill margin vs. heal threshold (the boss wipe pattern will recur).
- Style-rule vs. contract conflict: battle.gd 586 / algebra.gd 551 lines vs. the <300 rule — recommend the contract name them splittable at M1.

## Thin-batteries audit
Three persistent scripts, all still earning their seat (gate math / proof / sim harness). Nothing encoding judgment a model has overtaken. One script *gained* logic this cycle (patch-log preservation) — justified as protecting an audit trail, not judgment.

## For next cycle (M1)
The atelier is the whole milestone. Provisioning research is done (`appliances/RESEARCH-M1.md`, pins verified, licenses cleared); the first day should stand up the ComfyUI appliance with PIN.json, run the icon smoke test through the gate cascade, and only then accept work orders. The M0 game regenerating with real art is the exit test — Emberwake's manifest-less placeholder art is the before picture.
