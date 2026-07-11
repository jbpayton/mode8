# Ontology v0.1 — the fixed vocabulary

The schema language all agents write against (SPEC §2, L2). Versioned; evolves **only** by RFC (`RFCS.md`). Start here:

| File | What |
|---|---|
| `CONVENTIONS.md` | Encoding rules: tagged objects, shorthand, ids, validation snippet |
| `effect-algebra.md` | Semantics of the combinator language + formula DSL grammar + interpreter contract |
| `scene-registry.json` | The presentation vocabulary (scene types + UX conventions) |
| `RFCS.md` | Change log and change process |

## Schemas (`schema/`)

| Schema | Validates |
|---|---|
| `effect-algebra.schema.json` | `$defs` used by everything: Value, Selector, Trigger, Predicate, Effect, Costs, Ability |
| `gdd.schema.json` | `games/<t>/gdd/gdd.json` — machine-readable GDD core |
| `stat-model.schema.json` | `content/stat-model.json` — stats, resources, curves, damage routing |
| `elements.schema.json` | `content/elements.json` — element wheel |
| `statuses.schema.json` | `content/statuses.json` — status registry |
| `entities/item.schema.json` | `content/items.json` |
| `entities/equipment.schema.json` | `content/equipment.json` |
| `entities/spell.schema.json` | `content/spells.json` |
| `entities/class.schema.json` | `content/classes.json` |
| `entities/monster.schema.json` | `content/monsters.json` (incl. AI policies) |
| `entities/encounter.schema.json` | `content/encounters.json` |
| `world/map.schema.json` | `content/maps/*.json` |
| `world/world.schema.json` | `content/world.json` — regions/shops/treasure index |
| `narrative/story-graph.schema.json` | `content/story.json` |
| `narrative/dialogue.schema.json` | `content/dialogue.json` |
| `style-bible.schema.json` | `gdd/style-bible.json` |

Deferred (RFC when their milestone lands): Character sheets & recruit events (M3), cutscene/VN presentation (M3), SRPG map extensions — height/facing (M4), soundtrack slots (M1 stub in style bible).
