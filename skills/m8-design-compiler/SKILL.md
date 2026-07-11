---
name: m8-design-compiler
description: Compiles a game design into a GDD for the MODE 8 studio. Use when a build has no gdd/gdd.json yet, when asked to start/design a new game, or when asked to run a design conversation. Two modes — stub (M0–M5 milestones, emits the canonical fixed micro-GDD with zero questions) and conversation (a human is present and wants an original game).
---

# m8-design-compiler — Design Compiler (SPEC §2 L6)

The design conversation is the source code (Thesis 1). Your output — `gdd/` — is the only sacred directory in a game; everything downstream is regenerable from it. After you finish, **no human input is requested by anyone** for the rest of the build.

## Outputs (both modes; all four required)

```
games/<slug>/gdd/
├── gdd.json          # machine-readable core — MUST validate against ontology/schema/gdd.schema.json
├── gdd.md            # prose: premise, tone bible, world sketch, cast notes, what "done" feels like
├── style-bible.json  # MUST validate against ontology/schema/style-bible.schema.json
└── decisions.md      # numbered G-NNN decisions with rationale — the decision graph is a first-class artifact
```

Self-check both JSON files against their schemas (validation snippet in `ontology/CONVENTIONS.md`) before returning.

## Stub mode (milestone builds M0–M5)

Copy `assets/m0-gdd/*` into `games/emberwake/gdd/` unchanged. That's the whole job — the micro-GDD is fixed so milestone exit tests are comparable across sessions and skill versions. Do not "improve" it; improvements to the stub are skill edits owned by retrospectives. (M4 adds two more fixed GDDs as assets when it lands.)

## Conversation mode

Follow `references/conversation-guide.md`. Non-negotiables:

- Cover, in order: premise & tone → genre config (SPEC §3 matrix: cast model, battle model, narrative weight) → world sketch → scope (target hours, content targets) → difficulty philosophy (as *numbers*: TTK bands, wipe-rate band, grind tolerance — translate feelings like "tough but fair" into bands and read them back) → style bible (palette, proportions, resolution, tone keywords).
- Every open question the human doesn't decide: make the call, record it as G-NNN with rationale, and *tell them you did* — decisions are visible, not buried.
- The conversation ends when you can fill every required `gdd.json` field without guessing. Read the compiled logline + key numbers back for one confirmation, then stop asking things forever.
- Tone bible (in `gdd.md`) must contain: 5–10 tone keywords, 3 "never do this" lines, and a one-paragraph sample of narration voice — `m8-loremaster` enforces against it verbatim.
