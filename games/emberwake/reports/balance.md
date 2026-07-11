# Balance report — Emberwake

Party policy: heuristic_v1 (competent, not optimal). Seed 20260711.

## cp.floor1_L2 — GREEN
- n=1000, win 100.0%, wipe 0.0%, TTK mean 2.44 (p95 4), hp end 0.868
- ✓ ttk in [2, 5]
- ✓ wipe_rate in [0.0, 0.15]
- ✓ no timeouts

## cp.floor2_L3 — GREEN
- n=1000, win 99.9%, wipe 0.1%, TTK mean 4.08 (p95 6), hp end 0.834
- ✓ ttk in [2, 5]
- ✓ wipe_rate in [0.0, 0.15]
- ✓ no timeouts

## cp.floor3_L4 — GREEN
- n=1000, win 100.0%, wipe 0.0%, TTK mean 2.71 (p95 4), hp end 0.906
- ✓ ttk in [2, 5]
- ✓ wipe_rate in [0.0, 0.15]
- ✓ no timeouts

## cp.boss_L4 — GREEN
- n=300, win 91.0%, wipe 9.0%, TTK mean 10.84 (p95 15), hp end 0.434
- ✓ ttk in [6, 16]
- ✓ wipe_rate in [0.0, 0.15]
- ✓ no timeouts

## Patch log (m8-balancer round 1)
- **Violation:** cp.boss_L4 wipe_rate 0.230 > band max 0.15 (ttk 10.79 in band; spike lethality, not attrition).
- **Diagnosis:** phase-2 `eruption` (AoE, mag*3 ≈ 26/target post-mitigation) at ai weight 2/7, stacking with burn ticks + claw — kills the ashcaller (64 hp) from above heuristic_v1's 35% heal threshold in consecutive turns.
- **Patch (data only):** eruption value `source.mag * 3` → `source.mag * 2 + 4`; ai weight 2 → 1. monsters.json.
- **After re-sim (same seed):** wipe 0.090 ∈ [0, 0.15]; ttk 10.84 ∈ [6, 16]; other checkpoints unchanged. GREEN.
