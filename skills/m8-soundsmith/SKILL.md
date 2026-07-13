---
name: m8-soundsmith
description: Music and SFX for MODE 8 game builds. ACTIVE as of M1 — generates BGM and stingers via ACE-Step through ComfyUI; owns the music-slot interface (maps/scenes declare slot ids; engine plays silence for missing assets).
---

# m8-soundsmith — Soundsmith (SPEC §5 Assets) — ACTIVE (M1, 2026-07-12)

## The interface (binding on other skills)
- Maps and scene types declare `music` slot ids (`world/map.schema.json` music field; scene slots by convention: `music.battle`, `music.boss`, `music.title`, `music.victory`).
- Engines resolve slots via `M8Assets` (bgm/stinger class) → `assets/audio/<slot>.mp3`; **missing file = silence, never an error** — sound is progressive enhancement.
- SFX slots (by convention, not yet generated): `sfx.confirm`, `sfx.cancel`, `sfx.hit`, `sfx.heal`, `sfx.level`.

## Generation (active)
- Model: **ACE-Step v1-3.5B AIO** (D-010 — v1.5 needs a newer ComfyUI than the pinned v0.9.2; v1 is the research fallback, Apache-2.0, same serving path). Workflow: `assets/workflows/bgm_ace.json` (native ComfyUI ACE nodes; instrumental via ConditioningZeroOut negative; 50 steps cfg 5, ModelSamplingSD3 shift 5). ~15-19s per 60-90s track on one 3090.
- Prompts come ONLY from the style bible's `bgm_*` prompt_scaffolds (per-mood tag templates); ad-hoc prompting is a defect. Slot→scaffold mapping: town/dungeon(depth)/battle/boss/vault/title/victory.
- Gate: `m8-asset-warden/scripts/gate_tier1_audio.py --class bgm|stinger` (duration, levels, no-clip, no-silent-edges, musical spectral centroid). Title-style themes with a natural fade-out need a trailing-silence trim (record it in post_chain) so the loop doesn't gap.
- Manifest every track: workflow+sha, tags, seconds, seed, model revision, gate, status. Human Tier-3 is the final judge on mood fit (recorded as approval in the manifest, per music.town).

## Open (queued for a later cycle)
- Loop post-process battery (RESEARCH-M1 §A.4): beat-aligned seam / ACE-Step repaint; until then tracks ship as fade-restart BGM (honest: silence > noise > bad loop).
- SFX generation (Stable Audio Open per the research) — interface fixed, not yet built.
- ACE-Step v1.5 upgrade at the next deliberate ComfyUI re-pin.

## Activation (post-M1, milestone TBD by retrospective priority)
Candidate backends evaluated then: local music-gen models under the one-GPU policy, pinned as appliances like everything else. Slot semantics (loop points, layering, battle-transition stingers) will be RFC'd into the ontology when real audio lands. Until then: do not accept work orders; do not generate placeholder tones (silence beats noise).
