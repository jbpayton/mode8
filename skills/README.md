# The Skill Library — this IS the system

There is no software underneath these skills (SPEC Thesis 6). A Claude Code session + these instructions + the ontology + two pinned appliances = the studio. Scripts exist only where determinism or economy demands (each script's header states which test it passes); everything else is live judgment that improves as models do.

| Skill | Role | Active |
|---|---|---|
| `m8-conductor` | orchestrates builds, owns plan/ state | M0 |
| `m8-design-compiler` | conversation → GDD (stub mode for milestones) | M0 |
| `m8-systems-designer` | stat model, elements, statuses, curves | M0 |
| `m8-engine-smith` | generates the per-game Godot engine + tests | M0 |
| `m8-menu-wright` | menu/UI scenes, UX conventions | audit M0 · full M1/M3 |
| `m8-armory` · `m8-spellbook` · `m8-bestiary` · `m8-classweaver` · `m8-loremaster` · `m8-cartographer` | content domains (DSL data, never code) | M0 folded · M2 full |
| `m8-build-warden` | integration gates (content/tests/boot/save/smoke) | M0 |
| `m8-balancer` | Monte Carlo balance vs. GDD bands | M0 skeleton · M2 full |
| `m8-playtester` | completability proof + persona runs | M0 |
| `m8-atelier` | ComfyUI asset pipeline + manifests | M1 |
| `m8-asset-warden` | 4-tier asset gate cascade + repair loop | M1 |
| `m8-soundsmith` | music/SFX slots | stub (interface fixed) |
| `m8-newgame-plus` | retrospectives → skill mutations | every build |

Deterministic scripts in the library today: `m8-build-warden/scripts/gate_content.py`, `m8-playtester/scripts/static_completability.py`, `m8-balancer/scripts/simulate.py`.
