#!/usr/bin/env python3
"""Deterministic portrait bust extractor for Emberwake (portrait v1).

Source: the canonical clothed VNCCS front-view sprite (transparent bg,
2656x6336). A portrait is the head-and-shoulders bust, 96x96, shown in
dialogue/status. Gate class `portrait`: size (96,96), fill in [0.30,1.00],
<=256 colors, require_alpha False -> an opaque bust on a simple dark
background is green by construction (fill 1.0), and matches the classic
JRPG dialogue-window portrait look.

Steps:
 1. solid = alpha > THR; label 4-conn components (scipy); keep the largest
    (drops the ground-shadow specks / stray keyed pixels VNCCS leaves).
 2. figure bbox from that component; head_top = bbox top, head x-centre =
    centroid of the top HEADBAND fraction of the figure (the hair/skull),
    so the crop is centred on the face, not on outstretched arms.
 3. square bust window: side = BUST * figure_height, top = head_top -
    MARGIN*side, centred on head x; clamp into the canvas.
 4. composite the cropped bust over a simple dark vertical gradient
    (cool soot-blue at top -> faintly ember-warm near-black at the bottom,
    echoing the style-bible 'cool shadow blues' + 'ember on soot black').
 5. LANCZOS downscale to 96x96; mediancut quantize <= COLORS (default 256).

Usage:
  portrait_crop.py src.png out.png [--bust 0.36] [--margin 0.06]
                   [--headband 0.14] [--colors 256] [--thr 160]
                   [--preview out_4x.png]
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

THR = 160


def arg(argv, name, default, cast):
    return cast(argv[argv.index(name) + 1]) if name in argv else default


def dark_gradient(side):
    """side x side RGB: cool dark top -> warm-tinted near-black bottom."""
    top = np.array([26, 24, 34], np.float64)     # cool soot blue
    bot = np.array([30, 20, 18], np.float64)     # faint ember warmth
    t = np.linspace(0, 1, side)[:, None]
    col = top[None, :] * (1 - t) + bot[None, :] * t   # (side,3)
    return np.repeat(col[:, None, :], side, axis=1).astype(np.uint8)


def main(argv):
    src, dst = argv[1], argv[2]
    bust = arg(argv, "--bust", 0.36, float)
    margin = arg(argv, "--margin", 0.06, float)
    headband = arg(argv, "--headband", 0.14, float)
    colors = arg(argv, "--colors", 256, int)
    thr = arg(argv, "--thr", THR, int)

    im = Image.open(src).convert("RGBA")
    arr = np.array(im)
    solid = arr[:, :, 3] > thr
    lbl, n = ndimage.label(solid)
    if n == 0:
        raise SystemExit("no solid pixels")
    sizes = ndimage.sum(np.ones_like(lbl), lbl, index=range(1, n + 1))
    keep = int(np.argmax(sizes)) + 1
    comp = lbl == keep
    ys, xs = np.where(comp)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    fh = y1 - y0
    # head x-centre from the top headband of the figure
    band = comp[y0:y0 + int(headband * fh)]
    bxs = np.where(band.any(axis=0))[0]
    hxc = int((bxs.min() + bxs.max()) / 2) if len(bxs) else (x0 + x1) // 2

    side = int(round(bust * fh))
    top = int(round(y0 - margin * side))
    left = int(round(hxc - side / 2))
    H, W = arr.shape[:2]
    top = max(0, min(top, H - side))
    left = max(0, min(left, W - side))
    crop = im.crop((left, top, left + side, top + side))

    bg = Image.fromarray(dark_gradient(side), "RGB").convert("RGBA")
    comp_im = Image.alpha_composite(bg, crop).convert("RGB")
    small = comp_im.resize((96, 96), Image.LANCZOS)
    q = small.quantize(colors=colors, method=Image.MEDIANCUT).convert("RGB")
    out = np.dstack([np.array(q), np.full((96, 96), 255, np.uint8)])
    Image.fromarray(out, "RGBA").save(dst)

    ncol = len({tuple(c) for c in np.array(q).reshape(-1, 3)})
    print(f"{dst}: 96x96 opaque, side {side}px @ ({left},{top}), colors {ncol}")
    if "--preview" in argv:
        pv = argv[argv.index("--preview") + 1]
        Image.fromarray(out).resize((384, 384), Image.NEAREST).save(pv)


if __name__ == "__main__":
    main(sys.argv)
