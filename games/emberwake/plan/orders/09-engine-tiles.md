# Work order 09 — engine: render tileset + entity sprites in overworld

You are the m8-engine-smith for MODE 8, replacing the overworld's colored-rectangle tiles with the generated tileset. Bounded, determinism-critical.

BINDING RULES:
1. /home/seraphius/mode8/skills/m8-engine-smith/references/engine-contract.md (§3 determinism, §8 overworld obligations)
2. /home/seraphius/mode8/games/emberwake/src/engine/API.md (M8Assets)
3. The asset layer handles item_icon, bgm, sprite_sheet, battle_sprite. You ADD: `tile` class + entity-marker sprites.

CONTEXT:
- games/emberwake/assets/manifest.json now has 5 `tile` entries (keys = tileset_keys: town_floor, town_wall, town_well, cave_floor, cave_wall) and 3 entity-marker `sprite` entries (keys: chest, portal, npc) — all 16×16.
- Maps' legend entries carry `tileset_key`; the overworld currently hashes that key to a ColorRect color. Map entities (kind chest/portal/npc/trigger/spawn) currently render as glyphs.
- Tile size on screen = 16px logical; the game's internal res is 640×360 (style bible), so tiles render at 16×16 device px (or the overworld's existing tile pixel size — match whatever the current ColorRect grid uses; DON'T change the camera/scale).

TASK:
1. **M8Assets.tile_texture(key) -> Texture2D or null**: resolve `tile` class, runtime-load, cache. Add to API.md.
2. **overworld.gd tile rendering**: for each visible cell, if the legend's tileset_key resolves to a tile texture, draw it (TextureRect/Sprite2D, nearest filter, at the cell's existing pixel rect) instead of the ColorRect; fall back to the current ColorRect color when unresolved. Walkable/collision logic is UNCHANGED (it reads legend.walkable, not the visual).
3. **Entity markers**: chest/portal/npc entities render their marker sprite (M8Assets sprite class: chest→"chest", portal→"portal", npc→"npc") when resolved, glyph fallback otherwise. The player leader sprite (walk sheet) already works — leave it. trigger/spawn entities stay invisible/glyph as today.
4. DETERMINISM (critical): pure rendering. Zero Rng, zero Game-state writes, zero content-id literals (tileset_key and entity kind come from map data via ContentDB/Game). Rusher replay (reports/playtest/rusher/actions.json seed 1101) MUST stay byte-identical to reports/playtest/rusher/trace.jsonl.

VERIFY (all must pass):
- run_tests.gd all green (add a tile_texture resolution test, guarded/id-free)
- boot smoke exit 0
- rusher replay byte-identical (wipe saves first; cmp vs committed trace; use ABSOLUTE --m8-script path — bare relative paths silently no-op under --path)
- xvfb screenshots: capture Cinderfall (town tiles + well + npc + portal) AND a dungeon floor (cave tiles + chest) so the conductor can eyeball the rendered world. Save to scratchpad/world_shots/.

OUTPUTS: src/autoload/m8_assets.gd, src/scenes/overworld.gd, src/engine/API.md, test file, 2+ screenshots.

CONSTRAINTS: edit only src/**. Godot: /home/seraphius/mode8/appliances/godot/godot.

RETURN: (1) file manifest; (2) test/boot/rusher-byte-identical verdicts verbatim; (3) screenshot paths + honest description of how Cinderfall and the dungeon look now; (4) API.md additions.
