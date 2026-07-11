# Ontology Conventions (v0.1)

Rules every schema and every content file follows. Content agents: read this before writing a single entity.

## Serialization
- **JSON everywhere.** Content files are `.json`, schemas are JSON Schema **draft 2020-12**. Rationale: one-liner validation for agents, native `JSON.parse_string()` in generated Godot engines (D-003).
- Schema `$id`s use the URI scheme `https://mode8.dev/ontology/<path>` — never fetched, purely for cross-file `$ref` resolution against a local registry.

## The tagged-object encoding (D-004)
Every algebra node is an object discriminated by its `"op"` key:

```json
{"op": "damage", "value": {"op": "formula", "expr": "source.atk * 2 - target.def"}, "element": "fire", "type": "physical"}
```

**Shorthand rule:** any node whose only field is `op` may be written as its bare string. `"self"` ≡ `{"op": "self"}`, `"on_use"` ≡ `{"op": "on_use"}`, `"scan"` ≡ `{"op": "scan"}`. Interpreters MUST normalize strings to objects on load. Schemas accept both forms.

**Value shorthand:** a bare JSON number is a `const`. `3` ≡ `{"op": "const", "n": 3}`.

## Identifiers
- Entity ids: lowercase snake_case, namespaced by dot when referencing across domains: `spell.fire`, `item.potion`, `monster.slime`, `status.poison`, `class.knight`, `curve.mp_mage`.
- Within a file's own domain the prefix may be omitted only where the schema says so; cross-domain references are ALWAYS fully qualified.
- Flags: `flag.<snake_case>` — the global boolean namespace of a game.

## Validation
Any agent validates any content file with this ephemeral snippet (no persistent tooling required):

```python
python3 - <<'EOF'
import json, pathlib
from jsonschema import Draft202012Validator
from referencing import Registry, Resource
root = pathlib.Path("ontology/schema")
reg = Registry().with_resources(
    (json.loads(p.read_text())["$id"], Resource.from_contents(json.loads(p.read_text())))
    for p in root.rglob("*.schema.json"))
schema = json.loads((root / "entities/spell.schema.json").read_text())
doc = json.loads(open("games/<title>/content/spells.json").read_text())
errs = list(Draft202012Validator(schema, registry=reg).iter_errors(doc))
print("OK" if not errs else "\n".join(e.json_path + ": " + e.message for e in errs))
EOF
```

The deterministic gate version of this lives in `skills/m8-build-warden/scripts/` (thin-batteries: determinism).

## Evolution
- Schemas change **only** via RFC in `ontology/RFCS.md` (SPEC §12). Content agents finding an expressiveness gap file an RFC and use the closest existing expression in the meantime.
- `ontology_version` in root `config.json` bumps on any accepted RFC; game GDDs record the ontology version they were built against.

## Collection files
Content ships as collection files (one JSON array per domain: `content/spells.json`, `content/monsters.json`…). Every collection file has the envelope:

```json
{"ontology_version": "0.1.0", "domain": "spells", "entries": [ ... ]}
```
