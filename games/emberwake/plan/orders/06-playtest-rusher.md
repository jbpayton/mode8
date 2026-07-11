# Work order 06 — playtest phase: rusher persona

You are the m8-playtester for the MODE 8 studio, running the rusher persona on "Emberwake".

BINDING RULES — read first, in order:
1. /home/seraphius/mode8/skills/m8-playtester/SKILL.md (persona definitions, stuck-state rule, defect format, fun proxies)
2. /home/seraphius/mode8/skills/m8-engine-smith/references/engine-contract.md §6 (drive model: --m8-script/--m8-trace/--m8-seed; action vocabulary; trace format)

GAME CONTEXT:
- Game dir: /home/seraphius/mode8/games/emberwake/ (project in src/; godot binary /home/seraphius/mode8/appliances/godot/godot)
- Read content/maps/*.json to plan routes (tiles are strings through legend; entities have coordinates). Read content/story.json for the flag/item gates. The smoke artifacts at reports/playtest/smoke/ show working action-script style.
- Existing evidence: static completability GREEN (reports/completability.json). Your job is the DYNAMIC proof.

YOUR TASK — rusher: reach the ending with minimum detours, in ONE deterministic script:
- Work in reports/playtest/rusher/. Iterate: extend actions.json → run with a FIXED seed (--m8-seed=1101, keep it) → read trace.jsonl → extend further. Reruns are from the start and deterministic; use generous --m8-max-frames (e.g. 20000).
- Required beats: title → new game → party build (any 2) → intro fires → elder quest → shop (buy what the purse allows — rusher buys minimally but survival gear is allowed; you may include shopping if wipes block progress) → descend F1→F2 (take the guaranteed ember-key chest — it is required) → F3 → vault trigger → defeat the Ash Tyrant → ending scene → credits → back to title. Trace must show the ending scene and quit.
- Random encounters will interrupt movement: battles must be fought (or fled) through the battle menu via scripted actions. The trace's battle_event/state lines tell you battle state; adjust the script accordingly. This is the hard part — budget your iterations for it. If an encounter pattern makes a fixed script impossible to push through (e.g. unpredictable encounter positions derailing subsequent movement), that is expected to NOT happen with a fixed seed — if it does happen, that's a determinism defect: file it.
- Deaths/wipes on the way: allowed to adjust strategy (level a bit more, buy potions) — but total grind must stay within GDD grind_tolerance (party ≤L5 at the boss).
- File defects per the skill's format (reports/defects/PT-NNN.md) for anything broken, stuck (60-step no-state-diff), or contract-violating you hit. A completed run with defects is still a completed run — report both.
- When the run completes: write reports/playtest/summary.json: {"personas": {"rusher": {"status": "pass"|"fail", "seed": 1101, "script": "reports/playtest/rusher/actions.json", "trace": "reports/playtest/rusher/trace.jsonl", "ending_reached": bool, "defects": [ids], "final_party_levels": [...], "total_actions": n}}} plus fun-proxy telemetry per the skill (scene time-share by trace lines, battle length distribution, steps between reward events) under a "proxies" key.

OUTPUTS: reports/playtest/rusher/{actions.json,trace.jsonl}, reports/playtest/summary.json, reports/defects/PT-*.md (if any).

CONSTRAINTS:
- You may NOT edit anything outside reports/ — no content edits, no engine edits, no script/seed workarounds that mask defects (a defect you route around must still be filed).
- Return format: (1) pass/fail + ending reached, (2) final script length + iterations used, (3) defects filed with one-line summaries, (4) proxies snapshot, (5) anything the next persona (completionist, M2) should know. No prose recap.
