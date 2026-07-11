# Emberwake — Game Design Document (M0 micro-GDD, fixed)

**Purpose:** the walking-skeleton game (SPEC §11 M0). Ugly on purpose — placeholder art, minimal content — but *complete*: town, three-floor dungeon, boss, ending, save/load. Every downstream system must be the real system; only the scale is small.

## Premise

Cinderfall, last village on the caldera's lip. The mountain is waking. Two volunteers descend the old miners' shafts — the Ember Depth — to still the mountain's heart before ash takes the village. They find the Ember Key on the middle floor, unlock the vault at the bottom, and put down the Ash Tyrant.

## Tone bible

Keywords: warm ember glow · stoic frontier · quiet dread underground · small kindnesses · volcanic.
Never: comedy relief, meta-humor, grimdark cruelty.
Voice sample: *"The wells ran warm again this morning. Nobody said anything. Marta left two loaves at the shaft-house door, the way you do for people who might not come back."*

## Structure (fixed for M0)

1. **Cinderfall (town):** inn (heals, cheap), one shop (items + starter equipment), elder NPC (frames the quest, sets `flag.quest_started`), shaft-house door to the Depth.
2. **Ember Depth F1:** first encounters, one treasure chest (consumables).
3. **Ember Depth F2:** harder encounters; the **Ember Key** in a guaranteed chest, visibly placed.
4. **Ember Depth F3:** vault door requires `item.ember_key`; behind it the **Ash Tyrant** (boss, two phases via hp_below predicate). Victory sets `flag.tyrant_down` → ending scene → credits line → title.

Party: 2, player-built from 2 classes (a sturdy physical class, a fragile caster). 4 spells spread across coverage duties: single-target elemental damage, heal, defensive buff, damage-over-time status. Monsters: 3 regulars (one weak to the caster's element, one physical-resistant, one fast) + boss. 5 items (potion-tier heal, MP restore, status cure, key item, one escape/utility). 4 equipment pieces (one weapon + one armor per class archetype).

## Difficulty philosophy

Numbers in `gdd.json` and binding: regular fights die in 2–5 rounds at on-curve levels, boss in 6–16, wipe rate ≤15% per regular encounter, and no checkpoint may require grinding more than 1 level past the expected curve (expected curve: L1 town, L2 F1, L3 F2, L4 F3/boss).

## Out of scope for M0

Real art (colored rects + text glyphs only), music (silent slots), VN presentation, sidequests, economy depth. These arrive M1–M3; the schemas they'd fill stay empty rather than half-filled.
