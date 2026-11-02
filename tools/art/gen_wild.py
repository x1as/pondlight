"""Emerald Delta (flooded rainforest river) and Leviathan Trench (open sea over an abyss) dioramas.

Same layer contract as gen_world.py: water.png + flow.png (animated by water.gdshader), ground.png,
props.png, canopy.png, sky.png, _preview.png. Everything is pure pixel art from the shared palette.
"""
from __future__ import annotations

import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pxlib import ART, P, Canvas, Noise, load_json, mix  # noqa: E402
from gen_world import (H, W, apply_shadow, build_water_mask, cell_mask, cell_wh, cells_of, darken, distance_layers,  # noqa: E402
                       draw_canopy, draw_rock, draw_trunk, flower, grass_tuft, lily_pad, nearest, reed_cluster, sharp_pick)


def bayer_ok(x, y):
    return (x + y) % 2 == 0


def _bank_faces(wp):
    bank = {}
    for y in range(H):
        for x in range(W):
            if wp[x, y]:
                for k in range(1, 4):
                    if y - k < 0 or wp[x, y - k] == 0:
                        bank[(x, y)] = k
                        break
    return bank


def _dock(ground: Canvas, pond, rnd, plank_ramp, edge_c, gap_c, top_c):
    cw, ch = cell_wh(pond)
    dcells = cells_of(pond, "D")
    dmid = (min(c[2] for c in dcells) + max(c[2] for c in dcells) + cw) // 2
    dx0, dx1 = dmid - 22, dmid + 22
    dock_top = min(c[3] for c in dcells) - 6
    for y in range(dock_top, H):
        plank = (y - dock_top) // 6
        gap = (y - dock_top) % 6 == 5
        for x in range(dx0, dx1 + 1):
            if x in (dx0, dx1):
                ground.put(x, y, edge_c)
            elif gap:
                ground.put(x, y, gap_c)
            else:
                c = plank_ramp[plank % len(plank_ramp)]
                if (y - dock_top) % 6 == 0:
                    c = top_c
                if Noise(plank * 7 + 3, 5.0).at(x, y * 3) > 0.74:
                    c = darken(c, 0.16, (40, 20, 10))
                ground.put(x, y, c)
        if not gap and (y - dock_top) % 6 == 2:
            ground.put(dx0 + 3, y, P["s4"])
            ground.put(dx1 - 3, y, P["s4"])
    for px, py in ((dx0 - 1, dock_top - 6), (dx1 - 2, dock_top - 6), (dx0 - 1, dock_top + 40), (dx1 - 2, dock_top + 40)):
        for yy in range(py, py + 9):
            for xx in range(px, px + 4):
                ground.put(xx, yy, P["w4"] if yy == py else (P["w2"] if xx < px + 2 else P["w1"]))
        ground.hline(px, px + 3, py - 1, P["w0"])
        ground.put(px + 1, py + 3, P["e6"]); ground.put(px + 2, py + 3, P["e5"])
    return dx0, dx1, dock_top


def _lantern(cv: Canvas, lx, ly):
    for yy in range(ly - 12, ly + 4):
        cv.put(lx, yy, P["w1"]); cv.put(lx + 1, yy, P["w2"])
    cv.rect(lx - 1, ly - 17, 4, 5, P["fy"])
    cv.put(lx, ly - 15, P["fw"])
    cv.hline(lx - 1, lx + 2, ly - 18, P["e0"]); cv.hline(lx - 1, lx + 2, ly - 12, P["e0"])


def _save(out, layers, name):
    os.makedirs(out, exist_ok=True)
    for k, cv in layers.items():
        cv.save(os.path.join(out, k + ".png"))
    comp = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    for k in ("sky", "water", "ground", "props", "canopy"):
        comp.alpha_composite(layers[k].img)
    comp.save(os.path.join(out, "_preview.png"))
    print(name, "done")


# ============================================================================ EMERALD DELTA
def palm(cv: Canvas, x, base_y, h, rnd, shadow=None):
    """A leaning jungle palm: segmented trunk and a burst of drooping fronds."""
    lean = rnd.uniform(-0.35, 0.35)
    tx, ty = x, base_y
    for s in range(h):
        tx = x + lean * s * s / h
        ty = base_y - s
        c = P["e3"] if s % 4 else P["e2"]
        cv.put(int(tx), int(ty), c); cv.put(int(tx) + 1, int(ty), P["e4"] if s % 4 else P["e3"]); cv.put(int(tx) - 1, int(ty), P["e1"])
    top = (int(tx), int(ty))
    for k in range(7):
        a = -math.pi / 2 + (k - 3) * 0.55 + rnd.uniform(-0.1, 0.1)
        ln = rnd.randint(12, 18)
        for s in range(ln):
            px = top[0] + math.cos(a) * s
            py = top[1] + math.sin(a) * s * 0.7 + (s * s) / (ln * 1.6)
            c = P["g5"] if s < ln * 0.5 else P["g6"]
            cv.put(int(px), int(py), c)
            if s % 2 == 0 and s > 2:
                cv.put(int(px), int(py) + 1, P["g3"]); cv.put(int(px), int(py) + 2, P["g2"])
            if shadow is not None:
                shadow.add((int(px) + 7, int(py) + 9))
    cv.put(top[0], top[1], P["fo"]); cv.put(top[0] + 1, top[1] + 1, P["fy2"])


def gen_delta(ponds):
    pond = next(p for p in ponds["ponds"] if p["id"] == "delta")
    out = os.path.join(ART, "world", "delta")
    rnd = random.Random(31)
    cw, ch = cell_wh(pond)
    water = build_water_mask(pond, 9, blur=12, bias=96, wobble=110, lobes=18)
    wp = water.load()
    d_in = distance_layers(water, 14, True)
    d_out = distance_layers(water, 8, False)
    bank = _bank_faces(wp)
    mud = cell_mask(pond, "M", 12).load()
    black = cell_mask(pond, "B", 12).load()
    rapid = cell_mask(pond, "R", 8).load()

    sky = Canvas(W, H)
    ground = Canvas(W, H)
    wcv = Canvas(W, H)
    flow = Canvas(W, H, (0, 0, 0, 255))
    props = Canvas(W, H)
    canopy = Canvas(W, H)
    shadow: set = set()

    # --- jungle floor
    n1, n2, n3 = Noise(21, 40.0), Noise(22, 8.0), Noise(23, 3.0)
    floor_ramp = [P["g1"], P["g2"], P["g3"], P["g4"], P["g5"]]
    for y in range(H):
        for x in range(W):
            if wp[x, y] and (x, y) not in bank:
                continue
            t = n1.fbm(x, y, 2) * 0.6 + n2.at(x, y) * 0.3 + n3.at(x, y) * 0.1
            ground.put(x, y, sharp_pick(floor_ramp, (t - 0.2) * 1.4, x, y, 2.3))
    # muddy banks
    sn = Noise(41, 4.0)
    for y in range(H):
        for x in range(W):
            if wp[x, y]:
                continue
            d = d_out[y][x]
            if d == 1:
                ground.put(x, y, P["m1"])
            elif d == 2:
                ground.put(x, y, P["m2"] if sn.at(x, y) > 0.3 else P["m3"])
            elif d in (3, 4) and sn.at(x, y) > 0.45 + d * 0.06:
                ground.put(x, y, P["m3"] if sn.at(x * 2, y) > 0.5 else P["e3"])
    for (x, y), k in bank.items():
        ground.put(x, y, [P["m3"], P["m2"], P["m1"]][k - 1])
        if k == 1:
            ground.put(x, y - 1, P["g5"] if x % 3 else P["g6"])
    # ferns, flowers, fallen fruit
    for _ in range(1300):
        x, y = rnd.randrange(W), rnd.randrange(H)
        if wp[x, y] or d_out[y][x] in (1, 2):
            continue
        grass_tuft(ground, x, y, rnd, P["g6"], P["g5"], P["g2"])
    for _ in range(20):
        cx, cy = rnd.randrange(10, W - 10), rnd.randrange(30, H - 10)
        kind = rnd.choice([(P["fp"], P["fy"]), (P["fo"], P["fy"]), (P["fr"], P["fy"]), (P["fv"], P["fw"])])
        for _ in range(rnd.randint(2, 5)):
            x, y = cx + rnd.randint(-8, 8), cy + rnd.randint(-5, 5)
            if not wp[x % W, y % H] and d_out[y % H][x % W] > 3:
                flower(ground, x, y, kind[0], kind[1], rnd, P["g2"])

    dx0, dx1, dock_top = _dock(ground, pond, rnd, [P["w3"], P["w2"], P["w3"], P["w4"]], P["w0"], P["w1"], P["w4"])
    # stilt hut on the left bank (bottom-left)
    hx, hy = 20, 300
    for px in (hx + 2, hx + 40):
        ground.rect(px, hy + 18, 3, 30, P["e2"]); ground.vline(px, hy + 18, hy + 47, P["e1"])
    ground.rect(hx, hy + 2, 46, 18, P["e4"])
    for x in range(hx, hx + 46, 4):
        ground.vline(x, hy + 2, hy + 19, P["e3"])
    for x in range(hx - 6, hx + 52):  # thatched roof
        for y in range(hy - 16, hy + 3):
            if abs(x - (hx + 23)) <= (y - (hy - 16)) * 1.9:
                c = P["y0"] if (x + y * 2) % 5 else P["m3"]
                if y > hy:
                    c = P["m2"]
                ground.put(x, y, c)
    ground.rect(hx + 18, hy + 7, 9, 13, P["e1"])
    ground.rect(hx + 5, hy + 7, 8, 6, P["fy"]); ground.rect(hx + 6, hy + 8, 6, 4, P["fy2"])
    # canoe moored by the jetty
    for i in range(34):
        x = dx1 + 14 + i
        y = 284 + int(abs(i - 17) ** 2 / 60)
        wcv.put(x, y - 3, P["e4"]); wcv.put(x, y - 2, P["e3"]); wcv.put(x, y - 1, P["e2"]); wcv.put(x, y, P["e0"])

    # --- WATER
    wn = Noise(51, 7.0)
    j_ramp = [P["j6"], P["j5"], P["j4"], P["j3"], P["j2"], P["j1"]]
    m_ramp = [P["m4"], P["m3"], P["m2"], P["m1"], P["m0"]]
    k_ramp = [P["j3"], P["j2"], P["k3"], P["j1"], P["k2"]]
    for y in range(H):
        for x in range(W):
            if not wp[x, y]:
                continue
            d = d_in[y][x]
            D = min(1.0, d / 10.0) * 0.45 + (wn.fbm(x, y, 2) - 0.5) * 0.18
            for k in range(1, 4):
                if (x, y - k) in bank and (x, y) not in bank:
                    D += 0.25 / k
            if dx0 - 2 <= x <= dx1 + 5 and y >= dock_top - 2:
                D += 0.3
            mv, bv = mud[x, y] / 255.0, black[x, y] / 255.0
            noise = (Noise(52, 18.0).at(x, y) - 0.5) * 0.5
            if bv + noise > 0.55:
                c = sharp_pick(k_ramp, D + 0.1 + bv * 0.35, x, y, 2.2)
                spark = 70
            elif mv + noise > 0.5:
                c = sharp_pick(m_ramp, D + (Noise(54, 5.0).at(x, y) - 0.5) * 0.35, x, y, 2.0)
                if Noise(55, 11.0).fbm(x, y, 2) > 0.6:
                    c = P["j3"] if bayer_ok(x, y) else P["j2"]
                spark = 150
            else:
                c = sharp_pick(j_ramp, D + 0.1, x, y, 2.3)
                spark = 220
            if rapid[x, y] > 120:
                spark = 255
            wcv.put(x, y, c)
            foam = 255 if (d <= 1 and (x, y) not in bank) or (rapid[x, y] > 160 and Noise(53, 3.0).at(x, y * 3) > 0.7) else 0
            flow.put(x, y, (spark, foam, 0, 255))
    # rapids: white water streaks + wet rocks
    for (c, r, x0, y0) in cells_of(pond, "R"):
        for _ in range(16):
            sx, sy = x0 + rnd.randint(2, cw - 10), y0 + rnd.randint(3, ch - 3)
            if wp[sx, sy]:
                for i in range(rnd.randint(3, 8)):
                    wcv.put(sx + i, sy, P["n8"] if i % 3 else P["j6"])
        for (sx, sy) in ((8, 10), (cw - 10, ch - 10)):
            pts = draw_rock(props, x0 + sx, y0 + sy, rnd.uniform(3.5, 5), rnd.uniform(2.4, 3.2), rnd.randint(0, 999),
                            [P["s1"], P["s2"], P["s3"], P["s4"]], P["s0"], top=(P["g4"], P["g5"]), wet=P["s1"])
            ys = max(p[1] for p in pts)
            for (px, py) in pts:
                if py == ys:
                    props.put(px - 1, py + 2, P["n9"]); props.put(px + 1, py + 2, P["n8"])
    # giant lily pads (Victoria) with upturned red rims
    for (c, r, x0, y0) in cells_of(pond, "V"):
        for i, (sx, sy) in enumerate(((12, 10), (cw - 14, ch - 10), (cw - 12, 9), (11, ch - 9))[: rnd.randint(2, 4)]):
            cx, cy, rr = x0 + sx, y0 + sy, rnd.uniform(8.0, 10.5)
            lily_pad(props, cx, cy, rr, rnd, "pink" if i == 0 and rnd.random() < 0.6 else None)
            for a in range(0, 360, 6):
                px = cx + math.cos(math.radians(a)) * (rr + 0.6)
                py = cy + math.sin(math.radians(a)) * (rr + 0.6) * 0.78
                if math.sin(math.radians(a)) > -0.2:
                    props.put(int(px), int(py), P["c1"])
                    props.put(int(px), int(py) + 1, P["c0"])
    # flooded roots: mangrove arches standing in the water
    for (c, r, x0, y0) in cells_of(pond, "F"):
        for k in range(3):
            bx = x0 + 8 + k * (cw // 3) + rnd.randint(-3, 3)
            by = y0 + ch - 6 - rnd.randint(0, 8)
            top = by - rnd.randint(10, 16)
            for leg in (-6, -2, 3, 7):
                fx = bx + leg
                for yy in range(top, by + 1):
                    t = (yy - top) / max(1, by - top)
                    xx = int(bx + (fx - bx) * t)
                    props.put(xx, yy, P["e3"] if leg < 0 else P["e2"])
                    props.put(xx + 1, yy, P["e1"])
                props.put(fx, by + 1, P["j6"]); props.put(fx + 1, by + 1, P["j5"])
            props.rect(bx - 1, top - 6, 3, 7, P["e3"]); props.vline(bx + 2, top - 6, top, P["e1"])
            props.put(bx, top - 7, P["g6"]); props.put(bx - 1, top - 8, P["g5"]); props.put(bx + 1, top - 8, P["g7"])
    # floating leaves & flowers
    for _ in range(14):
        c, r, x0, y0 = rnd.choice(cells_of(pond, "MBV"))
        x, y = x0 + rnd.randint(4, cw - 6), y0 + rnd.randint(4, ch - 5)
        col = rnd.choice([P["fo"], P["fy"], P["g6"], P["fp"]])
        props.put(x, y, col); props.put(x + 1, y, col); props.put(x, y + 1, darken(col, 0.3))

    # --- canopy wall at the top, big trees and palms on the sides
    top_ramp = [P["g1"], P["g2"], P["g3"], P["g4"], P["g5"], P["g6"]]
    for i, x in enumerate(range(-20, W + 30, 34)):
        draw_canopy(canopy, x + rnd.randint(-6, 6), 8 + rnd.randint(-6, 8), rnd.randint(22, 30), top_ramp, 300 + i, P["g0"],
                    P["g7"], shadow, (4, 10))
    for i, (x, y, r) in enumerate(((20, 120, 30), (34, 210, 26), (14, 268, 24), (620, 112, 30), (606, 200, 26), (628, 270, 28),
                                   (70, 345, 22), (585, 345, 26))):
        draw_trunk(canopy, x, y, y + 30, 6, rnd, [P["e1"], P["e2"], P["e3"]], P["e0"])
        draw_canopy(canopy, x, y, r, top_ramp, 400 + i, P["g0"], P["g7"], shadow)
    for (x, y, h) in ((58, 96, 34), (586, 98, 32), (66, 175, 30), (574, 178, 34), (48, 240, 28), (598, 236, 30)):
        if not wp[x, y]:
            palm(canopy, x, y, h, rnd, shadow)
    # hanging vines from the top canopy over the river
    for x in range(30, W - 30, 23):
        ln = rnd.randint(8, 26)
        for s in range(ln):
            canopy.put(x + int(math.sin(s * 0.4 + x) * 1.2), 22 + s, P["g4"] if s % 3 else P["g6"])
        canopy.put(x, 22 + ln, P["fp"] if rnd.random() < 0.3 else P["g7"])
    apply_shadow(ground, shadow, 0.3, only=lambda x, y: canopy.get(x, y)[3] == 0)
    apply_shadow(wcv, shadow, 0.25, only=lambda x, y: canopy.get(x, y)[3] == 0)
    _lantern(ground, dx0 - 4, dock_top + 6)
    _lantern(ground, dx1 + 2, dock_top + 6)
    _save(out, {"sky": sky, "water": wcv, "flow": flow, "ground": ground, "props": props, "canopy": canopy}, "delta")


# ============================================================================ LEVIATHAN TRENCH
def gen_trench(ponds):
    pond = next(p for p in ponds["ponds"] if p["id"] == "trench")
    out = os.path.join(ART, "world", "trench")
    rnd = random.Random(53)
    cw, ch = cell_wh(pond)
    HORIZON = 30
    # the sea fills everything above the shore; land only at the bottom corners and the cliffs
    m = build_water_mask(pond, 17, blur=10, bias=90, wobble=90, lobes=14)
    mp = m.load()
    for y in range(0, 150):
        for x in range(W):
            edge = 26 + int(Noise(5, 20.0).fbm(x, y, 2) * 24)
            if HORIZON <= y and (edge < x < W - edge):
                mp[x, y] = 255
    for y in range(HORIZON, HORIZON + 2):
        for x in range(W):
            mp[x, y] = 255
    wp = mp
    d_in = distance_layers(m, 12, True)
    d_out = distance_layers(m, 8, False)
    bank = {k: v for k, v in _bank_faces(wp).items() if k[1] > HORIZON + 4}
    abyss = cell_mask(pond, "A", 16).load()
    swell = cell_mask(pond, "X", 10).load()
    sand = cell_mask(pond, "S", 16).load()
    coral = cell_mask(pond, "C", 6).load()
    kelp = cell_mask(pond, "K", 6).load()

    sky = Canvas(W, H)
    ground = Canvas(W, H)
    wcv = Canvas(W, H)
    flow = Canvas(W, H, (0, 0, 0, 255))
    props = Canvas(W, H)
    canopy = Canvas(W, H)

    # --- sky: sunset over the open sea
    sky_ramp = [P["fo"], P["c3"], P["c2"], P["fv"], P["fv2"], P["o3"]]
    for y in range(0, HORIZON + 4):
        for x in range(W):
            sky.put(x, y, sharp_pick(sky_ramp[::-1], y / float(HORIZON), x, y, 1.8))
    cn = Noise(7, 22.0)
    for y in range(3, HORIZON - 4):
        for x in range(W):
            v = cn.fbm(x * 0.5, y * 2.4, 3)
            if v > 0.62:
                sky.put(x, y, P["c3"] if v > 0.7 else P["c2"])
    for y in range(HORIZON - 9, HORIZON):  # setting sun
        for x in range(300, 340):
            if (x - 320) ** 2 + ((y - HORIZON) * 1.6) ** 2 < 140:
                sky.put(x, y, P["fy"] if (x - 320) ** 2 + ((y - HORIZON) * 1.6) ** 2 < 70 else P["gold3"])

    # --- rocky cliffs and a sandy beach
    rock_ramp = [P["s0"], P["s1"], P["s2"], P["s3"], P["s4"]]
    rn = Noise(81, 14.0)
    for y in range(HORIZON, H):
        for x in range(W):
            if wp[x, y] and (x, y) not in bank:
                continue
            if y > 214:
                t = Noise(82, 9.0).fbm(x, y, 2) + min(1.0, d_out[y][x] / 8.0) * 0.4 - 0.25
                ground.put(x, y, sharp_pick([P["y0"], P["y1"], P["y2"], P["y3"]], t, x, y, 2.4))
            else:
                t = rn.fbm(x, y * 1.4, 3)
                ground.put(x, y, sharp_pick(rock_ramp, t, x, y, 2.6))
                if rn.at(x * 2, y * 2) > 0.8:
                    ground.put(x, y, P["g3"])  # sea grass in cracks
    for y in range(H):
        for x in range(W):
            if not wp[x, y] and d_out[y][x] == 1:
                ground.put(x, y, P["n8"] if (x + y) % 3 else P["n7"])  # surf line on the rocks
    for (x, y), k in bank.items():
        ground.put(x, y, [P["s3"], P["s2"], P["s1"]][k - 1])
    # lighthouse on the left cliff
    lx, ly = 30, 130
    for y in range(ly - 46, ly):
        wdt = 6 + (y - (ly - 46)) // 9
        for x in range(lx - wdt, lx + wdt + 1):
            band = ((y - (ly - 46)) // 8) % 2
            c = (P["fr"] if band else P["fw"]) if x < lx + wdt - 2 else (P["fp2"] if band else P["p2"])
            ground.put(x, y, c)
    ground.rect(lx - 5, ly - 54, 11, 8, P["s1"])
    ground.rect(lx - 3, ly - 53, 7, 5, P["fy"]); ground.rect(lx - 1, ly - 52, 3, 3, P["fw"])
    ground.hline(lx - 6, lx + 6, ly - 55, P["s0"]); ground.hline(lx - 4, lx + 4, ly - 57, P["fr"])
    ground.rect(lx - 3, ly - 12, 4, 7, P["e1"])
    # seagulls on the right cliff
    for (gx, gy) in ((590, 104), (602, 110), (612, 98)):
        for dx, dy, c in ((0, 0, P["fw"]), (1, 0, P["fw"]), (-1, -1, P["s4"]), (2, -1, P["s4"]), (0, 1, P["fo"])):
            ground.put(gx + dx, gy + dy, c)

    dx0, dx1, dock_top = _dock(ground, pond, rnd, [P["w2"], P["w3"], P["w2"], P["w1"]], P["w0"], P["w0"], P["w3"])
    # coiled rope and a harpoon rack on the pier
    for a in range(0, 360, 20):
        ground.put(int(dx0 + 10 + math.cos(math.radians(a)) * 4), int(318 + math.sin(math.radians(a)) * 3), P["e6"])
    for i in range(14):
        ground.put(dx1 - 8, 300 + i, P["s3"])
    ground.put(dx1 - 9, 299, P["s5"]); ground.put(dx1 - 7, 299, P["s5"]); ground.put(dx1 - 8, 298, P["s6"])

    # --- WATER
    sea_ramp = [P["o8"], P["o7"], P["o6"], P["o5"], P["o4"], P["o3"], P["o2"], P["o1"], P["o0"]]
    wn = Noise(91, 9.0)
    for y in range(HORIZON, H):
        for x in range(W):
            if not wp[x, y]:
                continue
            d = d_in[y][x]
            D = 0.25 + min(1.0, d / 10.0) * 0.2 + (wn.fbm(x, y, 2) - 0.5) * 0.16
            D += abyss[x, y] / 255.0 * 0.5 - sand[x, y] / 255.0 * 0.25 + swell[x, y] / 255.0 * 0.05
            D += max(0.0, (120 - y) / 90.0) * 0.25  # the far sea darkens toward the horizon
            if dx0 - 2 <= x <= dx1 + 5 and y >= dock_top - 2:
                D += 0.2
            c = sharp_pick(sea_ramp, D, x, y, 2.4)
            if sand[x, y] > 140 and wn.at(x * 2, y * 2) > 0.3:
                c = sharp_pick([P["t3"], P["t2"], P["t1"], P["t0"]], D, x, y, 2.2)
            if y < HORIZON + 3:
                c = P["o6"] if (x // 3) % 2 else P["o5"]
            wcv.put(x, y, c)
            spark = 255 if abyss[x, y] < 120 else 140
            foam = 255 if (d <= 1 and (x, y) not in bank and y > HORIZON + 2) else 0
            flow.put(x, y, (spark, foam, 0, 255))
    # coral heads under the surface
    for (c, r, x0, y0) in cells_of(pond, "C"):
        for _ in range(6):
            cx, cy = x0 + rnd.randint(5, cw - 6), y0 + rnd.randint(6, ch - 5)
            col = rnd.choice([(P["c1"], P["c2"]), (P["fo"], P["c3"]), (P["fv2"], P["fv"]), (P["fy2"], P["fy"])])
            for k in range(rnd.randint(4, 8)):
                a = rnd.uniform(-math.pi, 0)
                ln = rnd.randint(2, 5)
                for s in range(ln):
                    wcv.put(int(cx + math.cos(a) * s), int(cy + math.sin(a) * s), col[0] if s < ln - 1 else col[1])
    # kelp forest: tall swaying strands reaching the surface
    for (c, r, x0, y0) in cells_of(pond, "K"):
        for k in range(7):
            bx = x0 + 4 + k * 8 + rnd.randint(-2, 2)
            by = y0 + ch - 2
            ln = rnd.randint(14, ch - 4)
            for s in range(ln):
                x = bx + int(math.sin(s * 0.35 + k) * 2)
                wcv.put(x, by - s, P["g2"] if s % 4 else P["g3"])
                if s % 5 == 2:
                    wcv.put(x + 1, by - s, P["g4"])
            props.put(bx + int(math.sin(ln * 0.35 + k) * 2), by - ln, P["g5"])
            props.put(bx + int(math.sin(ln * 0.35 + k) * 2) + 1, by - ln, P["g4"])
    # the shipwreck: a dark hull and a broken mast breaking the surface
    for (c, r, x0, y0) in cells_of(pond, "W"):
        hx, hy = x0 + 8, y0 + ch // 2 + 4
        for i in range(cw - 16):
            depth = int(6 - abs(i - (cw - 16) / 2) / 5)
            for j in range(max(2, depth)):
                wcv.put(hx + i, hy + j, nearest(mix(P["e1"], P["o2"], 0.45)))
            if i % 5 == 0:
                wcv.put(hx + i, hy - 1, nearest(mix(P["e2"], P["o3"], 0.4)))
        mx = hx + (cw - 16) // 2 + rnd.randint(-6, 6)
        for s in range(14):
            props.put(mx + s // 5, hy - 2 - s, P["e2"] if s > 3 else nearest(mix(P["e2"], P["o4"], 0.5)))
            props.put(mx + s // 5 + 1, hy - 2 - s, P["e1"])
        props.hline(mx - 3, mx + 6, hy - 11, P["e2"])
        props.put(mx + 3, hy - 16, P["fp2"]); props.put(mx + 4, hy - 16, P["fr"]); props.put(mx + 4, hy - 15, P["fr"])
    # storm swells: rolling white crests
    for (c, r, x0, y0) in cells_of(pond, "X"):
        for k in range(4):
            sx, sy = x0 + rnd.randint(2, cw - 22), y0 + 6 + k * 9
            for i in range(rnd.randint(12, 20)):
                yy = sy + int(math.sin(i * 0.5) * 1.5)
                wcv.put(sx + i, yy, P["n9"] if i % 4 else P["o8"])
                wcv.put(sx + i, yy + 1, P["o5"])
    # the abyss: a faint ring of light far below + sinking glints
    for (c, r, x0, y0) in cells_of(pond, "A"):
        if rnd.random() < 0.5:
            cx, cy = x0 + cw // 2, y0 + ch // 2
            for a in range(0, 360, 9):
                wcv.put(int(cx + math.cos(math.radians(a)) * 9), int(cy + math.sin(math.radians(a)) * 4), P["o3"])
    # sea stacks and buoys
    for (x, y) in ((96, 60), (548, 66), (70, 200), (570, 205)):
        pts = draw_rock(props, x, y, rnd.uniform(6, 9), rnd.uniform(5, 7), rnd.randint(0, 999), rock_ramp, P["s0"], top=(P["n8"], P["n9"]))
        ys = max(p[1] for p in pts)
        for (px, py) in pts:
            if py == ys:
                props.put(px, py + 1, P["n9"]); props.put(px + 2, py + 2, P["o7"])
    for (bx, by) in ((228, 232), (414, 236)):
        props.rect(bx, by - 6, 4, 6, P["fr"]); props.rect(bx, by - 4, 4, 2, P["fw"]); props.put(bx + 1, by - 8, P["fy"])
        props.hline(bx - 1, bx + 4, by, P["o7"])

    # --- foreground: palm fronds hanging into the bottom corners
    shadow: set = set()
    for (x, y, h) in ((14, 360, 48), (628, 362, 52)):
        palm(canopy, x, y, h, rnd, shadow)
    apply_shadow(ground, shadow, 0.25, only=lambda x, y: canopy.get(x, y)[3] == 0)
    _lantern(ground, dx0 - 4, dock_top + 6)
    _lantern(ground, dx1 + 2, dock_top + 6)
    _save(out, {"sky": sky, "water": wcv, "flow": flow, "ground": ground, "props": props, "canopy": canopy}, "trench")


def make_thumbs():
    """Map thumbnails: 1:1 crops of each composite (no resampling)."""
    base = os.path.join(ART, "world")
    for pid, (cx, cy) in (("willow", (322, 226)), ("frostmere", (322, 236)), ("delta", (322, 236)), ("trench", (322, 236))):
        Image.open(os.path.join(base, pid, "_preview.png")).crop((cx - 64, cy - 32, cx + 64, cy + 32)).save(os.path.join(base, pid, "thumb.png"))


if __name__ == "__main__":
    ponds = load_json("data/ponds.json")
    which = sys.argv[1:] or ["delta", "trench", "thumbs"]
    if "delta" in which:
        gen_delta(ponds)
    if "trench" in which:
        gen_trench(ponds)
    if "thumbs" in which:
        make_thumbs()
