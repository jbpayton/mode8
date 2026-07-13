# Retrospective — Emberwake / M1 (The Atelier)

Second milestone. The M0 walking skeleton — completable but placeholder-ugly — regenerated with generated HD-2D art and a full score. 34 assets, 85% first-try green, every one gate-verified and manifest-pinned, and the game's playtest trace byte-identical throughout. **[Showcase](../games/emberwake/SHOWCASE.md).**

## What shipped
Full asset pipeline behind a pinned ComfyUI appliance: character walk cycles (VNCCS identity→clothes→cycles on Qwen-Image-Edit), monster battle sprites (SDXL non-humanoid path), a seamless tileset, painterly battle backgrounds, portraits, 9 icons, a 7-track ACE-Step soundtrack. Engine grew a manifest-driven asset layer (icons, walk animation, tiles, entity markers, battle sprites, backgrounds, portraits, music) — all soft-failing to M0 placeholders, all provably determinism-neutral.

## What worked (keep)
- **The manifest-as-contract paid off exactly as designed.** Content declares semantic art keys; assets resolve by key/alias; the engine never hardcodes an asset. Wiring each new art class was a bounded, determinism-checked engine order, and every one kept the rusher trace byte-identical — the visual layer provably never touched game logic (7/7 checkpoints).
- **The gate cascade caught real defects at generation time**: a boss/regular monster contrast fail, a cave wall indistinguishable from its floor, thin-blade icons below the fill floor, a title theme whose fade gapped the loop. All caught by deterministic Tier-1 scripts before a human ever looked.
- **Deterministic post-chains beat model tricks** where the model was weak: seamless tiling (quadrant-offset blend), pixel downscale+quantize, adaptive dark-subject alpha keying, silent-tail trim. The thin-batteries rule holds — these are economy/determinism scripts, not judgment.
- **License discipline held under temptation**: three separate strong-looking models (FLUX-class quality, two user-suggested pixel models) were excluded on license grounds with recorded rationale. The two-axis filter (SDXL-family arch AND commercial-image license) is now explicit.
- **Recovery from interruption was cheap** because of the write-manifest-per-asset rule (added mid-milestone from the monster credit-out): every agent that hit a limit or stalled left complete, gated, provenance-intact work behind.

## What broke (and the fix)
| Finding | Response |
|---|---|
| Agent ran out of credits mid-finalize, batching manifest writes → lost seed provenance | Rule added: write each manifest entry the moment its asset gates green. Every later interruption was clean. |
| Conductor **double-launched** two agents on the icon task (misread a progress notification as death) | No corruption — first agent detected the live worker and gracefully backed off. Lessons: a quiet/partial-progress notification is NOT proof of death; encode graceful-backoff (detect live workers via process/scratch activity) into atelier SKILL.md. |
| Concurrent commit swept an additive `--rotate` into the pinned post-chain script → sha mismatch | Verified byte-identical reproduction, re-pinned 8 entries to the on-disk script. |
| WO10 agent wrote temp files to an in-repo path; `git add -A` committed them | Purged, gitignored `games/*/scratchpad/`; work orders must name the session scratchpad. |
| ACE-Step v1.5 unsupported by pinned ComfyUI v0.9.2 | Activated the research-planned v1 fallback (Apache-2.0, checkpoint swap); D-010. Don't re-pin the appliance mid-milestone. |

## Skill mutations applied this cycle
- `m8-asset-warden`: status stub→active; three Tier-1 gate scripts promoted from smoke-test math (image/audio/sheet), each thin-batteries-justified.
- `m8-soundsmith`: stub→active with the ACE-Step generation recipe + slot→scaffold mapping.
- `gate_tier1_image` v2 (tileset 16×16 size check).
- Style bible: validated prompt scaffolds promoted (icon + 7 bgm moods) — taste captured as reusable data.

## Proposed, not yet applied
- **Adjacent-tile contrast gate** (walkable vs blocked luma margin) — would have auto-caught the cave_wall failure.
- **Graceful-backoff protocol** written into `m8-atelier` SKILL.md (concurrency safety as a rule, not luck).
- **Loop post-process battery** (RESEARCH-M1 §A.4) — tracks currently ship fade-restart; seamless loops are the honest open item.
- **Tier 2 (embeddings)** and **Tier 4 (in-engine differential auto-judge)** — the two dormant cascade tiers; Tier 4's screenshot hook is already built.
- **The two queued A/B experiments** (Illustrious-pixel character base; a license-clean pixel-scene model for 16px markers — the weakest current output).

## Metrics
34 assets · 85% first-try green · 11 repair rounds (10 in two icons) · 0 hash mismatches · 0 unresolved keys · 7/7 determinism checkpoints. Per-character chain calibrated at ~40 min; music ~15s/track; icons ~10s + gates. Gate stats: `games/emberwake/reports/gate_stats.{json,md}`.

## For M2
Depth at scale: 150+ items, 60+ monsters (families + palette-swap logic — the palette-swap discipline is speced but untested), 30+ spells, the balance sim at 10k battles per checkpoint, economy. The asset pipeline is now proven per-asset; M2 stresses it at volume, where the family/palette-swap economics and the Tier-2 embedding gate start to matter.
