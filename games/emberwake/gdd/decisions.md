# Emberwake — Decision Log

Per-game decisions, numbered G-NNN. Studio-level decisions live in /DECISIONS.md.

## G-001 — GDD provenance: design-compiler stub mode (fixed micro-GDD)
No human conversation occurred; this GDD is the canonical M0 asset from `skills/m8-design-compiler/assets/m0-gdd/`, fixed so milestone exit tests are comparable across sessions and skill versions (SPEC §11 M0).

## G-002 — Expected level curve
L1 town → L2 clearing F1 → L3 clearing F2 → L4 at the vault. Encounter XP must support this without grinding (grind_tolerance 1). Rationale: gives m8-balancer a concrete curve to sim against in a 30-minute game.

## G-003 — Boss loss consequence
Ash Tyrant defeat = game over → title (on_defeat: game_over). Regular encounters likewise; there is no retry crutch at M0 because save points (inn + shaft entrance) make runs cheap.

## G-004 — Starting purse: 120 gold, no starting equipment or items
Content phase priced the shop (265g total equipment + consumables) assuming a modest purse so first purchases land before/during F1. Conductor call: Game.new_run grants 120g, empty inventory, no equipment — the first player decision is a shopping decision, which teaches the economy. m8-balancer sims must use this purse for the L1/L2 checkpoint.

## G-005 — Spawn-co-located triggers fire on placement
A trigger entity sharing a tile with the active spawn fires when the party is placed there (new run or portal arrival), before input. Required for node.intro on the town start tile; one-shot behavior via blocked_by_flag remains the content-side idiom.

## G-006 — Save points: town only at M0 (amends G-003)
G-003 assumed inn + shaft entrance; the world data only grants the town (inn + save_point service). Conductor call: accept town-only saves for M0 — a 30-minute game with a save before the descent doesn't need a mid-dungeon anchor, and adding one now would invalidate the balance sim's death-cost assumptions. Revisit at M2 scope via m8-cartographer.

## G-007 — Style bible gains validated prompt scaffolds from M1 smoke tests
The icon scaffold (gate-passing warm-draught run) and the town-music scaffold (human Tier-3 approved: "good calming town theme") are promoted into prompt_scaffolds as the canonical templates; dungeon/battle music scaffolds derived from the approved direction pending their own approval. Per m8-atelier rules, scaffolds are now the ONLY prompt source for these asset classes.
