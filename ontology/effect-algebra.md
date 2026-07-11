# The Effect Algebra (v0.1)

The combinator language in which ALL game mechanics are expressed. Weapons, spells, monster moves, statuses, item uses, passives: every one is an **Ability** whose behavior is an **Effect expression** interpreted by the per-game engine. Content agents write these as data and may never invent new primitives — gaps become RFCs (`RFCS.md`).

Schema: `schema/effect-algebra.schema.json`. Encoding rules: `CONVENTIONS.md` (tagged objects, string shorthand for parameterless nodes, bare numbers as `const`).

## The Ability envelope

The unit of mechanics. Spells, item-use effects, monster moves, and equipment passives are all abilities:

```json
{
  "id": "spell.fire",
  "name": "Fire",
  "trigger": "on_use",
  "target": {"op": "single", "side": "enemy"},
  "accuracy": 0.95,
  "effect": {"op": "damage",
             "value": {"op": "formula", "expr": "source.mag * 3 + 10"},
             "element": "fire", "type": "magical", "variance": 0.1},
  "costs": {"mp": 6}
}
```

`accuracy: null` (or omitted) = always hits. `costs` and `target` may be omitted for passives (triggered abilities target per their trigger context).

## Values — numeric expressions

| Node | Fields | Meaning |
|---|---|---|
| `const` | `n` | literal (bare numbers auto-promote) |
| `stat` | `ref`, `of: "source"\|"target"` | live stat read |
| `dice` | `d: "NdM"`, `"NdM+K"`, `"NdM-K"` | dice roll |
| `formula` | `expr` | sandboxed arithmetic DSL (grammar below) |
| `scaling` | `curve`, `level` (Value) | lookup on a growth curve declared in the stat model |

### Formula DSL grammar

```
expr   := term (('+' | '-') term)*
term   := unary (('*' | '/' | '//' | '%') unary)*
unary  := '-' unary | factor
factor := NUMBER | ref | CONTEXTVAR | func '(' expr (',' expr)* ')' | '(' expr ')'
ref    := ('source' | 'target' | 'game') '.' IDENT
func   := min | max | floor | ceil | round | abs | clamp
```

`CONTEXTVAR` (RFC-002): a bare identifier valid only where its evaluation context declares it — today only `value` inside the stat model's `damage_formulas`. Parsers reject context vars outside their context.

- `source.X` / `target.X` where `X` is any stat or resource id from the game's stat model, plus built-ins: `level`, `hp`, `max_hp`, `hp_pct`, and each resource pool + `max_` variant.
- `game.X` reads flag `flag.X` as 0/1.
- `/` is float division, `//` floors, final Values are rounded to int by consumers that need ints (damage), documented per effect.
- No assignment, no comparison, no side effects. Comparisons live in Predicates.

## Target selectors

`self` · `single(side)` · `all(side)` · `row(side, which: front|back)` · `random(side, n)` · `lowest(stat, side)` · `dead(side)` — sides are `ally`/`enemy`/`any`, always from the **source's** perspective.
SRPG additions (battle_grid games only): `radius(n)` · `line(n)` · `cone(n)` · `cell` · `adjacent`.

## Triggers

`on_use` · `on_hit` · `on_crit` · `on_kill` · `on_damage_taken` · `on_turn_start` · `on_turn_end` · `on_equip` (passive while equipped) · `on_battle_start` · `on_hp_below(pct)` (edge-triggered, once per crossing) · `aura(range)` (SRPG).

## Effects

**Atomic:**
`damage(value, element?, type: physical|magical|fixed, variance?, pierce?, crit?)` — physical/magical route through the game's damage formulas and element affinities; `fixed` bypasses defense and affinity ·
`heal(value)` · `apply_status(status, duration, potency?, chance)` — `duration: null` = until cured ·
`cure_status(statuses)` · `modify_stat(stat, mod: add|mul|set, value, duration)` — battle-scoped buff/debuff ·
`resource(pool, delta)` — delta may be negative ·
`revive(pct)` · `summon(entity, duration)` · `steal(table)` · `scan` · `flee` · `transform(entity)` · `set_flag(id)` ·
SRPG: `move(pattern)` · `knockback(n)`.

**Composition:**
`seq(effects…)` — in order, same resolved targets ·
`choice(options: [{weight, effect}…])` — weighted random pick ·
`repeat(n, effect)` — n may be a Value ·
`branch(if: Predicate, then, else?)` ·
`combo(participants, effect)` — dual/triple techs; participants are character/class ids that must all be able to act.

`conditional(predicate, effect)` from SPEC §4 is `branch` without `else`; the schema accepts `conditional` as an alias and interpreters normalize it (RFC-000).

## Predicates

`has_status(who, status)` · `element_affinity(who, element, relation: weak|resist|immune|absorb)` · `hp_below(who, pct)` / `hp_above(who, pct)` · `flag(id)` · `terrain(type)` (SRPG) · logical `and(preds)` / `or(preds)` / `not(pred)` (RFC-000 baseline). `who` is `source|target`.

## Costs & constraints

Object on the ability: `{"mp": n, "hp": n, "item": "item.x", "charge": turns, "cooldown": turns, "row_lock": "front"|"back", "range": {"min": m, "max": n}, "class_lock": ["class.x"], "once_per_battle": true}` — all fields optional.

## Worked examples (the design test, SPEC §4)

**FF6-style relic** (passive counterattack): trigger `on_damage_taken`, effect `branch(hp_below(source, 0.25), damage(formula("source.atk * 2"), type=physical))` on target = attacker.

**Chrono-style dual tech:**
```json
{"id": "tech.fire_whirl", "trigger": "on_use",
 "target": {"op": "all", "side": "enemy"},
 "effect": {"op": "combo", "participants": ["char.crono", "char.lucca"],
            "effect": {"op": "damage", "value": {"op": "formula",
                       "expr": "(source.mag + source.atk) * 2"}, "element": "fire", "type": "magical"}},
 "costs": {"mp": 8}}
```

**Tactics-style line spell:** target `{"op": "line", "n": 3}`, costs `{"range": {"min": 1, "max": 4}}` — the grid battle interpreter resolves geometry; the effect is genre-agnostic.

**Monster AI policies** (m8-bestiary) are rule lists over the monster's own abilities — `{"rules": [{"when": Predicate?, "weight": n, "ability": "id"}]}` (schema: `entities/monster.schema.json`). Each turn: keep rules whose predicate holds and whose ability costs are payable, weighted-pick one, resolve its target selector (uniform random for `single`). Boss phases are `when` predicates like `hp_below(source, 0.5)`. AI is data, so the balance sim executes the real thing.

## Interpreter contract (m8-engine-smith requirement)

1. Normalize shorthand on load (strings → `{"op": …}`, numbers → `const`).
2. Resolution order per ability activation: costs check+pay → target resolution → accuracy roll → effect tree evaluation (depth-first; `seq` items see state mutated by earlier items).
3. Element affinity applied inside `damage` per the game's `elements.json` (weak ×2, resist ×½, immune ×0, absorb = heal), after variance, before clamping to ≥0 (fixed damage skips all of it).
4. Every atomic effect application emits a structured battle-log event `{turn, source, ability, effect_op, target, rolled, result}` — the balance sim and playtester consume this stream.
5. Unknown `op` = hard error at content-load time, not battle time.
6. Resource maxima resolve in priority order (RFC-001): explicit resource id in a monster's `stats` → class `growth` binding a resource to a curve → the stat model's `max_formula`.
