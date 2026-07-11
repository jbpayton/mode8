---
name: m8-asset-warden
description: The MODE 8 asset gate cascade — deterministic geometry checks, measured semantics (pose/identity/style embeddings), VLM rubric judging, in-engine differential testing. Owns the defect-report → repair-instruction loop. ACTIVATES AT M1 alongside m8-atelier.
---

# m8-asset-warden — Asset Warden (SPEC §6) — M1 SKILL, INTERFACE FIXED NOW

## Status
Stub until M1. The cascade below is the committed design; scripts land with the first real asset.

## The cascade (cheapest first; any failure → structured defect report, never bare rejection)
1. **Tier 1 — deterministic geometry (ms, `scripts/` when built):** alpha QA (single connected component, no islands/halos), sheet registration (feet baseline, centroid drift, bbox variance across frames), palette conformance (histogram distance vs. style-bible anchors), scale conformance (px height vs. spec), format checks. Bit-identical verdicts — pure scripts.
2. **Tier 2 — measured semantics (s):** re-run pose estimation, keypoint deviation vs. conditioning skeleton; identity via embedding similarity of masked crops vs. the character's canonical reference embedding (frozen at character approval); style embedding distance vs. bible anchors. Thresholds versioned in the skill, tuned by retrospectives.
3. **Tier 3 — VLM judge (rubric + reference images in context):** anatomy defects, style drift, expression-vs-spec, and the in-game readability test (downscale to render size, judge silhouette legibility). Local VLM first (config endpoint); escalate low-confidence/disagreement to the frontier model. Every judgment ships rubric score + inputs (auditable).
4. **Tier 4 — in-engine differential:** load into headless Godot, render in situ (tile grid / battle scene), screenshot via xvfb-run, judge in context; animation cycles → GIF, judged as motion + optical-flow smoothness metrics.

## Defect reports
`{asset_key, tier, check, measured, threshold, region (bbox/mask if localizable), repair_instruction}` — the repair instruction is the point: "inpaint left hand region, 6 fingers detected" converges; "try again" random-walks. m8-atelier consumes these directly.

## Gate stats
Per build: hit-rates by tier and defect class, repair-round distributions, escalation and judge-disagreement rates → `reports/gate_stats.json` (m8-newgame-plus's primary food).
