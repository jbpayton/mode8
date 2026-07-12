#!/usr/bin/env python3
# Thin-batteries test: ECONOMY — this gate runs for every candidate of every
# animation-sheet asset (walk x4dir now; idle/attack/cast/hit/KO next), several
# times per asset through repair rounds. It is Tier-1: purely deterministic
# geometry/alpha/palette measurements, ZERO aesthetic judgment (that is the
# judge tier). Re-deriving these measurements ad hoc per asset would be waste
# and would drift; one pinned implementation keeps green == green.
"""Tier-1 deterministic gate for character animation sprite sheets.

Input: a sheet PNG laid out as R rows (directions) x C cols (frames) of a
fixed frame box, RGBA with hard alpha. Emits one JSON report line and exits
0 iff all checks are green.

Checks and thresholds (one-line justifications):
  feet_dev   <= 1 px      foot-row jitter >1px on a ~24px character reads as
                          bouncing/floating in a 4-frame loop.
  baseline   row in [baseline_row-1, baseline_row]
                          all directions must share the ground row, or the
                          sprite hops when turning in-engine.
  cx_drift   <= 2.5 px    stride + arm swing legitimately shifts the x-centroid
                          ~2px at this scale; more means mis-registration.
  cy_drift   <= 2.0 px    walk bob is 1-2px at 24px char height; more means a
                          scale or baseline error, not animation.
  height     each in [20, 28] px, per-direction spread <= 4 px
                          nominal char height is 24 (style bible); contact
                          crouch vs passing extension spans <=3px, +1 for hair.
  fill       in [0.08, 0.60] of the frame box
                          skinny profile passing frames of a 24px character
                          legitimately measure ~0.09; below 0.08 = broken/empty
                          frame; above 0.60 = blob or neighbour-frame bleed.
  semi_alpha == 0 px      hard-alpha contract for pixel sprites (engine blits
                          without blending surprises).
  component  >= 0.97 of opaque px in largest 8-connected component
                          floating specks are keying/shadow residue.
  edges      cols 0 and W-1, row 0 empty; rows > baseline_row empty
                          any ink on the frame border means the box clipped
                          the figure or residue leaked from the next frame.
  colors     <= max_colors unique opaque RGB per direction (row)
                          palette budget from the work order (<=64/direction).
"""
import json
import sys
import collections

import numpy as np
from PIL import Image


def largest_component_fraction(mask):
    if not mask.any():
        return 0.0
    lbl = np.zeros(mask.shape, np.int32)
    cur = 0
    for y, x in zip(*np.nonzero(mask)):
        if lbl[y, x]:
            continue
        cur += 1
        q = collections.deque([(y, x)])
        lbl[y, x] = cur
        while q:
            cy, cx = q.popleft()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = cy + dy, cx + dx
                    if (0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1]
                            and mask[ny, nx] and not lbl[ny, nx]):
                        lbl[ny, nx] = cur
                        q.append((ny, nx))
    sizes = np.bincount(lbl.ravel())
    sizes[0] = 0
    return float(sizes.max()) / float(mask.sum())


def gate(sheet_path, rows, cols, frame_w, frame_h, baseline_row, max_colors):
    img = Image.open(sheet_path).convert("RGBA")
    arr = np.asarray(img)
    exp_w, exp_h = frame_w * cols, frame_h * len(rows)
    report = {"asset": sheet_path,
              "params": {"rows": rows, "cols": cols, "frame_box": [frame_w, frame_h],
                         "baseline_row": baseline_row, "max_colors": max_colors},
              "sheet_dims_ok": (img.width, img.height) == (exp_w, exp_h),
              "directions": {}}
    all_green = report["sheet_dims_ok"]

    for r, dname in enumerate(rows):
        feet, tops, cxs, cys = [], [], [], []
        fills, semis, comps, edge_ok = [], [], [], []
        colors = set()
        for c in range(cols):
            f = arr[r * frame_h:(r + 1) * frame_h, c * frame_w:(c + 1) * frame_w]
            a = f[..., 3]
            m = a == 255
            semis.append(int(((a > 0) & (a < 255)).sum()))
            if not m.any():
                feet.append(-1); tops.append(-1); cxs.append(-1.0); cys.append(-1.0)
                fills.append(0.0); comps.append(0.0); edge_ok.append(False)
                continue
            ys, xs = np.nonzero(m)
            feet.append(int(ys.max()))
            tops.append(int(ys.min()))
            cxs.append(float(xs.mean()))
            cys.append(float(ys.mean()))
            fills.append(float(m.sum()) / (frame_w * frame_h))
            comps.append(largest_component_fraction(m))
            edge_ok.append(bool(not m[:, 0].any() and not m[:, -1].any()
                                and not m[0, :].any()
                                and not m[baseline_row + 1:, :].any()))
            for px in f[m][:, :3]:
                colors.add(tuple(int(v) for v in px))

        med_feet = float(np.median(feet))
        heights = [f - t + 1 for f, t in zip(feet, tops)]
        checks = {
            "feet_dev": {"value": max(abs(f - med_feet) for f in feet),
                         "limit": 1, "pass": max(abs(f - med_feet) for f in feet) <= 1},
            "baseline": {"value": med_feet, "limit": [baseline_row - 1, baseline_row],
                         "pass": baseline_row - 1 <= med_feet <= baseline_row},
            "cx_drift": {"value": round(max(abs(v - float(np.mean(cxs))) for v in cxs), 2),
                         "limit": 2.5,
                         "pass": max(abs(v - float(np.mean(cxs))) for v in cxs) <= 2.5},
            "cy_drift": {"value": round(max(abs(v - float(np.mean(cys))) for v in cys), 2),
                         "limit": 2.0,
                         "pass": max(abs(v - float(np.mean(cys))) for v in cys) <= 2.0},
            "height": {"value": heights, "limit": [20, 28, 4],
                       "pass": all(20 <= h <= 28 for h in heights)
                               and (max(heights) - min(heights)) <= 4},
            "fill": {"value": [round(v, 3) for v in fills], "limit": [0.08, 0.60],
                     "pass": all(0.08 <= v <= 0.60 for v in fills)},
            "semi_alpha": {"value": semis, "limit": 0, "pass": all(v == 0 for v in semis)},
            "component": {"value": [round(v, 4) for v in comps], "limit": 0.97,
                          "pass": all(v >= 0.97 for v in comps)},
            "edges": {"value": edge_ok, "limit": True, "pass": all(edge_ok)},
            "colors": {"value": len(colors), "limit": max_colors,
                       "pass": len(colors) <= max_colors},
        }
        green = all(c["pass"] for c in checks.values())
        report["directions"][dname] = {"checks": checks, "green": green}
        all_green = all_green and green

    report["all_green"] = all_green
    return report


def main(argv):
    sheet = argv[1]
    def opt(name, default):
        return argv[argv.index(name) + 1] if name in argv else default
    rows = opt("--rows", "down,left,right,up").split(",")
    cols = int(opt("--cols", 4))
    fw = int(opt("--frame-w", 24))
    fh = int(opt("--frame-h", 32))
    baseline_row = int(opt("--baseline-row", 29))
    max_colors = int(opt("--max-colors", 64))
    report = gate(sheet, rows, cols, fw, fh, baseline_row, max_colors)
    print(json.dumps(report))
    return 0 if report["all_green"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
