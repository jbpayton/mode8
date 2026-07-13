# Work order 10 — engine: battle backgrounds + dialogue/status portraits

You are the m8-engine-smith for MODE 8, wiring the last two art classes into scenes. Bounded, determinism-critical.

BINDING RULES:
1. /home/seraphius/mode8/skills/m8-engine-smith/references/engine-contract.md (§3 determinism, §8 scenes)
2. /home/seraphius/mode8/games/emberwake/src/engine/API.md (M8Assets — you'll add two accessors)
3. Asset layer already handles item_icon, bgm, sprite_sheet, battle_sprite, tile, sprite. You ADD: battle_background + portrait.

CONTEXT — manifest now has:
- battle_background: bg_ember_depth, bg_vault (~640×360, opaque)
- portrait: por_warden, por_ashcaller (96×96) — content classes.json `portrait` field = these keys (class.warden.portrait="por_warden", class.ashcaller.portrait="por_ashcaller")

TASK:
1. **M8Assets.background_texture(key)** and **M8Assets.portrait_texture(key)** — class-gated (battle_background / portrait), runtime-load, cache. Add both to API.md.
2. **battle_menu.gd — background**: draw a full-screen background behind everything (below the sprite layer and UI). WHICH background: derive from context — if any enemy is a boss (is_boss) use bg_vault; else use bg_ember_depth. (Town has no random encounters, so ember_depth is the sensible default for all regular fights in this game.) Scale to fill the 640×360 view, nearest or linear (backgrounds are painterly — linear is fine for them specifically; sprites stay nearest). Fallback: current black when unresolved.
3. **dialogue.gd — portrait**: when a dialogue line's speaker corresponds to a party member whose class has a portrait key that resolves, show the 96×96 portrait beside the text box. The dialogue schema lines have a `speaker` (display name) and optional `portrait` field (currently unused). Resolution: if line.portrait resolves via M8Assets.portrait_texture use it; else if the speaker name matches a party member's name, use that member's class portrait; else no portrait (text-only, as today). Keep all existing dialogue advancement/flag logic unchanged.
4. **status.gd — portrait**: show the viewed party member's class portrait (96×96) on their status sheet when it resolves; glyph/none fallback.
5. DETERMINISM (critical): pure rendering. Zero Rng, zero Game-state writes, zero content-id literals (keys from ContentDB/dialogue data). Rusher replay (reports/playtest/rusher/actions.json seed 1101) MUST stay byte-identical to reports/playtest/rusher/trace.jsonl.

VERIFY:
- run_tests.gd all green (add background_texture + portrait_texture resolution tests, guarded/id-free)
- boot smoke exit 0
- rusher replay byte-identical (wipe saves; ABSOLUTE --m8-script path; cmp vs committed trace)
- xvfb screenshots: a regular battle (with bg_ember_depth), and the intro dialogue (with a portrait if the intro speaker is a party member — if the intro is narrator-only, capture the elder/quest dialogue or a status screen showing a portrait). Save to scratchpad/bg_shots/.

OUTPUTS: src/autoload/m8_assets.gd, src/scenes/{battle_menu,dialogue,status}.gd, src/engine/API.md, test file, screenshots.

CONSTRAINTS: edit only src/**. Godot: /home/seraphius/mode8/appliances/godot/godot.

RETURN: (1) file manifest; (2) test/boot/rusher-byte-identical verdicts verbatim; (3) screenshot paths + honest description (does the battle look complete with a backdrop? do portraits land?); (4) API.md additions; (5) note if the dialogue portrait rarely triggers (the M0 dialogue may be mostly narrator/NPC, not party) — that's fine, report honestly which scenes actually show portraits.
