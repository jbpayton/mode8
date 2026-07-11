# Emberwake — Decision Log

Per-game decisions, numbered G-NNN. Studio-level decisions live in /DECISIONS.md.

## G-001 — GDD provenance: design-compiler stub mode (fixed micro-GDD)
No human conversation occurred; this GDD is the canonical M0 asset from `skills/m8-design-compiler/assets/m0-gdd/`, fixed so milestone exit tests are comparable across sessions and skill versions (SPEC §11 M0).

## G-002 — Expected level curve
L1 town → L2 clearing F1 → L3 clearing F2 → L4 at the vault. Encounter XP must support this without grinding (grind_tolerance 1). Rationale: gives m8-balancer a concrete curve to sim against in a 30-minute game.

## G-003 — Boss loss consequence
Ash Tyrant defeat = game over → title (on_defeat: game_over). Regular encounters likewise; there is no retry crutch at M0 because save points (inn + shaft entrance) make runs cheap.
