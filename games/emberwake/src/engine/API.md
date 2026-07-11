# Emberwake engine API (03a) — what scene code calls

Entity/member dicts are plain Dictionaries; mutate only through these APIs.
Error convention: fallible calls return a Dictionary with `"error"` (and/or `"ok": false`).

## ContentDB (autoload) — read-only content access; loaded+validated at boot
- `loaded: bool` / `load_errors: Array` — content state; `load_all(root := "res://content") -> bool` re-loads (tests/sim only).
- `stat_ids() -> Array` · `resource_ids() -> Array` — stat model ids (this game: atk/def/mag/res/agi; hp/mp).
- `stat_range(stat_id) -> Array` — `[min, max]` or `[]`.
- `speed_stat() -> String` — turn-order stat (project setting `m8/battle/speed_stat`, validated).
- `multiplier(relation) -> float` — element multiplier for weak/resist/immune/absorb.
- `curve(id) -> Dictionary` · `xp_curve_id() -> String` · `damage_formula_ast(kind) -> Dictionary` (pre-parsed).
- `status_def(id)` / `item(id)` / `equip(id)` / `cls(id)` / `monster(id)` / `encounter(id)` / `map_def(id)` / `dialogue(id)` — entity lookups; `{}` if missing. `spell(id)` returns the whole spell entry (ability under `"ability"`, plus tier/school/usable_in/learn).
- `world() -> Dictionary` / `story() -> Dictionary` — full indexes; `shop(id)` / `treasure_table(id)` from world.
- `spells_for_class(class_id, level) -> Array` — spell ids learnable at that level (sorted).

## Game (autoload) — the run; contract §4 state
- Fields: `party: Array` (member dicts: class/name/level/xp/hp/mp/equipment/spells/row), `inventory: {id: count}`, `gold: int`, `flags: Array`, `map: String`, `pos: [x, y]`, `opened: Array`, `playtime_s: float`, `scene_args: Dictionary`, `stats` (Stats helper, see below).
- `new_game()` — reset run; map/pos from world start. `add_party_member(class_id, name) -> Dictionary` — L1 member, full resources, L1 spells.
- `set_flag(id)` / `has_flag(id) -> bool`.
- `add_item(id, n := 1)` / `remove_item(id, n := 1) -> bool` / `item_count(id) -> int`.
- `start_battle(monster_ids: Array, opts := {}) -> Battle` — battle over live party+inventory (mutated in place). `apply_battle_result(result)` — banks `result.rewards.gold`.
- `goto_scene(type, args := {})` — THE scene choke point: emits the M8Debug trace line, changes to `res://scenes/<type>.tscn`; sets `scene_args` for the target scene.
- `snapshot() -> Dictionary` / `restore(snap)` — deep-equal round trip (contract §4).
- `save_game(slot) -> bool` / `load_game(slot) -> bool` — `user://saves/slot_<n>.json`, pretty JSON.
- `Game.stats` (engine/stats.gd): `member_view(member) -> Dictionary` pseudo-entity with `stats` + `resources` (cur/max); `effective_stat(entity, stat_id, persistent_only := false) -> float`; `max_resource(entity, res_id) -> int` (RFC-001 order); `class_base_stats(class_id, level)`; `xp_to_reach(level) -> int`; `curve_value(curve_id, level) -> float`. Status screens/inns read through these.

## Rng (autoload) — THE random source (contract §3); never use randi()/randf() globals
- `set_seed(n)` · `seed_value: int` — seeded from `--m8-seed` else randomized.
- `randf() -> float` · `randi_range(a, b) -> int` · `randf_range(a, b) -> float`.
- `weighted_index(weights: Array) -> int` — one draw; -1 on empty/zero pool.
- `choice(arr: Array) -> Variant` — uniform pick; null on empty.

## M8Input (autoload) — the only way scenes read input (contract §6)
- `is_just_pressed(action) -> bool` / `is_pressed(action) -> bool` — actions: `move_up move_down move_left move_right confirm cancel menu`. Delegates to Input, or to the injected schedule in script mode. Never call `Input` directly.

## M8Debug (autoload) — CLI args, script driver, trace writer (contract §6)
- Parses `--m8-script/--m8-trace/--m8-seed/--m8-max-frames`; drives M8Input one step per frame group; quits(0) with a final `quit`/`timeout` line.
- `trace_scene(type, args)` — called by `Game.goto_scene` (scenes don't call it directly).
- `trace_battle_event(ev)` — battle scenes wire `battle.event_cb = M8Debug.trace_battle_event`.
- `trace_dialogue(detail)` — dialogue scene calls per line advance.
- `trace_line(event, detail)` — generic; adds frame/scene/state envelope.
- Scene obligations: every scene implements `m8_scene_type() -> String` and `m8_detail() -> Dictionary`.

## Battle (engine/battle.gd, via Game.start_battle) — UI-free battle engine (§5)
- `begin()` — start round 1 and advance to the first party command (or the end).
- `needs_command() -> bool` / `current_actor() -> Dictionary` — the party entity awaiting a command.
- `submit_command(action)` — `{"kind": "attack"|"spell"|"item"|"defend"|"row"|"flee", "id": spell/item id, "target": entity key}`; resolves the turn and auto-plays monsters until the next command point or battle end.
- `is_over() -> bool` · `outcome: String` — `"win" | "wipe" | "timeout" | "fled"` (empty while running).
- `run(policy) -> Dictionary` — drive whole battle with a policy object (`decide(battle, actor) -> action`); `BattleScript.HeuristicV1.new()` is the built-in contract policy.
- `result() -> Dictionary` — outcome flags, rounds, party_hp_end_pct, mp_spent, items_used, deaths, dmg_dealt, dmg_taken, ability_usage, rewards {xp, gold, drops, level_ups}.
- `party: Array` / `monsters: Array` — battle entities (`key`, `name`, `row`, `alive`, `statuses`, `resources: {pool: {cur, max}}`); render state from these.
- `events: Array` — full battle log (`{turn, source, ability, effect_op, target, rolled, result}`); `event_cb: Callable` — live event tap.
- `expected_damage(ability, src, tgt) -> float` — heuristic expectation (mean × element multiplier).
- `costs_payable(entity, ability) -> bool` — menu graying; `basic_attack_ability(entity) -> Dictionary` — weapon attack (unarmed: 1 physical).
- `resolve_targets(src, selector, designated) -> Array` — selector semantics for target menus.
- Victory already applies xp/level-ups/spell learning to `Game.party` and drops to `Game.inventory`; scenes only bank gold via `Game.apply_battle_result(result)`.

Notes: entity `key` is `"p<i>"`/`"m<i>"`; battle turn order is `speed_stat()` descending, ties party-first then list order; defend halves damage until the entity's next turn; back row halves physical damage both ways.
