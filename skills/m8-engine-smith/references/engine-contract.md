# Engine Contract v0.1 — BINDING

Every generated engine implements this exactly. m8-balancer, m8-playtester, and m8-build-warden execute these interfaces sight-unseen; the contract, not the engine, is what they trust. Changes to this file are skill edits (retrospective-owned), not per-game choices.

## 1. Project layout

```
src/
├── project.godot            # main scene = scenes/title.tscn; window from style-bible resolution
├── autoload/
│   ├── content_db.gd        # ContentDB — content loading/validation/normalization
│   ├── game.gd              # Game — run state (party, inventory, gold, flags, map, pos)
│   ├── rng.gd               # Rng — THE random source
│   ├── m8_input.gd          # M8Input — input wrapper seam
│   └── m8_debug.gd          # M8Debug — CLI args, script driver, trace writer
├── engine/
│   ├── formula.gd           # formula DSL recursive-descent parser + evaluator (AST cached)
│   ├── algebra.gd           # effect-algebra interpreter (values, predicates, effects)
│   ├── stats.gd             # effective-stat resolution: class base+growth → equipment → statuses
│   ├── battle.gd            # battle engine: turn order, AI policies, targeting, event log
│   └── save.gd              # snapshot/restore + slot IO
├── scenes/                  # one .tscn + .gd per active scene type (ontology/scene-registry.json)
├── sim/sim_battle.gd        # SceneTree script — balancer entrypoint (§5)
└── tests/
    ├── run_tests.gd         # SceneTree script — discovers tests/unit/test_*.gd (§7)
    └── unit/…
```

## 2. CLI invocations (build-warden runs all four)

```
godot --headless --path src --script res://tests/run_tests.gd     # unit tests; exit 0 = green
godot --headless --path src --script res://sim/sim_battle.gd -- <spec.json> <out.jsonl>
godot --headless --path src -- --m8-script=<actions.json> --m8-trace=<trace.jsonl> --m8-seed=<n> [--m8-max-frames=<n>]
godot --headless --path src -- --m8-max-frames=120                # boot smoke: title loads, no script
```
Custom args come after `--` and are read via `OS.get_cmdline_user_args()`. Exit code 0 unless a script error/crash occurred. `--m8-max-frames` default 20000; hitting it exits 0 with a final `timeout` trace line.

## 3. Determinism

- `Rng` wraps one `RandomNumberGenerator`. Seed: `--m8-seed` if given, else randomized. EVERY gameplay roll (encounters, variance, crits, AI weights, treasure) uses it. No `randi()`/`randf()` globals anywhere.
- Same content + same seed + same action script ⇒ identical trace. The playtester's repro guarantee and the save/load gate both assume this.

## 4. Game state & save (`Game`, `engine/save.gd`)

- `Game.snapshot() -> Dictionary` — pure JSON-serializable types (String/int/float/bool/Array/Dictionary). Contents: `party: [{class, name, level, xp, hp, mp, equipment: {slot: id}, spells: [ids], row}]`, `inventory: {id: count}`, `gold`, `flags: [ids]`, `map`, `pos: [x, y]`, `opened: [chest entity ids]`, `playtime_s`.
- `Game.restore(snap)` rebuilds the run exactly; `restore(snapshot())` then `snapshot()` must be deep-equal (build-warden gate).
- Saves: `user://saves/slot_<n>.json`, written pretty-printed. Save points per world data; save_load scene per registry.

## 5. Sim entrypoint (`sim/sim_battle.gd`) — m8-balancer's interface

Reads spec JSON, runs N battles WITHOUT any scene tree UI (battle engine is UI-free by construction), writes one JSON line per battle.

Spec: `{"seed": int, "battles": [{"party": [{"class": id, "level": int, "equipment": {slot: id}, "spells": [ids], "items": {id: count}}], "monsters": [ids], "max_rounds": 50}]}`

Result line: `{"i": idx, "win": bool, "wipe": bool, "timeout": bool, "rounds": int, "party_hp_end_pct": float, "mp_spent": int, "items_used": {id: n}, "deaths": int, "dmg_dealt": int, "dmg_taken": int, "ability_usage": {id: n}}`

**Party policy `heuristic_v1`** (fixed so sims are comparable): per ally turn —
1. any ally `hp_pct < 0.35` AND a heal is available (spell with payable cost, else usable item) → strongest heal on lowest-hp ally;
2. else best expected-damage option (basic attack vs. each payable damage spell; expectation = mean value of the damage node × element multiplier vs. that target, via `battle.expected_damage(ability, src, tgt)`) on the lowest-hp enemy that isn't immune/absorbing;
3. else Defend.
Ties break by list order. Item use allowed only for rule 1.

## 6. Debug drive (m8-playtester's interface)

- `--m8-script=<file>` — JSON array of steps, consumed one per frame group: `{"do": "press", "action": "<action>"}` (press+release next frame) · `{"do": "hold", "action": "...", "frames": n}` · `{"do": "wait", "frames": n}`. Actions: `move_up move_down move_left move_right confirm cancel menu`.
- `M8Input` API used by ALL scenes: `is_just_pressed(action)`, `is_pressed(action)` — delegates to `Input` normally; in script mode returns the injected schedule. Scenes never call `Input` directly.
- Trace (`--m8-trace`, JSONL): one line per executed step and per scene transition:
  `{"frame": n, "event": "step"|"scene"|"battle_event"|"dialogue"|"timeout"|"quit", "scene": "<scene_type>", "detail": {...}, "state": Game.snapshot() minus playtime}`
  plus, in battle, the interpreter's battle-log events (`effect-algebra.md` §Interpreter contract) as `battle_event` lines. Every scene implements `m8_scene_type() -> String` and `m8_detail() -> Dictionary` (cursor position, open menu, current dialogue id/line, battle turn...).
- Script exhausted or max-frames reached → write final line, `quit(0)`.

## 7. Test harness

`tests/run_tests.gd` (SceneTree script): loads each `tests/unit/test_*.gd`, instantiates, calls every zero-arg method starting `test_`, passing nothing; test classes get assert helpers from `tests/unit/_t.gd` (`T.eq(a, b, msg)`, `T.ok(cond, msg)`, `T.err(callable, msg)` — count failures, print `file:method: message`). One summary line per test file (`test_x.gd: n/n`) followed by `TESTS: <pass>/<total> PASSED`, exit 1 on any failure — gate 2 evidence must prove each required file ran.

Required files (a missing one fails build-warden):
- `test_formula.gd` — parser: precedence, `//`, unary minus, funcs, source/target/game refs, parse errors
- `test_values.gd` — const/stat/dice (seeded)/formula/scaling + shorthand promotion
- `test_predicates.gd` — every predicate op incl. and/or/not
- `test_effects.gd` — damage routing (physical/magical/fixed, element ×, variance seeded, pierce, crit), heal clamps, apply_status stacking rules + tick + expiry, modify_stat duration, resource, revive, seq/choice/repeat/branch/conditional-normalization
- `test_battle.gd` — full seeded battle vs. fixture monsters: exact round count & outcome; AI rule eligibility (when-predicates, cost gating); turn order
- `test_save.gd` — snapshot/restore deep-equality, slot IO round-trip
- `test_content.gd` — real game content loads; every cross-ref resolves; unknown-op fixture rejected at load

## 8. Scene obligations (beyond scene-registry UX conventions)

- Scenes read/write ONLY `Game` + their own UI state; battle mutations go through `engine/battle.gd`.
- Placeholder art at M0: `ColorRect`/`Label` only, colors from style-bible tone; every visible entity gets a 1-char glyph + color so traces and screenshots stay debuggable.
- Scene transitions via `Game.goto_scene(type, args)` (single choke point — it emits the trace line).
- battle_menu: commands Attack / Spell / Item / Defend / Row / Flee (hide unavailable); victory screen applies xp/gold/drops through engine code, then returns to the invoking scene.
- overworld: 4-dir tile movement, `confirm` interacts (NPC/chest/portal facing rule: the tile faced), encounter roll per step on encounter-tiles via `Rng`.
