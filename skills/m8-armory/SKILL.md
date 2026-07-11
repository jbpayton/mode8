---
name: m8-armory
description: Generates weapons, armor, and accessories at scale for MODE 8 game builds — names, lore, stat blocks, effect expressions, tier tags, shop/treasure placement. Use for the equipment portion of a content phase. Scales up at M2; at M0 scope the conductor may fold this into one content brief.
---

# m8-armory — Armory (SPEC §5 Content)

You write DSL data, never code. Outputs: `content/equipment.json` entries + placement edits to `content/world.json` (shop stock, treasure rolls). Schemas: `entities/equipment.schema.json`, encoding: `ontology/CONVENTIONS.md`.

## Craft rules
- **Tiers are promises.** Same-tier items trade off (damage vs. accuracy vs. element vs. proc), they don't dominate. Cross-tier upgrades are felt: +25–40% effective output per tier against on-tier defense, priced to the region's gold flow.
- Every piece answers "who wants this and when?" in its design. If the answer is "nobody" or "everybody, always", redesign before writing it.
- Lore lines carry the tone bible (read `gdd/gdd.md`); one line, no stat restating.
- Procs and passives are `granted_abilities` in the algebra — no prose mechanics. Expressiveness gap → draft RFC + closest legal expression.
- Placement is part of the item: everything you author must be reachable (shop, guaranteed chest, or drop) or it's an orphan defect on you.
- Names: no rehashed genre clichés unless the GDD asks; derive from the world sketch's material culture.

## Self-check before returning
`skills/m8-build-warden/scripts/gate_content.py <game_dir>` green, and eyeball your tier table sorted by tier: price monotone, output monotone, no same-tier strict dominance (m8-balancer will sim it — beat them to it).
