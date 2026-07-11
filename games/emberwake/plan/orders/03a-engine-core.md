# Work order 03a — engine phase, part 1: core (no scenes)

You are the m8-engine-smith for the MODE 8 studio, building "Emberwake" — core engine only; a second work order builds scenes on top of your APIs.

BINDING RULES — read first, in order:
1. /home/seraphius/mode8/skills/m8-engine-smith/SKILL.md
2. /home/seraphius/mode8/skills/m8-engine-smith/references/engine-contract.md  ← THE contract; §1 layout, §2 CLI, §3 determinism, §4 state, §5 sim, §7 tests are yours
3. /home/seraphius/mode8/ontology/effect-algebra.md (§Interpreter contract: resolution order, element multipliers, battle-log events, load-time unknown-op errors)
4. /home/seraphius/mode8/ontology/CONVENTIONS.md (shorthand normalization you must implement)

GAME CONTEXT:
- Game dir: /home/seraphius/mode8/games/emberwake/ — engine goes in src/
- All content in content/ is final and gate-green: stat-model, elements, statuses, items, equipment, spells, classes, monsters, encounters, world, story, dialogue, maps/. Your ContentDB loads THESE files (res:// paths — content is copied/linked into the project? NO: load via absolute-ish "res://../content/" does not work. Put content INSIDE the project: create src/content/ as a directory containing a Godot-visible copy — DECISION: implement ContentDB to load from "res://content/", and create that as a symlink src/content -> ../content (relative symlink; Godot follows symlinks on Linux). Verify headless load works; if symlink fails under export later, that's an M1 problem).
- Godot binary: /home/seraphius/mode8/appliances/godot/godot (4.7-stable). Warm imports once: <godot> --headless --path src --import (expect exit 0).

YOUR TASK — build and test, in this order (test each module before the next):
1. src/project.godot — application name, main_scene left pointing at res://scenes/title.tscn (scenes arrive in 03b; that's fine for --script runs), window size from gdd/style-bible.json (640×360, nearest), [autoload] entries: ContentDB, Game, Rng, M8Input, M8Debug (autoload/*.gd — implement Rng, ContentDB, Game fully; M8Input/M8Debug as contract-correct implementations §6 — they don't need scenes to be testable), custom input actions per contract §6 (move_up/down/left/right, confirm, cancel, menu) mapped to arrows+WASD, Enter/Z, Esc/X, M.
2. src/engine/formula.gd — recursive-descent parser per the DSL grammar (tokenizer + parser to AST + evaluator with a context {source, target, game}); parse errors carry position; ASTs cacheable.
3. src/engine/algebra.gd — normalize (strings→ops, numbers→const, conditional→branch), eval_value, eval_predicate, apply_effect per interpreter contract; emits battle-log events via a callback.
4. src/engine/stats.gd — effective stats: class base + growth curve(level) → equipment stat_mods (add, then mul, then set order — document) → status stat_mods; resource max via stat-model max_formula; expected_damage(ability, src, tgt) mean-value helper.
5. src/engine/battle.gd — UI-free battle engine: round-based, agility-ordered turns (ties: party first, then list order); party commands supplied by a policy interface; monster turns via ai.rules (eligibility = when-predicate ∧ costs payable; weighted pick via Rng; 'single' target = uniform random via Rng); statuses tick per their trigger; modify_stat durations decrement on the affected entity's turn end; victory applies xp/gold/drops; implements heuristic_v1 as the built-in policy (contract §5, exact rules).
6. src/engine/save.gd + Game autoload snapshot/restore per contract §4.
7. src/sim/sim_battle.gd — SceneTree script per contract §5 exactly (args after --: spec.json out.jsonl).
8. src/tests/run_tests.gd + src/tests/unit/_t.gd + the seven required test files (contract §7 list) — write them AGAINST REAL CONTENT where the contract says so (test_content.gd loads the actual game content; test_battle.gd uses fixture monsters defined inline in the test, not game content, for exact-outcome assertions).
9. src/engine/API.md — one page: every public method signature on ContentDB/Game/Rng/M8Input/M8Debug/battle.gd that scene code will call, with one-line semantics. The scenes order builds against this file sight-unseen.

GODOT 4.7 NOTES (avoid the classic traps):
- SceneTree scripts: `extends SceneTree`, override `_initialize()`, use `quit(code)`; args via OS.get_cmdline_user_args().
- JSON.parse_string / JSON.stringify; Dictionary `==` is by-value in Godot 4 but write a deep_eq helper for clarity in tests.
- No `randi()` globals anywhere — everything through Rng autoload (contract §3).
- Static typing where types are known; `class_name` only where needed; keep files <300 lines.

RUN COMMANDS (must be green before returning):
- /home/seraphius/mode8/appliances/godot/godot --headless --path /home/seraphius/mode8/games/emberwake/src --import
- /home/seraphius/mode8/appliances/godot/godot --headless --path /home/seraphius/mode8/games/emberwake/src --script res://tests/run_tests.gd   → "TESTS: n/n PASSED", exit 0
- echo '{"seed":42,"battles":[{"party":[{"class":"<real class id>","level":2,"equipment":{},"spells":["<real spell id>"],"items":{}}],"monsters":["<real monster id>"],"max_rounds":50}]}' > /tmp/spec.json && <godot> --headless --path .../src --script res://sim/sim_battle.gd -- /tmp/spec.json /tmp/out.jsonl && cat /tmp/out.jsonl  → one valid result line

OUTPUTS (write, exactly): src/project.godot, src/autoload/*.gd (5), src/engine/{formula,algebra,stats,battle,save}.gd + src/engine/API.md, src/sim/sim_battle.gd, src/tests/run_tests.gd, src/tests/unit/*.gd, src/content (symlink). Do NOT create src/scenes/ (03b owns it) — but title.tscn missing means boot smoke is 03b's gate, not yours.

CONSTRAINTS:
- Content is data: ZERO game-content ids in .gd files (fixture ids inside test files are exempt but must be clearly fixtures).
- You may not edit content/, ontology/, skills/, plan/.
- Return format: (1) file manifest, (2) test summary line + sim smoke output verbatim, (3) any contract ambiguities you resolved (list, one line each — these feed the retrospective), (4) API.md path confirmation. No prose recap.
