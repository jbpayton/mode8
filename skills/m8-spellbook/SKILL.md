---
name: m8-spellbook
description: Generates spells and techniques for MODE 8 game builds — per-class lists, elemental coverage, learn curves, costs, animation specs. Use for the spell portion of a content phase. Scales up at M2; at M0 scope the conductor may fold this into one content brief.
---

# m8-spellbook — Spellbook (SPEC §5 Content)

Output: `content/spells.json` (schema `entities/spell.schema.json`). Spells are Abilities plus acquisition; all mechanics in the algebra.

## Craft rules
- **Coverage is a matrix, not a list**: elements × single/all targets × damage/heal/buff/debuff/status. Fill the GDD's needs, mark deliberate gaps in your return (a hole every caster feels should be a choice, not an accident).
- Learn curves pace power: a class's next spell should arrive within 2–3 levels of the previous; dead zones longer than that need a G-decision.
- MP costs scale superlinearly with effect (double output ≳ 2.5× cost) so tier-1 spells stay situationally alive.
- Every spell either has a niche (element, timing, resource trade) or doesn't exist. `m8-balancer` measures usage floors — design for them.
- `anim` spec per spell (loose object at M0: `{"kind": "flash", "color": "#..."}`); m8-atelier tightens the contract at M1.
- No spell no class can learn (orphan check); respect school/class fantasy from the GDD.

## Self-check
Content gate green; per-class learn table printed in your return (level → spell) so the conductor can eyeball pacing.
