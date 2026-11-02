"""Frostmere Lake diorama: sky band, mountains, snowy pines, frozen lake with ice holes."""
from __future__ import annotations

import math
import os
import random

from PIL import Image

from pxlib import ART, P, Canvas, Noise
from gen_world import (H, W, apply_shadow, build_water_mask, cell_wh, cells_of, darken, distance_layers,
                       draw_rock, draw_trunk, reed_cluster, sharp_pick)


def draw_pine(cv: Canvas, x, base_y, h, rnd, shadow_pts=None, snow=True):
    tiers = max(3, int(h / 9))
    top = base_y - h
    pts = set()
    # trunk
    for yy in range(base_y - 4, base_y + 1):
        for xx in (x - 1, x, x + 1):
            cv.put(xx, yy, P["e1"] if xx != x - 1 else P["e2"])
    for t in range(tiers):
        ty0 = top + int(t * h * 0.8 / tiers)
        ty1 = ty0 + int(h * 0.38)
        ty1 = min(ty1, base_y - 3)
        for yy in range(ty0, ty1 + 1):
            f = (yy - ty0) / max(1, (ty1 - ty0))
            half = (1.5 + f * (3.2 + t * 2.6 * (h / 40.0))) * (0.9 + 0.1 * math.sin(yy * 1.7 + x))
            jag = 1 if (yy + t) % 3 == 0 and f > 0.6 else 0
            for xx in range(int(x - half) - jag, int(x + half) + 1 + jag):
                rel = (xx - (x - half)) / max(1.0, 2 * half)
                if rel < 0.32:
                    c = P["q4"]
                elif rel < 0.62:
                    c = P["q3"]
                elif rel < 0.85:
                    c = P["q2"]
                else:
                    c = P["q1"]
                if f > 0.85 and rel > 0.2:
                    c = P["q1"]
                cv.put(xx, yy, c)
                pts.add((xx, yy))
            # snow on the upper-left of each tier
            if snow and f < 0.55:
                for xx in range(int(x - half), int(x + half * 0.2) + 1):
                    if (xx, yy - 1) not in pts or f < 0.12:
                        cv.put(xx, yy, P["n9"] if f < 0.3 else P["n8"])
        if snow:
            # drooping snow lip at the tier bottom
            for xx in range(int(x - 3 - t * 2.2 * (h / 40.0)), int(x + 1)):
                if rnd.random() < 0.6:
                    cv.put(xx, ty1 - 1, P["n8"])
                    if rnd.random() < 0.3:
                        cv.put(xx, ty1, P["n7"])
    cv.put(x, top - 1, P["n9"] if snow else P["q4"])
    for (px, py) in list(pts):
        for dx, dy in ((1, 0), (-1, 0), (0, 1)):
            if (px + dx, py + dy) not in pts and cv.get(px + dx, py + dy) not in (P["n9"], P["n8"], P["n7"]):
                cv.put(px + dx, py + dy, P["q0"])
    if shadow_pts is not None:
        for (px, py) in pts:
            shadow_pts.add((px + 8, py + int((base_y - py) * 0.15) + 5))
    return pts


def gen_frost(ponds):
    pond = next(p for p in ponds["ponds"] if p["id"] == "frostmere")
    out = os.path.join(ART, "world", "frostmere")
    os.makedirs(out, exist_ok=True)
    rnd = random.Random(99)
    cw, chh = cell_wh(pond)
    SKY = 44
    lake = build_water_mask(pond, 17, blur=10, bias=100, wobble=70, lobes=10)
    lp = lake.load()
    d_out = distance_layers(lake, 8, False)
    d_in = distance_layers(lake, 10, True)

    sky = Canvas(W, H)
    ground = Canvas(W, H)
    water = Canvas(W, H)
    flow = Canvas(W, H, (0, 0, 0, 255))
    props = Canvas(W, H)
    canopy = Canvas(W, H)
    shadow_pts: set = set()

    # ---------------------------------------------------------- sky band
    sky_ramp = [P["n4"], P["n5"], P["n6"], P["n7"], P["n8"]]
    for y in range(0, SKY + 6):
        for x in range(W):
            t = y / float(SKY)
            sky.put(x, y, sharp_pick(sky_ramp, t, x, y, 1.6))
    cn = Noise(5, 18.0)
    for y in range(2, 22):
        for x in range(W):
            v = cn.fbm(x * 0.7, y * 2.2, 3)
            if v > 0.6:
                sky.put(x, y, P["n8"] if v > 0.68 else P["n7"])

    # ---------------------------------------------------------- mountains
    mn = Noise(8, 30.0)
    far = [int(10 + mn.fbm(x, 0, 3) * 20 - 8 * math.sin(x / 90.0)) for x in range(W)]
    near = [int(22 + Noise(9, 22.0).fbm(x, 5, 3) * 16) for x in range(W)]
    def slope(arr, x):
        return arr[min(W - 1, x + 4)] - arr[max(0, x - 4)]
    for x in range(W):
        sf = slope(far, x)
        for y in range(far[x], SKY + 4):
            t = 0.5 + sf * 0.06 + (y - far[x]) * 0.012
            c = sharp_pick([P["n6"], P["n5"], P["n4"]], t, x, y, 1.8)
            if y - far[x] < 4 + (x * 7) % 3:
                c = P["n9"] if sf >= 0 else P["n7"]
            ground.put(x, y, c)
        sn_ = slope(near, x)
        for y in range(near[x], SKY + 4):
            t = 0.5 + sn_ * 0.07
            c = sharp_pick([P["n4"], P["n3"], P["n2"]], t, x, y, 1.8)
            if y - near[x] < 3:
                c = P["n8"] if sn_ >= 0 else P["n6"]
            ground.put(x, y, c)

    # ---------------------------------------------------------- snowfield + ice
    sn = Noise(31, 30.0)
    sn2 = Noise(32, 6.0)
    snow_ramp = [P["n6"], P["n7"], P["n8"], P["n9"]]
    ice_ramp = [P["i4"], P["i5"], P["i6"], P["i7"]]
    bank = {}
    for y in range(H):
        for x in range(W):
            if lp[x, y]:
                for k in range(1, 4):
                    if y - k < 0 or lp[x, y - k] == 0:
                        bank[(x, y)] = k
                        break
    in2 = Noise(41, 14.0)
    for y in range(SKY - 4, H):
        for x in range(W):
            if y < SKY + 4 and ground.get(x, y)[3] and not lp[x, y]:
                continue
            if lp[x, y]:
                if (x, y) in bank:
                    ground.put(x, y, [P["n7"], P["n6"], P["n5"]][bank[(x, y)] - 1])
                    continue
                t = 0.55 + (in2.fbm(x * 0.6, y * 1.8, 3) - 0.5) * 0.9
                t += (1 - min(1.0, d_in[y][x] / 8.0)) * 0.25
                c = sharp_pick(ice_ramp, t, x, y, 2.2)
                ground.put(x, y, c)
            else:
                t = sn.fbm(x, y, 2) * 0.7 + sn2.at(x, y) * 0.3 + 0.15
                ground.put(x, y, sharp_pick(snow_ramp, t, x, y, 2.4))
                d = d_out[y][x]
                if d == 1:
                    ground.put(x, y, P["n6"])
    # ice cracks & reflections
    for _ in range(26):
        cells = cells_of(pond, "#")
        c, r, x0, y0 = rnd.choice(cells)
        x, y = x0 + rnd.randint(0, cw), y0 + rnd.randint(0, chh)
        ang = rnd.uniform(0, math.tau)
        for s in range(rnd.randint(8, 22)):
            ang += rnd.uniform(-0.6, 0.6)
            x += math.cos(ang)
            y += math.sin(ang) * 0.6
            ix, iy = int(x), int(y)
            if lp[ix % W, iy % H] and (ix, iy) not in bank:
                ground.put(ix, iy, P["i3"])
                ground.put(ix, iy + 1, P["i7"])
    for k in range(9):
        x0, y0 = rnd.randint(100, 520), rnd.randint(60, 270)
        for s in range(rnd.randint(8, 16)):
            x, y = x0 + s, y0 - s // 2
            if lp[x, y] and (x, y) not in bank:
                ground.put(x, y, P["n9"])
    # snow drifts on the ice
    dn = Noise(61, 9.0)
    for y in range(SKY, H):
        for x in range(W):
            if lp[x, y] and (x, y) not in bank and dn.fbm(x, y * 1.6, 2) > 0.66:
                ground.put(x, y, P["n9"] if dn.at(x * 2, y * 2) > 0.5 else P["n8"])

    # ---------------------------------------------------------- ice holes
    for (c, r, x0, y0) in cells_of(pond, "oOvc"):
        ch = pond["layout"][r][c]
        cx, cy = x0 + cw / 2, y0 + chh / 2 + 1
        rx, ry = (13.0, 7.6) if ch in "Oc" else (11.0, 6.6)
        # shoveled snow ring on the near side
        for y in range(int(cy - ry - 4), int(cy + ry + 6)):
            for x in range(int(cx - rx - 6), int(cx + rx + 7)):
                ex, ey = (x + 0.5 - cx) / (rx + 5), (y + 0.5 - cy - 1.5) / (ry + 4)
                e = ex * ex + ey * ey
                if e <= 1.0 and ey > -0.2:
                    ground.put(x, y, P["n9"] if ey < 0.45 else (P["n8"] if e < 0.8 else P["n6"]))
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                ex, ey = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                e = ex * ex + ey * ey
                if e <= 1.0:
                    # inner ice wall on the far side
                    depth_from_top = y - (cy - ry * math.sqrt(max(0.0, 1 - ex * ex)))
                    if depth_from_top < 3.2:
                        ground.put(x, y, [P["i5"], P["i4"], P["i3"], P["i3"]][min(3, int(depth_from_top))])
                    else:
                        ground.put(x, y, (0, 0, 0, 0))
                        ground.px[x, y] = (0, 0, 0, 0)
                        wt = (y - cy) / ry
                        col = P["i1"] if wt < 0.1 else P["i2"]
                        if ch == "O":
                            col = P["i0"] if wt < 0.3 else P["i1"]
                        water.put(x, y, col)
                        flow.put(x, y, (200, 255 if e > 0.72 else 0, 0, 255))
                elif e <= 1.0 + 2.4 / rx:
                    ground.put(x, y, P["i7"] if (y > cy) else P["i3"])
        if ch == "v":
            pass
    # tip-up flags next to some holes (classic ice-fishing markers)
    for (c, r, x0, y0) in cells_of(pond, "oc")[:5]:
        fx, fy = x0 + cw - 12, y0 + 10
        for yy in range(fy - 9, fy + 1):
            props.put(fx, yy, P["e2"])
        props.put(fx + 1, fy - 9, P["fr"]); props.put(fx + 2, fy - 9, P["fr"]); props.put(fx + 3, fy - 8, P["fr"])
        props.put(fx + 1, fy - 8, P["fr"]); props.put(fx + 2, fy - 8, P["fp2"]); props.put(fx + 1, fy - 7, P["fp2"])
        props.put(fx, fy + 1, P["n6"]); props.put(fx - 1, fy + 1, P["n7"]); props.put(fx + 1, fy + 1, P["n7"])

    # ---------------------------------------------------------- dock / ice walkway
    dcells = cells_of(pond, "D")
    dmid = (min(c[2] for c in dcells) + max(c[2] for c in dcells) + cw) // 2
    dx0, dx1 = dmid - 22, dmid + 22
    dock_top = min(c[3] for c in dcells) - 4
    for y in range(dock_top, H):
        plank = (y - dock_top) // 6
        gap = (y - dock_top) % 6 == 5
        for x in range(dx0, dx1 + 1):
            if x in (dx0, dx1):
                ground.put(x, y, P["w0"])
            elif gap:
                ground.put(x, y, P["w1"])
            else:
                base = [P["w2"], P["w3"], P["w2"], P["w4"]][plank % 4]
                if (y - dock_top) % 6 == 0:
                    base = P["n8"] if (x + plank) % 5 else P["n9"]  # snow on plank edges
                ground.put(x, y, base)
        if (y - dock_top) % 6 == 3:
            ground.put(dx0 + 3, y, P["s4"]); ground.put(dx1 - 3, y, P["s4"])
    for x in range(dx0, dx1 + 1):  # snow along the left rail
        if rnd.random() < 0.7:
            ground.put(x, dock_top, P["n9"])
    # lantern posts
    for (lx, ly) in ((dx0 - 3, dock_top + 2), (dx1 + 1, dock_top + 2)):
        for yy in range(ly - 10, ly + 6):
            ground.put(lx, yy, P["w1"]); ground.put(lx + 1, yy, P["w2"])
        ground.rect(lx - 1, ly - 15, 4, 5, P["fy"])
        ground.put(lx, ly - 13, P["fw"])
        ground.hline(lx - 1, lx + 2, ly - 16, P["e0"]); ground.hline(lx - 1, lx + 2, ly - 10, P["e0"])
        ground.put(lx - 1, ly - 17, P["n9"]); ground.put(lx, ly - 17, P["n9"]); ground.put(lx + 1, ly - 17, P["n8"])
    # footprints in the snow
    for i in range(26):
        x = 292 - i * 9 + (3 if i % 2 else -3)
        y = 344 - i * 1
        if 0 <= x < W and y < H:
            ground.put(x, y, P["n6"]); ground.put(x + 1, y, P["n5"]); ground.put(x, y + 1, P["n6"])

    # ---------------------------------------------------------- fishing hut (bottom-left)
    hx, hy = 12, 304
    for y in range(hy, hy + 30):
        for x in range(hx, hx + 46):
            c = P["fr"] if (x - hx) % 6 else P["fp2"]
            if (x - hx) < 3:
                c = P["fp2"]
            ground.put(x, y, c)
    for x in range(hx - 6, hx + 52):  # roof with snow
        for y in range(hy - 14, hy + 1):
            if abs(x - (hx + 23)) <= (y - (hy - 14)) * 2.2:
                c = P["e1"] if y > hy - 4 else P["e2"]
                if y < hy - 6:
                    c = P["n9"] if (x + y) % 7 else P["n8"]
                ground.put(x, y, c)
    ground.rect(hx + 18, hy + 12, 10, 18, P["e1"])
    ground.rect(hx + 19, hy + 13, 8, 16, P["e2"])
    ground.put(hx + 25, hy + 21, P["fy"])
    ground.rect(hx + 5, hy + 8, 8, 6, P["fy"])
    ground.rect(hx + 6, hy + 9, 6, 4, P["fy2"])
    ground.hline(hx + 5, hx + 12, hy + 11, P["e1"])
    ground.hline(hx - 1, hx + 47, hy + 30, P["n6"])
    for x in range(hx - 2, hx + 50):
        ground.put(x, hy + 31, P["n5"])
    # stovepipe with smoke-blackened cap
    ground.rect(hx + 36, hy - 20, 4, 10, P["s1"]); ground.hline(hx + 35, hx + 40, hy - 21, P["s0"])

    # ---------------------------------------------------------- rocks & pines
    rock_ramp = [P["s1"], P["s2"], P["s3"], P["s4"]]
    for (x, y, r) in ((574, 120, 6), (586, 128, 4), (62, 150, 5), (52, 158, 3), (584, 226, 6), (60, 236, 4),
                      (150, 300, 4), (470, 304, 5), (96, 70, 4), (548, 66, 5)):
        if not lp[x, y]:
            draw_rock(ground, x, y, r, r * 0.75, rnd.randint(0, 99), rock_ramp, P["s0"], top=(P["n8"], P["n9"]))
    # ridge holes get boulders (props layer so they sit on the ice)
    for (c, r, x0, y0) in cells_of(pond, "c"):
        draw_rock(props, x0 + 9, y0 + 9, 6.0, 4.5, rnd.randint(0, 99), rock_ramp, P["s0"], top=(P["n8"], P["n9"]))
        draw_rock(props, x0 + 16, y0 + 12, 3.5, 2.6, rnd.randint(0, 99), rock_ramp, P["s0"], top=(P["n8"], P["n9"]))
    # treeline behind the lake
    for x in range(-6, W + 6, 7):
        h = rnd.randint(12, 20)
        draw_pine(ground, x + rnd.randint(-2, 2), SKY + 2 + rnd.randint(-2, 2), h, rnd)
    for x in list(range(-4, 70, 12)) + list(range(574, W + 8, 12)):
        h = rnd.randint(20, 30)
        draw_pine(ground, x + rnd.randint(-3, 3), 76 + rnd.randint(0, 10), h, rnd, shadow_pts)
    big = [(20, 150, 42), (50, 196, 36), (12, 240, 40), (44, 284, 34), (110, 362, 40), (600, 150, 44),
           (628, 200, 40), (590, 252, 36), (624, 300, 42), (604, 360, 44), (176, 364, 30), (440, 364, 28)]
    for (x, y, h) in big:
        draw_pine(canopy, x, y, h, rnd, shadow_pts)
    # frozen reeds along the edges
    for (x, y) in ((76, 262), (566, 262), (70, 108), (572, 104)):
        if lp[x, y]:
            continue
        reed_cluster(props, x, y, rnd, 6, 6, 13, [P["e3"], P["e4"], P["e6"]], head=False, snow=True)

    apply_shadow(ground, shadow_pts, 0.28, only=lambda x, y: canopy.get(x, y)[3] == 0 and y > SKY + 6)

    sky.save(os.path.join(out, "sky.png"))
    ground.save(os.path.join(out, "ground.png"))
    water.save(os.path.join(out, "water.png"))
    flow.save(os.path.join(out, "flow.png"))
    props.save(os.path.join(out, "props.png"))
    canopy.save(os.path.join(out, "canopy.png"))
    comp = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    for c in (sky, water, ground, props, canopy):
        comp.alpha_composite(c.img)
    comp.save(os.path.join(out, "_preview.png"))
    print("frostmere done")
