# Ontology RFCs

Schema changes happen here or not at all (SPEC §12). Format: RFC-NNN, status (draft/accepted/rejected), rationale, affected schemas. Content agents may not extend the algebra — they file drafts here and the conductor adjudicates (escalating to the human only for vocabulary-level changes).

---

## RFC-000 — v0.1 baseline clarifications — **accepted** (2026-07-11)

Decisions made while transcribing SPEC §4 into `schema/`, recorded so they are auditable rather than silent:

1. **Logical predicates.** `and` / `or` / `not` added to the predicate set. SPEC lists predicate *subjects* (status, affinity, HP, flags, terrain) without connectives; conditionals over compound conditions are unexpressible without them and per-game workarounds would fork semantics.
2. **`conditional` ≡ `branch` without `else`.** Both accepted by the schema; interpreters normalize `conditional` → `branch`. One implementation path, spec vocabulary preserved.
3. **Monster AI shape.** SPEC §5 calls AI "effect-algebra policies". v0.1 fixes the shape as rule lists `{when: Predicate, weight, ability: id}` over the monster's own abilities rather than bare Effect trees — abilities keep their target selectors and costs, so the balance sim executes exactly what the engine executes. (`entities/monster.schema.json`.)
4. **World index folding.** Region/Town/Dungeon/Shop/Treasure are one `world.json` index (groupings of map refs + service/stock/roll tables) instead of five files. They gain their own files when they gain depth (expected M2). `world/world.schema.json`.
5. **String/number shorthand.** Parameterless nodes may be bare strings, numeric constants bare numbers (CONVENTIONS.md). Cuts generated-content token volume materially at M2 scale; interpreters normalize on load.
6. **Guaranteed treasure.** `treasure_tables[].guaranteed` added so required-item chests are deterministic — static completability (SPEC §8) cannot be proven over random required drops.
7. **Damage formula routing.** SPEC §4 leaves physical/magical defense application to the per-game engine; v0.1 puts the routing formulas in the stat model (`damage_formulas.physical/magical`) so the balance sim and engine share one definition.

## RFC-001 — Resource maxima overrides (hand-shaped bosses, class resource curves) — **accepted** (2026-07-11)
**Filed by:** m8-systems-designer (emberwake, work order 01)
**Problem:** Two entities cannot get correct resource maxima through `max_formula` alone. (1) `monster.schema.json` says resources are "computed from max_formula", but Emberwake's boss band (`boss_ttk_band` [6,16], 2-member party) needs Ash Tyrant HP ≈ 380 while any sane L5 stat block under `hp = source.def * 3 + source.level * 12 + 14` yields ~100; inflating `def`/`level` to reach it wrecks the damage formulas and the level curve. (2) Classes need distinct HP/MP growth (sturdy vs caster) that a single stat-driven `max_formula` cannot express without adding a vitality stat past the M0 5-stat cap.
**Proposal:** (a) `entities/monster.schema.json`: document that a resource id appearing directly in a monster's `stats` object (e.g. `"hp": 380`) overrides `max_formula` — the encoding is already structurally legal (`additionalProperties: {"type": "number"}`). (b) `entities/class.schema.json`: document that `growth` may bind a resource id to a curve (e.g. `"hp": "curve.hp_sturdy"`) and that the curve value at level overrides `max_formula` for that entity. `max_formula` remains the default for any entity with no override.
**Blast radius:** description text in `entities/monster.schema.json` and `entities/class.schema.json` (no structural change; gate already accepts both keys); engine resource-initialization order in the interpreter contract.
**Adjudication (m8-conductor):** clarification-grade (no structural schema change; encodings already legal). Accepted; schema descriptions + interpreter contract updated. Resource-maxima resolution order fixed as: explicit resource id in a monster's stats > class growth curve binding > stat-model max_formula.
**Workaround in the meantime:** Emberwake uses both encodings as-is (structurally legal today); its `max_formula`s are tuned to agree with on-curve character values (warden L4: formula 98 = curve.hp_sturdy(4) 98) so the two paths do not fork the balance sim.

## RFC-002 — `value` context variable is outside the Formula DSL grammar — **accepted** (2026-07-11)
**Filed by:** m8-systems-designer (emberwake, work order 01)
**Problem:** `stat-model.schema.json` defines `damage_formulas.physical/magical` as "Formula DSL with extra var 'value'", and the m8-systems-designer baseline shapes use bare `value` (e.g. `max(1, value - target.def)`), but the grammar in `effect-algebra.md` has no production for it: `factor := NUMBER | ref | func(...) | (expr)` and `ref` requires a `source.`/`target.`/`game.` scope. A strict parser rejects the sanctioned baseline.
**Proposal:** extend the grammar with per-context identifiers: `factor := ... | CONTEXTVAR`, where each evaluation context declares its context vars (damage_formulas: `value`; status ticks already route theirs through `source.potency`). Doc change in `effect-algebra.md` plus a note in `stat-model.schema.json`.
**Blast radius:** `effect-algebra.md` (doc), engine formula parser (accept declared context vars only in their context); no existing content changes.
**Adjudication (m8-conductor):** clarification-grade (grammar doc aligned with what stat-model.schema.json already sanctions). Accepted; grammar gains CONTEXTVAR, valid only where a context declares it (damage_formulas: `value`).
**Workaround in the meantime:** use bare `value` exactly as the stat-model schema description sanctions; no other context identifiers are used anywhere in Emberwake content.

## RFC template

```
## RFC-NNN — <title> — draft (<date>)
**Filed by:** <skill/agent>
**Problem:** what cannot be expressed today (with the content that hit the wall)
**Proposal:** exact schema diff
**Blast radius:** affected schemas, interpreters, existing content
**Workaround in the meantime:** closest existing expression
```
