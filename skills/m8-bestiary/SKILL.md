---
name: m8-bestiary
description: Generates monsters for MODE 8 game builds — stat blocks, AI policies as effect-algebra rules, drop/steal tables, palette-swap families, boss phase mechanics. Use for the bestiary portion of a content phase. Scales up at M2; at M0 scope the conductor may fold this into one content brief.
---

# m8-bestiary — Bestiary (SPEC §5 Content)

Output: `content/monsters.json` (+ encounter tables in `content/encounters.json`). Schema: `entities/monster.schema.json`. AI is data — `ai.rules` with `when` predicates and weights — because the balance sim executes exactly what ships.

## Craft rules
- **Every regular monster teaches something**: a weakness to exploit, a status to respect, a speed to answer. Write the lesson as a one-line `lore` (it doubles as scan text).
- Stat blocks derive from the region tier's expected party stats (read the GDD curve + m8-systems-designer's model): a regular dies in the GDD's TTK band *to an on-curve party*, show your arithmetic for one exemplar per tier.
- AI rules: 2–4 per regular (weighted flavor), 4–8 per boss with `hp_below` phase predicates. A boss with one phase is a big regular — don't.
- Families share a `family` id (art reuse at M1) and a mechanical theme, varied by tier: the palette swap should *play* different, not just look different.
- Drops: commons fund the economy (m8-balancer checks gold flow), rares create hunts; drop chances ≥0.05 or the item is effectively unobtainable (completability treats drops as non-guaranteed).
- XP/gold per monster: back-compute from the GDD's expected curve and encounter density — grinding is a design failure, not player laziness.

## Self-check
Content gate green; every ai rule's ability id is the monster's own; every element referenced has a party-side source by your region (coordinate with m8-spellbook via the conductor).
