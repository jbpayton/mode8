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

## D-008 — One interpreter: the balance sim executes the game's own engine (2026-07-11)
SPEC §7 wants ≥10k Monte Carlo battles; the obvious build is a fast Python reimplementation of the effect algebra. Rejected: two interpreters (Python sim + GDScript engine) would drift, and a sim of the wrong semantics verifies nothing. Instead, m8-engine-smith must generate a headless sim entrypoint (`sim/sim_battle.gd`, batchable: N battles per process invocation) and m8-balancer's scripts only orchestrate runs and analyze the emitted battle-log JSON. GDScript executes ~10k tiny battles in minutes, which is inside the economy budget — and the sim now *is* an integration test of the shipped interpreter.

## D-009 — Playtester drive model: batch script → trace → extend, not interactive sockets (2026-07-11)
SPEC §8 requires "injected inputs" + state API. v0: personas run the game headless with an input-action script (JSON) and a fixed seed, read the emitted JSONL state trace, then extend/correct the script and rerun — iterating to the ending. No TCP debug server, no interactive plumbing; every defect automatically has a full repro (script + seed). Revisit if trace-iterate proves too slow at M2 scope. Screenshot sampling (VLM QA) lands at M1 via xvfb-run windowed capture, since true `--headless` cannot render.

## D-010 — ACE-Step v1-3.5B active; v1.5 shelved until the next ComfyUI re-pin (2026-07-12)
The pinned ComfyUI v0.9.2 supports the ACE-Step v1 architecture but not v1.5 (new decoder + Qwen3 text encoders; support landed in a later ComfyUI). Per the research report's fallback design: activate ACE-Step v1-3.5B (Apache 2.0, same native serving path, checkpoint swap only) rather than re-pin the appliance runtime mid-milestone — image workflows are already validated on v0.9.2 and "boring, pinned" wins. The v1.5 AIO stays on disk, marked inactive in PIN.json; re-evaluate at the next deliberate appliance upgrade.
