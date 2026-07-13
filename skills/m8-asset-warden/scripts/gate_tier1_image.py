#!/usr/bin/env python3
# Thin-batteries test: DETERMINISM — Tier-1 image gates must verdict
# bit-identically across sessions (SPEC §6 tier 1). Promoted from the
# ephemeral gate math validated in the M1 icon smoke test (2026-07-12).
# Requires PIL + numpy in the calling environment.
# v2 (2026-07-12, tileset job): tileset class gains size (16,16) — every
#   Emberwake map declares 16x16 tiles, so a fixed size check is a real gate
#   (a mis-sized tile is a defect); override with --size if a future tileset
#   uses another grid.
"""Usage: gate_tier1_image.py <image.png> --class <asset_class> [--size WxH] [--report <path>]

Classes and their thresholds live in THRESHOLDS below; add classes as the
atelier grows (each addition is a skill edit, evidenced by a build).
Exit 0 = all gates green. Report JSON always written when --report given.
"""
import json, sys, pathlib
import numpy as np
from PIL import Image
from collections import deque

THRESHOLDS = {
    "item_icon":  {"size": (64, 64),  "fill": (0.15, 0.85), "max_colors": 64,
                   "max_specks": 3, "require_alpha": True},
    "sprite":     {"size": None,      "fill": (0.10, 0.90), "max_colors": 96,
                   "max_specks": 3, "require_alpha": True},
    "portrait":   {"size": (96, 96),  "fill": (0.30, 1.00), "max_colors": 256,
                   "max_specks": 8, "require_alpha": False},
    "tileset":    {"size": (16, 16),  "fill": (0.90, 1.00), "max_colors": 256,
                   "max_specks": 10**9, "require_alpha": False},
    "battle_background": {"size": None, "fill": (0.95, 1.00), "max_colors": 10**9,
                   "max_specks": 10**9, "require_alpha": False},
}

def components(fg):
    h, w = fg.shape
    sizes, seen = [], np.zeros_like(fg)
    for y in range(h):
        for x in range(w):
            if fg[y, x] and not seen[y, x]:
                n, dq = 0, deque([(y, x)])
                seen[y, x] = True
                while dq:
                    cy, cx = dq.popleft(); n += 1
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True; dq.append((ny, nx))
                sizes.append(n)
    return sizes

def run(path, klass, size_override=None):
    t = THRESHOLDS[klass]
    img = Image.open(path).convert("RGBA")
    arr = np.array(img)
    fg = arr[:, :, 3] > 0
    expected = size_override or t["size"]
    sizes = components(fg)
    major = [s for s in sizes if s > 4]
    colors = len({tuple(c) for c in arr[fg][:, :3]}) if fg.any() else 0
    fill = float(fg.sum()) / fg.size
    gates = {}
    if expected: gates[f"size {expected[0]}x{expected[1]}"] = img.size == tuple(expected)
    if t["require_alpha"]:
        gates["has transparent region"] = bool((arr[:, :, 3] == 0).any())
        gates["single major component"] = len(major) == 1
        gates[f"specks <= {t['max_specks']}"] = len(sizes) - len(major) <= t["max_specks"]
    lo, hi = t["fill"]
    gates[f"fill in [{lo}, {hi}]"] = lo <= fill <= hi
    if t["max_colors"] < 10**9:
        gates[f"palette <= {t['max_colors']}"] = colors <= t["max_colors"]
    return {"gate": "tier1_image", "file": str(path), "class": klass,
            "gates": {k: bool(v) for k, v in gates.items()},
            "measured": {"size": list(img.size), "fill": round(fill, 3),
                         "fg_colors": colors, "components": len(sizes)},
            "status": "green" if all(gates.values()) else "red"}

if __name__ == "__main__":
    argv = sys.argv
    klass = argv[argv.index("--class") + 1]
    size = tuple(int(x) for x in argv[argv.index("--size") + 1].split("x")) if "--size" in argv else None
    result = run(argv[1], klass, size)
    if "--report" in argv:
        rp = pathlib.Path(argv[argv.index("--report") + 1])
        rp.parent.mkdir(parents=True, exist_ok=True)
        rp.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=1))
    sys.exit(0 if result["status"] == "green" else 1)
