#!/usr/bin/env python3
"""Deterministic post-chain for Emberwake 64x64 item/equipment icons (icon v1).

Successor to the ephemeral warm_draught smoke-test chain (corner-flood tol 90
-> bbox crop -> 64 nearest -> quantize 32). Same shape of result — transparent
64x64, single component, <=64 colors, crop-to-content — but the fixed corner
tol is replaced by the ADAPTIVE border-flood key proven on the tile-entity and
monster-battle chains: measure the flat pixel-art-xl background from the border
ring, flood from the border, and let the subject's bold black outline stop the
flood. This survives dark subjects on a plain background (a fixed tol 90 would
eat dark armor / the ember key), which the icon set needs.

Gate class item_icon: size (64,64), fill in [0.15,0.85], <=64 colors,
require_alpha True (transparent region, single major component, <=3 specks).

Steps (same skeleton as tile_post_chain --mode entity, scaled to 64):
 1. adaptive border-flood key (ring median, tol=clamp(p99(ring dist)+12,28,70)).
 2. keep largest 4-conn component (drops keyed-through specks).
 3. bbox crop -> scale to fit (SIZE - 2*MARGIN) box, NEAREST (pixel look).
 4. paste x/y-centred on a transparent SIZE canvas.
 5. binary alpha (>=128), keep largest component again.
 6. mediancut quantize <= QUANT foreground colors.

A thin vertical subject (sword, staff) fills far below the item_icon 0.15
floor when scaled upright. --rotate DEG rotates the keyed subject before the
fit (icon convention: blades/staves sit diagonally so they fill the square).
Rotation happens at source resolution with a hard alpha re-threshold, so the
pixel look survives the later NEAREST downscale.

Usage: icon_post_chain.py in.png out.png [--size 64] [--margin 3] [--quant 32]
                          [--rotate 45]
"""
import sys
import numpy as np
from PIL import Image
from collections import deque

RING = 12


def arg(argv, name, default, cast):
    return cast(argv[argv.index(name) + 1]) if name in argv else default


def largest_component(alpha):
    a = alpha > 0
    h, w = a.shape
    seen = np.zeros_like(a)
    best, bestset = 0, None
    for y in range(h):
        for x in range(w):
            if a[y, x] and not seen[y, x]:
                comp = [(y, x)]
                seen[y, x] = True
                dq = deque(comp)
                while dq:
                    cy, cx = dq.popleft()
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and a[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            comp.append((ny, nx))
                            dq.append((ny, nx))
                if len(comp) > best:
                    best, bestset = len(comp), comp
    keep = np.zeros_like(a)
    if bestset:
        for y, x in bestset:
            keep[y, x] = True
    return keep


def border_key(arr):
    h, w, _ = arr.shape
    rgb = arr[:, :, :3].astype(np.float64)
    ring = np.zeros((h, w), bool)
    ring[:RING, :] = ring[-RING:, :] = True
    ring[:, :RING] = ring[:, -RING:] = True
    px = rgb[ring]
    med = np.median(px, axis=0)
    d = np.sqrt(((px - med) ** 2).sum(axis=1))
    tol = float(np.clip(np.percentile(d, 99) + 12, 28, 70))
    dist = np.sqrt(((rgb - med) ** 2).sum(axis=-1))
    bglike = dist <= tol
    bg = np.zeros((h, w), bool)
    dq = deque()
    for y in range(h):
        for x in (0, w - 1):
            if bglike[y, x] and not bg[y, x]:
                bg[y, x] = True; dq.append((y, x))
    for x in range(w):
        for y in (0, h - 1):
            if bglike[y, x] and not bg[y, x]:
                bg[y, x] = True; dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and bglike[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True; dq.append((ny, nx))
    return bg, tol


def main(argv):
    src, dst = argv[1], argv[2]
    size = arg(argv, "--size", 64, int)
    margin = arg(argv, "--margin", 3, int)
    quant = arg(argv, "--quant", 32, int)
    rotate = arg(argv, "--rotate", 0.0, float)
    arr = np.array(Image.open(src).convert("RGBA"))
    bg, tol = border_key(arr)
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    keep = largest_component(alpha)
    alpha = np.where(keep, 255, 0).astype(np.uint8)
    ys, xs = np.where(alpha > 0)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    crop = np.dstack([arr[:, :, :3], alpha])[y0:y1, x0:x1]
    if rotate:
        rot = Image.fromarray(crop, "RGBA").rotate(
            rotate, resample=Image.BICUBIC, expand=True)
        r = np.array(rot)
        r[:, :, 3] = np.where(r[:, :, 3] >= 128, 255, 0)   # hard alpha back
        rys, rxs = np.where(r[:, :, 3] > 0)
        crop = r[rys.min():rys.max() + 1, rxs.min():rxs.max() + 1]
    ch, cw = crop.shape[:2]
    fit = size - 2 * margin
    scale = min(fit / ch, fit / cw)
    nh, nw = max(1, round(ch * scale)), max(1, round(cw * scale))
    small = np.array(Image.fromarray(crop, "RGBA").resize((nw, nh), Image.NEAREST))
    small[:, :, 3] = np.where(small[:, :, 3] >= 128, 255, 0)
    out = np.zeros((size, size, 4), np.uint8)
    oy, ox = (size - nh) // 2, (size - nw) // 2
    out[oy:oy + nh, ox:ox + nw] = small
    keep2 = largest_component(out[:, :, 3])
    out[:, :, 3] = np.where(keep2, out[:, :, 3], 0)
    a = out[:, :, 3] > 0
    fg = out[a][:, :3]
    if len(fg):
        strip = Image.fromarray(fg.reshape(1, -1, 3), "RGB").quantize(
            colors=quant, method=Image.MEDIANCUT).convert("RGB")
        out[a] = np.concatenate(
            [np.array(strip).reshape(-1, 3), np.full((len(fg), 1), 255, np.uint8)], axis=1)
    Image.fromarray(out).save(dst)
    fill = float(a.sum()) / (size * size)
    ncol = len({tuple(c) for c in out[a][:, :3]})
    print(f"{dst}: {size}x{size}, bgtol {tol:.0f}, subj {nw}x{nh}, fill {fill:.3f}, colors {ncol}")


if __name__ == "__main__":
    main(sys.argv)
