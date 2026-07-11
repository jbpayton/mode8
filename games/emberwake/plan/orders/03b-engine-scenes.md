# Work order 03b — engine phase, part 2: scenes + debug drive

You are the m8-engine-smith for the MODE 8 studio, building "Emberwake" — scene layer on top of the tested core from order 03a.

BINDING RULES — read first, in order:
1. /home/seraphius/mode8/skills/m8-engine-smith/SKILL.md
2. /home/seraphius/mode8/skills/m8-engine-smith/references/engine-contract.md — §6 (debug drive + trace) and §8 (scene obligations) are yours
3. /home/seraphius/mode8/games/emberwake/src/engine/API.md — the core APIs you build against (do not modify core modules; if an API is missing/misdocumented, note it and add the minimal accessor, flagging it in your return)
4. /home/seraphius/mode8/ontology/scene-registry.json — scene types + ux_conventions (cursor memory, cancel semantics)

GAME CONTEXT:
- Game dir: /home/seraphius/mode8/games/emberwake/; project in src/; content readable via ContentDB.
- GDD: player_built cast (party_builder at new game: pick 2 members from 2 classes, name them or default names), menu_rows battle, light narrative.
- Placeholder art rules (contract §8): ColorRect + Label glyphs only; style-bible tone colors (ember orange #e08040-ish on soot black, cool shadow blues — pick a small consistent set); every visible entity gets a 1-char glyph.

YOUR TASK — scenes in dependency order, booting headless after each (`--m8-max-frames=60`):
1. scenes/title.tscn+gd — New Game / Continue (Continue hidden if no saves); project.godot main_scene already points here.
2. scenes/party_builder.tscn+gd — 2 slots, class pick per slot, confirm starts run (Game.new_run(party)) → overworld at world.start.
3. scenes/overworld.tscn+gd — renders current map (tile rects from legend, tileset_key→color hash), 4-dir grid movement, facing-tile interact (npc dialogue, chest open once via Game.opened + treasure roll, portal transition, trigger story nodes incl. requires_flag/requires_items gates), encounter rolls per legend encounter_table (steps_per_check/encounter_chance via Rng), menu key → pause menu (Items/Status/Save if at save point/Quit-to-title).
4. scenes/dialogue.tscn+gd — script playback (speaker + text, confirm advances), fires story-node consequences through Game (sets_flags, gives_items, next chaining: scene→battle→ending etc.).
5. scenes/battle_menu.tscn+gd — front-end over engine/battle.gd: party rows vs monster group, commands Attack/Spell/Item/Defend/Row/Flee (hide unavailable), target picking, battle-log lines rendered as text, victory/defeat flow (on_defeat game_over → title; victory → xp/gold/drops screen → return). Story battles come from story nodes; random encounters from tables.
6. scenes/inventory.tscn+gd + scenes/status.tscn+gd + scenes/shop.tscn+gd — per registry conventions; shop reads world.json stock, buy/sell (sell = floor(price/2)); inn service heals+saves (inn_price gold).
7. scenes/save_load.tscn+gd — 3 slots, save at save points, load from title Continue.
8. scenes/ending.tscn+gd — plays ending dialogue, credits line ("MODE 8 — built by the studio, not by hands"), → title.
9. Debug drive verification (contract §6): every scene implements m8_scene_type() + m8_detail(); Game.goto_scene is the single transition choke point emitting trace lines; then run the 40-action integration smoke from the build-warden skill (title → new game → build party → reach town map → open menu → save) with --m8-script/--m8-trace/--m8-seed and confirm the trace shows ≥3 scene types and a quit line.

RUN COMMANDS (green before returning):
- boot: <godot> --headless --path src -- --m8-max-frames=120   (exit 0, no script errors)
- full tests still green: <godot> --headless --path src --script res://tests/run_tests.gd
- smoke: the 40-action drive above; keep script+trace under reports/playtest/smoke/ (create dir).

OUTPUTS: src/scenes/*.tscn+gd (the 9 above), reports/playtest/smoke/{actions.json,trace.jsonl}, minimal additions to autoload/game.gd ONLY if API.md gaps force it (flag every such change).

CONSTRAINTS:
- Content is data: zero content ids in scene code (read everything from ContentDB/world data).
- All input via M8Input; all randomness via Rng; scenes mutate battle state only through engine/battle.gd.
- You may not edit content/, ontology/, skills/, plan/, or core engine/tests except as flagged above.
- Return format: (1) file manifest, (2) boot/tests/smoke outputs verbatim (summary lines), (3) API.md gaps you hit + what you added, (4) UX-convention deviations if any. No prose recap.
