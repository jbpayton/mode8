# Work order 02 — content phase (all six domains folded at M0 scope)

You are the content specialist for the MODE 8 studio, building "Emberwake". At M0 scope you cover six domains in one pass: armory, spellbook, bestiary, classweaver, loremaster, cartographer.

BINDING RULES — read these files first, in order:
1. /home/seraphius/mode8/ontology/CONVENTIONS.md (encoding: tagged objects, shorthand, ids, collection envelopes)
2. /home/seraphius/mode8/ontology/effect-algebra.md (the algebra you write everything in)
3. The six SKILL.md craft-rule files: /home/seraphius/mode8/skills/m8-{armory,spellbook,bestiary,classweaver,loremaster,cartographer}/SKILL.md — their craft rules are binding at any scope.

GAME CONTEXT:
- Game dir: /home/seraphius/mode8/games/emberwake/ (work here; all paths below relative to it)
- Read first: gdd/gdd.json, gdd/gdd.md (structure §"Structure (fixed for M0)" is binding), gdd/decisions.md
- Phase-1 outputs are law: content/stat-model.json (stat ids, curve ids, damage formulas, xp curve), content/elements.json, content/statuses.json. Use ONLY ids declared there.
- XP budget note from systems phase: {XP_NOTE}

YOUR TASK — produce exactly the GDD's content targets:
- classes.json: 2 classes — sturdy physical (knight archetype) + fragile caster (mage archetype). Cover EVERY stat in base_stats and growth (curves from stat-model). Knight verb ≠ mage verb; description states it.
- spells.json: 4 spells — single-target fire damage (mage), heal (mage), defensive buff via modify_stat (knight or mage — decide), damage-over-time via apply_status using a status from statuses.json. Learn levels within L1–L4. school ids allowed but optional at M0.
- items.json: 5 items — heal consumable, MP restore consumable, status-cure consumable (cures the statuses in statuses.json), item.ember_key (kind=key, no price — story-gift/chest only), and one utility consumable (your call: escape rope home-portal effect is NOT in the algebra — pick something legal, e.g. a damage stone or revive tonic). Consumables need use ability + usable_in.
- equipment.json: 4 pieces — one weapon + one body armor per class archetype (class_lock accordingly), priced for the town shop.
- monsters.json: 3 regulars + 1 boss (is_boss). Regulars: one weak to fire (frost-flavored), one physical-resistant (high def, fire-flavored — teach the mage's value), one fast (high agi, teaches turn order). Boss "Ash Tyrant": two ai phases via hp_below(source, 0.5) 'when' predicates, fire attacks, a burn/status move. Stats: cover every model stat; derive from expected party stats at the GDD curve (L2 floor1, L3 floor2, L4 boss) so ttk_band [2,5] regular / boss_ttk_band [6,16] plausibly hold — show arithmetic for one regular and the boss in your return. XP/gold per the budget note above.
- encounters.json: 3 tables (floor1, floor2, floor3) stepping up per the curve; groups of 1–2 monsters; steps_per_check/encounter_chance tuned for 3–6 fights per floor crossing (state your expected-fights arithmetic per floor).
- world.json + maps/*.json: town map (cinderfall) + 3 dungeon floors (ember_depth_f1/f2/f3), each ~20×15 max, ASCII-designed. Town: inn (services), shop (stock = the 4 equipment + 3–4 purchasable items), elder NPC (dialogue + story_node), portal to F1. F1: encounters, 1 chest (consumables treasure table), stairs down. F2: encounters, THE ember key chest (guaranteed table, visibly placed), stairs. F3: quiet corridor to vault door — vault door is a trigger entity whose story_node requires item.ember_key and leads to the boss battle node; boss room behind. Portals bidirectional with spawn entities both sides. Save: inn + shaft entrance (save_point true on town services; the F1 entrance is in the town map region). Region: one region, tier 1, places town + dungeon.
- story.json + dialogue.json: nodes — intro scene (auto-fires at start via trigger on town spawn... place a trigger entity), elder quest scene (sets flag.quest_started), vault gate (flag_gate/battle: requires item.ember_key → battle node vs ash_tyrant, on_defeat game_over, victory sets flag.tyrant_down, next → ending scene node), ending (kind ending, dialogue = closing scene). Dialogue per tone bible (gdd.md): stoic frontier, small kindnesses, ≤80 words/scene. The ending must be reachable; run the prover.

INPUTS (read): listed above.
OUTPUTS (write, exactly): content/{classes,spells,items,equipment,monsters,encounters,world,story,dialogue}.json, content/maps/{cinderfall,ember_depth_f1,ember_depth_f2,ember_depth_f3}.json

THE GATES THAT JUDGE YOUR WORK (run both before returning; failing = redo):
1. python3 /home/seraphius/mode8/skills/m8-build-warden/scripts/gate_content.py /home/seraphius/mode8/games/emberwake  → must be GREEN (zero errors).
2. python3 /home/seraphius/mode8/skills/m8-playtester/scripts/static_completability.py /home/seraphius/mode8/games/emberwake → must be GREEN (ending reachable, no orphaned items, no errors).

CONSTRAINTS:
- You may NOT edit files outside your OUTPUTS list, the ontology, other skills, plan/, or phase-1's three files.
- Algebra gap → draft RFC in ontology/RFCS.md + closest legal expression; note both.
- Sprite/portrait/tileset_key/music fields: set semantic keys (e.g. "mon_cinder_slime") — placeholders resolve at M1; music slots per m8-soundsmith conventions.
- Return format: (1) file manifest, (2) both gate outputs verbatim (summary lines), (3) monster + encounter-density arithmetic, (4) per-class learn table, (5) open questions/RFCs. No prose recap.
