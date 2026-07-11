# Studio-Level Decision Log

Per SPEC §12: when blocked by genuine ambiguity, make the call, record it with rationale, continue. Per-game decisions live in `games/<title>/gdd/decisions.md`; this file holds decisions about the *studio itself*.

---

## D-001 — Godot pin: 4.7-stable (2026-07-11)
Latest stable at studio founding. Headless-capable single binary, text-native scenes. Appliance binaries are gitignored; `PIN.json` (URL + sha256) + `fetch.sh` are the committed artifact. Rationale: GitHub file-size limits and the spec's "pinned, boring, reproducible" rule — pins in git, blobs restored on demand.

## D-002 — License: MIT (2026-07-11)
Human directive: fully open source, non-commercial intent, prove-it-in-public. MIT is the lowest-friction choice.

## D-003 — Ontology serialization: JSON with JSON Schema (draft 2020-12) (2026-07-11)
The spec mandates JSON Schema. Content files are JSON (not YAML) so any agent can validate with a Python one-liner (`jsonschema` lib) and Godot can parse natively with `JSON.parse_string()` — no importer code needed in generated engines.

## D-004 — Effect algebra encoding: tagged objects, not arrays (2026-07-11)
Expressions serialize as `{"op": "damage", "value": {"op": "formula", "expr": "atk*2 - def"}, "element": "fire", "type": "physical"}` rather than s-expression arrays. Rationale: JSON Schema can discriminate on `op` for per-primitive validation (schema `oneOf` + `const`), defect reports can point at named fields, and GDScript interpreters dispatch on a string key naturally.

## D-005 — Studio-level state: this file + task files per game (2026-07-11)
The spec defines per-game plan state (`games/<title>/plan/`) but is silent on studio-level bookkeeping. Decision: DECISIONS.md (this file) + milestone status in README. No database, no dashboard — files only, per Thesis 6.

## D-006 — Skills live in `skills/` and are symlinked into `.claude/skills/` (2026-07-11)
Claude Code discovers project skills under `.claude/skills/`. The spec mandates `skills/` as the canonical library location (it IS the system). Decision: canonical files in `skills/m8-*/`, with `.claude/skills` a symlink to `skills` so the session auto-discovers them. One source of truth, no copy drift.

## D-007 — GPU budget: two RTX 3090s available, but per-stage budget stays "one consumer GPU" (2026-07-11)
Hardware exceeds the spec's assumption. Decision: keep every single stage runnable within one 24GB device (per spec's degrade-gracefully rule) and use the second device only for overlap (e.g., generation on cuda:0 while the VLM judge holds cuda:1). This keeps the studio portable to the spec's baseline.
