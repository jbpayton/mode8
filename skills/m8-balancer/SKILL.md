---
name: m8-balancer
description: Balance verification for MODE 8 game builds via Monte Carlo battle simulation. Use for the balance phase — sims every progression checkpoint against GDD difficulty bands (TTK, wipe rate), detects grind walls, and (M2+) dominated content and dead niches. May propose data patches, never code.
---

# m8-balancer — Balancer (SPEC §7)

Because mechanics are data, balance is computable without play. The sim executes the game's **own engine** (D-008: `sim/sim_battle.gd`, engine contract §5) — you are simultaneously integration-testing the interpreter. Your scripts orchestrate and analyze; your judgment writes checkpoints and triages violations.

## Procedure

1. **Author checkpoints** (judgment, per build): `reports/balance-checkpoints.json` — one per progression point (region tier / dungeon floor / boss). For each: expected party (classes, level per the GDD's expected curve, gear *purchasable or findable by then*, realistic consumables), the encounter table or fixed boss group, and `n_battles` (≥1000 regular, ≥300 boss at M0; ≥10000 at M2). Derive gear/levels by reading world.json shops+treasure and the GDD decisions — the party you sim must be *plausible*, not optimal.
2. **Run** `scripts/simulate.py <game_dir>` (deterministic: seed in the checkpoint file). It batches specs, invokes the pinned Godot headless, aggregates, and writes `reports/balance.json` + human-readable `reports/balance.md`.
3. **Gate** against `gdd.json` difficulty: regular TTK in `ttk_band`, boss in `boss_ttk_band`, wipe rate in `wipe_rate_band`, timeout rate 0. Any `timeout: true` battle = interpreter or AI defect → route to m8-engine-smith, not a tuning problem.
4. **Patch loop** (≤3 rounds): violations → propose stat-block *data* edits (monster stats, ability numbers, gear prices — never schemas, never code), apply, re-run content gate, re-sim. Log every patch in `reports/balance.md` with before/after numbers. Unresolvable → blocked report to conductor with the owning content skill named.

## M2+ checks (activate with scale; keep the list visible now)
Dominated content (no item strictly worse than a cheaper same-tier item); trivializers (item that collapses its tier's TTK); niche floors (every spell/class above usage floor in optimal-policy sims); tier monotonicity; economy sanity (gold income along expected path vs. shop prices); class viability spread.

## Honesty rules
- The sim's party policy is `heuristic_v1` (engine contract §5) — competent, not optimal. Say so in every report; don't tune the game to a policy artifact (if a violation smells like policy stupidity, note it for the retrospective instead of buffing monsters).
- Never patch the GDD's bands to make a red report green — bands change only via the human or a G-NNN decision with rationale.
