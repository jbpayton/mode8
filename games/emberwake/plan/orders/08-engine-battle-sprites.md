# Work order 08 — engine: render battle sprites + party portraits in battle

You are the m8-engine-smith for MODE 8, making the battle scene show generated monster art (and party sprites) instead of glyphs. Small, bounded, determinism-critical.

BINDING RULES:
1. /home/seraphius/mode8/skills/m8-engine-smith/references/engine-contract.md (§3 determinism, §8 scene obligations)
2. /home/seraphius/mode8/games/emberwake/src/engine/API.md (M8Assets is your tool — resolve/texture; sheet() for sprite_sheet class)
3. The asset layer already handles: item_icon, bgm, sprite_sheet. You ADD: battle_sprite class support.

CONTEXT:
- games/emberwake/assets/manifest.json now has 4 battle_sprite entries: mon_rime_whelp, mon_ash_skitter, mon_slag_crawler (128x128), mon_ash_tyrant (224x224). Content monsters.json 'sprite' field = these keys (e.g. monster.rime_whelp.sprite = "mon_rime_whelp").
- Party walk sheets exist (chr_warden, chr_ashcaller, class sprite field). In battle, show the party members too — use the DOWN-facing frame 0 of their walk sheet (front view) as a static battle portrait-sprite, OR the class portrait if one exists (none yet — use walk sheet down-frame).

TASK:
1. **M8Assets.battle_texture(key) -> Texture2D or null**: resolve battle_sprite class, runtime-load, cache. Add to API.md.
2. **battle_menu.gd**: render each enemy as its monster's battle sprite (scaled so a 128 sprite ≈ 96px tall on screen, 224 boss ≈ 150px, preserving aspect, nearest filter) positioned in the enemy formation area; glyph fallback when unresolved. Render each party member as their walk-sheet down-frame-0 (scaled to ~64px) in the party area. Keep all existing battle text/log/menus exactly as-is — sprites are visual dressing over the working scene.
3. **Layout**: enemies upper area, party lower — don't overlap the command menu or battle log. Boss (is_boss) centered and larger. Multiple same-species enemies: offset horizontally.
4. DETERMINISM (critical): this is pure rendering. Zero Rng, zero Game-state writes, zero content-id literals (read sprite keys from ContentDB). The rusher replay (reports/playtest/rusher/actions.json seed 1101) MUST stay byte-identical to reports/playtest/rusher/trace.jsonl.

VERIFY (all must pass):
- godot --headless --path src --script res://tests/run_tests.gd → all green (add a test for battle_texture resolution using the real manifest, guarded/id-free like test_assets.gd)
- boot smoke exit 0
- rusher replay byte-identical (rm -rf ~/.local/share/godot/app_userdata/Emberwake/saves first; cmp against committed trace)
- xvfb capture of one battle: use a debug script that reaches a fight, screenshot to scratchpad — so the conductor can eyeball monsters actually rendering. (xvfb-run -a -s "-screen 0 1280x720x24" <godot> --path src -- --m8-script=... --m8-trace=... --m8-seed=... with a "screenshot" step)

OUTPUTS: src/autoload/m8_assets.gd (battle_texture), src/scenes/battle_menu.gd (sprite rendering), src/engine/API.md, src/tests/unit/test_assets.gd (or new test), one battle screenshot in /tmp/claude-1000/-home-seraphius-mode8/cb673ff3-cb1b-440b-8c80-ce6af8eebbfa/scratchpad/battle_shots/.

CONSTRAINTS: edit only src/**. No assets/, content/, skills/, plan/. Godot: /home/seraphius/mode8/appliances/godot/godot.

RETURN: (1) file manifest; (2) test summary + boot + rusher byte-identical verdict verbatim; (3) the battle screenshot path + honest description of how it looks; (4) any API.md additions.
