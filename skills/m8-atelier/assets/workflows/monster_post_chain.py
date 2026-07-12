#!/usr/bin/env python3
"""Deterministic post-chain for battle sprites (battle v3).

History:
 v1 corner-flood tol 90 (icon precedent): tol 90 > dist(light-grey bg, pale
    ice coat) ~73 -> flood ate the whelp's head. Fixed tol is wrong when the
    subject palette can approach the bg color.
 v2 green-screen chroma key (walk-cycle blessed path): pixel-art-xl IGNORES
    'green screen background' -- it paints flat grey/blue-grey studio bgs.
    Key found no green; bgs survived whole.
 v3 adaptive border-flood: the LoRA's bgs are FLAT, so measure them. tol from
    border-ring noise (p99 dist to median + 12, clamped [28,60]) stays far
    below subject-vs-bg distances while the dark pixel outlines block leaks.

Steps:
 1. bg_med = median RGB of the 8px border ring; tol = clamp(p99(ring dists)+12, 28, 60).
 2. flood from all border px: kill 4-connected px with dist(px, bg_med) <= tol.
 3. guided fringe erosion, <=4 iters: kill px adjacent to transparency if
    dist(px,bg_med) < 1.8*tol or (s<0.20 & v>0.72) (anti-alias/white halo);
    dark outlines match neither rule and stop the erosion.
 3b. pocket kill: 4-conn components of exact-bg px (dist<=tol), size>=250,
    die when >=72% of their boundary is dark ink (max(RGB)<70) OR
    transparency, AND ordinary-opaque boundary <=28% -- enclosed bg pockets
    between limbs are bounded by pixel-art outlines and/or already-keyed bg;
    subject-color patches that merely match the bg are embedded in ordinary
    body colors. (A plain global bg-kill perforated near-white ice highlights
    when the bg itself rendered near-white, whelp seed 20260712; a dark-only
    >=30% judge missed white pockets whose boundary is half transparency,
    slag_crawler 20260712/14.)
 4. shadow-component pass (global): pixel-art-xl OUTLINES real subject matter
    in dark ink but paints ground shadows soft, desaturated, un-outlined.
    shadowish = s<0.32 & 0.45<v<0.88; 4-conn components >=150 px killed when
    >=40% of boundary is transparent (shadows border the keyed bg directly).
 5. band shadow scrub (v2.1 rethought for statics): the walk-cycle cone
    protection CASCADES through a wide contiguous shadow skirt touching the
    body everywhere and protects nearly all of it (measured: whelp-13 skirt
    70% suspect yet survived). Static sprites need no feet registration, so
    drop the cone; use the outline principle instead. In the band below
    bbox_top+0.70*bbox_h: suspect = ((s<0.38 & 0.20<v<0.86) |
    (dist<2.6*tol & v<0.82)) & NOT dark(max<56) -- dark outline px are never
    suspect so they partition suspect components. 4-conn suspect comps
    >=200 px die when >=22% of their boundary px are transparent. Outlined
    forms (paws, legs) have near-zero transparent boundary; shadows lie
    along the keyed bg.
 5b. optional masked repairs (repeatable, 1024-res coords, recorded in the
    manifest) for pockets/shadows that are pixel-level ambiguous with subject
    colors elsewhere on the canvas:
    --kill-rect-bg y0:y1:x0:x1[:mult] -> inside rect kill px with
       dist<=mult*tol (default 1.5; bg-colored only; safe when subject is
       chromatically far from bg -- raise mult for shadow-tinted bg patches).
    --kill-rect y0:y1:x0:x1[:vfloor] -> inside rect kill px matching
       (dist<2.2*tol | (s<0.38 & vfloor<v<0.86 & max(RGB)>=56)), default
       vfloor 0.20; raise vfloor to protect dark feet/legs under a light
       shadow. Dark outlines and saturated creature colors always survive.
    --shadow-flood SEEDROW -> seed from opaque shadow-like px (max(RGB)>=56 &
       s<0.38 & v>0.40, or dist<=1.5*tol) in rows>=SEEDROW, 4-conn flood
       through shadow-like px at any row, kill all reached. For ground-shadow
       masses visible through leg gaps far above the ground line; the dark
       pixel-art outlines on limbs stop the flood (same outline principle).
    --kill-comp-rect y0:y1:x0:x1[:vfloor[:btfrac]] -> comp_kill voting scoped
       to a rect: 4-conn comps of (s<0.38 & vfloor<v<0.85 & max(RGB)>=56) px
       inside the rect, size>=300, die when boundary-transparency fraction
       >=btfrac (default vfloor 0.40, btfrac 0.15). Separates shadow pockets
       (border keyed bg) from same-colored rock facets (enclosed in ink).
 6. keep largest 4-connected component (gate: single major component).
 7. bbox crop [optional --mirror]; scale = min(subj/bbox_h, (canvas-6)/bbox_w), nearest.
 8. paste onto transparent canvas, x-centered, bottom margin --bottom.
 9. mediancut quantize <=64 colors (fg only), binary alpha.
Usage: post_battle_sprite.py in.png out.png --canvas 128 --subj 104 [--bottom 9] [--mirror]
"""
import sys
import numpy as np
from PIL import Image
from collections import deque

BAND_FRAC = 0.70
QUANT = 64
RING = 8


def hsv_sv(rgb):
    mx = rgb.max(axis=-1).astype(np.float64)
    mn = rgb.min(axis=-1).astype(np.float64)
    v = mx / 255.0
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0.0)
    return s, v


def bg_stats(arr):
    h, w, _ = arr.shape
    ring = np.zeros((h, w), bool)
    ring[:RING, :] = ring[-RING:, :] = True
    ring[:, :RING] = ring[:, -RING:] = True
    px = arr[ring][:, :3].astype(np.float64)
    med = np.median(px, axis=0)
    d = np.sqrt(((px - med) ** 2).sum(axis=1))
    tol = float(np.clip(np.percentile(d, 99) + 12, 28, 60))
    return med, tol


def adaptive_key(arr, med, tol):
    h, w, _ = arr.shape
    rgb = arr[:, :, :3].astype(np.float64)
    dist = np.sqrt(((rgb - med) ** 2).sum(axis=-1))
    bglike = dist <= tol
    bg = np.zeros((h, w), bool)
    dq = deque()
    for y in range(h):
        for x in (0, w - 1):
            if bglike[y, x] and not bg[y, x]:
                bg[y, x] = True
                dq.append((y, x))
    for x in range(w):
        for y in (0, h - 1):
            if bglike[y, x] and not bg[y, x]:
                bg[y, x] = True
                dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and bglike[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True
                dq.append((ny, nx))
    out = arr.copy()
    out[:, :, 3] = np.where(bg, 0, 255)
    return out, dist


def fringe_erode(arr, dist, med, tol):
    s, v = hsv_sv(arr[:, :, :3])
    eatable = (dist < 1.8 * tol) | ((s < 0.20) & (v > 0.72))
    for _ in range(4):
        a = arr[:, :, 3] > 0
        tr = ~a
        adj = np.zeros_like(a)
        adj[1:, :] |= tr[:-1, :]
        adj[:-1, :] |= tr[1:, :]
        adj[:, 1:] |= tr[:, :-1]
        adj[:, :-1] |= tr[:, 1:]
        kill = a & adj & eatable
        if not kill.any():
            break
        arr[:, :, 3] = np.where(kill, 0, arr[:, :, 3])
    return arr


def comp_kill(arr, mask, min_size, judge):
    """Kill 4-conn components of `mask` px where judge(size, btrans, bdark,
    bopaque) is True. Boundary px classified: transparent / dark ink
    (opaque, max(RGB)<70) / other opaque."""
    a = arr[:, :, 3] > 0
    darkpx = arr[:, :, :3].max(axis=-1) < 70
    h, w = a.shape
    seen = np.zeros_like(mask)
    out = arr.copy()
    for y in range(h):
        for x in range(w):
            if mask[y, x] and not seen[y, x]:
                comp = [(y, x)]
                seen[y, x] = True
                dq = deque(comp)
                btrans = bdark = bopaque = 0
                while dq:
                    cy, cx = dq.popleft()
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if not (0 <= ny < h and 0 <= nx < w):
                            btrans += 1
                            continue
                        if mask[ny, nx]:
                            if not seen[ny, nx]:
                                seen[ny, nx] = True
                                comp.append((ny, nx))
                                dq.append((ny, nx))
                        elif not a[ny, nx]:
                            btrans += 1
                        elif darkpx[ny, nx]:
                            bdark += 1
                        else:
                            bopaque += 1
                if len(comp) >= min_size and judge(len(comp), btrans, bdark, bopaque):
                    for cy, cx in comp:
                        out[cy, cx, 3] = 0
    return out


def pocket_kill(arr, dist, tol):
    a = arr[:, :, 3] > 0
    mask = a & (dist <= tol)
    return comp_kill(arr, mask, 250,
                     lambda n, bt, bd, bo: (bt + bd) / max(1, bt + bd + bo) >= 0.72)


def shadow_components(arr):
    a = arr[:, :, 3] > 0
    s, v = hsv_sv(arr[:, :, :3])
    mask = a & (s < 0.32) & (v > 0.45) & (v < 0.88)
    return comp_kill(arr, mask, 150,
                     lambda n, bt, bd, bo: bt / max(1, bt + bd + bo) >= 0.40)


def band_shadow_scrub(arr, dist, tol):
    a = arr[:, :, 3] > 0
    if not a.any():
        return arr
    ys, xs = np.where(a)
    top, bot = ys.min(), ys.max()
    band0 = int(top + BAND_FRAC * (bot - top + 1))
    s, v = hsv_sv(arr[:, :, :3])
    dark = arr[:, :, :3].max(axis=-1) < 56
    suspect = a & ~dark & (((s < 0.38) & (v > 0.20) & (v < 0.86)) |
                           ((dist < 2.6 * tol) & (v < 0.82)))
    suspect[:band0, :] = False
    return comp_kill(arr, suspect, 200,
                     lambda n, bt, bd, bo: bt / max(1, bt + bd + bo) >= 0.22)


def largest_component(arr):
    a = arr[:, :, 3] > 0
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
    for y, x in bestset:
        keep[y, x] = True
    out = arr.copy()
    out[:, :, 3] = np.where(keep, out[:, :, 3], 0)
    return out


def quantize_fg(arr, ncolors):
    a = arr[:, :, 3] > 0
    fg = arr[a][:, :3]
    strip = Image.fromarray(fg.reshape(1, -1, 3), "RGB")
    q = strip.quantize(colors=ncolors, method=Image.MEDIANCUT).convert("RGB")
    arr = arr.copy()
    arr[a] = np.concatenate([np.array(q).reshape(-1, 3),
                             np.full((fg.shape[0], 1), 255, np.uint8)], axis=1)
    return arr


def main(argv):
    src, dst = argv[1], argv[2]
    canvas = int(argv[argv.index("--canvas") + 1])
    subj = int(argv[argv.index("--subj") + 1])
    bottom = int(argv[argv.index("--bottom") + 1]) if "--bottom" in argv else 9
    arr = np.array(Image.open(src).convert("RGBA"))
    med, tol = bg_stats(arr)
    arr, dist = adaptive_key(arr, med, tol)
    arr = pocket_kill(arr, dist, tol)
    arr = fringe_erode(arr, dist, med, tol)
    arr = shadow_components(arr)
    arr = band_shadow_scrub(arr, dist, tol)
    for i, tok in enumerate(argv):
        if tok == "--kill-rect":
            parts = argv[i + 1].split(":")
            y0, y1, x0, x1 = (int(t) for t in parts[:4])
            vfloor = float(parts[4]) if len(parts) > 4 else 0.20
            s, v = hsv_sv(arr[:, :, :3])
            nd = arr[:, :, :3].max(axis=-1) >= 56
            rem = (dist < 2.2 * tol) | ((s < 0.38) & (v > vfloor) & (v < 0.86) & nd)
            reg = np.zeros(rem.shape, bool)
            reg[y0:y1, x0:x1] = True
            arr[:, :, 3] = np.where(reg & rem, 0, arr[:, :, 3])
        elif tok == "--kill-comp-rect":
            parts = argv[i + 1].split(":")
            y0, y1, x0, x1 = (int(t) for t in parts[:4])
            vfloor = float(parts[4]) if len(parts) > 4 else 0.40
            btfrac = float(parts[5]) if len(parts) > 5 else 0.15
            s, v = hsv_sv(arr[:, :, :3])
            a = arr[:, :, 3] > 0
            mask = a & (s < 0.38) & (v > vfloor) & (v < 0.85) & (arr[:, :, :3].max(axis=-1) >= 56)
            reg = np.zeros(mask.shape, bool)
            reg[y0:y1, x0:x1] = True
            arr = comp_kill(arr, mask & reg, 300,
                            lambda n, bt, bd, bo: bt / max(1, bt + bd + bo) >= btfrac)
        elif tok == "--shadow-flood":
            seedrow = int(argv[i + 1])
            s, v = hsv_sv(arr[:, :, :3])
            a = arr[:, :, 3] > 0
            shl = a & (((arr[:, :, :3].max(axis=-1) >= 56) & (s < 0.38) & (v > 0.40))
                       | (dist <= 1.5 * tol))
            h, w = shl.shape
            reach = np.zeros_like(shl)
            dq = deque()
            for yy in range(seedrow, h):
                for xx in range(w):
                    if shl[yy, xx] and not reach[yy, xx]:
                        reach[yy, xx] = True
                        dq.append((yy, xx))
            while dq:
                cy, cx = dq.popleft()
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and shl[ny, nx] and not reach[ny, nx]:
                        reach[ny, nx] = True
                        dq.append((ny, nx))
            arr[:, :, 3] = np.where(reach, 0, arr[:, :, 3])
        elif tok == "--kill-rect-bg":
            parts = argv[i + 1].split(":")
            y0, y1, x0, x1 = (int(t) for t in parts[:4])
            mult = float(parts[4]) if len(parts) > 4 else 1.5
            reg = np.zeros(dist.shape, bool)
            reg[y0:y1, x0:x1] = True
            arr[:, :, 3] = np.where(reg & (dist <= mult * tol), 0, arr[:, :, 3])
    arr = largest_component(arr)
    a = arr[:, :, 3] > 0
    ys, xs = np.where(a)
    crop = arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    if "--mirror" in argv:
        crop = crop[:, ::-1]
    ch, cw = crop.shape[:2]
    scale = min(subj / ch, (canvas - 6) / cw)
    nh, nw = max(1, round(ch * scale)), max(1, round(cw * scale))
    small = np.array(Image.fromarray(crop).resize((nw, nh), Image.NEAREST))
    small[:, :, 3] = np.where(small[:, :, 3] >= 128, 255, 0)
    out = np.zeros((canvas, canvas, 4), np.uint8)
    y0 = canvas - bottom - nh
    x0 = (canvas - nw) // 2
    out[y0:y0 + nh, x0:x0 + nw] = small
    out = largest_component(out)
    out = quantize_fg(out, QUANT)
    Image.fromarray(out).save(dst)
    fgc = int((out[:, :, 3] > 0).sum())
    print(f"{dst}: bgtol {tol:.0f}, subject {nw}x{nh}, fill {fgc / (canvas * canvas):.3f}")


if __name__ == "__main__":
    main(sys.argv)
