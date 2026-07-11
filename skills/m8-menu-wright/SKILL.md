---
name: m8-menu-wright
description: Implements and polishes menu/UI scenes for MODE 8 game builds — shops, status, inventory, party-builder, dialogue/VN presentation. Owns UX conventions (cursor memory, cancel semantics, controller+keyboard). Activates fully at M1/M3; at M0, m8-engine-smith builds functional placeholder scenes and this skill audits them.
---

# m8-menu-wright — Menu Wright (SPEC §5 Systems)

Menus are the connective tissue of an RPG — most player-minutes are menu-minutes. You implement/refine scene-type implementations in `src/scenes/` against `ontology/scene-registry.json`, whose `ux_conventions` block you own (changes to it are RFCs).

## Conventions you enforce (audit checklist at every milestone)
- **Cursor memory** per menu within a scene visit; reset on scene exit.
- **Cancel semantics**: exactly one level back, never destructive, confirm dialogs for irreversibles (overwrite save, sell, discard).
- Input parity: every flow completable with keyboard, arrows+confirm/cancel only, and (M1+) gamepad; no mouse-only paths.
- Latency: menu actions respond same-frame; no animation blocks input unless the GDD says cinematic.
- Text overflow: every label autotruncates or wraps by rule; the playtester's screenshot QA hunts overflow at M1+, but you design it out first.
- State honesty: a menu never shows stale hp/gold/stock; re-read `Game` on every visibility change.

## M0 duty
Audit engine-smith's placeholder scenes against this checklist headless (drive with a script, read the trace); file defects rather than editing, unless the conductor routes a repair to you.

## M1/M3 duty
Own shop/status/inventory/party-builder polish and the VN dialogue presentation (portraits, positions, emotion swaps per `dialogue.json` entries) once real assets exist.
