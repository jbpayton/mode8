---
name: m8-atelier
description: The MODE 8 asset generation pipeline — character sheets, walk cycles, monster art, tilesets, portraits, battle backgrounds, item icons, UI chrome via ComfyUI staged conditioning. Owns style-bible enforcement at generation time and the per-asset manifest (seed/model/workflow pins). ACTIVATES AT M1 — the ComfyUI appliance is not yet provisioned.
---

# m8-atelier — Atelier (SPEC §5 Assets · §6 pipeline) — M1 SKILL, INTERFACE FIXED NOW

## Status
Stub until M1 provisions `appliances/comfyui/` (pinned container, VNCCS + VNCCS-Utils node packs at pinned commits, model hashes in PIN.json). Do not generate assets before then; M0 uses engine placeholder rects.

## The contract other skills already rely on (binding when activated)
- **Asset keys**: content files reference assets by key (`sprite`, `portrait`, `tileset_key` fields). You resolve keys to files under `assets/<class>/<key>.png` and every asset gets a manifest line in `assets/manifest.json`: `{key, class, workflow_json_sha, model_hashes, seeds, conditioning_inputs, style_bible_version, gate_report}`. Any asset regenerable from its manifest entry alone (SPEC L1).
- **Generation recipe** (mined from VNCCS): staged conditioning — base identity → clothing → emotions → poses; pose-skeleton ControlNet for sheet frames; face-detect refinement passes; identity-preserving edit models for repairs; background removal to alpha. Workflows are JSON composed/rewritten by the agent per job; the only persistent client code is `scripts/comfy_client.py` (submit via /prompt, poll history, fetch outputs — thin-batteries: economy).
- **Animation strategy**: cycles as single-canvas sheets (model attends to all frames at once); keyframe+interpolate fallback. v1 cycle set: walk×4dir, idle, attack, cast, hit, KO.
- **Candidates policy**: N candidates → m8-asset-warden gate cascade → judge ranks → winner; ≤K repair rounds (masked inpaint on the failing region) → reseed → after R reseeds escalate to retrospective queue as systemic (bad scaffold/style-bible entry). N/K/R start at 4/2/2.
- Style bible (`gdd/style-bible.json`) prompt scaffolds are the ONLY prompt source — ad-hoc prompt creativity is a defect; improving scaffolds is a retrospective-owned skill edit.
- VRAM discipline (root config gpu_policy): generation and VLM judging never co-loaded beyond one device's budget; sequence stages.

## M1 provisioning checklist (first activation)
Pin container digest + node-pack commits + model hashes in `appliances/comfyui/PIN.json`; write `fetch.sh`; smoke-generate one 64×64 icon end-to-end through the gate cascade; only then accept work orders.
