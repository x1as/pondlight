"""12 original fish sprites, side view, facing right.

Each species has its own silhouette (profile curve, hump, nose, tail type),
fin layout, pattern and special features - not recolours of one sprite.
"""
from __future__ import annotations

import math
import os
import random

from pxlib import ART, P, Canvas, hexc, outline, bayer

OUT = os.path.join(ART, "fish")


def ramp_at(ramp, t, x, y, sharp=2.4):
    t = max(0.0, min(0.9999, t))
    f = t * (len(ramp) - 1)
    i = int(f)
    frac = (f - i - 0.5) * sharp + 0.5
    if i + 1 < len(ramp) and frac > bayer(x, y):
        return ramp[i + 1]
    return ramp[i]


def C(h):
    return hexc(h)


SPECIES = {
    "bluegill": dict(L=30, H=22, hump=0.55, nose=0.75, top=1.05, bot=0.95, stalk=2.5, tail="fork", tail_len=8,
                     ramp=["#1f3a5c", "#2f5d7a", "#5d8f7a", "#c9b45a", "#ffd76a"], fin="#3e6f6a", fin2="#2a4a55",
                     pattern="bars_faint", pat="#24465e", dorsal=[(0.2, 0.75, 6, "spiny")], anal=(0.15, 0.4, 5),
                     ear=True, eye="#1a1a1a"),
    "river_perch": dict(L=36, H=16, hump=0.6, nose=0.9, top=1.15, bot=0.85, stalk=2.5, tail="fork", tail_len=8,
                        ramp=["#2d4a1f", "#4f7a2c", "#8fae45", "#d9d48a", "#f4f0c8"], fin="#ff8a3c", fin2="#d0582a",
                        pattern="bars", pat="#24361a", dorsal=[(0.4, 0.75, 7, "spiny"), (0.12, 0.36, 5, "soft")],
                        anal=(0.12, 0.3, 5), eye="#d0a020"),
    "silver_carp": dict(L=42, H=20, hump=0.5, nose=0.8, top=1.1, bot=0.95, stalk=3.5, tail="fork", tail_len=10,
                        ramp=["#4a5868", "#7d8d9c", "#b6c3cc", "#dfe6ea", "#ffffff"], fin="#9aa7b2", fin2="#6d7a86",
                        pattern="scales", pat="#8a98a5", dorsal=[(0.3, 0.6, 6, "soft")], anal=(0.12, 0.3, 4),
                        barbels=True, eye="#ffd04a"),
    "golden_tench": dict(scaled=False, L=38, H=17, hump=0.5, nose=0.85, top=1.0, bot=1.0, stalk=4.0, tail="square", tail_len=9,
                         ramp=["#4a4210", "#7a6a18", "#b89a2a", "#e3c652", "#fff0a0"], fin="#6b5a16", fin2="#4a3e10",
                         pattern="velvet", pat="#d4b23c", dorsal=[(0.38, 0.6, 7, "round")], anal=(0.15, 0.32, 6),
                         pectoral_big=True, eye="#e2433a"),
    "moonlit_eel": dict(L=60, H=8, eel=True, ramp=["#141a2e", "#262f4a", "#3d4a6a", "#8a96b8", "#d6defa"],
                        fin="#2a3352", fin2="#1a2038", pattern="lateral", pat="#cfe0ff", eye="#cfe0ff"),
    "willow_pike": dict(L=56, H=15, hump=0.45, nose=0.7, top=0.95, bot=1.0, stalk=3.0, tail="fork", tail_len=11,
                        ramp=["#1d3a1c", "#2f5a28", "#5f8a3a", "#b6c46a", "#eef0c0"], fin="#6a7a2a", fin2="#a35a2a",
                        pattern="pike_spots", pat="#d8e07a", dorsal=[(0.08, 0.26, 7, "soft")], anal=(0.08, 0.24, 6),
                        jaw=True, eye="#ffd04a"),
    "ice_minnow": dict(scaled=False, L=26, H=8, hump=0.55, nose=0.95, top=1.0, bot=1.0, stalk=1.5, tail="fork", tail_len=6,
                       ramp=["#5aa0c8", "#8fd0e8", "#bde8f5", "#e2f8ff", "#ffffff"], fin="#bde8f5", fin2="#8fd0e8",
                       pattern="stripe", pat="#2a7fa3", dorsal=[(0.42, 0.6, 3, "soft")], anal=(0.2, 0.36, 3),
                       translucent=0.78, eye="#0a2a3e"),
    "arctic_char": dict(L=40, H=14, hump=0.5, nose=0.95, top=1.0, bot=1.05, stalk=3.0, tail="fork", tail_len=9,
                        ramp=["#2c3e52", "#4a6278", "#8a9aa8", "#e2563a", "#ff9a6a"], fin="#e2563a", fin2="#fff8ee",
                        pattern="char_spots", pat="#ffd0b0", dorsal=[(0.35, 0.58, 6, "soft")], anal=(0.15, 0.3, 5),
                        fin_edge=True, eye="#1a1a1a"),
    "snow_whitefish": dict(L=38, H=15, hump=0.5, nose=0.65, top=1.1, bot=0.92, stalk=2.5, tail="fork", tail_len=10,
                           ramp=["#5a6a82", "#8fa3bd", "#c8d6e6", "#eef4fb", "#ffffff"], fin="#a7c6e6", fin2="#7fa3cf",
                           pattern="scales_fine", pat="#b0c4da", dorsal=[(0.38, 0.6, 6, "soft")], anal=(0.15, 0.3, 4),
                           small_mouth=True, eye="#1f2c52"),
    "glass_pike": dict(scaled=False, L=52, H=13, hump=0.45, nose=0.72, top=0.95, bot=1.0, stalk=2.5, tail="fork", tail_len=10,
                       ramp=["#2a7fa3", "#56a9cc", "#8fd0e8", "#bde8f5", "#e2f8ff"], fin="#8fd0e8", fin2="#56a9cc",
                       pattern="glass", pat="#e2f8ff", dorsal=[(0.08, 0.24, 6, "soft")], anal=(0.08, 0.22, 5),
                       jaw=True, translucent=0.7, eye="#0a2a3e"),
    "aurora_salmon": dict(L=50, H=17, hump=0.5, nose=1.0, top=1.1, bot=0.95, stalk=3.0, tail="fork", tail_len=11,
                          ramp=["#1f3a5a", "#2c6a7a", "#3fae8a", "#b98ae0", "#ffd0f0"], fin="#3a6a8a", fin2="#8a5ac0",
                          pattern="aurora", pat="#7affc8", dorsal=[(0.38, 0.58, 7, "soft"), (0.12, 0.18, 3, "adipose")],
                          anal=(0.12, 0.28, 5), hook=True, eye="#1a1a1a"),
    "frost_sturgeon": dict(scaled=False, L=64, H=14, hump=0.45, nose=0.95, top=1.0, bot=0.8, stalk=3.0, tail="heterocercal", tail_len=13,
                           ramp=["#2a3442", "#46566a", "#6f8296", "#b8c6d4", "#e6eef6"], fin="#46566a", fin2="#2a3442",
                           pattern="scutes", pat="#e6eef6", dorsal=[(0.12, 0.26, 6, "soft")], anal=(0.1, 0.22, 5),
                           barbels=True, snout=True, eye="#1a1a1a"),
}


def lighten(c, a=0.35):
    return tuple(int(v + (255 - v) * a) for v in c[:3]) + (255,)


def darken_c(c, a=0.25):
    return tuple(int(v * (1 - a)) for v in c[:3]) + (255,)


def draw_fish(sid: str, sp: dict) -> Canvas:
    rnd = random.Random(sid)
    if sp.get("eel"):
        return draw_eel(sp)
    k = sp.get("k", 1.35)
    L, Hh = round(sp["L"] * k), round(sp["H"] * k)
    tl = round(sp["tail_len"] * k)
    pad = 4
    Wc = L + tl + pad * 2 + 2
    Hc = Hh + 18
    cv = Canvas(Wc, Hc)
    x0 = pad + tl  # tail base x
    cy = Hc // 2 + 1
    ramp = [C(h) for h in sp["ramp"]]
    fin, fin2 = C(sp["fin"]), C(sp["fin2"])
    p_ = math.log(0.5) / math.log(sp["hump"])

    def hh(t):
        t = max(0.0, min(1.0, t))
        v = math.sin(math.pi * (t ** p_))
        v = max(0.0, v) ** sp["nose"] if t > sp["hump"] else max(0.0, v) ** 0.8
        return max(sp["stalk"] * (1 - t) ** 3, v * Hh / 2)

    def top(t):
        return cy - hh(t) * sp["top"]

    def bot(t):
        return cy + hh(t) * sp["bot"]

    # ---- fins behind the body
    for (a, b, h, kind) in sp.get("dorsal", []):
        h = h * k
        for x in range(int(x0 + a * L), int(x0 + b * L) + 1):
            t = (x - x0) / L
            rel = min(1.0, max(0.0, (t - a) / max(0.01, (b - a))))
            if kind == "spiny":
                fh = h * (0.55 + 0.45 * math.sin(math.pi * min(1, rel * 1.1))) + (1 if x % 2 else 0)
            elif kind == "round":
                fh = h * max(0.0, math.sin(math.pi * rel)) ** 0.6
            elif kind == "adipose":
                fh = h * math.sin(math.pi * rel)
            else:
                fh = h * (1 - rel) ** 0.4 * min(1.0, rel * 4 + 0.3)
            for y in range(int(top(t) - fh), int(top(t)) + 1):
                c = fin2 if x % 3 == 0 else fin  # rays
                if kind == "spiny" and x % 2 == 0:
                    c = fin2
                if y <= int(top(t) - fh) + 1 and kind != "spiny":
                    c = lighten(fin)
                cv.put(x, y, c)
            if sp.get("fin_edge"):
                cv.put(x, int(top(t) - fh), C("#fff8ee"))
    if "anal" in sp:
        a, b, h = sp["anal"]
        h = h * k
        for x in range(int(x0 + a * L), int(x0 + b * L) + 1):
            t = (x - x0) / L
            rel = min(1.0, max(0.0, (t - a) / max(0.01, (b - a))))
            fh = h * max(0.0, math.sin(math.pi * rel)) ** 0.7
            for y in range(int(bot(t)), int(bot(t) + fh) + 1):
                cv.put(x, y, fin2 if x % 3 == 0 else fin)
            if sp.get("fin_edge"):
                cv.put(x, int(bot(t) + fh), C("#fff8ee"))
    # pelvic fin
    px = int(x0 + L * 0.5)
    for i in range(5 if not sp.get("pectoral_big") else 7):
        for j in range(i // 2 + 1):
            cv.put(px - i + j, int(bot((px - x0) / L)) + i // 2, fin2 if j == 0 else fin)
    # ---- tail
    ty = cy
    stalk = sp["stalk"] * k
    for x in range(pad, x0 + 1):
        u = (x0 - x) / tl  # 0 at base, 1 at tip
        kind = sp["tail"]
        if kind == "fork":
            spread = stalk + u * (Hh * 0.55)
            notch = u * u * Hh * 0.45
            for y in range(int(ty - spread), int(ty + spread) + 1):
                if abs(y - ty) < notch - 1:
                    continue
                edge = abs(y - ty) >= spread - 1
                ray = int(abs(y - ty) + u * 2) % 3 == 0
                cv.put(x, y, fin2 if (edge or ray) else fin)
        elif kind == "square":
            spread = stalk + u * Hh * 0.45
            for y in range(int(ty - spread), int(ty + spread) + 1):
                cv.put(x, y, fin2 if int(abs(y - ty)) % 3 == 0 else fin)
        elif kind == "heterocercal":
            up = stalk + u * Hh * 0.75
            dn = stalk + u * Hh * 0.25
            for y in range(int(ty - up), int(ty + dn) + 1):
                if y > ty and u > 0.7:
                    continue
                cv.put(x, y, fin2 if int(abs(y - ty)) % 3 == 0 else fin)
    # ---- body
    pts = []
    for x in range(x0, x0 + L + 1):
        t = (x - x0) / L
        y0, y1 = top(t), bot(t)
        for y in range(int(math.floor(y0)), int(math.ceil(y1)) + 1):
            if y < y0 - 0.4 or y > y1 + 0.4:
                continue
            s = (y - y0) / max(1.0, (y1 - y0))
            col = ramp_at(ramp, s * 1.02 - 0.02, x, y)
            if 0.22 < s < 0.32 and 0.15 < t < 0.85:
                col = ramp[min(len(ramp) - 1, ramp.index(col) + 1)] if col in ramp else col
            if y - y0 < 1.2 and 0.12 < t < 0.9:
                col = lighten(ramp[1])  # rim light along the back (light from the top-left)
            elif y1 - y < 1.2:
                col = darken_c(col)  # belly falls into shadow
            elif sp.get("scaled", True) and 0.12 < t < 0.8 and 0.15 < s < 0.85 and (x + (y % 4 // 2) * 2) % 4 == 0 and y % 2 == 0:
                col = darken_c(col, 0.12)  # scale crescents
            cv.put(x, y, col)
            pts.append((x, y, t, s))
    pset = {(x, y) for x, y, _, _ in pts}
    pat = C(sp["pat"])
    pattern = sp["pattern"]
    for (x, y, t, s) in pts:
        if t > 0.86:
            continue
        if pattern == "bars" and t > 0.12 and int(t * 7) % 2 == 0 and s < 0.75 and (x % 7) < 3:
            cv.put(x, y, pat)
        elif pattern == "bars_faint" and t > 0.15 and (x % 6) < 2 and s < 0.6 and (x + y) % 2:
            cv.put(x, y, pat)
        elif pattern == "scales" and t > 0.1 and s < 0.85:
            if (x + (y // 3) * 2) % 4 == 0 and y % 3 == 0:
                cv.put(x, y, pat)
        elif pattern == "scales_fine" and t > 0.1 and (x + y) % 4 == 0 and s < 0.7:
            cv.put(x, y, pat)
        elif pattern == "velvet" and s < 0.45 and (x * 3 + y * 5) % 11 == 0:
            cv.put(x, y, pat)
        elif pattern == "pike_spots" and t > 0.05 and s > 0.15 and s < 0.75:
            if (x // 3 + y // 2) % 3 == 0 and (x + y) % 2 == 0 and rnd.random() < 0.55:
                cv.put(x, y, pat)
        elif pattern == "char_spots" and s < 0.6 and rnd.random() < 0.06:
            cv.put(x, y, pat)
        elif pattern == "stripe" and 0.42 < s < 0.56:
            cv.put(x, y, pat)
        elif pattern == "glass":
            if abs(s - 0.48) < 0.06:
                cv.put(x, y, C("#e2f8ff"))  # spine
            elif x % 3 == 0 and 0.2 < s < 0.8 and t > 0.08:
                cv.put(x, y, C("#bde8f5"))  # ribs
        elif pattern == "aurora":
            band = math.sin(x * 0.35 + s * 6.0)
            if 0.35 < s < 0.7 and band > 0.55:
                cv.put(x, y, C("#7affc8") if band > 0.8 else C("#c98aff"))
            if s < 0.4 and (x + y) % 9 == 0:
                cv.put(x, y, C("#1a2a3e"))
        elif pattern == "scutes":
            if s < 0.08 and x % 5 == 0:
                cv.put(x, y, pat); cv.put(x, y - 1, pat)
            if abs(s - 0.5) < 0.06 and x % 5 == 2:
                cv.put(x, y, pat)
            if s > 0.88 and x % 6 == 3:
                cv.put(x, y, pat)
    # lateral line
    for x in range(x0 + 2, x0 + int(L * 0.8)):
        t = (x - x0) / L
        y = int(top(t) + (bot(t) - top(t)) * 0.38)
        if (x, y) in pset and x % 2 == 0 and pattern not in ("glass", "stripe"):
            c = cv.get(x, y)
            cv.put(x, y, tuple(max(0, v - 30) for v in c[:3]) + (255,))
    # gill arc
    gx = x0 + int(L * 0.78)
    for y in range(int(top(0.78)) + 2, int(bot(0.78)) - 1):
        off = int(1.5 * math.sin(math.pi * (y - top(0.78)) / max(1, bot(0.78) - top(0.78))))
        cv.put(gx - off, y, ramp[0])
    if sp.get("ear"):
        for y in range(int(cy - 2), int(cy + 2)):
            for x in range(gx - 3, gx):
                cv.put(x, y, C("#141a2a"))
        cv.put(gx - 3, int(cy + 1), C("#ff8a3c"))
    # eye
    ex = x0 + int(L * (0.88 if not sp.get("jaw") else 0.82))
    ey = int(top((ex - x0) / L) + (bot((ex - x0) / L) - top((ex - x0) / L)) * 0.35)
    eye = C(sp["eye"])
    for dx in range(-1, 3):
        for dy in range(-1, 3):
            if abs(dx - 0.5) + abs(dy - 0.5) <= 2.0:
                cv.put(ex + dx, ey + dy, darken_c(ramp[0], 0.3))
    cv.put(ex, ey, eye); cv.put(ex + 1, ey, eye); cv.put(ex, ey + 1, eye); cv.put(ex + 1, ey + 1, C("#000000"))
    cv.put(ex, ey, C("#ffffff"))
    # mouth / jaws
    mx = x0 + L
    my = int(cy + (1 if not sp.get("small_mouth") else 2))
    if sp.get("jaw"):
        for i in range(1, 6 if not sp.get("translucent") else 4):
            half = 2 if i < 3 else 1  # duckbill tapers to the tip
            for dy in range(-half, half + 1):
                cv.put(mx + i, my + dy, ramp[0] if dy == 0 else (ramp[2] if dy < 0 else ramp[3]))
        for i in range(0, 5):
            cv.put(mx - i, my, ramp[0])
    elif sp.get("snout"):
        for i in range(1, 6):
            cv.put(mx + i, my - 2 + i // 3, ramp[2]); cv.put(mx + i, my - 1 + i // 3, ramp[1])
            if i < 3:
                cv.put(mx + i, my + i // 3, ramp[1])
    else:
        cv.put(mx - 1, my, ramp[0]); cv.put(mx - 2, my, ramp[0])
    if sp.get("hook"):
        cv.put(mx, my + 1, ramp[1]); cv.put(mx + 1, my + 1, ramp[1]); cv.put(mx + 1, my, ramp[1])
    if sp.get("barbels"):
        bx = mx - (0 if not sp.get("snout") else -3)
        for i in range(4):
            cv.put(bx - i // 2, my + 2 + i, C(sp["fin2"]))
    # pectoral fin on the flank (in front)
    pcx = gx - 3
    pcy = int(cy + Hh * 0.15)
    big = 6 if sp.get("pectoral_big") else 4
    for i in range(big):
        for j in range(max(1, (big - i) // 2)):
            cv.put(pcx - i, pcy + j + i // 3, fin if j else fin2)

    if sp.get("translucent"):
        a = int(255 * sp["translucent"])
        for (x, y) in pset:
            c = cv.get(x, y)
            cv.px[x, y] = (c[0], c[1], c[2], a)
    return outline(cv, C("#120c08") if not sp.get("translucent") else C("#0a2a3e"))


def draw_eel(sp: dict) -> Canvas:
    L, Hh = sp["L"], sp["H"]
    Wc, Hc = L + 10, 30
    cv = Canvas(Wc, Hc)
    ramp = [C(h) for h in sp["ramp"]]
    fin, fin2 = C(sp["fin"]), C(sp["fin2"])
    x0 = 4

    def cyf(t):
        return Hc / 2 + math.sin(t * math.pi * 1.6 + 0.6) * 5.0

    def hh(t):
        if t > 0.9:
            return Hh / 2 * (1 - (t - 0.9) / 0.1) ** 0.5 + 1.2
        return 1.2 + (Hh / 2 - 1.2) * min(1.0, t * 2.4)

    pts = []
    for x in range(x0, x0 + L + 1):
        t = (x - x0) / L
        c = cyf(t)
        h = hh(t)
        # continuous fin fringe
        for y in range(int(c - h - 2), int(c + h + 3)):
            if t < 0.82:
                cv.put(x, y, fin if (x + y) % 3 else fin2)
        for y in range(int(math.floor(c - h)), int(math.ceil(c + h)) + 1):
            s = (y - (c - h)) / max(1.0, 2 * h)
            cv.put(x, y, ramp_at(ramp, s, x, y))
            pts.append((x, y, t, s))
    for (x, y, t, s) in pts:
        if abs(s - 0.42) < 0.09 and 0.05 < t < 0.85 and x % 2 == 0:
            cv.put(x, y, C(sp["pat"]))
    ex = x0 + int(L * 0.93)
    ey = int(cyf(0.93) - 1)
    cv.put(ex, ey, C("#cfe0ff")); cv.put(ex + 1, ey, C("#000000"))
    cv.put(x0 + L - 1, int(cyf(1.0)) + 1, ramp[0])
    return outline(cv, C("#06080f"))


def main():
    os.makedirs(OUT, exist_ok=True)
    sheet = Canvas(80 * 4, 40 * 3, (40, 60, 50, 255))
    for i, (sid, sp) in enumerate(SPECIES.items()):
        cv = draw_fish(sid, sp)
        # crop to content
        bbox = cv.img.getbbox()
        img = cv.img.crop(bbox)
        img.save(os.path.join(OUT, f"fish_{sid}.png"))
        sx, sy = (i % 4) * 80 + 4, (i // 4) * 40 + 4
        sheet.img.alpha_composite(img, (sx, sy))
    sheet.img.resize((sheet.w * 3, sheet.h * 3), 0).save(os.path.join(OUT, "_sheet.png"))
    print("fish done")


if __name__ == "__main__":
    main()
