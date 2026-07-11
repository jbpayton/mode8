# MODE 8 — An Autonomous RPG Studio

> **Everything Mode 7 couldn't.**

MODE 8 is an experiment in post-software game development: an autonomous studio that takes nothing but a human design conversation and produces a complete, great-looking, great-playing 2D HD RPG — with zero human labor between the conversation and the shipped game. And then the deeper bet: that the studio can make *itself* better at making games, so quality is a curve, not a ceiling.

There is no application here. No orchestration framework. No engine of our own.
The studio is:

- **A skill library** (`skills/`) — the studio's "weights." Instructions, rubrics, and a handful of deterministic scripts that an agent session loads and follows.
- **An ontology** (`ontology/`) — a versioned schema language for what RPGs are made of, centered on an *effect algebra*: every weapon, spell, monster, and status effect is data interpreted by a small per-game engine, which makes thousand-item armories generatable *and verifiable*.
- **Pinned appliances** (`appliances/`) — Godot 4.x headless and (later) a ComfyUI generation backend, driven as frozen services.
- **Games** (`games/<title>/`) — each with its Game Design Document as the *source code* and everything else (engine, content, assets, builds) as regenerable output.

Every artifact class passes a verification gate — deterministic where possible, rubric-scored model judgment where not, with failures compiled into repair instructions. After every build, a retrospective mutates the skill library. The design conversation is sacred; everything else is disposable.

Read [SPEC.md](SPEC.md) — the founding charter — for the full architecture and theses.

## Status

| Milestone | Description | Status |
|---|---|---|
| **M0** | Walking skeleton: ontology v0, effect-algebra interpreter, a completable micro-RPG, ugly on purpose | 🔨 in progress |
| M1 | The Atelier: full asset pipeline + gate cascade | — |
| M2 | Depth: 150+ items, 60+ monsters, balance simulation | — |
| M3 | Story: VN interludes, character arcs, branch soundness proofs | — |
| M4 | Genre proof: FF1-style, FF6-style, and grid SRPG from one pipeline | — |
| M5 | The flywheel: measured self-improvement across build cycles | — |
| M6 | The real one: a full design conversation → an original ~15-hour RPG | — |

## Running it

The studio *is* a Claude Code session pointed at this repo with the skills in `skills/` installed.

```bash
appliances/godot/fetch.sh       # restore the pinned Godot appliance
# then, in a Claude Code session:
#   "build the game in games/<title>/"
```

All build state lives in files (`games/<title>/plan/`), so any fresh session can resume any build cold.

## License

MIT. This is open research — the point is to prove it's possible, in public.
