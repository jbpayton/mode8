---
name: m8-soundsmith
description: Music and SFX for MODE 8 game builds. STUB at v1 per SPEC — owns the slot interface now (maps/scenes declare music slot ids; engine plays silence for missing assets); model-backed generation lands in a later milestone.
---

# m8-soundsmith — Soundsmith (SPEC §5 Assets) — STUB, INTERFACE FIXED NOW

## The interface (already binding on other skills)
- Maps and scene types declare `music` slot ids (`world/map.schema.json` music field; battle/title slots by convention: `music.battle`, `music.boss`, `music.title`, `music.victory`).
- Engines resolve slots via `assets/audio/<slot>.ogg`; **missing file = silence, never an error** — sound is progressive enhancement until this skill activates.
- SFX slots (M1+, by convention): `sfx.confirm`, `sfx.cancel`, `sfx.hit`, `sfx.heal`, `sfx.level`, resolved the same way.

## Activation (post-M1, milestone TBD by retrospective priority)
Candidate backends evaluated then: local music-gen models under the one-GPU policy, pinned as appliances like everything else. Slot semantics (loop points, layering, battle-transition stingers) will be RFC'd into the ontology when real audio lands. Until then: do not accept work orders; do not generate placeholder tones (silence beats noise).
