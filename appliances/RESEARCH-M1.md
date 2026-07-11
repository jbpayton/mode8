# RESEARCH-M1 — Local Generation Stacks for m8-soundsmith & m8-atelier

**Date:** 2026-07-11 · **Scope:** M1 provisioning survey per SPEC §6 (Asset Pipeline), `skills/m8-atelier/SKILL.md`, `skills/m8-soundsmith/SKILL.md`, and `config.json` GPU policy (2× RTX 3090 24GB, one-device-per-stage, everything local & pinnable).
**License bar:** outputs must be shippable in a free MIT-licensed game whose downstream users may do anything (including commercial). Anything weights-NC or output-restricted is flagged.
**Nothing was downloaded.** All pins below are HF API `sha` revisions / git commits verified 2026-07-11.

---

## Executive Summary

| Slot | Primary | Fallback | Peak VRAM (est.) | License posture |
|---|---|---|---|---|
| **Music BGM (1–3 min, instrumental, loopable-after-post)** | **ACE-Step v1.5** (2B turbo AIO, ComfyUI-native) — MIT weights, "commercial-ready" training claim, <10 s/song on a 3090 | **ACE-Step v1-3.5B** (Apache 2.0, ComfyUI-native since 2025-05) | 1.5 AIO: ~4–8 GB; XL: 12–20 GB; v1: ~8–12 GB | Clean (MIT / Apache 2.0) |
| **Jingles / stingers / SFX (≤47 s)** | **Stable Audio Open 1.0** (Stability Community License; CC0/CC-BY training data) | ACE-Step 1.5 short-duration prompts | ~6 GB | OK for us (<$1M revenue clause on *model use*; outputs owned by user) — see flag A3 |
| **Image: HD-2D pixel-art RPG assets** | **SDXL-family stack**: Illustrious-XL v2.0 (characters, via VNCCS 3.0.1) + SDXL base 1.0 (tiles/icons/backdrops) + nerijs pixel-art-xl LoRA + xinsir OpenPose & Union-ProMax ControlNets (Apache 2.0) + h94 IP-Adapter (Apache; **not** FaceID) + **Qwen-Image-Edit-2509** as the identity-preserving edit/repair model + BiRefNet (MIT) alpha extraction | **Full Qwen-Image stack**: Qwen-Image fp8 + InstantX ControlNet-Union (pose) + Qwen-Image-Edit-2509, all Apache 2.0 | Primary: ~10–14 GB per stage; Fallback: ~20–22 GB per stage (fp8, tight but fits) | Clean-ish (OpenRAIL++ base + Apache conditioning; Civitai LoRAs need per-model license checks) |

**Hard license exclusions found:** Meta MusicGen/AudioCraft weights (CC-BY-NC), FLUX.1-dev & FLUX.2-dev (non-commercial model license), BRIA RMBG-2.0 (CC-BY-NC), anything InsightFace-based (IP-Adapter-FaceID, InstantID, PuLID — NC face models), and VNCCS's newer "Anima" base model (reported non-commercial / NVIDIA Cosmos-derivative license).

---

# PART A — Promptable Music Generation (m8-soundsmith)

## A.1 Candidate findings

### ACE-Step v1.5 — ⭐ PRIMARY
- **What:** Music-generation foundation model (ACE Studio × StepFun lineage), released Jan–Feb 2026 (paper arXiv:2602.00744, 2026-01-31; code v0.1.8 2026-05-18). Marketed as "the most powerful local music generation model," explicitly **commercial-ready**: trained on licensed / royalty-free / synthetic data (the model card stresses this vs. competitors). https://github.com/ace-step/ACE-Step-1.5
- **License:** Code MIT; **weights MIT** (verified via HF API for `acestep-v15-base`, `-sft`, `-xl-turbo`). Model card states generated music may be used for commercial purposes; asks for AI-involvement disclosure (a norm, not a license term). Outputs: no restriction found.
- **Sizes / VRAM:** 2B (base/sft/turbo) and 5B XL variants. Min <4 GB with INT8+offload; XL wants ≥12 GB (offload) / ≥20 GB (no offload). Trivially inside the one-3090 budget.
- **Clip length:** 10 s – 10 min. Covers both 1–3 min BGM and short stingers.
- **Speed:** <10 s per full song on an RTX 3090 (turbo, 8-step); base/sft 50-step still fast.
- **Modes:** text→music, instrumental, reference-audio guidance, cover, **repaint (selective re-generation of a time region)**, track separation, vocal→BGM. Repaint is directly useful for loop-seam repair (see A.3).
- **ComfyUI:** native support; Comfy-Org repackage `Comfy-Org/ace_step_1.5_ComfyUI_files` with an all-in-one checkpoint `checkpoints/ace_step_1.5_turbo_aio.safetensors` ([docs.comfy.org tutorial](https://docs.comfy.org/tutorials/audio/ace-step/ace-step-v1-5), [HF repo](https://huggingface.co/Comfy-Org/ace_step_1.5_ComfyUI_files)).
- **Pins:**
  - `ACE-Step/acestep-v15-sft` @ `c410d249e71ea9385a7b586865e65b1473e1098d` (MIT, 2B)
  - `ACE-Step/acestep-v15-base` @ `e432212fec32b8965a14ffa57ae653438d6abd14` (MIT, 2B)
  - `ACE-Step/acestep-v15-xl-turbo` @ `d4a0b288b83ebb7e25a8c0b32c573c22e134e8ee` (MIT, 5B)
  - `Comfy-Org/ace_step_1.5_ComfyUI_files` @ `54b2ef4d8af5582f54c7e6b84c22b679a194bc4b` (Apache 2.0 repackage)
  - GitHub `ace-step/ACE-Step-1.5` tag `v0.1.8` = `dce621408bee8c31b4fcf4811682eb9359e1bc94`
- **Uncertainty (honest):** it is optimized for *songs* (incl. vocals). Quality on **retro/orchestral instrumental RPG moods** is plausible ("1000+ instruments and styles" claim) but unproven for our aesthetic — this is exactly what the M1 acceptance test must measure (A.4). Loopability is not a native feature.

### ACE-Step v1 (3.5B) — ⭐ FALLBACK
- **What:** the original May-2025 model; the most battle-tested open music model in ComfyUI. https://github.com/ace-step/ACE-Step · [HF](https://huggingface.co/ACE-Step/ACE-Step-v1-3.5B)
- **License:** **Apache 2.0** (code + weights). No output restrictions (usage-policy asks not to launder AI music as human-made).
- **VRAM:** ~8–12 GB class (community reports; min 12 GB "recommended" per third-party guides). Fits easily.
- **Length/speed:** full songs up to ~4 min in ~20 s on A100 (≈1–2 min on a 3090); >5 min degrades structurally per model card. Instrumental mode supported ("rare instruments may not render perfectly").
- **ComfyUI:** native since 2025-05 ([Comfy blog](https://blog.comfy.org/p/stable-diffusion-moment-of-audio), [docs](https://docs.comfy.org/tutorials/audio/ace-step/ace-step-v1)); repackage `Comfy-Org/ACE-Step_ComfyUI_repackaged` @ `9496247418317321988fb3a14fd44c5141bfc767`.
- **Pin:** `ACE-Step/ACE-Step-v1-3.5B` @ `82cd0d7b6322bd28cd4e830fe675ddb6180ce36c`.
- **Why fallback not primary:** v1.5 beats it on quality/speed/features in every published comparison; v1's known weakness is slightly muffled high-end and looser prompt adherence. But it has 14 months of community validation and a pure-Apache pedigree, so it is the safe pin if v1.5 disappoints on instrumental quality.

### Stable Audio Open 1.0 (+ Small) — recommended adjunct for jingles/stingers/SFX
- **What:** Stability AI T2A diffusion, 1.06B, **max 47 s** stereo 44.1 kHz. [HF](https://huggingface.co/stabilityai/stable-audio-open-1.0) · [announcement](https://stability.ai/news-updates/introducing-stable-audio-open)
- **License:** **Stability AI Community License** ([LICENSE.md](https://huggingface.co/stabilityai/stable-audio-open-1.0/blob/main/LICENSE.md)): free incl. commercial for entities <$1M annual revenue; you own your outputs. Flag A3 below on the MIT-downstream nuance.
- **Training data provenance is the cleanest of all candidates:** 486k recordings, all CC0/CC-BY/CC-Sampling+ from Freesound/FMA ([paper](https://arxiv.org/html/2407.14358v1)) — lowest copyright-laundering risk in the whole survey.
- **Fit:** 47 s ceiling disqualifies it for 1–3 min BGM, but it is *ideal* for `music.victory`-style stingers, title flourishes, and the M1+ SFX slots (`sfx.confirm`, `sfx.hit`, …) — its model-card demos are literally sample/loop prompts ("128 BPM tech house drum loop"). VRAM ~6 GB. ComfyUI: native audio workflow support.
- **Pins:** `stabilityai/stable-audio-open-1.0` @ `f21265c1e2710b3bd2386596943f0007f55f802e`; `stable-audio-open-small` (341M, ~11 s, fast) @ `dc620d91535857b72ebb59b4ca45978db6d417f5`.

### DiffRhythm / DiffRhythm2 — viable, but instrumental support is the catch
- **What:** ASLP-lab (NPU) latent-diffusion full-song models. v1/1.2 "full" generates up to 285 s; extremely fast. v2 (2025-10-30) moves to semi-autoregressive block flow matching. [GitHub](https://github.com/ASLP-lab/DiffRhythm) · [DiffRhythm2 HF](https://huggingface.co/ASLP-lab/DiffRhythm2)
- **License:** **Apache 2.0** (code + weights, both versions — verified via HF API).
- **VRAM:** v1 base ≥8 GB with `--chunked` decoding. Fine on a 3090.
- **Catch:** the pipeline is lyric-conditioned; **DiffRhythm2's own TODO lists "instrumental music generation" as unshipped**, and v1's instrumental mode is a workaround (empty/minimal lyrics) with mixed community results. No ComfyUI-native support (community nodes only).
- **Verdict:** keep on the bench; not primary or fallback. Pins: `ASLP-lab/DiffRhythm-full` @ `613846abae8e5b869b3845a5dfabc9ecc37ecdab`; `ASLP-lab/DiffRhythm2` @ `9aa15742e4889c0eb2e198db6fdab1facf1b6761`.

### YuE — excluded (fit)
- Open full-song foundation model (HKUST/M-A-P, 2025-01), **Apache 2.0** weights (relicensed 2025-01-30, attribution "YuE by HKUST/M-A-P"). [GitHub](https://github.com/multimodal-art-projection/YuE) · [HF](https://huggingface.co/m-a-p/YuE-s1-7B-anneal-en-cot) @ `454c20e1748888800f8e4b3da45125f55482d967`.
- Excluded on fit, not license: it is a *vocal song* model (lyrics→song, chain-of-thought over segments); full-song generation wants 80 GB-class GPUs (24 GB handles short segments / quantized runs only). Wrong tool for instrumental BGM.

### Meta MusicGen / AudioCraft — ❌ EXCLUDED (license)
- Code MIT, but **weights CC-BY-NC 4.0** ([audiocraft #98](https://github.com/facebookresearch/audiocraft/issues/98), [HF LICENSE_weights](https://huggingface.co/spaces/facebook/MusicGen/blob/main/LICENSE_weights)). Non-commercial weights are incompatible with our bar: even if a hobby game is arguably non-commercial, MIT-licensed shipping means downstream commercial use we cannot honor. Same exclusion applies to Meta's MAGNeT and JASCO. Do not provision.

### Google Magenta RealTime 2 — watchlist (adaptive-music future)
- 2026-06; code Apache 2.0, **weights CC-BY 4.0** (fine for us). 2.4B base / 230M small; streaming ~10 s chunks with live text/MIDI/audio control; offline inference on NVIDIA GPUs supported. [GitHub](https://github.com/magenta/magenta-realtime) · [HF](https://huggingface.co/google/magenta-realtime-2) @ `010aa0dcb0dfd27b24f0ad07b4dad63e8f9521cc`.
- Not a fit for "render a 2-min OGG to a slot" (it's a live/interactive model, chunked context), but it is the obvious candidate when soundsmith's RFC gets to *layered/adaptive* battle-transition music. Note for the ontology RFC.

### Others checked briefly
- **Qwen-Audio family:** audio *understanding*, not music generation — could serve later as a local audio-QA judge, not a generator.
- **Alibaba InspireMusic:** code Apache 2.0; weight licensing and instrumental quality not verified in this pass — bench only.
- **Suno/Udio/Stable Audio 2.x:** API-only or closed — excluded by the local-only rule.

## A.2 Recommendation (Part A)

**Primary: ACE-Step v1.5** — turbo AIO checkpoint through native ComfyUI nodes (same appliance as the image pipeline; no second serving stack to maintain). Use `duration` + genre/mood/instrument tags from the style bible; instrumental flag on; 2B turbo for iteration and 5B XL-sft for final renders if the quality delta justifies it.
**Fallback: ACE-Step v1-3.5B** — Apache 2.0, proven, same ComfyUI serving path (swap checkpoint + nodes only).
**Adjunct (recommended, not required): Stable Audio Open 1.0** for stingers and the M1+ SFX slots — cleanest data provenance in the field and purpose-built for short samples.

VRAM: all three run comfortably on one 3090, so music generation trivially satisfies the one-device-per-stage rule and can share a device schedule with the VLM judge (sequenced, never co-loaded — `config.json` gpu_policy).

## A.3 License flags (Part A)
1. **MusicGen weights CC-BY-NC** — excluded (above).
2. **ACE-Step 1.5 "MIT weights"** — verified via HF API cardData on all three repos, but M1 provisioning should snapshot each repo's LICENSE file at the pinned revision into `PIN.json` metadata (HF cardData occasionally diverges from in-repo LICENSE).
3. **Stability Community License (<$1M clause)** — the revenue cap conditions *use of the model*, not the outputs; MODE 8 is under it and owns its outputs, so shipping SAO-generated audio in an MIT game is fine. Downstream users of the *game* never touch the model, so the clause doesn't propagate. Nuance worth recording, not a blocker.
4. **Output copyright status** — in most jurisdictions pure AI outputs may be uncopyrightable; that's *compatible* with MIT-shipping (we're granting rights we may not even need to hold) but note it in DECISIONS.md once.

## A.4 Loopability — unproven everywhere; the M1 acceptance test
No surveyed model natively emits seamless loops or loop-point metadata. Honest status: **game-BGM loopability is an unsolved output property; we make it a post-process + gate, not a model feature.**

Proposed soundsmith gate (mirror of the image gate cascade):
1. **Generate** 1–3 min instrumental at fixed BPM (put BPM and "seamless loop, consistent tempo" in the prompt; measure whether ACE-Step respects BPM tags — record hit-rate).
2. **Beat-align cut:** detect bars (librosa beat-track), cut loop region on bar boundaries; equal-power crossfade 20–200 ms at the seam — OR use **ACE-Step repaint** on the final+first 5 s window to synthesize a musical seam (this is the experiment that could beat crossfading; unproven, test it).
3. **Tier-1 deterministic check:** spectral flux / RMS discontinuity at the seam below threshold vs. the track's own bar-transition distribution; BPM drift < 1% across the loop.
4. **Tier-3 judge:** render seam-centered 10 s A/B (loop jump vs. random in-track bar transition); local audio-capable judge (or human spot-check at M1) must not reliably identify the seam.
5. **Tier-4 in-engine:** encode OGG Vorbis, set Godot `AudioStreamOggVorbis` loop + loop_offset, play 3 full cycles headless, assert no underrun/click via captured output.
**M1 pass bar:** ≥3 of 4 candidate tracks per mood survive the cascade within N=4/K=2 candidate/repair budget; else fall back to v1-3.5B and re-run; else BGM ships longer non-looping tracks with fade-restart (soundsmith stays honest: silence > noise > bad loop).

---

# PART B — Image Generation for HD-2D Pixel-Art RPG Assets (m8-atelier)

## B.1 VNCCS — verified ✅ (with one license landmine)
- **Exists:** [`AHEKOT/ComfyUI_VNCCS`](https://github.com/AHEKOT/ComfyUI_VNCCS), **MIT license**, actively maintained — current release **v3.0.1 (2026-07-06)**, 4 tagged releases. Registered in ComfyUI Manager ([runcomfy listing](https://www.runcomfy.com/comfyui-nodes/ComfyUI_VNCCS)).
- **What it does (matches SPEC §6 exactly):** staged pipeline — base character sheet (init → stabilization → upscale) → clothing sets → emotions → poses; Pose Studio (3D posing environment) generates the pose conditioning; consistent-identity sprites across the set. v3 adds a migration assistant, UniCanvas, and SAM3-based background/detail recovery.
- **Companion requirement:** [`AHEKOT/ComfyUI_VNCCS_Utils`](https://github.com/AHEKOT/ComfyUI_VNCCS_Utils) (MIT) — provides Pose Studio, UniCanvas, Qwen detailers, model management. **No tagged releases** → must pin by commit.
- **Base models expected:** **Illustrious** (SDXL-architecture anime family; "huge LoRA selection", the mature path) or **Anima** (2B DiT, CircleStone Labs × Comfy Org, 2026-01; Qwen-3-0.6B text encoder + Qwen-Image VAE; GGUF Q4/Q5/Q8 quantizations via VNCCS's built-in downloader).
  - ⚠️ **Anima license flag:** reported as a **CircleStone Labs non-commercial license** and a derivative of NVIDIA Cosmos-Predict2 ([Civitai](https://civitai.com/models/2458426/anima), [HF GGUF](https://huggingface.co/JusteLeo/Anima-GGUF)). Until someone reads the actual license text and confirms otherwise, **treat Anima as non-shippable and use the Illustrious path.** Verify at provisioning time; record verdict in DECISIONS.md.
  - VNCCS v2 also published **Qwen workflows** ([Civitai VNCCS v2.0.0](https://civitai.com/models/2265016/vnccs-character-creation-suite)) — meaningful for our Qwen fallback stack.
- **Pinning story:** good on the node side — tags exist. **Weak on the model side:** VNCCS's "Control Center" downloads models itself, and the README doesn't enumerate exact checkpoints/LoRAs (it references e.g. `vn_character_sheet_v4.safetensors`, pose models, SAM3). **M1 action:** run VNCCS Easy Install once inside the pinned container, then snapshot every file it fetched (path + SHA256 + source URL) into `appliances/comfyui/PIN.json`, and have `fetch.sh` reproduce from those hashes — never from the Control Center — thereafter. Also verify the SAM3 license at that point (tool-only model; doesn't touch output IP, but the appliance must still be redistributable-in-recipe).
- **Pins:** `ComfyUI_VNCCS` tag `3.0.1` = commit `050cb4b15875a7eefc180d1f00b97bf5e8b17104`; `ComfyUI_VNCCS_Utils` @ `1908ddfa8a5084a360783ca596f27678743c5496` (HEAD 2026-07-11); ComfyUI itself latest tag `v0.9.2` = `8f40b43e0204d5b9780f3e9618e140e929e80594`.

## B.2 Base model evaluation

| Model | License (weights) | Outputs | Pose ControlNet | Identity tooling | 24 GB fit | Verdict |
|---|---|---|---|---|---|---|
| **SDXL base 1.0** | CreativeML OpenRAIL++-M ([HF](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0)) | Commercial OK (use-restriction clauses only) | **Best in class** (xinsir, Apache 2.0) | IP-Adapter (Apache), mature | ~7 GB fp16, easy | ⭐ primary (non-character assets) |
| **Illustrious-XL v2.0** | CreativeML OpenRAIL-M per HF cardData ([repo](https://huggingface.co/OnomaAIResearch/Illustrious-XL-v2.0); note v0.1 was fair-ai-public-license — [discussion](https://huggingface.co/OnomaAIResearch/Illustrious-XL-v1.0/discussions/1)) | Commercial OK | inherits all SDXL ControlNets | inherits IP-Adapter; **VNCCS targets it** | same as SDXL | ⭐ primary (characters/portraits) |
| **Qwen-Image** (20B MMDiT, 2025-08) | **Apache 2.0** ([HF](https://huggingface.co/Qwen/Qwen-Image)) | Unrestricted | InstantX Union (canny/softedge/depth/**pose**, Apache 2.0, [HF](https://huggingface.co/InstantX/Qwen-Image-ControlNet-Union)); DiffSynth patches ([Comfy rehost](https://docs.comfy.org/tutorials/image/qwen/qwen-image)) | **Qwen-Image-Edit-2509** — best-in-class identity-preserving edits | fp8 ≈ 20 GB, "24GB comfortable for FP8" ([ComfyUI wiki](https://comfyui-wiki.com/en/tutorial/advanced/image/qwen/qwen-image)); GGUF for headroom | ⭐ fallback stack + edit model in primary |
| FLUX.1-dev / FLUX.2-dev | **Non-commercial** model license ([BFL](https://bfl.ai/legal/non-commercial-license-terms)); outputs are *not* Derivatives, but model *use* must be non-commercial | Outputs technically free; model-use restriction is the problem | good (union/InstantX for dev) | Kontext-dev (also NC) | dev fp8 ~12–16 GB | ❌ excluded — license friction for an open pipeline |
| FLUX.1-schnell | Apache 2.0 ([HF](https://huggingface.co/black-forest-labs/FLUX.1-schnell)) | Unrestricted | weak — no solid pose CN for schnell | weak | ~12 GB fp8 | Bench only |
| SD3.5 Large | Stability Community License (<$1M) | Owned by user | canny/depth/blur official; **no good OpenPose** | thin | ~16 GB fp8 | ❌ pose gap |
| PixArt-Sigma | OpenRAIL++ ([HF](https://huggingface.co/PixArt-alpha/PixArt-Sigma-XL-2-1024-MS)) | OK | ecosystem thin | thin | easy | Bench |
| Lumina-Image 2.0 | Apache 2.0 ([HF](https://huggingface.co/Alpha-VLLM/Lumina-Image-2.0)) | Unrestricted | ecosystem thin | thin | easy | Bench |
| Chroma1-HD (FLUX-schnell derivative, 2025) | Apache 2.0 ([HF](https://huggingface.co/lodestones/Chroma1-HD)) | Unrestricted | emerging | emerging | ~18 GB | Watchlist |
| Anima 2B | reported **non-commercial** (see B.1) | ⚠️ unverified | via VNCCS | via VNCCS | tiny (GGUF) | ❌ until license verified |

## B.3 The conditioning & repair toolbox (primary stack details)

**Pose (REQUIRED):**
- `xinsir/controlnet-openpose-sdxl-1.0` — Apache 2.0, the strongest SDXL pose CN ([HF](https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0)). Pin @ `23f966cd5cfdd3f7729c903e243d87152162d2b7`.
- `xinsir/controlnet-union-sdxl-1.0` (ProMax) — Apache 2.0, one model for openpose/depth/canny/**inpaint-repaint** modes ([HF](https://huggingface.co/xinsir/controlnet-union-sdxl-1.0)). Pin @ `801a4a3fa3d4c936f4feea95b98607bc6726f80c`. This gives the SPEC's masked-repair loop a conditioned repaint path with zero extra license surface.
- Preprocessors: `Fannovel16/comfyui_controlnet_aux` @ `e8b689a513c3e6b63edc44066560ca5919c0576e` (DWPose etc.); VNCCS Pose Studio supplies synthetic skeletons directly (better than estimation for sheet frames — deterministic input for the Tier-2 keypoint-deviation gate).

**Identity preservation:**
- `h94/IP-Adapter` (incl. IPAdapter-Plus variants) — **Apache 2.0** ([HF](https://huggingface.co/h94/IP-Adapter)). Pin @ `018e402774aeeddd60609b4ecdb7e298259dc729`.
- ⚠️ **Do NOT use IP-Adapter-FaceID / InstantID / PuLID:** they depend on InsightFace models that are **non-commercial** ([FaceID discussion](https://huggingface.co/h94/IP-Adapter-FaceID/discussions/18), [InstantID discussion](https://huggingface.co/InstantX/InstantID/discussions/2)). For anime/pixel characters, face-ID embeddings are near-useless anyway; VNCCS's staged-conditioning recipe + IPAdapter-Plus reference conditioning is the right mechanism.
- **Qwen-Image-Edit-2509** (Apache 2.0, ComfyUI-native since 2025-09, [Comfy blog](https://blog.comfy.org/p/wan22-animate-and-qwen-image-edit-2509)) is the strongest local identity-preserving *edit* model: instruction edits, multi-image (character + pose reference) composition, pose change with identity retention ([NextDiffusion tutorial](https://www.nextdiffusion.ai/tutorials/consistent-poses-qwen-image-edit-2509-controlnet-union-comfyui)). This is the SPEC's "identity-preserving edit model" for the repair loop. Pins: `Qwen/Qwen-Image-Edit-2509` @ `d3968ef930e841f4c73640fb8afa3b306a78167e`; fp8 repackage `Comfy-Org/Qwen-Image-Edit_ComfyUI` @ `e9e85de74a8f48c1e3e2656617626348675a2f21`. (Newer 2511 exists; 2509 is the pin with the most community validation.)

**Pixel-art style:**
- `nerijs/pixel-art-xl` LoRA — CreativeML OpenRAIL-M, HF-hosted (pinnable!) @ `8bf4a4d9ea283e00a51fafda8e0539f8248ea037` ([HF](https://huggingface.co/nerijs/pixel-art-xl), [Civitai](https://civitai.com/models/120096/pixel-art-xl)). No trigger word; guidance ~1.5; **8× nearest-neighbor downscale for pixel-perfect output** — that downscale should be a deterministic post-step in the atelier workflow, feeding the Tier-1 palette/scale gates.
- Illustrious-native options on Civitai (character sprites in the VNCCS path): [Pixo pixel art style](https://civitai.com/models/1821405/pixo-pixel-art-style-lora), [Game Character Sprites / Assets Generator](https://civitai.com/models/1936887/game-character-sprites-assets-generator-retro-rpg-video-game-dev-2d-pixel-art), [Pixel Art Sprite Sheet (space candy)](https://civitai.com/models/1028198/pixel-art-sprite-sheet-space-candy-media), checkpoint [Pixel Art Diffusion XL "Sprite Shaper"](https://civitai.com/models/277680/pixel-art-diffusion-xl). ⚠️ Civitai licenses are per-model checkboxes ("commercial use: images" etc.) — **each one must be individually license-checked before pinning**; pin by modelVersionId + file SHA256 (Civitai exposes both). None verified in this pass.
- HD-2D nuance: Octopath-style = pixel sprites over painterly environments. Sprites/tiles/icons take the pixel LoRA; battle backgrounds and portraits may deliberately *not* use it — style bible should carry two scaffold families.

**Background removal → alpha:** **BiRefNet** — **MIT** weights ([HF](https://huggingface.co/ZhengPeng7/BiRefNet) @ `e2bf8e4460fc8fa32bba5ea4d94b3233d367b0e4`), supported in ComfyUI ([docs tutorial](https://docs.comfy.org/tutorials/utility/remove-background-birefnet); node pack [`1038lab/ComfyUI-RMBG`](https://github.com/1038lab/ComfyUI-RMBG) wraps it). ⚠️ **BRIA RMBG-1.4/2.0 are CC-BY-NC** ([HF](https://huggingface.co/briaai/RMBG-2.0)) — the ComfyUI-RMBG pack defaults must be configured to BiRefNet, never the BRIA weights. Note: for hard-edged pixel sprites, deterministic flood-fill/chroma keying after nearest-neighbor downscale may beat any neural matting — try it first in Tier-1 (cheaper and exactly reproducible).

**Masked inpaint:** SDXL/Illustrious via ComfyUI-core differential diffusion + Union-ProMax repaint mode (no extra weights, no extra licenses); instruction-level repairs via Qwen-Image-Edit-2509. (Fooocus-inpaint patch and BrushNet exist but add license/pin surface for little gain.)

## B.4 Recommended stacks (Part B)

**PRIMARY — "SDXL-family + Qwen-edit hybrid" (all ComfyUI-native, all pinned):**
- Characters/portraits/walk-cycle sheets: **Illustrious-XL v2.0** through **VNCCS 3.0.1** staged conditioning (base → clothes → emotions → poses), Pose Studio skeletons → **xinsir OpenPose CN**, identity via VNCCS recipe + **IPAdapter-Plus**.
- Tilesets/icons/battle-backgrounds/UI: **SDXL base 1.0** (+ **pixel-art-xl** LoRA where the style bible says pixel), same CN stack.
- Repair loop: masked differential-diffusion inpaint / Union-ProMax repaint; escalate to **Qwen-Image-Edit-2509 fp8** for identity-preserving instruction edits.
- Alpha: **BiRefNet** (or deterministic keying for downscaled sprites).
- **VRAM:** SDXL fp16 UNet+CLIP ≈ 7 GB + CN ≈ 2.5 GB + IPAdapter <1 GB → **~10–14 GB peak**; Qwen-Edit fp8 stage ≈ 20 GB but runs *sequenced* as its own stage (one-device rule holds; it simply must not co-load with anything).
- Everything sits on `cuda:0`; the future local VLM judge takes `cuda:1`.

**FALLBACK — "all-Qwen" (Apache 2.0 end-to-end):**
- **Qwen-Image fp8** (`Comfy-Org/Qwen-Image_ComfyUI` @ `46839d338df81ce625d5fae27d7e370314c0fbc9`) + **InstantX ControlNet-Union** (pose; @ `b13036f066d6dee7c20513e263d3d673055e9de8`) + **Qwen-Image-Edit-2509** for identity/repair; VNCCS's published Qwen workflows as the recipe source. ~20–22 GB per stage.
- Trade-offs: cleanest licensing in the survey and the best prompt adherence/text rendering; but pixel-art LoRA ecosystem is young, generation is slower (20B), and the InstantX pose CN was trained on *human photos at 1328×1328* — obedience on chibi/stylized proportions is **unproven** (acceptance test below).

**Explicitly rejected:** FLUX.1-dev/FLUX.2-dev (NC model license), Anima (unverified NC), SD3.5 (pose-CN gap), InsightFace-anything (NC), RMBG-2.0 (NC).

## B.5 M1 acceptance tests (image)
1. **Smoke (per SKILL.md):** one 64×64 item icon end-to-end (generate → pixel downscale → alpha → gates → manifest) on pinned appliance.
2. **Pose obedience:** 8 Pose Studio skeletons × 4 candidates through Illustrious+xinsir-openpose; Tier-2 keypoint deviation must beat threshold on ≥6/8 poses. Run the same battery through the Qwen fallback to quantify the stylized-proportions risk before we ever need it.
3. **Identity hold:** VNCCS full staged run (base → 2 outfits → 4 emotions → 8 poses); embedding similarity of masked crops vs. canonical reference above bar across all frames.
4. **Sheet coherence:** one 4-dir walk cycle as a single-canvas sheet; Tier-1 registration gates (feet baseline, centroid drift, bbox variance) + Tier-4 GIF motion judge.
5. **Repair convergence:** inject a deliberate defect (mask a hand), verify Qwen-Edit-2509 repair converges within K=2 rounds where SDXL re-roll random-walks.
6. **License snapshot:** `PIN.json` gains LICENSE-file hashes for every model at its pinned revision; Anima and each Civitai LoRA get an explicit shippable/non-shippable verdict recorded in DECISIONS.md.

---

# Consolidated PIN table (verified 2026-07-11)

| Artifact | Repo / source | Pin (revision / tag / commit) | License |
|---|---|---|---|
| ComfyUI | github.com/comfyanonymous/ComfyUI | `v0.9.2` = `8f40b43e0204d5b9780f3e9618e140e929e80594` | GPL-3.0 (app; irrelevant to outputs) |
| VNCCS | github.com/AHEKOT/ComfyUI_VNCCS | `3.0.1` = `050cb4b15875a7eefc180d1f00b97bf5e8b17104` | MIT |
| VNCCS-Utils | github.com/AHEKOT/ComfyUI_VNCCS_Utils | `1908ddfa8a5084a360783ca596f27678743c5496` (no tags) | MIT |
| controlnet_aux | github.com/Fannovel16/comfyui_controlnet_aux | `e8b689a513c3e6b63edc44066560ca5919c0576e` | Apache 2.0 |
| ACE-Step 1.5 code | github.com/ace-step/ACE-Step-1.5 | `v0.1.8` = `dce621408bee8c31b4fcf4811682eb9359e1bc94` | MIT |
| ACE-Step 1.5 AIO (ComfyUI) | HF `Comfy-Org/ace_step_1.5_ComfyUI_files` | `54b2ef4d8af5582f54c7e6b84c22b679a194bc4b` | Apache 2.0 (repack; weights MIT) |
| ACE-Step 1.5 sft 2B | HF `ACE-Step/acestep-v15-sft` | `c410d249e71ea9385a7b586865e65b1473e1098d` | MIT |
| ACE-Step 1.5 XL turbo 5B | HF `ACE-Step/acestep-v15-xl-turbo` | `d4a0b288b83ebb7e25a8c0b32c573c22e134e8ee` | MIT |
| ACE-Step v1 3.5B (fallback) | HF `ACE-Step/ACE-Step-v1-3.5B` | `82cd0d7b6322bd28cd4e830fe675ddb6180ce36c` | Apache 2.0 |
| Stable Audio Open 1.0 | HF `stabilityai/stable-audio-open-1.0` | `f21265c1e2710b3bd2386596943f0007f55f802e` | Stability Community |
| SDXL base 1.0 | HF `stabilityai/stable-diffusion-xl-base-1.0` | `462165984030d82259a11f4367a4eed129e94a7b` | OpenRAIL++-M |
| Illustrious-XL v2.0 | HF `OnomaAIResearch/Illustrious-XL-v2.0` | `69459c1fe6f46db41ab31e6114f05acc0e06bcaa` | OpenRAIL-M (per cardData) |
| pixel-art-xl LoRA | HF `nerijs/pixel-art-xl` | `8bf4a4d9ea283e00a51fafda8e0539f8248ea037` | OpenRAIL-M |
| OpenPose CN (SDXL) | HF `xinsir/controlnet-openpose-sdxl-1.0` | `23f966cd5cfdd3f7729c903e243d87152162d2b7` | Apache 2.0 |
| Union-ProMax CN (SDXL) | HF `xinsir/controlnet-union-sdxl-1.0` | `801a4a3fa3d4c936f4feea95b98607bc6726f80c` | Apache 2.0 |
| IP-Adapter | HF `h94/IP-Adapter` | `018e402774aeeddd60609b4ecdb7e298259dc729` | Apache 2.0 |
| Qwen-Image (fallback base) | HF `Qwen/Qwen-Image` / fp8 `Comfy-Org/Qwen-Image_ComfyUI` | `75e0b4be04f60ec59a75f475837eced720f823b6` / `46839d338df81ce625d5fae27d7e370314c0fbc9` | Apache 2.0 |
| Qwen-Image-Edit-2509 | HF `Qwen/Qwen-Image-Edit-2509` / fp8 `Comfy-Org/Qwen-Image-Edit_ComfyUI` | `d3968ef930e841f4c73640fb8afa3b306a78167e` / `e9e85de74a8f48c1e3e2656617626348675a2f21` | Apache 2.0 |
| Qwen CN Union (fallback pose) | HF `InstantX/Qwen-Image-ControlNet-Union` | `b13036f066d6dee7c20513e263d3d673055e9de8` | Apache 2.0 |
| BiRefNet | HF `ZhengPeng7/BiRefNet` | `e2bf8e4460fc8fa32bba5ea4d94b3233d367b0e4` | MIT |
| Civitai pixel/sprite LoRAs (Illustrious) | civitai.com (models 1821405, 1936887, 1028198, 277680) | pin by modelVersionId + file SHA256 at download | ⚠️ per-model — verify each |

**Open verification items for M1 day-one:** (1) Anima license text; (2) VNCCS Control Center download manifest → hash snapshot; (3) Civitai LoRA license checkboxes; (4) SAM3 license (tooling only); (5) in-repo LICENSE files vs. HF cardData for the ACE-Step 1.5 weights; (6) the two "unproven" acceptance batteries — BGM loop-seam quality (A.4) and stylized-proportion pose obedience for the Qwen fallback (B.5-2).
