# Work order 07 — engine asset-loading layer (M1)

You are the m8-engine-smith for the MODE 8 studio, adding the real-asset loading layer to Emberwake's engine. The M0 engine renders ColorRect/glyph placeholders; M1 assets are arriving (icons, music, walk sheets). Your layer loads what exists and falls back to placeholders for what doesn't — progressive enhancement, never a hard dependency on an asset.

BINDING RULES — read first:
1. /home/seraphius/mode8/skills/m8-engine-smith/SKILL.md
2. /home/seraphius/mode8/skills/m8-engine-smith/references/engine-contract.md (§3 determinism is CRITICAL here — see rule below)
3. /home/seraphius/mode8/games/emberwake/src/engine/API.md
4. /home/seraphius/mode8/skills/m8-soundsmith/SKILL.md (music slot interface: missing file = silence, never an error)

GAME CONTEXT:
- Game dir /home/seraphius/mode8/games/emberwake/; assets live OUTSIDE src/ in assets/ — create symlink src/assets -> ../assets (same validated pattern as src/content).
- assets/manifest.json is the asset contract: entries {key, class, file, ...}. Currently: item_warm_draught_64 (item_icon), music.town (bgm). A walk sheet (class sprite_sheet, 4 rows down/left/right/up × 4 cols, uniform frame box = image_size/4) is being generated in parallel — build the loader to that format now, test with a synthetic fixture sheet you generate in the test itself.
- Content sprite keys: items.json/classes.json/monsters.json carry semantic sprite fields (read them). Resolution rule: content key → manifest entry whose key equals it OR whose "aliases" array contains it. Missing → placeholder as today.

YOUR TASK:
1. **M8Assets autoload** (autoload/m8_assets.gd): loads assets/manifest.json at boot (absent file = empty manifest, all placeholders); resolve(key) -> {class, path} or null; runtime image loading via Image.load_from_file + ImageTexture (no import pipeline); cache textures.
2. **Music player** (autoload/m8_audio.gd): play_slot(slot_id) resolving through M8Assets (bgm class); AudioStreamMP3 via data-from-bytes (runtime-loadable), loop on; missing slot = stop/silence; no error, one trace-visible detail field. Wire: overworld plays current map's music field on map change; battle_menu plays music.battle (music.boss if any monster is_boss); title plays music.title; ending plays music.victory else keeps silence. Volume modest (-6 dB).
3. **Icon rendering**: inventory + shop + battle item lists show the item's icon (16x16 or 24x24 scaled, nearest) before the name when the item's sprite key resolves; glyph fallback otherwise.
4. **Walk-sheet rendering**: overworld party leader sprite: if the leader class's sprite key resolves to a sprite_sheet, replace the placeholder rect with the animated sprite — row by facing (down/left/right/up), 4-frame cycle while moving at ~8 fps (frame index from a movement-step counter, NOT wall time, NOT Rng), frame 0 when idle. Scale to tile grid (16px tile, 24px sprite height convention: bottom-anchored, overhang upward).
5. **Tests + verification**: unit tests for M8Assets resolution (incl. aliases, absent manifest) and music soft-fail, using fixture files written by the test; full suite green; boot smoke green; AND replay the rusher script (reports/playtest/rusher/actions.json, seed 1101) — trace must remain BYTE-IDENTICAL to reports/playtest/rusher/trace.jsonl (your layer must consume no Rng and mutate no game state; if the trace diverges you broke determinism — fix, don't re-baseline).

CONSTRAINTS: edit only src/** (new autoloads, scene render additions, tests) — no content/, no assets/ (read-only), no skills, no plan/. All new code: zero Rng usage, zero Game-state writes, zero content-id literals. Godot binary: /home/seraphius/mode8/appliances/godot/godot.

RETURN: (1) file manifest; (2) test summary + boot + rusher-replay verdict (byte-identical yes/no) verbatim; (3) how the walk-sheet loader will behave when warden_walk.png lands (exact resolution path); (4) any API.md additions made.
