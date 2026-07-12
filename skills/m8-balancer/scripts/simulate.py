#!/usr/bin/env python3
# Thin-batteries tests: ECONOMY (thousands of battles per build) and
# DETERMINISM (seeded; identical checkpoints+content ⇒ identical report).
# This script only orchestrates and aggregates — the battles run inside the
# game's own GDScript engine (sim/sim_battle.gd, engine contract §5; D-008),
# so there is exactly one interpreter to trust.
"""Usage: simulate.py <game_dir> [--checkpoints <path>] [--godot <bin>]  (exit 0 = all bands green)"""
import json, random, statistics, subprocess, sys, pathlib, tempfile

REPO = pathlib.Path(__file__).resolve().parents[3]

def load(p):
    with open(p) as f: return json.load(f)

def godot_bin(cli):
    if "--godot" in cli: return cli[cli.index("--godot") + 1]
    cfg = load(REPO / "config.json")
    return str(REPO / cfg["appliances"]["godot"]["bin"])

def sample_group(enc, rng):
    groups = enc["groups"]
    total = sum(g["weight"] for g in groups)
    x, acc = rng.uniform(0, total), 0.0
    for g in groups:
        acc += g["weight"]
        if x <= acc: return g["monsters"]
    return groups[-1]["monsters"]

def build_specs(cp, encounters, rng):
    battles = []
    for _ in range(cp["n_battles"]):
        if "monsters" in cp:                      # fixed group (bosses)
            group = cp["monsters"]
        else:
            group = sample_group(encounters[cp["encounter_table"]], rng)
        battles.append({"party": cp["party"], "monsters": group,
                        "max_rounds": cp.get("max_rounds", 50)})
    return battles

def run_batch(godot, src_dir, spec, tag):
    with tempfile.NamedTemporaryFile("w", suffix=f"_{tag}.json", delete=False) as f:
        json.dump(spec, f); spec_path = f.name
    out_path = spec_path.replace(".json", "_out.jsonl")
    cmd = [godot, "--headless", "--path", str(src_dir),
           "--script", "res://sim/sim_battle.gd", "--", spec_path, out_path]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
    if r.returncode != 0:
        raise RuntimeError(f"sim batch '{tag}' failed (exit {r.returncode}):\n{r.stderr[-2000:]}")
    return [json.loads(line) for line in open(out_path) if line.strip()]

def analyze(cp, results, diff):
    wins = [r for r in results if r["win"]]
    rounds = [r["rounds"] for r in wins]
    n = len(results)
    stats = {
        "checkpoint": cp["id"], "boss": cp.get("boss", False), "n": n,
        "win_rate": len(wins) / n,
        "wipe_rate": sum(r["wipe"] for r in results) / n,
        "timeout_rate": sum(r.get("timeout", False) for r in results) / n,
        "ttk_mean": round(statistics.mean(rounds), 2) if rounds else None,
        "ttk_p95": sorted(rounds)[int(0.95 * len(rounds))] if rounds else None,
        "hp_end_mean": round(statistics.mean(r["party_hp_end_pct"] for r in wins), 3) if wins else None,
        "ability_usage": {},
    }
    for r in results:
        for k, v in r.get("ability_usage", {}).items():
            stats["ability_usage"][k] = stats["ability_usage"].get(k, 0) + v
    band = diff["boss_ttk_band"] if cp.get("boss") else diff["ttk_band"]
    lo_w, hi_w = diff["wipe_rate_band"]
    checks = {
        f"ttk in {band}": stats["ttk_mean"] is not None and band[0] <= stats["ttk_mean"] <= band[1],
        f"wipe_rate in [{lo_w}, {hi_w}]": lo_w <= stats["wipe_rate"] <= hi_w,
        "no timeouts": stats["timeout_rate"] == 0,
    }
    stats["checks"] = checks
    stats["verdict"] = "green" if all(checks.values()) else "red"
    return stats

def main(argv):
    game_dir = pathlib.Path(argv[1])
    cp_path = pathlib.Path(argv[argv.index("--checkpoints") + 1]) if "--checkpoints" in argv \
        else game_dir / "reports" / "balance-checkpoints.json"
    cps = load(cp_path)
    gdd = load(game_dir / "gdd" / "gdd.json")
    encounters = {e["id"]: e for e in load(game_dir / "content/encounters.json")["entries"]}
    godot = godot_bin(argv)
    rng = random.Random(cps["seed"])
    out = []
    for cp in cps["checkpoints"]:
        spec = {"seed": rng.randrange(2**31), "battles": build_specs(cp, encounters, rng)}
        results = run_batch(godot, game_dir / "src", spec, cp["id"])
        stats = analyze(cp, results, gdd["difficulty"])
        out.append(stats)
        print(f"  {cp['id']}: {stats['verdict'].upper()} ttk={stats['ttk_mean']} "
              f"wipe={stats['wipe_rate']:.3f} win={stats['win_rate']:.3f} n={stats['n']}")
    report = {"gate": "balance", "policy": "heuristic_v1 (competent, not optimal)",
              "seed": cps["seed"], "checkpoints": out,
              "status": "green" if all(c["verdict"] == "green" for c in out) else "red"}
    rp = game_dir / "reports" / "balance.json"
    rp.parent.mkdir(parents=True, exist_ok=True)
    rp.write_text(json.dumps(report, indent=2) + "\n")
    md = [f"# Balance report — {gdd['title']}", "",
          f"Party policy: heuristic_v1 (competent, not optimal). Seed {cps['seed']}.", ""]
    for c in out:
        md.append(f"## {c['checkpoint']} — {c['verdict'].upper()}")
        md.append(f"- n={c['n']}, win {c['win_rate']:.1%}, wipe {c['wipe_rate']:.1%}, "
                  f"TTK mean {c['ttk_mean']} (p95 {c['ttk_p95']}), hp end {c['hp_end_mean']}")
        for k, ok in c["checks"].items(): md.append(f"- {'✓' if ok else '✗'} {k}")
        md.append("")
    md_path = game_dir / "reports" / "balance.md"
    if md_path.exists() and "## Patch log" in md_path.read_text():
        # preserve the balancer's hand-appended patch-log audit trail (retro: emberwake/M0 gap 2)
        md.append("## Patch log" + md_path.read_text().split("## Patch log", 1)[1].rstrip())
        md.append("")
    md_path.write_text("\n".join(md) + "\n")
    print(f"balance gate: {report['status'].upper()} -> {rp}")
    return 0 if report["status"] == "green" else 1

if __name__ == "__main__":
    sys.exit(main(sys.argv))
