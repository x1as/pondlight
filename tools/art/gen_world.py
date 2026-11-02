"""Generates the pond dioramas (Willow Pond, Frostmere Lake).

Output per pond (assets/art/world/<pond>/):
  water.png   - water base colours (animated in-game by water.gdshader)
  flow.png    - R: sparkle allowance, G: shore foam
  ground.png  - grass/snow, shore, banks, dock (water area transparent)
  props.png   - things floating/standing in the water (lily pads, moss, reeds, rocks)
  canopy.png  - tree canopies drawn above the water and props
  sky.png     - (frostmere only) sky band behind mountains
"""
from __future__ import annotations

import math
import os
import random
import sys

from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from pxlib import (ART, CLEAR, P, Canvas, Noise, bayer, load_json, mix, shade_sphere)  # noqa: E402

W, H = 640, 360
PALETTE = list({v for v in P.values()})
_near_cache: dict = {}


def nearest(c):
    k = c[:3]
    v = _near_cache.get(k)
    if v is None:
        best, bd = None, 1e9
        for p in PALETTE:
            d = (p[0] - k[0]) ** 2 * 0.3 + (p[1] - k[1]) ** 2 * 0.59 + (p[2] - k[2]) ** 2 * 0.11
            if d < bd:
                bd, best = d, p
        v = best
        _near_cache[k] = v
    return v


def darken(c, amount=0.42, tint=(8, 26, 24)):
    return nearest(mix(c, tint + (255,), amount))


def sharp_pick(ramp, t, x, y, sharp=2.6):
    t = max(0.0, min(0.9999, t))
    f = t * (len(ramp) - 1)
    i = int(f)
    frac = (f - i - 0.5) * sharp + 0.5
    if i + 1 < len(ramp) and frac > bayer(x, y):
        return ramp[i + 1]
    return ramp[i]


# ======================================================================== masks
def cell_wh(pond):
    c = pond["cell_size"]
    return (c, c) if isinstance(c, int) else (int(c[0]), int(c[1]))


def cell_rect(origin, cell, col, row):
    cw, ch = (cell, cell) if isinstance(cell, int) else (int(cell[0]), int(cell[1]))
    return origin[0] + col * cw, origin[1] + row * ch


def build_water_mask(pond, seed, blur=9, bias=104, wobble=78, lobes=10):
    layout = pond["layout"]
    origin = pond["grid_origin"]
    cs = pond["cell_size"]
    cw, chh = cell_wh(pond)
    m = Image.new("L", (W, H), 0)
    mp = m.load()
    for r, row in enumerate(layout):
        for c, ch in enumerate(row):
            if ch in ".D":
                continue
            x0, y0 = cell_rect(origin, cs, c, r)
            for y in range(y0, y0 + chh):
                for x in range(x0, x0 + cw):
                    mp[x, y] = 255
    lr = random.Random(seed)
    edge_cells = []
    for r, row in enumerate(layout):
        for c, ch in enumerate(row):
            if ch == "." or ch == "D":
                continue
            nbrs = [(c + 1, r), (c - 1, r), (c, r + 1), (c, r - 1)]
            if any(not (0 <= cc < len(row) and 0 <= rr < len(layout)) or layout[rr][cc] == "." for cc, rr in nbrs):
                edge_cells.append((c, r))
    for _ in range(lobes):
        c, r = lr.choice(edge_cells)
        x0, y0 = cell_rect(origin, cs, c, r)
        cx, cy = x0 + lr.randint(0, cw), y0 + lr.randint(0, chh)
        rad = lr.randint(8, 15)
        for y in range(cy - rad, cy + rad):
            for x in range(cx - rad, cx + rad):
                if 0 <= x < W and 0 <= y < H and (x - cx) ** 2 + ((y - cy) * 1.3) ** 2 < rad * rad:
                    mp[x, y] = 255
    b = m.filter(ImageFilter.GaussianBlur(blur))
    bp = b.load()
    n = Noise(seed, 13.0)
    out = Image.new("L", (W, H), 0)
    op = out.load()
    for y in range(H):
        for x in range(W):
            th = bias + (n.fbm(x, y, 2) - 0.5) * wobble
            if bp[x, y] > th:
                op[x, y] = 255
    # guarantee every fishable cell centre is water
    for r, row in enumerate(layout):
        for c, ch in enumerate(row):
            if ch not in ".D#":
                x0, y0 = cell_rect(origin, cs, c, r)
                for y in range(y0 + 6, y0 + chh - 6):
                    for x in range(x0 + 8, x0 + cw - 8):
                        op[x, y] = 255
    return out


def distance_layers(mask: Image.Image, steps: int, inside=True):
    """Chebyshev-ish distance (in px) to the mask border, capped at steps."""
    dist = [[0] * W for _ in range(H)]
    cur = mask if inside else mask.point(lambda v: 255 - v)
    for s in range(1, steps + 1):
        cp = cur.load()
        for y in range(H):
            row = dist[y]
            for x in range(W):
                if cp[x, y] > 0:
                    row[x] = s
        cur = cur.filter(ImageFilter.MinFilter(3))
    return dist


def cell_mask(pond, chars, blur=0.0):
    layout = pond["layout"]
    origin = pond["grid_origin"]
    cs = pond["cell_size"]
    cw, chh = cell_wh(pond)
    m = Image.new("L", (W, H), 0)
    mp = m.load()
    for r, row in enumerate(layout):
        for c, ch in enumerate(row):
            if ch in chars:
                x0, y0 = cell_rect(origin, cs, c, r)
                for y in range(y0, y0 + chh):
                    for x in range(x0, x0 + cw):
                        mp[x, y] = 255
    if blur > 0:
        m = m.filter(ImageFilter.GaussianBlur(blur))
    return m


def cells_of(pond, chars):
    out = []
    for r, row in enumerate(pond["layout"]):
        for c, ch in enumerate(row):
            if ch in chars:
                x0, y0 = cell_rect(pond["grid_origin"], pond["cell_size"], c, r)
                out.append((c, r, x0, y0))
    return out


# ======================================================================== objects
def draw_canopy(cv: Canvas, cx, cy, r, ramp, seed, outline_c, hi_c=None, shadow_cv=None,
                shadow_off=(7, 9), squash=0.82, clusters=None):
    rnd = random.Random(seed)
    n = Noise(seed + 11, 3.2)
    if clusters is None:
        clusters = []
        k = rnd.randint(6, 10)
        for i in range(k):
            a = rnd.uniform(0, math.tau)
            d = rnd.uniform(0.15, 0.62) * r
            rc = rnd.uniform(0.36, 0.55) * r
            clusters.append((cx + math.cos(a) * d, cy + math.sin(a) * d * squash, rc))
        clusters.append((cx, cy + r * 0.05, r * 0.62))
    clusters.sort(key=lambda c: c[1])  # back (north) to front (south)
    owner = {}
    for idx, (ccx, ccy, rc) in enumerate(clusters):
        for y in range(int(ccy - rc - 3), int(ccy + rc + 4)):
            for x in range(int(ccx - rc - 3), int(ccx + rc + 4)):
                dx, dy = (x + 0.5 - ccx) / rc, (y + 0.5 - ccy) / (rc * squash)
                d = math.sqrt(dx * dx + dy * dy) + (n.at(x, y) - 0.5) * 0.32
                if d > 1.0:
                    continue
                prev = owner.get((x, y))
                lit = shade_sphere(dx, dy)
                t = lit * 0.95 + (n.at(x * 1.7, y * 1.7) - 0.5) * 0.3 - 0.05
                col = sharp_pick(ramp, t, x, y, 2.2)
                if d > 0.86 and prev is not None and prev != idx:
                    col = outline_c  # crease between puffs
                cv.put(x, y, col)
                owner[(x, y)] = idx
    # outer outline + leaf highlights
    pts = list(owner.keys())
    sset = set(pts)
    for (x, y) in pts:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in sset:
                cv.put(x + dx, y + dy, outline_c)
    if hi_c is not None:
        for _ in range(int(r * r * 0.05)):
            x, y = rnd.choice(pts)
            dx, dy = x - cx, y - cy
            if dx + dy < r * 0.2 and (x, y - 1) in sset:
                cv.put(x, y, hi_c)
                if rnd.random() < 0.5:
                    cv.put(x + 1, y, hi_c)
    if shadow_cv is not None:
        sx, sy = shadow_off
        for (x, y) in pts:
            shadow_cv.add((x + sx, y + sy))
    return sset


def apply_shadow(cv: Canvas, pts, amount=0.42, only=None):
    for (x, y) in pts:
        if 0 <= x < W and 0 <= y < H:
            c = cv.get(x, y)
            if c[3] == 0:
                continue
            if only is not None and not only(x, y):
                continue
            cv.put(x, y, darken(c, amount))


def draw_rock(cv: Canvas, cx, cy, rx, ry, seed, ramp, outline_c, top=None, wet=None):
    rnd = random.Random(seed)
    n = Noise(seed, 2.5)
    pts = set()
    for y in range(int(cy - ry - 2), int(cy + ry + 3)):
        for x in range(int(cx - rx - 2), int(cx + rx + 3)):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = math.sqrt(dx * dx + dy * dy) + (n.at(x, y) - 0.5) * 0.25
            if d <= 1.0:
                pts.add((x, y))
                lit = shade_sphere(dx * 1.05, dy * 0.9)
                t = lit + (n.at(x * 2, y * 2) - 0.5) * 0.2
                cv.put(x, y, sharp_pick(ramp, t, x, y, 2.0))
                if top is not None and dy < -0.25 and n.at(x * 1.3, y * 1.3 + 50) > 0.45:
                    cv.put(x, y, top[0] if lit < 0.75 else top[1])
                if wet is not None and dy > 0.55:
                    cv.put(x, y, wet)
    for (x, y) in list(pts):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in pts:
                cv.put(x + dx, y + dy, outline_c)
    return pts


def grass_tuft(cv: Canvas, x, y, rnd, light, mid, dark):
    k = rnd.randint(0, 3)
    if k == 0:
        for px, py, c in ((0, 0, dark), (0, -1, mid), (-1, -1, mid), (1, -2, light), (-1, -2, light), (0, -2, mid)):
            cv.put(x + px, y + py, c)
    elif k == 1:
        for px, py, c in ((0, 0, dark), (1, 0, dark), (0, -1, mid), (1, -2, light), (2, -1, mid), (-1, -1, light)):
            cv.put(x + px, y + py, c)
    elif k == 2:
        for px, py, c in ((0, 0, dark), (0, -1, mid), (0, -2, light), (-1, -1, mid), (1, -1, light), (-2, -2, light), (2, -2, light)):
            cv.put(x + px, y + py, c)
    else:
        for px, py, c in ((0, 0, mid), (-1, -1, light), (1, -1, light)):
            cv.put(x + px, y + py, c)


def flower(cv: Canvas, x, y, petal, center, rnd, dark=None):
    if dark is not None:
        cv.put(x, y + 2, dark)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        cv.put(x + dx, y + dy, petal)
    cv.put(x, y, center)


def lily_pad(cv: Canvas, cx, cy, r, rnd, flower_kind=None):
    notch = rnd.uniform(0, math.tau)
    pts = set()
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            dx, dy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / (r * 0.78)
            d = math.hypot(dx, dy)
            if d > 1.0:
                continue
            a = math.atan2(dy, dx)
            da = abs((a - notch + math.pi) % math.tau - math.pi)
            if da < 0.28 and d > 0.12:
                continue
            pts.add((x, y))
            lit = dx * -0.6 + dy * -0.8
            if d > 0.78 and lit < 0:
                c = P["g3"]
            elif lit > 0.45 and d > 0.35:
                c = P["g7"]
            elif lit > -0.1:
                c = P["g6"]
            else:
                c = P["g5"]
            cv.put(x, y, c)
    # veins
    for i in range(5):
        a = notch + math.pi + (i - 2) * 0.55
        for s in range(2, int(r * 0.8)):
            x, y = int(cx + math.cos(a) * s), int(cy + math.sin(a) * s * 0.78)
            if (x, y) in pts and (s % 2 == 0):
                cv.put(x, y, P["g5"] if cv.get(x, y) == P["g6"] else P["g4"])
    for (x, y) in list(pts):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in pts:
                cv.put(x + dx, y + dy, P["g1"] if dy >= 0 else P["g2"])
    if flower_kind:
        fx, fy = int(cx + rnd.choice((-2, 2))), int(cy - 1)
        petal, petal2 = (P["fp"], P["fp2"]) if flower_kind == "pink" else (P["fw"], P["p2"])
        for dx, dy, c in ((0, -2, petal), (-1, -1, petal), (1, -1, petal), (-2, 0, petal2), (2, 0, petal2),
                          (-1, 0, petal), (1, 0, petal), (0, -1, P["fy"]), (0, 0, P["fy2"]), (-1, 1, petal2), (1, 1, petal2)):
            cv.put(fx + dx, fy + dy, c)


def reed_cluster(cv: Canvas, bx, by, rnd, count, hmin, hmax, ramp, head=True, snow=False):
    for _ in range(count):
        x = bx + rnd.randint(-6, 6)
        y = by + rnd.randint(-2, 3)
        h = rnd.randint(hmin, hmax)
        lean = rnd.uniform(-0.25, 0.25)
        for s in range(h):
            px = int(round(x + lean * s * s / h))
            py = y - s
            t = s / h
            c = ramp[0] if t < 0.2 else (ramp[1] if t < 0.55 else ramp[2])
            cv.put(px, py, c)
            if s < h * 0.6 and rnd.random() < 0.12:
                cv.put(px + (1 if lean > 0 else -1), py, ramp[1])
        if head and rnd.random() < 0.45:
            hx = int(round(x + lean * h))
            for s in range(4):
                cv.put(hx, y - h + 1 + s, P["e2"] if s > 0 else P["e3"])
                cv.put(hx + 1, y - h + 1 + s, P["e1"])
            cv.put(hx, y - h, ramp[2])
        if snow:
            cv.put(int(round(x + lean * h)), y - h, P["n9"])


def draw_trunk(cv: Canvas, x, y_top, y_bot, w, rnd, ramp, outline_c):
    for yy in range(y_top, y_bot):
        flare = int(max(0, (yy - (y_bot - 5))) * 0.9)
        for xx in range(x - w // 2 - flare, x + w // 2 + flare + 1):
            rel = (xx - (x - w // 2 - flare)) / max(1, (w + 2 * flare))
            c = ramp[2] if rel < 0.3 else (ramp[1] if rel < 0.75 else ramp[0])
            if rnd.random() < 0.08:
                c = ramp[0]
            cv.put(xx, yy, c)
        cv.put(x - w // 2 - flare - 1, yy, outline_c)
        cv.put(x + w // 2 + flare + 1, yy, outline_c)


# ======================================================================== WILLOW
def gen_willow(ponds):
    pond = next(p for p in ponds["ponds"] if p["id"] == "willow")
    out_dir = os.path.join(ART, "world", "willow")
    rnd = random.Random(7)
    cw, ch = cell_wh(pond)
    water = build_water_mask(pond, 3, blur=14, bias=92, wobble=120, lobes=20)
    wp = water.load()
    d_in = distance_layers(water, 16, True)
    d_out = distance_layers(water, 8, False)

    deep = cell_mask(pond, "=", 8).load()
    shade = cell_mask(pond, "t", 6).load()
    mossm = cell_mask(pond, "m", 5).load()
    rockm = cell_mask(pond, "k", 6).load()
    sunm = cell_mask(pond, "~", 10).load()

    ground = Canvas(W, H)
    wcv = Canvas(W, H)
    flow = Canvas(W, H, (0, 0, 0, 255))
    props = Canvas(W, H)
    canopy = Canvas(W, H)

    # --- bank faces: water pixels with land within 3px above (we look from the south)
    bank = {}
    for y in range(H):
        for x in range(W):
            if wp[x, y] == 0:
                continue
            for k in range(1, 4):
                if y - k < 0 or wp[x, y - k] == 0:
                    bank[(x, y)] = k
                    break

    # --- grass ground
    n1 = Noise(21, 46.0)
    n2 = Noise(22, 9.0)
    n3 = Noise(23, 3.0)
    grass = [P["g3"], P["g4"], P["g5"], P["g6"]]
    for y in range(H):
        for x in range(W):
            if wp[x, y] and (x, y) not in bank:
                continue
            t = n1.fbm(x, y, 2) * 0.62 + n2.at(x, y) * 0.28 + n3.at(x, y) * 0.1
            t = (t - 0.22) * 1.35
            ground.put(x, y, sharp_pick(grass, t, x, y, 2.4))

    # --- dirt path from the dock to the bottom-left edge
    path_pts = []
    for i in range(80):
        t = i / 79
        px = (1 - t) ** 2 * 320 + 2 * (1 - t) * t * 230 + t * t * 90
        py = (1 - t) ** 2 * 320 + 2 * (1 - t) * t * 348 + t * t * 372
        path_pts.append((px, py))
    pn = Noise(31, 5.0)
    for y in range(270, H):
        for x in range(60, 380):
            if wp[x, y]:
                continue
            md = min(math.hypot(x - a, y - b) for a, b in path_pts[::2])
            rad = 11 + (pn.at(x, y) - 0.5) * 6
            if md < rad:
                t = 1 - md / rad
                ground.put(x, y, sharp_pick([P["e3"], P["e4"], P["e5"]], t * 0.9 + pn.at(x * 2, y * 2) * 0.3, x, y))
            elif md < rad + 1.5:
                ground.put(x, y, P["g3"])

    # --- shore bands (outside water)
    sn = Noise(41, 4.0)
    for y in range(H):
        for x in range(W):
            if wp[x, y]:
                continue
            d = d_out[y][x]
            if d == 0:
                continue
            k = d  # 1 = adjacent to water
            if k == 1:
                ground.put(x, y, P["e1"])
            elif k == 2:
                ground.put(x, y, P["e2"] if sn.at(x, y) > 0.35 else P["e3"])
            elif k == 3 and sn.at(x, y) > 0.3:
                ground.put(x, y, P["e3"] if sn.at(x, y) < 0.6 else P["e4"])
            elif k == 4 and sn.at(x, y) > 0.62:
                ground.put(x, y, P["e4"])
    # bank faces
    for (x, y), k in bank.items():
        c = [P["e3"], P["e2"], P["e1"]][k - 1]
        if k == 1 and (x * 7 + y) % 5 == 0:
            c = P["e4"]
        ground.put(x, y, c)
        if k == 1:
            ground.put(x, y - 1, P["g6"] if (x % 3) else P["g7"])
            if rnd.random() < 0.18:
                ground.put(x, y, P["g5"])  # hanging grass blade
                ground.put(x, y + 1, P["g4"])

    # --- stones along the shore
    stone_ramp = [P["s1"], P["s2"], P["s3"], P["s4"], P["s5"]]
    dcells = cells_of(pond, "D")
    dmid = (min(c[2] for c in dcells) + max(c[2] for c in dcells) + cw) // 2
    dx0, dx1 = dmid - 22, dmid + 22
    dock_top = min(c[3] for c in dcells) - 6
    placed = []
    cand = [(x, y) for y in range(0, H, 2) for x in range(0, W, 2) if not wp[x, y] and d_out[y][x] in (1, 2, 3)]
    rnd.shuffle(cand)
    groups = 0
    for (gx, gy) in cand:
        if groups >= 8:
            break
        if any(abs(gx - a) < 60 and abs(gy - b) < 40 for a, b in placed):
            continue
        if dx0 - 12 < gx < dx1 + 12 and gy > dock_top - 10:
            continue
        placed.append((gx, gy))
        groups += 1
        for k in range(rnd.randint(2, 5)):
            x, y = gx + rnd.randint(-9, 9), gy + rnd.randint(-4, 4)
            if wp[x % W, y % H] and k > 0:
                continue
            rx = rnd.uniform(2.4, 5.2) if k == 0 else rnd.uniform(1.6, 3.4)
            draw_rock(ground, x, y, rx, rx * 0.72, rnd.randint(0, 9999), stone_ramp, P["s0"],
                      top=(P["g4"], P["g6"]) if rnd.random() < 0.6 else None)

    # --- tufts, flowers, leaves on grass
    for _ in range(900):
        x, y = rnd.randrange(W), rnd.randrange(8, H)
        if wp[x, y] or ground.get(x, y)[3] == 0:
            continue
        if ground.get(x, y) in (P["e3"], P["e4"], P["e5"], P["e2"], P["e1"]):
            continue
        grass_tuft(ground, x, y, rnd, P["g7"], P["g6"], P["g3"])
    flower_kinds = [(P["fw"], P["fy"]), (P["fp"], P["fy"]), (P["fv"], P["fw"]), (P["fy"], P["fo"])]
    for _ in range(26):
        cx, cy = rnd.randrange(20, W - 20), rnd.randrange(60, H - 10)
        kind = rnd.choice(flower_kinds)
        for _ in range(rnd.randint(3, 7)):
            x, y = cx + rnd.randint(-10, 10), cy + rnd.randint(-6, 6)
            if wp[x % W, y % H] or d_out[y % H][x % W] <= 3:
                continue
            if dx0 - 10 < x < dx1 + 10 and y > dock_top - 10:
                continue
            flower(ground, x, y, kind[0], kind[1], rnd, P["g3"])
    for _ in range(70):
        x, y = rnd.randrange(W), rnd.randrange(H)
        if wp[x, y]:
            continue
        c = rnd.choice([P["fo"], P["fy2"], P["e5"]])
        ground.put(x, y, c)
        ground.put(x + 1, y, darken(c, 0.3))

    # --- dock (pier) from the pond's south shore down off-screen
    for y in range(dock_top, H):
        plank = (y - dock_top) // 6
        in_gap = (y - dock_top) % 6 == 5
        for x in range(dx0, dx1 + 1):
            if x in (dx0, dx1):
                ground.put(x, y, P["w0"])
                continue
            if in_gap:
                ground.put(x, y, P["w1"])
                continue
            base = [P["w3"], P["w4"], P["w3"], P["w5"]][plank % 4]
            gr = Noise(plank * 13 + 5, 6.0).at(x, y * 3)
            c = base
            if gr > 0.72:
                c = darken(base, 0.18, (40, 20, 10))
            if (y - dock_top) % 6 == 0:
                c = P["w5"] if base != P["w5"] else P["w6"]
            ground.put(x, y, c)
        # plank seams & nails
        if not in_gap and (y - dock_top) % 6 == 2:
            seam = dx0 + 10 + (plank * 11) % 20
            ground.put(seam, y, P["w1"])
            ground.put(seam, y + 1, P["w1"])
            ground.put(dx0 + 3, y, P["s4"])
            ground.put(dx1 - 3, y, P["s4"])
    for px, py in ((dx0 - 1, dock_top - 6), (dx1 - 2, dock_top - 6), (dx0 - 1, dock_top + 40), (dx1 - 2, dock_top + 40)):
        for yy in range(py, py + 9):
            for xx in range(px, px + 4):
                c = P["w2"] if xx < px + 2 else P["w1"]
                if yy == py:
                    c = P["w4"]
                ground.put(xx, yy, c)
        ground.put(px, py + 9, P["w0"]); ground.put(px + 3, py + 9, P["w0"])
        ground.hline(px, px + 3, py - 1, P["w0"])
        # rope ring
        ground.put(px + 1, py + 3, P["e6"]); ground.put(px + 2, py + 3, P["e5"])
    # bucket on the dock
    for yy in range(312, 323):
        for xx in range(304, 314):
            if (xx - 309) ** 2 / 25 + (yy - 317) ** 2 / 36 <= 1:
                ground.put(xx, yy, P["s3"] if xx < 308 else P["s2"])
    for xx in range(305, 313):
        ground.put(xx, 312, P["s5"])
        ground.put(xx, 313, P["a3"])
    ground.put(306, 314, P["a5"]); ground.put(307, 314, P["a6"])
    ground.hline(304, 313, 323, P["s0"])
    # tackle box
    for yy in range(334, 342):
        for xx in range(318, 332):
            c = P["fr"] if yy > 335 else P["fo"]
            if xx in (318, 331) or yy == 341:
                c = P["e0"]
            ground.put(xx, yy, c)
    ground.hline(322, 327, 333, P["s4"]); ground.put(322, 334, P["s4"]); ground.put(327, 334, P["s4"])
    ground.hline(319, 330, 337, P["fp2"])

    # --- WATER base colours
    wn = Noise(51, 7.0)
    wramp = [P["a7"], P["a6"], P["a5"], P["a4"], P["a3"], P["a2"], P["a1"]]
    for y in range(H):
        for x in range(W):
            if not wp[x, y]:
                continue
            d = d_in[y][x]
            D = min(1.0, d / 9.0) * 0.34
            D += deep[x, y] / 255.0 * 0.42 + shade[x, y] / 255.0 * 0.36 + mossm[x, y] / 255.0 * 0.1
            D -= sunm[x, y] / 255.0 * 0.12
            D += (wn.fbm(x, y, 2) - 0.5) * 0.14
            for k in range(1, 4):  # shadow under the bank face
                if (x, y - k) in bank and (x, y) not in bank:
                    D += 0.25 / k
            if dx0 - 2 <= x <= dx1 + 5 and y >= dock_top - 2:
                D += 0.3  # pier shadow
            c = sharp_pick(wramp, D, x, y, 2.4)
            if d <= 3 and y > 160:  # sandy shallows on the near shore
                c = nearest(mix(c, P["e5"], 0.28))
            wcv.put(x, y, c)
            spark = 1.0 - shade[x, y] / 255.0 * 0.75 - mossm[x, y] / 255.0 * 0.9
            foam = 255 if d <= 1 and (x, y) not in bank else 0
            flow.put(x, y, (int(max(0, spark) * 255), foam, 0, 255))
    # submerged weeds and rocks (static under the shimmer)
    for (c, r, x0, y0) in cells_of(pond, "=k"):
        for _ in range(3):
            bx, by = x0 + rnd.randint(2, cw - 3), y0 + rnd.randint(8, ch - 1)
            for s in range(rnd.randint(4, 9)):
                x = bx + int(math.sin(s * 0.9 + bx) * 1.2)
                if wp[x, by - s]:
                    wcv.put(x, by - s, nearest(mix(wcv.get(x, by - s), P["g2"], 0.45)))
    for (c, r, x0, y0) in cells_of(pond, "k"):
        for _ in range(2):
            draw_rock(wcv, x0 + rnd.randint(4, 18), y0 + rnd.randint(6, 18), rnd.uniform(3, 5), rnd.uniform(2, 3.5),
                      rnd.randint(0, 999), [P["a2"], P["a3"], P["a4"]], P["a1"])

    # --- PROPS: moss mats
    mn = Noise(61, 4.5)
    mossmask = cell_mask(pond, "m", 11).load()
    centres = [(x0 + cw // 2 + rnd.randint(-6, 6), y0 + ch // 2) for (_, _, x0, y0) in cells_of(pond, "m")]
    rnd.shuffle(centres)
    centres = centres[:2]
    for y in range(H):
        for x in range(W):
            if not wp[x, y] or (x, y) in bank:
                continue
            v = mossmask[x, y] / 255.0 + (mn.fbm(x, y, 2) - 0.5) * 1.1
            if v < 0.68:
                continue
            if any((x - cx) ** 2 + ((y - cy) * 1.25) ** 2 < 20 + mn.at(x * 3, y * 3) * 14 for cx, cy in centres):
                continue  # open gaps where the bobber sits
            t = mn.at(x * 1.8 + 40, y * 1.8) + (v - 0.68) * 0.6
            props.put(x, y, sharp_pick([P["g3"], P["g4"], P["g5"], P["g6"], P["g7"]], t, x, y, 2.0))
    # moss edge darkening + speckles
    msnap = Canvas(W, H)
    msnap.img = props.img.copy()
    msnap.px = msnap.img.load()
    for y in range(H):
        for x in range(W):
            if msnap.get(x, y)[3] and msnap.get(x, y + 1)[3] == 0:
                props.put(x, y + 1, P["a1"])
                props.put(x, y, P["g2"])
            elif msnap.get(x, y)[3] and rnd.random() < 0.04:
                props.put(x, y, P["g8"])

    # lily pads
    for (c, r, x0, y0) in cells_of(pond, "p"):
        kx, ky = cw / 22.0, ch / 22.0
        spots = [(int(a * kx), int(b * ky)) for a, b in ((3, 4), (16, 3), (4, 17), (17, 16), (11, 1), (1, 11), (8, 19), (19, 9))]
        rnd.shuffle(spots)
        for i, (sx, sy) in enumerate(spots[: rnd.randint(4, 6)]):
            kind = None
            if i == 0 and rnd.random() < 0.7:
                kind = rnd.choice(["pink", "white"])
            lily_pad(props, x0 + sx + rnd.randint(-1, 1), y0 + sy + rnd.randint(-1, 1), rnd.uniform(4.5, 7.0), rnd, kind)

    # roots & sunken timber (habitat "n"): gnarled roots reaching from the bank + a waterlogged branch
    root_c = [P["e1"], P["e2"], P["e3"]]
    for (c, r, x0, y0) in cells_of(pond, "n"):
        for k in range(5):
            x, y = x0 + rnd.randint(-6, 8), y0 + rnd.randint(2, ch - 4)
            ang = rnd.uniform(-0.5, 0.5)
            thick = rnd.choice((2, 2, 3))
            for sgm in range(rnd.randint(16, 30)):
                ang += rnd.uniform(-0.35, 0.35)
                x += math.cos(ang) * 1.1
                y += math.sin(ang) * 0.6
                for t in range(thick):
                    props.put(int(x), int(y) + t, root_c[min(2, t)] if t < thick - 1 else P["e0"])
                if sgm % 7 == 3:
                    props.put(int(x), int(y) - 1, P["g5"])
                if thick > 1 and rnd.random() < 0.1:
                    thick -= 1
        # half-sunken branch
        bx, by = x0 + cw // 2 - 12, y0 + ch // 2 + 4
        for i in range(26):
            yy = by + int(math.sin(i * 0.25) * 2)
            props.put(bx + i, yy, P["e3"]); props.put(bx + i, yy + 1, P["e2"]); props.put(bx + i, yy + 2, P["e0"])
            if i % 6 == 0:
                props.put(bx + i, yy + 3, P["a7"])
        for i in range(8):
            props.put(bx + 6 + i, by - 1 - i // 2, P["e2"])
    # reeds
    reed_ramp = [P["g3"], P["g5"], P["g7"]]
    for (c, r, x0, y0) in cells_of(pond, "r"):
        for (bx, by) in ((x0 + 7, y0 + ch - 2), (x0 + cw - 8, y0 + ch - 4), (x0 + cw // 2, y0 + 10)):
            reed_cluster(props, bx, by, rnd, rnd.randint(6, 9), 10, 22, reed_ramp)
    # shore reed clumps & cattails at the edges (not on cells)
    edge = [(x, y) for y in range(24, 290, 3) for x in range(70, 570, 3)
            if wp[x, y] and d_in[y][x] == 2 and (x, y) not in bank and not (dx0 - 20 < x < dx1 + 20 and y > dock_top - 20)]
    rnd.shuffle(edge)
    used = []
    for (x, y) in edge:
        if len(used) >= 7:
            break
        if any(abs(x - a) < 50 and abs(y - b) < 40 for a, b in used):
            continue
        used.append((x, y))
        reed_cluster(props, x, y + 2, rnd, 8, 8, 20, reed_ramp)

    # rocks breaching the surface
    for (c, r, x0, y0) in cells_of(pond, "k"):
        for (sx, sy) in ((7, ch - 8), (cw - 8, 8), (cw // 2, ch // 2 + 6)):
            pts = draw_rock(props, x0 + sx, y0 + sy, rnd.uniform(3.2, 4.8), rnd.uniform(2.4, 3.2), rnd.randint(0, 999),
                            stone_ramp, P["s0"], top=(P["g4"], P["g6"]), wet=P["s1"])
            ys = max(p[1] for p in pts)
            for (px, py) in pts:
                if py == ys:
                    props.put(px, py + 2, P["a7"])
    # floating leaves
    for _ in range(9):
        cells = cells_of(pond, "~=")
        c, r, x0, y0 = rnd.choice(cells)
        x, y = x0 + rnd.choice((4, cw - 6)), y0 + rnd.choice((4, ch - 5))
        col = rnd.choice([P["fo"], P["fy"], P["g7"]])
        props.put(x, y, col); props.put(x + 1, y, col); props.put(x + 1, y - 1, darken(col, 0.25)); props.put(x, y + 1, P["a2"])

    # fallen log at the east shore
    for i in range(46):
        x = 516 + i
        y = int(196 + i * 0.42)
        for k in range(-4, 5):
            c = P["e3"] if k < -1 else (P["e2"] if k < 2 else P["e1"])
            if k == -4:
                c = P["e4"]
            if abs(k) == 4 and k > 0:
                c = P["e0"]
            props.put(x, y + k, c)
        if i % 9 == 0:
            props.put(x, y - 1, P["e1"])
        if i % 7 == 3:
            props.put(x, y - 4, P["g6"]); props.put(x + 1, y - 4, P["g5"])
    for k in range(-4, 5):  # cut end with rings
        x, y = 515, 196 + k
        props.put(x, y, P["e5"] if abs(k) < 3 else P["e4"])
        props.put(x - 1, y, P["e0"])
    props.put(515, 196, P["e3"])

    # --- CANOPY: the big willow over the shade cells
    shadow_pts: set = set()
    trunk_ramp = [P["e1"], P["e2"], P["e3"]]
    draw_trunk(ground, 100, -4, 34, 12, rnd, trunk_ramp, P["e0"])
    for (rx, ry, ang) in ((94, 32, 2.6), (108, 34, 0.4), (102, 35, 1.6)):
        for s in range(10):
            ground.put(int(rx + math.cos(ang) * s), int(ry + math.sin(ang) * s * 0.4), P["e2"])
    willow_ramp = [P["g3"], P["g4"], P["g5"], P["g6"], P["g7"], P["g8"]]
    wset = draw_canopy(canopy, 150, 0, 64, willow_ramp, 501, P["g2"], P["g9"], shadow_pts, (6, 14))
    # hanging fronds
    xs = sorted({x for (x, y) in wset})
    for x in xs[::2]:
        col_y = max(y for (xx, y) in wset if xx == x)
        if col_y < 26:
            continue
        L = rnd.randint(10, 40) if 130 < x < 230 else rnd.randint(4, 18)
        sway = rnd.choice((-1, 1))
        for s in range(L):
            px = x + (sway if s > L * 0.6 else 0)
            py = col_y + s
            c = P["g6"] if s % 3 else P["g7"]
            if s > L - 3:
                c = P["g5"]
            canopy.put(px, py, c)
            if s % 4 == 1:
                canopy.put(px + sway, py, P["g5"])
            canopy.put(px + 1, py, P["g2"]) if s % 5 == 0 else None
            shadow_pts.add((px + 5, py + 6))

    # --- top band forest
    top_trees = [(26, 6, 34), (250, -24, 30), (300, -28, 30), (350, -26, 32), (404, -24, 32), (456, -26, 30),
                 (612, 4, 34), (40, 60, 28), (604, 64, 30)]
    for i, (x, y, r) in enumerate(top_trees):
        ramp = [P["g1"], P["g2"], P["g3"], P["g4"], P["g5"], P["g6"]]
        if i % 3 == 1:
            ramp = [P["g2"], P["g3"], P["g4"], P["g5"], P["g6"], P["g7"]]
        draw_canopy(canopy, x, y, r, ramp, 700 + i, P["g0"], P["g8"] if i % 3 == 1 else P["g7"], shadow_pts, (6, 10))
    # side trees & bushes
    side = [(18, 122, 28, 0), (40, 176, 20, 1), (14, 232, 26, 1), (36, 290, 24, 0), (10, 344, 28, 0),
            (110, 350, 22, 1), (622, 124, 28, 1), (604, 178, 20, 0), (628, 236, 26, 0), (606, 292, 22, 1),
            (630, 346, 28, 0), (566, 352, 18, 2), (190, 352, 14, 2), (250, 346, 10, 2), (420, 352, 12, 2),
            (64, 96, 14, 2), (584, 96, 14, 2)]
    for i, (x, y, r, kind) in enumerate(side):
        if kind == 2:
            ramp = [P["g2"], P["g3"], P["g4"], P["g5"], P["g6"], P["g7"]]
            draw_canopy(canopy, x, y, r * 0.8, ramp, 900 + i, P["g1"], P["g8"], shadow_pts, (4, 5), squash=0.7)
            # berries on bushes
            for _ in range(6):
                bx, by = x + rnd.randint(-int(r * 0.5), int(r * 0.5)), y + rnd.randint(-int(r * 0.3), int(r * 0.3))
                if canopy.get(bx, by)[3]:
                    canopy.put(bx, by, P["fr"]); canopy.put(bx + 1, by + 1, P["fp2"])
        else:
            ramp = [P["g1"], P["g2"], P["g3"], P["g4"], P["g5"], P["g6"]] if kind == 0 else \
                [P["g2"], P["g3"], P["g4"], P["g5"], P["g6"], P["g7"]]
            draw_trunk(ground, x + 2, y + int(r * 0.4), y + int(r * 0.85), 6, rnd, trunk_ramp, P["e0"])
            draw_canopy(canopy, x, y, r, ramp, 800 + i, P["g0"], P["g8"], shadow_pts, (7, 10))
    # shoreline bushes that break up the pond outline
    near = [(x, y) for y in range(20, 300, 3) for x in range(60, 590, 3)
            if not wp[x, y] and d_out[y][x] in (5, 6) and not (dx0 - 30 < x < dx1 + 30 and y > dock_top - 30)]
    rnd.shuffle(near)
    bushes = []
    for (x, y) in near:
        if len(bushes) >= 9:
            break
        if any(abs(x - a) < 70 and abs(y - b) < 50 for a, b in bushes) or (60 < x < 240 and y < 70):
            continue
        bushes.append((x, y))
        ramp = [P["g2"], P["g3"], P["g4"], P["g5"], P["g6"], P["g7"]]
        draw_canopy(canopy, x, y, rnd.uniform(9, 14), ramp, 1200 + len(bushes), P["g1"], P["g8"], shadow_pts, (3, 4), squash=0.72)
        if rnd.random() < 0.5:
            for _ in range(5):
                bx, by = x + rnd.randint(-7, 7), y + rnd.randint(-5, 3)
                if canopy.get(bx, by)[3]:
                    canopy.put(bx, by, rnd.choice([P["fw"], P["fp"], P["fy"]]))
    # a second old tree leaning over the north-east bank
    draw_trunk(ground, 540, -6, 22, 8, rnd, trunk_ramp, P["e0"])
    draw_canopy(canopy, 532, -2, 40, [P["g1"], P["g2"], P["g3"], P["g4"], P["g5"], P["g6"]], 1301, P["g0"], P["g7"],
                shadow_pts, (6, 12))
    # ferns
    for _ in range(14):
        fx, fy = rnd.randrange(10, W - 10), rnd.randrange(90, H - 5)
        if wp[fx, fy] or d_out[fy][fx] < 6 or (dx0 - 20 < fx < dx1 + 20):
            continue
        for a in range(-3, 4):
            ang = -math.pi / 2 + a * 0.42
            for sgm in range(1, 8 - abs(a)):
                px, py = int(fx + math.cos(ang) * sgm), int(fy + math.sin(ang) * sgm * 0.8)
                ground.put(px, py, P["g6"] if sgm % 2 else P["g7"])
                if sgm % 2 == 0:
                    ground.put(px + (1 if a >= 0 else -1), py, P["g5"])
        ground.put(fx, fy + 1, P["g2"])

    # mushrooms & ferns at the forest edge
    for (x, y) in [(150, 306), (470, 312), (52, 262), (590, 160), (56, 150)]:
        for k in range(rnd.randint(2, 3)):
            mx, my = x + k * 4, y + (k % 2) * 2
            ground.put(mx, my, P["fw"]); ground.put(mx, my - 1, P["fw"])
            ground.hline(mx - 1, mx + 1, my - 2, P["fr"]); ground.put(mx, my - 3, P["fr"])
            ground.put(mx - 1, my - 2, P["fp"])
            ground.put(mx + 1, my - 3, P["fw"])

    # tree shadows on ground and water (not on bank / foam lines)
    apply_shadow(ground, shadow_pts, 0.42, only=lambda x, y: canopy.get(x, y)[3] == 0)
    apply_shadow(wcv, shadow_pts, 0.3, only=lambda x, y: canopy.get(x, y)[3] == 0)
    for (x, y) in shadow_pts:
        if 0 <= x < W and 0 <= y < H and wp[x, y]:
            f = flow.get(x, y)
            flow.put(x, y, (int(f[0] * 0.35), f[1], 0, 255))

    os.makedirs(out_dir, exist_ok=True)
    wcv.save(os.path.join(out_dir, "water.png"))
    flow.save(os.path.join(out_dir, "flow.png"))
    ground.save(os.path.join(out_dir, "ground.png"))
    props.save(os.path.join(out_dir, "props.png"))
    canopy.save(os.path.join(out_dir, "canopy.png"))
    # composite preview for art review
    comp = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    for c in (wcv, ground, props, canopy):
        comp.alpha_composite(c.img)
    comp.save(os.path.join(out_dir, "_preview.png"))
    print("willow done")


if __name__ == "__main__":
    ponds = load_json("data/ponds.json")
    which = sys.argv[1:] or ["willow", "frostmere"]
    if "willow" in which:
        gen_willow(ponds)
    if "frostmere" in which:
        import gen_frost
        gen_frost.gen_frost(ponds)


def make_thumbs():
    """Map-screen thumbnails cropped 1:1 from the composite previews (no resampling)."""
    base = os.path.join(ART, "world")
    for pid, box in (("willow", (226, 150, 412, 242)), ("frostmere", (227, 160, 413, 252))):
        Image.open(os.path.join(base, pid, "_preview.png")).crop(box).save(os.path.join(base, pid, "thumb.png"))


if __name__ == "__main__":
    make_thumbs()
