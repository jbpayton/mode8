# Emberwake M1 — Gate Statistics

*Generated 2026-07-12. Machine-readable: `gate_stats.json`.*

The Atelier milestone: every placeholder replaced with generated, gate-verified, manifest-pinned art and music.

## Headline

| Metric | Value |
|---|---|
| Total assets generated | **34** |
| First-try green (no repair) | **85%** (29/34) |
| Total repair rounds | 11 |
| Missing files / hash mismatches | **0 / 0** |
| Unresolved content art keys | **0** — every sprite/portrait/tile/music key resolves |
| Determinism checkpoints (rusher byte-identical) | **7/7** |

## By asset class

| Class | Assets | Repair rounds | Pipeline |
|---|---|---|---|
| sprite_sheet (walk cycles) | 2 | 0 | VNCCS identity→clothes→cycles (Qwen-Image-Edit) |
| battle_sprite (monsters) | 4 | 0 | SDXL + pixel-art-xl, text-prompt (non-humanoid) |
| tile (terrain) | 5 | 1 | SDXL + pixel-art-xl + deterministic seamless post-blend |
| sprite (entity markers) | 3 | 0 | SDXL + pixel-art-xl |
| item_icon | 9 | 10 | SDXL + pixel-art-xl + adaptive-key post-chain |
| portrait | 2 | 0 | deterministic bust-crop of clothed identity |
| battle_background | 2 | 0 | SDXL (no pixel LoRA — painterly HD-2D) |
| bgm + stinger | 7 | 0 | ACE-Step v1 |

**Where the repairs concentrated:** 10 of 11 repair rounds were two weapon icons (`coldiron_brand`, `ashwood_stave`) — pixel-art-xl renders thin blades/shafts too small to clear the fill floor. Root cause recorded: broad shapes render diagonally on their own; thin implements need subject reshaping, not rotation. The one tile repair (`cave_wall`) was a walkable/blocked contrast failure — too close to `cave_floor` luma — fixed by reseed and queued as a proposed adjacent-tile contrast gate.

## Gate cascade status (SPEC §6)

- **Tier 1 (deterministic, bit-identical):** ACTIVE — `gate_tier1_image.py` (geometry/palette/component, per-class thresholds), `gate_tier1_audio.py` (levels/clipping/silent-edges/spectral centroid), `gate_tier1_sheet.py` (feet-baseline, centroid drift, bbox variance). Every asset passed before shipping.
- **Tier 3 (VLM/agent/human judge):** ACTIVE — recorded per asset in `manifest.gates.tier3`; `music.town` carries a human Tier-3 approval.
- **Tier 2 (embeddings):** deferred to M2 (needs canonical reference embeddings frozen at character approval).
- **Tier 4 (in-engine differential):** screenshot hook built (debug `screenshot` action + xvfb capture); differential judging manual this milestone.

## Reproducibility

Every manifest entry pins: workflow file + its SHA, exact model HF revisions, seed, prompt overrides, and the deterministic post-chain (with its own SHA where scripted). Verified: the `emberdew` icon **re-generates byte-identically** from its manifest entry; all 34 files match their pinned hashes; the game's rusher playtest trace is byte-identical after every visual integration.

## License posture

All models license-vetted before pinning. Excluded and recorded: FLUX.1/2 (non-commercial), MusicGen (CC-BY-NC weights), Anima (non-commercial), InsightFace-based identity tools (non-commercial), and two human-suggested Civitai pixel models (one SD1.5 wrong-arch, one commercial-locked license). Full audit: `appliances/RESEARCH-M1.md` + `retrospectives/queue.md`.
