---
name: m8-playtester
description: Autonomous playtesting for MODE 8 game builds. Use for the playtest phase — static completability proof over the story/world graph, then dynamic persona runs (rusher, completionist, chaos monkey) driving the game headless with input scripts. Produces defect reports with full repro traces.
---

# m8-playtester — Playtester (SPEC §8)

Two jobs: **prove** the game is completable (static), then **play** it and try to break it (dynamic). You file defects; you don't fix. Repro or it didn't happen: every defect carries `{action script, seed, trace line numbers}`.

## Static completability (always first — cheap, and personas can't finish an uncompletable game)

`scripts/static_completability.py <game_dir>` — monotone fixpoint over maps/portals/story/flags/guaranteed-treasure. Evidence: `reports/completability.json`. Red = route to the owning content skill with the unreachable thing named. It proves: an ending is reachable from a new save; every required item has a guaranteed obtainable path; and it lists orphaned content (authored, never reachable) and non-monotone hazards (`blocked_by_flag` on portals) as warnings you must triage, not ignore.

## Dynamic personas (engine contract §6 drive model: script → run → read trace → extend → rerun)

Work in `reports/playtest/<persona>/`. Loop per persona: write `actions.json` → run with a fixed seed → read `trace.jsonl` → extend or correct the script → rerun *from the start* (determinism makes this cheap). You are navigating by state, not pixels: positions, flags, hp, scene types are all in the trace. Consult `content/maps/*.json` to plan routes like a human reads a walkthrough map.

**Exact invocation** (custom args go AFTER `--`, read via `OS.get_cmdline_user_args()`; use an ABSOLUTE `--m8-script` path — a bare relative path silently no-ops under `--path`):
```
<godot> --headless --path games/<t>/src -- --m8-script=<ABS actions.json> --m8-trace=<ABS trace.jsonl> --m8-seed=<n> [--m8-max-frames=<n>]
```
Determinism repro = `cmp` the new trace against the committed one. **Screenshots** (`{"do":"screenshot","path":"<abs>"}` step; Tier-4 QA) need a windowed run — they no-op under `--headless`; wrap with `xvfb-run -a -s "-screen 0 1280x720x24" <godot> --path games/<t>/src -- …` (drop `--headless`). Full drive/trace contract: `skills/m8-engine-smith/references/engine-contract.md` §6.

- **rusher** (M0+): critical path, minimum fights (flee when allowed), straight to the ending. Success = trace ends in the ending scene → title/credits. This is the M0 exit persona.
- **completionist** (M2+): every chest, every shop item purchasable check, every sidequest, full bestiary contact.
- **chaos monkey** (M2+): menu fuzzing, cancel-spam, save/load at hostile moments, sell-everything, flee-everything. Runs on a random-action generator seeded per run; crashes and stuck-states are the quarry.

**Stuck-state rule:** no state-diff across 60 consecutive steps (excluding waits) = defect. Crash (nonzero exit / script error in stderr) = defect, attach stderr verbatim.

## Fun proxies (v1, honest)
From the rusher+completionist traces compute and report (no gate, telemetry for retrospectives): time-share of battle/menu/dialogue/overworld scenes vs. GDD pacing expectations; reward cadence (steps between chest/level/gear events); battle length distribution drift across floors.

## Defect format
`reports/defects/PT-<NNN>.md`: persona, seed, script path, trace excerpt (±5 lines), expected vs observed, owning skill. Update `reports/playtest/summary.json` with pass/fail per persona + defect count; the conductor gates on it.
