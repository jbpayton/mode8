#!/usr/bin/env python3
"""Deterministic post-chain for Emberwake 16x16 tiles (tileset v1).

Three modes:

  --mode terrain   opaque, full-bleed, MUST tile seamlessly (town_floor,
                   town_wall, cave_floor, cave_wall).
     1. crop center CROP px patch P from the gen (default 512 of 1024) — skips
        the gen-edge vignette the LoRA sometimes paints.
     2. seamless_blend(P): T = roll(P, H/2, W/2) has seamless OUTER edges (they
        were P's continuous interior); its only discontinuity is the cross at
        center. result = T*w + P*(1-w), w = max(ramp_x, ramp_y) (1 at the four
        edges, 0 at center). Outer ring is pure T -> provably tileable; center
        uses P -> smooth, no cross artifact. Deterministic.
     3. area-downsample CROP -> 16 (box filter, good color averaging).
     4. mediancut quantize <= QUANT colors, alpha forced opaque (255).

  --mode object    opaque, full-bleed, single centered feature (town_well).
     center-crop CROP, area-downsample to 16, quantize, opaque. (No seamless
     blend — a well is a placed object, not a repeated field; it only ever sits
     next to one more well.)

  --mode entity    16x16 transparent, single component (chest, portal, npc).
     border-flood alpha key (adaptive tol from border ring, LoRA bgs are flat)
     -> keep largest component -> bbox crop -> scale to fit (16 - 2*margin)
     -> paste centered on transparent 16x16 -> hard alpha -> quantize.

Usage:
  tile_post_chain.py in.png out.png --mode terrain [--crop 512] [--quant 32]
  tile_post_chain.py in.png out.png --mode object  [--crop 640] [--quant 32]
  tile_post_chain.py in.png out.png --mode entity  [--margin 1] [--quant 32]
"""
import sys
import numpy as np
from PIL import Image
from collections import deque

QUANT = 32
RING = 8


def arg(argv, name, default, cast):
    return cast(argv[argv.index(name) + 1]) if name in argv else default


def center_crop(arr, c):
    h, w = arr.shape[:2]
    y0 = (h - c) // 2
    x0 = (w - c) // 2
    return arr[y0:y0 + c, x0:x0 + c]


def seamless_blend(rgb):
    """Make an RGB patch perfectly tileable via quadrant-offset blend."""
    h, w, _ = rgb.shape
    P = rgb.astype(np.float64)
    T = np.roll(np.roll(P, h // 2, axis=0), w // 2, axis=1)
    yy = np.abs(np.arange(h) - (h - 1) / 2.0) / ((h - 1) / 2.0)   # 0 center -> 1 edge
    xx = np.abs(np.arange(w) - (w - 1) / 2.0) / ((w - 1) / 2.0)
    ry, rx = np.meshgrid(yy, xx, indexing="ij")
    # smoothstep for a soft transition
    def ss(t):
        t = np.clip(t, 0, 1)
        return t * t * (3 - 2 * t)
    w2 = np.maximum(ss(ry), ss(rx))[:, :, None]
    out = T * w2 + P * (1 - w2)
    return np.clip(out, 0, 255).astype(np.uint8)


def quantize_rgb(rgb, ncolors):
    im = Image.fromarray(rgb, "RGB")
    q = im.quantize(colors=ncolors, method=Image.MEDIANCUT).convert("RGB")
    return np.array(q)


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
    """Adaptive border-ring flood key. Returns bool bg mask."""
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


def do_terrain(arr, crop, quant):
    rgb = center_crop(arr[:, :, :3], crop)
    rgb = seamless_blend(rgb)
    small = np.array(Image.fromarray(rgb, "RGB").resize((16, 16), Image.BOX))
    small = quantize_rgb(small, quant)
    out = np.dstack([small, np.full((16, 16), 255, np.uint8)])
    return out


def do_object(arr, crop, quant):
    rgb = center_crop(arr[:, :, :3], crop)
    small = np.array(Image.fromarray(rgb, "RGB").resize((16, 16), Image.BOX))
    small = quantize_rgb(small, quant)
    out = np.dstack([small, np.full((16, 16), 255, np.uint8)])
    return out


def do_entity(arr, margin, quant):
    bg, tol = border_key(arr)
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    keep = largest_component(alpha)
    alpha = np.where(keep, 255, 0).astype(np.uint8)
    ys, xs = np.where(alpha > 0)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    crop = np.dstack([arr[:, :, :3], alpha])[y0:y1, x0:x1]
    ch, cw = crop.shape[:2]
    fit = 16 - 2 * margin
    scale = min(fit / ch, fit / cw)
    nh, nw = max(1, round(ch * scale)), max(1, round(cw * scale))
    small = np.array(Image.fromarray(crop, "RGBA").resize((nw, nh), Image.BOX))
    small[:, :, 3] = np.where(small[:, :, 3] >= 128, 255, 0)
    out = np.zeros((16, 16, 4), np.uint8)
    oy = (16 - nh) // 2
    ox = (16 - nw) // 2
    out[oy:oy + nh, ox:ox + nw] = small
    # largest component again after downscale, then quantize fg
    keep2 = largest_component(out[:, :, 3])
    out[:, :, 3] = np.where(keep2, out[:, :, 3], 0)
    a = out[:, :, 3] > 0
    fg = out[a][:, :3]
    if len(fg):
        strip = Image.fromarray(fg.reshape(1, -1, 3), "RGB").quantize(
            colors=quant, method=Image.MEDIANCUT).convert("RGB")
        out[a] = np.concatenate(
            [np.array(strip).reshape(-1, 3), np.full((len(fg), 1), 255, np.uint8)], axis=1)
    return out, tol


def main(argv):
    src, dst = argv[1], argv[2]
    mode = arg(argv, "--mode", "terrain", str)
    quant = arg(argv, "--quant", QUANT, int)
    arr = np.array(Image.open(src).convert("RGBA"))
    if mode == "terrain":
        crop = arg(argv, "--crop", 512, int)
        out = do_terrain(arr, crop, quant)
        note = f"terrain seamless crop{crop}"
    elif mode == "object":
        crop = arg(argv, "--crop", 640, int)
        out = do_object(arr, crop, quant)
        note = f"object crop{crop}"
    elif mode == "entity":
        margin = arg(argv, "--margin", 1, int)
        out, tol = do_entity(arr, margin, quant)
        note = f"entity margin{margin} bgtol{tol:.0f}"
    else:
        raise SystemExit(f"unknown mode {mode}")
    Image.fromarray(out).save(dst)
    fill = float((out[:, :, 3] > 0).sum()) / (16 * 16)
    ncol = len({tuple(c) for c in out[out[:, :, 3] > 0][:, :3]})
    print(f"{dst}: {note}, fill {fill:.3f}, colors {ncol}")


if __name__ == "__main__":
    main(sys.argv)
