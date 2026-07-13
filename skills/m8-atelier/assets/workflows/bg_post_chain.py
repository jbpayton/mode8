#!/usr/bin/env python3
"""Deterministic post-chain for Emberwake battle backgrounds (bg v1).

A battle_background is opaque, full-bleed, sized to the game internal
resolution (style-bible: 640x360, nearest upscale). No alpha, no keying,
no single-component constraint (gate class battle_background: fill>=0.95,
size unconstrained, unlimited colors).

Steps:
 1. center-crop the 1344x768 gen to an exact 16:9 window (1344x756) so the
    downscale preserves aspect with no letterbox.
 2. LANCZOS downscale to 640x360.
 3. optional mediancut quantize (--quant N; default 0 = off). Backgrounds
    gate on unlimited colors, but a light pass (e.g. 192) harmonizes the
    backdrop with the pixel palette and kills gradient banding at 640x360.
 4. flatten to opaque RGBA (alpha forced 255) so fill == 1.0.

Usage: bg_post_chain.py in.png out.png [--quant 192]
"""
import sys
import numpy as np
from PIL import Image

TARGET = (640, 360)


def arg(argv, name, default, cast):
    return cast(argv[argv.index(name) + 1]) if name in argv else default


def main(argv):
    src, dst = argv[1], argv[2]
    quant = arg(argv, "--quant", 0, int)
    im = Image.open(src).convert("RGB")
    w, h = im.size
    # center-crop to exact 16:9
    target_ar = TARGET[0] / TARGET[1]
    if w / h > target_ar:            # too wide -> crop width
        nw = int(round(h * target_ar)); nh = h
    else:                            # too tall -> crop height
        nw = w; nh = int(round(w / target_ar))
    x0 = (w - nw) // 2
    y0 = (h - nh) // 2
    im = im.crop((x0, y0, x0 + nw, y0 + nh))
    im = im.resize(TARGET, Image.LANCZOS)
    if quant > 0:
        im = im.quantize(colors=quant, method=Image.MEDIANCUT).convert("RGB")
    arr = np.array(im)
    out = np.dstack([arr, np.full(TARGET[::-1], 255, np.uint8)])
    Image.fromarray(out, "RGBA").save(dst)
    ncol = len({tuple(c) for c in arr.reshape(-1, 3)})
    print(f"{dst}: size {TARGET[0]}x{TARGET[1]}, opaque, colors {ncol}, quant {quant or 'off'}")


if __name__ == "__main__":
    main(sys.argv)
