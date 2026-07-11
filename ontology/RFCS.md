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

## RFC template

```
## RFC-NNN — <title> — draft (<date>)
**Filed by:** <skill/agent>
**Problem:** what cannot be expressed today (with the content that hit the wall)
**Proposal:** exact schema diff
**Blast radius:** affected schemas, interpreters, existing content
**Workaround in the meantime:** closest existing expression
```
