"""Wood-and-leaf UI kit: 9-slice panels, buttons, bars, icons, logo, FX sprites, cursor."""
from __future__ import annotations

import math
import os
import random

from PIL import Image

from pxlib import ART, P, Canvas, Noise, hexc, outline, shade_sphere
from gen_font import G as GLYPHS

UI = os.path.join(ART, "ui")
FX = os.path.join(ART, "fx")
K = P["ink"]


def save(cv: Canvas, name: str, folder=UI):
    os.makedirs(folder, exist_ok=True)
    cv.save(os.path.join(folder, name + ".png"))


# ------------------------------------------------------------------ wood helpers
def wood_fill(cv, x0, y0, w, h, ramp, seed, vertical=False, knots=True):
    """Hand-style wood: long grain lines that drift gently (periodic along the grain so
    9-slice tiling stays seamless), a lighter sheen band and the odd knot."""
    rnd = random.Random(seed)
    along, across = (h, w) if vertical else (w, h)
    phase = rnd.uniform(0, math.tau)
    for j in range(across):
        line_kind = rnd.random()
        for i in range(along):
            drift = 1.1 * math.sin(math.tau * i / max(1, along) + phase + j * 0.7)
            g = (j + drift) % 4.0
            c = ramp[1]
            if g < 0.9 and line_kind > 0.35:
                c = ramp[0]  # dark grain line
            elif 2.0 < g < 2.6 and line_kind < 0.5:
                c = ramp[2]  # light streak
            x, y = (x0 + j, y0 + i) if vertical else (x0 + i, y0 + j)
            cv.put(x, y, c)
    if knots and along > 24 and across >= 20:
        for _ in range(max(1, along * across // 900)):
            ki, kj = rnd.randint(6, along - 7), rnd.randint(4, across - 5)
            for di in range(-4, 5):
                for dj in range(-2, 3):
                    d = (di / 4.0) ** 2 + (dj / 2.2) ** 2
                    if d <= 1.0:
                        c = ramp[0] if d < 0.18 or 0.7 < d else (ramp[2] if di < 0 else ramp[1])
                        x, y = (x0 + kj + dj, y0 + ki + di) if vertical else (x0 + ki + di, y0 + kj + dj)
                        cv.put(x, y, c)


def leaf(cv, x, y, ang, size, rnd):
    """A small hand-placed leaf: dark outline, two-tone fill, highlight vein."""
    pts = set()
    for s in range(-size, size + 1):
        for t in range(-size, size + 1):
            u = s / size
            wdt = (1 - u * u) * 0.5
            if abs(t / size) <= wdt:
                px = x + s * math.cos(ang) - t * math.sin(ang)
                py = y + s * math.sin(ang) + t * math.cos(ang)
                pts.add((int(round(px)), int(round(py))))
    for (px, py) in pts:
        cv.put(px, py, P["g6"])
    for s in range(-size + 1, size):
        px = x + s * math.cos(ang)
        py = y + s * math.sin(ang)
        cv.put(int(round(px)), int(round(py)), P["g7"] if s < 0 else P["g5"])
    for (px, py) in pts:
        if (px + 1, py + 1) not in pts:
            cv.put(px, py, P["g4"])
    for (px, py) in list(pts):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (px + dx, py + dy) not in pts and cv.get(px + dx, py + dy) not in (P["g6"], P["g5"], P["g4"], P["g7"]):
                cv.put(px + dx, py + dy, P["g1"])


def sprig(cv, x, y, flip, rnd):
    d = -1 if flip else 1
    leaf(cv, x + 4 * d, y + 3, math.radians(20 if not flip else 160), 4, rnd)
    leaf(cv, x + 2 * d, y + 7, math.radians(80 if not flip else 100), 3, rnd)
    leaf(cv, x + 8 * d, y + 1, math.radians(-15 if not flip else 195), 3, rnd)
    cv.put(x + 1 * d, y + 2, P["fp"]); cv.put(x + 2 * d, y + 2, P["fw"]); cv.put(x + 1 * d, y + 3, P["fw"])
    cv.put(x + 2 * d, y + 3, P["fy"])


# ------------------------------------------------------------------ panels
def panel_wood(name, size=48, frame=6, inner=(P["w1"], P["w2"], P["w3"]), leaves=True, seed=1):
    cv = Canvas(size, size)
    rnd = random.Random(seed)
    frame_ramp = [P["w3"], P["w4"], P["w5"]]
    # frame planks
    wood_fill(cv, 1, 1, size - 2, frame, frame_ramp, seed)
    wood_fill(cv, 1, size - 1 - frame, size - 2, frame, frame_ramp, seed + 1)
    wood_fill(cv, 1, 1, frame, size - 2, frame_ramp, seed + 2, vertical=True)
    wood_fill(cv, size - 1 - frame, 1, frame, size - 2, frame_ramp, seed + 3, vertical=True)
    # inner field
    wood_fill(cv, 1 + frame, 1 + frame, size - 2 - 2 * frame, size - 2 - 2 * frame, list(inner), seed + 4)
    # bevels
    cv.hline(1, size - 2, 1, P["w6"])
    cv.vline(1, 1, size - 2, P["w5"])
    cv.hline(1, size - 2, size - 2, P["w1"])
    cv.vline(size - 2, 1, size - 2, P["w2"])
    # inner groove
    cv.hline(frame, size - 1 - frame, frame, P["w0"])
    cv.vline(frame, frame, size - 1 - frame, P["w0"])
    cv.hline(frame, size - 1 - frame, size - 1 - frame, P["w4"])
    cv.vline(size - 1 - frame, frame, size - 1 - frame, P["w3"])
    cv.hline(frame + 1, size - 2 - frame, frame + 1, P["w1"])
    # outline with rounded corners
    for x in range(size):
        cv.put(x, 0, K); cv.put(x, size - 1, K)
    for y in range(size):
        cv.put(0, y, K); cv.put(size - 1, y, K)
    for (x, y) in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)):
        cv.px[x, y] = (0, 0, 0, 0)
    for (x, y) in ((1, 1), (size - 2, 1), (1, size - 2), (size - 2, size - 2)):
        cv.put(x, y, K)
    # brass nails
    for (x, y) in ((3, 3), (size - 5, 3), (3, size - 5), (size - 5, size - 5)):
        cv.put(x, y, P["gold3"]); cv.put(x + 1, y, P["gold2"]); cv.put(x, y + 1, P["gold2"]); cv.put(x + 1, y + 1, P["gold0"])
    if leaves:
        sprig(cv, 2, 0, False, rnd)
        sprig(cv, size - 3, 0, True, rnd)
    save(cv, name)


def panel_parchment(name, size=24):
    cv = Canvas(size, size)
    n = Noise(3, 3.0)
    for y in range(size):
        for x in range(size):
            v = n.at(x, y)
            c = P["p1"]
            if v > 0.8:
                c = P["p2"]
            elif v < 0.12:
                c = P["p0"]
            cv.put(x, y, c)
    for i in range(size):
        cv.put(i, 1, P["p2"]); cv.put(1, i, P["p2"])
        cv.put(i, size - 2, P["p3"]); cv.put(size - 2, i, P["p3"])
        cv.put(i, 0, P["p4"]); cv.put(0, i, P["p4"]); cv.put(i, size - 1, P["p4"]); cv.put(size - 1, i, P["p4"])
    for (x, y) in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)):
        cv.px[x, y] = (0, 0, 0, 0)
    save(cv, name)


def panel_dark(name, size=16):
    """Small dark tooltip / slot plate."""
    cv = Canvas(size, size)
    wood_fill(cv, 0, 0, size, size, [P["w0"], P["w1"], P["w2"]], 77, knots=False)
    cv.hline(1, size - 2, 1, P["w0"])
    cv.hline(1, size - 2, size - 2, P["w2"])
    for i in range(size):
        cv.put(i, 0, K); cv.put(0, i, K); cv.put(i, size - 1, K); cv.put(size - 1, i, K)
    for (x, y) in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)):
        cv.px[x, y] = (0, 0, 0, 0)
    save(cv, name)


def button(name, ramp, rim, shadow, pressed=False, w=24, h=16, accent=None):
    cv = Canvas(w, h)
    top = 1 if pressed else 0
    wood_fill(cv, 1, 1 + top, w - 2, h - 3, ramp, hash(name) % 1000)
    if not pressed:
        cv.hline(2, w - 3, 1, rim)
        cv.hline(1, w - 2, h - 3, shadow)
        cv.hline(1, w - 2, h - 2, P["w0"])
    else:
        cv.hline(1, w - 2, 1, P["w0"])
        cv.hline(1, w - 2, 2, shadow)
    for x in range(w):
        cv.put(x, 0, K); cv.put(x, h - 1, K)
    for y in range(h):
        cv.put(0, y, K); cv.put(w - 1, y, K)
    for (x, y) in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        cv.px[x, y] = (0, 0, 0, 0)
    if accent:
        for x in range(1, w - 1):
            cv.put(x, 0, accent); cv.put(x, h - 1, accent)
        for y in range(1, h - 1):
            cv.put(0, y, accent); cv.put(w - 1, y, accent)
    # brass pins in the (non-tiled) end caps
    py = (h - 3) // 2 + (1 if pressed else 0)
    for px_ in (2, w - 4):
        cv.put(px_, py, P["gold3"]); cv.put(px_ + 1, py, P["gold2"]); cv.put(px_, py + 1, P["gold1"]); cv.put(px_ + 1, py + 1, P["gold0"])
    save(cv, name)


def focus_frame(name, size=16):
    cv = Canvas(size, size)
    for i in range(size):
        for (x, y) in ((i, 0), (0, i), (i, size - 1), (size - 1, i)):
            cv.put(x, y, P["gold3"])
    for (x, y) in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)):
        cv.px[x, y] = (0, 0, 0, 0)
    for (x, y) in ((1, 1), (size - 2, 1), (1, size - 2), (size - 2, size - 2)):
        cv.put(x, y, P["gold4"])
    save(cv, name)


def bars():
    cv = Canvas(12, 8)
    for y in range(8):
        for x in range(12):
            cv.put(x, y, P["w0"] if y < 2 else P["w1"])
    for i in range(12):
        cv.put(i, 0, K); cv.put(i, 7, K)
    for i in range(8):
        cv.put(0, i, K); cv.put(11, i, K)
    cv.hline(1, 10, 6, P["w2"])
    save(cv, "bar_frame")
    fills = {
        "green": (P["g8"], P["g6"], P["g4"]), "gold": (P["gold4"], P["gold3"], P["gold1"]),
        "red": (P["fp"], P["fr"], P["fp2"]), "blue": (P["a8"], P["a6"], P["a4"]),
        "cream": (P["p0"], P["p1"], P["p3"]), "purple": (hexc("#ead2ff"), hexc("#c983ff"), hexc("#7a46b0")),
    }
    for k, (a, b, c) in fills.items():
        f = Canvas(4, 6)
        for x in range(4):
            f.put(x, 0, a); f.put(x, 1, b); f.put(x, 2, b); f.put(x, 3, b); f.put(x, 4, c); f.put(x, 5, c)
        save(f, "bar_fill_" + k)


# ------------------------------------------------------------------ icons (12x12 hand pixel maps)
IC = {
    ".": None, "k": K, "y": P["gold3"], "Y": P["gold2"], "o": P["gold1"], "O": P["gold4"], "w": P["fw"],
    "g": P["g6"], "G": P["g4"], "d": P["g2"], "b": P["e3"], "B": P["e2"], "l": P["e5"], "r": P["fr"],
    "R": P["fp2"], "c": P["a6"], "C": P["a4"], "n": P["n8"], "N": P["n6"], "s": P["s4"], "S": P["s2"],
    "p": P["p1"], "P": P["p3"], "u": P["i5"], "U": P["i3"], "v": P["fv"],
    "V": P["fv2"],
}
ICONS = {
    "book": ["............", "..kkkkkkkk..", ".kGgggggGpk.", ".kGgyyyygpk.", ".kGgyGGygpk.", ".kGgyyyygpk.",
             ".kGgggggGpk.", ".kGgggggGpk.", ".kGgggggGpk.", ".kdddddddPk.", "..kkkkkkkk..", "............"],
    "bag": ["............", ".....kk.....", "....kllk....", "...kkBBkk...", "....kbbk....", "...kllllk...",
            "..klllbllk..", ".kllblllllk.", ".klllllblbk.", ".kbllllllbk.", "..kbbbbbbk..", "...kkkkkk..."],
    "shop": ["............", ".kkkkkkkkkk.", "krwrwrwrwrwk", "krwrwrwrwrwk", ".kkkkkkkkkk.", ".kb......bk.",
             ".kb.kkkk.bk.", ".kb.kyyk.bk.", ".kb.kkkk.bk.", ".kbbbbbbbbk.", ".kBBBBBBBBk.", "..kkkkkkkk.."],
    "map": ["............", ".kkkkkkkkkk.", ".kpppppppPk.", ".kpccppGGpk.", ".kpcCcpGgpk.", ".kppccpppPk.",
            ".kpppprkpPk.", ".kpPpprrppk.", ".kpppppppPk.", ".kPPPPPPPPk.", ".kkkkkkkkkk.", "............"],
    "rod": ["..........k.", ".........kb.", "........kb.w", ".......kb..w", "......kb...w", ".....kb....w",
            "....kb.....w", "...kyb.....r", "..kyk......r", ".kyk.......w", "kbk.........", "kk.........."],
    "worm": ["............", "............", "......kkk...", ".....krrRk..", "....krRkrk..", "...krRk.kk..",
             "..krRk......", ".krRk..kk...", ".krk..krRk..", "..kRkkrRk...", "...kRRRk....", "....kkk....."],
    "larva": ["............", "............", "...kkkkkk...", "..kOyyoyyk..", ".kOyyoyyoyk.", ".kyyoyyoyyk.",
              ".kyoyyoyyok.", "..kyyoyyok..", "...kkkkkk...", "............", "............", "............"],
    "grub": ["............", "............", "...kkkkkk...", "..kwggGggk..", ".kwggGggGgk.", ".kggGggGggk.",
             ".kgGggGggGk.", "..kggGggGk..", "...kkkkkk...", "............", "............", "............"],
    "frost": ["............", ".....kk.....", "....kuUk....", "...kuuUUk...", "..kuuwuUUk..", "..kuwuuUUk..",
              "..kuuuUUUk..", "...kuuUUk...", "....kuUk....", ".....kk.....", ".....kk.....", "....k..k...."],
    "rain": ["............", "....kkkk....", "..kkNnnnk...", ".kNnnnnnnkk.", "kNnnnnnnnNNk", "kNNNNNNNNNNk",
             ".kkkkkkkkkk.", "..c..c..c...", ".c..c..c....", "............", "..c..c..c...", ".c..c..c...."],
    "snow": [".....n......", "...n.n.n....", "....nnn.....", ".n...n...n..", "..n..n..n...", "nnnnnwnnnnn.",
             "..n..n..n...", ".n...n...n..", "....nnn.....", "...n.n.n....", ".....n......", "............"],
    "check": ["............", "..........k.", ".........kgk", "........kggk", "..k....kggk.", ".kgk..kggk..",
              ".kggkkggk...", "..kgggggk...", "...kgggk....", "....kgk.....", ".....k......", "............"],
    "close": ["............", ".kk......kk.", "krrk....krrk", ".krrk..krrk.", "..krrkkrrk..", "...krrrrk...",
              "...krrrrk...", "..krrkkrrk..", ".krrk..krrk.", "krrk....krrk", ".kk......kk.", "............"],
    "trophy": ["............", ".kkkkkkkkkk.", "kykOyyyyyoyk", "kykOyyyyyoyk", ".kkOyyyyyok.", "..kOyyyyyok.",
               "...kyyyyok..", "....kyyok...", ".....kok....", "....kyyok...", "...kooooook.", "...kkkkkkk.."],
    "scroll": ["............", ".kkkkkkkkk..", "kPppppppPpk.", ".kpPPPPppk..", ".kppppppPk..", ".kpPPPPPpk..",
               ".kppppppPk..", ".kpPPPpppk..", ".kppppppPk..", "kPppppppPpk.", ".kkkkkkkkk..", "............"],
    "mouse": ["............", "...kkkkkk...", "..krrkwwwk..", "..krrkwwwk..", "..krrkwwwk..", "..kkkkkkkk..",
              "..kwwwwwwk..", "..kwwwwwwk..", "..kwwwwwwk..", "...kwwwwk...", "....kkkk....", "............"],
    "pad_a": ["............", "...kkkkkk...", "..kGGGGGGk..", ".kGGGwwGGGk.", ".kGGwGGwGGk.", ".kGGwGGwGGk.",
              ".kGGwwwwGGk.", ".kGGwGGwGGk.", ".kGGwGGwGGk.", "..kGGGGGGk..", "...kkkkkk...", "............"],
    "pad_b": ["............", "...kkkkkk...", "..kRRRRRRk..", ".kRRwwwRRRk.", ".kRRwRRwRRk.", ".kRRwwwRRRk.",
              ".kRRwRRwRRk.", ".kRRwRRwRRk.", ".kRRwwwRRRk.", "..kRRRRRRk..", "...kkkkkk...", "............"],
    "fish": ["............", "............", ".....kkkk...", "k...kccCck..", "kk.kccccwkk.", "kCkcccccckck",
             "kCCccccccCk.", "kCkcCcCcck..", "kk.kCCCCk...", "k...kkkk....", "............", "............"],
    "lock": ["............", "....kkkk....", "...kSssSk...", "..kSk..kSk..", "..kSk..kSk..", ".kkkkkkkkkk.",
             ".kyOyyyyyok.", ".kyyykkyyok.", ".kyyykkyyok.", ".kyyyyyyyok.", ".kkkkkkkkkk.", "............"],
    "star": ["............", ".....kk.....", "....kOyk....", "....kyyk....", "kkkkkyyokkkk", "kOyyyyyyyyok",
             ".kkyyyyyokk.", "..kyyyyyyk..", "..kyyokyyk..", ".kyok..kyok.", ".kkk....kkk.", "............"],
    "sun": ["............", ".....yy.....", "..y......y..", "....kkkk....", "...kOyyyk...", ".yykyyyyokyy",
            ".yykyyyyokyy", "...kyyyook..", "....kkkk....", "..y......y..", ".....yy.....", "............"],
    "moon": ["............", ".....kkkk...", "...kknnk....", "..knnnk.....", ".knnnk......", ".knnNk......",
             ".knnNk......", ".knnnNk.....", "..knnnNkkkk.", "...knnnnnk..", "....kkkkk...", "............"],
    "gear": ["............", ".....kk.....", "..k.kssk.k..", ".kskssssksk.", "..ksskkssk..", ".kssk..kssk.",
             ".kssk..kssk.", "..ksskkssk..", ".kskssssksk.", "..k.kssk.k..", ".....kk.....", "............"],
    "reel": ["............", "....kkkk....", "...kSssSk...", "..ksskkssk..", "..kskyyksk..", "..kskyyksk..",
             "..ksskkssk..", "...kSssSkkk.", "....kkkk.kbk", "..........k.", "............", "............"],
    "line": ["............", "..kkkkkkkk..", "..kbbbbbbk..", "...kwwwwk...", "...kwPwwk...", "...kwwPwk...",
             "...kwwwwk...", "...kwPwwk...", "..kbbbbbbk..", "..kkkkkkkk..", "............", "............"],
    "charm": ["............", "..kk...kk...", ".kggk.kggk..", ".kgGgkgGgk..", "..kgggggk...", ".kggkgkggk..",
              ".kgGgkgGgk..", "..kkk.kkk...", ".....kk.....", "......kk....", ".......k....", "............"],
    "shrimp": ["............", "....kkkk....", "...kRrrrk...", "..kRrrwrrk..", ".kRrrrrrrk..", ".kRrkkkrrk..",
               ".krk...krk..", "..k...krrk..", ".....krrk...", "....krrk.kk.", "....kkk.krk.", ".........k.."],
    "squid": ["....kkkk....", "...kvvvvk...", "..kvvwvvvk..", "..kvvvvvVk..", "..kvwkvwVk..", "..kvvvvvVk..",
              "...kvvvVk...", "..kvkvkVkk..", ".kvk.vk.Vk..", ".kk.kv.kVk..", "....kk..kk..", "............"],
    "chum": ["............", "..kkkkkkkk..", ".krRrRrrRrk.", ".kSssssssSk.", "..kssssssk..", "..kSssssSk..",
             "..ksssssskk.", "..kSssssSk..", "...kssssk...", "...kkkkkk...", "............", "............"],
    "fly": ["............", "..kk....kk..", ".kwwk..kwwk.", ".kwwwkkwwwk.", "..kwwkkwwk..", "....kyyk....",
            "...kyOyyk...", "...kyyyok...", "....kyok....", ".....kk.....", "............", "............"],
    "chest": ["............", "..kkkkkkkk..", ".kbBBBBBBbk.", ".kBbbbbbbBk.", "kkkkkkkkkkkk", "kBbbbyybbbBk",
              "kbbbkyykbbbk", "kbbbbkkbbbbk", "kBbbbbbbbbBk", "kbbbbbbbbbbk", "kkkkkkkkkkkk", "............"],
    "wave": ["............", "............", "......kkk...", "....kkcwwk..", "...kcck.kwk.", "..kcck....k.",
             ".kccCk...kk.", "kcCCCCkkkck.", "kCCCCCCCCCk.", "kCCCCCCCCCCk", ".kkkkkkkkkk.", "............"],
    "target": ["............", "....kkkk....", "..kkrwwrkk..", "..krwkkwrk..", ".krwkrrkwrk.", ".kwkrkkrkwk.",
               ".kwkrkkrkwk.", ".krwkrrkwrk.", "..krwkkwrk..", "..kkrwwrkk..", "....kkkk....", "............"],
    "clover": ["............", "...kk..kk...", "..kggkkggk..", "..kgGggGgk..", "...kggggk...", ".kkkgggkkk..",
               "kggGgkgGggk.", "kgggk.kgggk.", ".kkk.k.kkk..", ".....k......", "......k.....", "............"],
    "reach": ["............", ".....kk.....", "....kyyk....", "...kyyyyk...", "..kyykkyyk..", "..kkkyykkk..",
              "....kyyk....", "....kyyk....", "....kyyk....", "....kyyk....", "....kkkk....", "............"],
}


def icons():
    for name, rows in ICONS.items():
        cv = Canvas(12, 12)
        for y, row in enumerate(rows):
            assert len(row) == 12, (name, y, row)
            for x, ch in enumerate(row):
                c = IC[ch]
                if c is not None:
                    cv.put(x, y, c)
        save(cv, "icon_" + name, os.path.join(UI, "icons"))
    # coin: procedural shaded disc with engraved fish mark
    cv = Canvas(12, 12)
    for y in range(12):
        for x in range(12):
            dx, dy = (x + 0.5 - 6) / 5.2, (y + 0.5 - 6) / 5.2
            if dx * dx + dy * dy <= 1:
                l = shade_sphere(dx, dy)
                c = P["gold1"] if l < 0.35 else (P["gold2"] if l < 0.6 else (P["gold3"] if l < 0.85 else P["gold4"]))
                cv.put(x, y, c)
    for (x, y) in ((4, 5), (5, 4), (6, 4), (7, 5), (6, 6), (5, 6), (3, 4), (3, 6), (8, 5)):
        cv.put(x, y, P["gold1"])
    cv = outline(cv, K)
    save(cv, "icon_coin", os.path.join(UI, "icons"))
    # rarity gems 8x8
    rar = {"common": "#d6dccf", "uncommon": "#7fe36a", "rare": "#4fb6ff", "epic": "#c983ff", "legendary": "#ffbe3d"}
    for k, h in rar.items():
        base = hexc(h)
        cv = Canvas(8, 8)
        for y in range(1, 7):
            for x in range(1, 7):
                if abs(x - 3.5) + abs(y - 3.5) <= 3.2:
                    l = (3.5 - x) * 0.2 + (3.5 - y) * 0.25
                    c = tuple(max(0, min(255, int(v * (1 + l * 0.6)))) for v in base[:3]) + (255,)
                    cv.put(x, y, c)
        cv.put(3, 2, P["white"]); cv.put(2, 3, P["white"])
        cv = outline(cv, K)
        save(cv, "gem_" + k, os.path.join(UI, "icons"))


# ------------------------------------------------------------------ logo
def logo():
    text = "PONDLIGHT"
    s = 3
    gw = sum(len(GLYPHS[c].split("|")[0]) * s + s for c in text) + 10
    cv = Canvas(gw + 8, 7 * s + 22)
    x = 6
    letters = Canvas(cv.w, cv.h)
    for ch in text:
        rows = GLYPHS[ch].split("|")
        for ry, row in enumerate(rows):
            for rx, v in enumerate(row):
                if v == "#":
                    for yy in range(s):
                        for xx in range(s):
                            py = 8 + ry * s + yy
                            t = (ry * s + yy) / (7 * s)
                            c = P["gold4"] if t < 0.18 else (P["gold3"] if t < 0.5 else (P["gold2"] if t < 0.8 else P["gold1"]))
                            if ch in "LIGHT" and text.index(ch) >= 4:
                                c = P["p0"] if t < 0.18 else (P["p1"] if t < 0.5 else (P["p2"] if t < 0.8 else P["p3"]))
                            letters.put(x + rx * s + xx, py, c)
        x += len(rows[0]) * s + s
    # chunky shadow + outline
    for y in range(cv.h):
        for xx in range(cv.w):
            if letters.get(xx, y)[3]:
                for d in range(1, 4):
                    cv.put(xx + d // 2, y + d, P["w0"])
    cv.blit(outline(letters, P["w0"], diagonal=True), 0, 0)
    rnd = random.Random(4)
    leaf(cv, 5, 7, math.radians(-140), 5, rnd)
    leaf(cv, 10, 4, math.radians(-70), 4, rnd)
    leaf(cv, cv.w - 8, 7, math.radians(-40), 5, rnd)
    # the "light": a glowing firefly above the I
    ix = 6 + sum(len(GLYPHS[c].split("|")[0]) * s + s for c in "PONDL") + 1
    for (dx, dy, c) in ((0, 0, P["gold4"]), (1, 0, P["fy"]), (0, 1, P["fy"]), (1, 1, P["gold2"])):
        cv.put(ix + dx, 2 + dy, c)
    for (dx, dy) in ((-1, 0), (2, 0), (0, -1), (1, 2), (-1, 1), (2, 1), (0, 2), (1, -1)):
        cv.put(ix + dx, 2 + dy, (255, 230, 120, 110))
    save(cv, "logo")


# ------------------------------------------------------------------ fx sprites
def fx():
    os.makedirs(FX, exist_ok=True)
    # bobber 7x11: antenna, red cap, white band, body, keel
    rows = ["...k...", "...y...", "..krk..", ".krrrk.", "krrwrrk", "kwwwwwk", "kwwwwPk", ".kwwPk.", "..kPk..",
            "...k...", "......."]
    cmap = {".": None, "k": K, "r": P["fr"], "y": P["fy"], "w": P["fw"], "P": P["p3"]}
    cv = Canvas(7, 11)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if cmap[ch]:
                cv.put(x, y, cmap[ch])
    cv.put(2, 3, P["fp"])
    save(cv, "bobber", FX)
    # leaves for falling-leaf particles (3 variants, 5x4)
    leaves = Canvas(15, 4)
    for i, (a, b) in enumerate(((P["g7"], P["g5"]), (P["fy"], P["fo"]), (P["fo"], P["fr"]))):
        for (x, y, c) in ((1, 0, a), (2, 0, a), (0, 1, a), (1, 1, a), (2, 1, b), (3, 1, a), (1, 2, b), (2, 2, b), (3, 2, b), (4, 3, b)):
            leaves.put(i * 5 + x, y, c)
    save(leaves, "leaves", FX)
    # exclamation bubble 9x12
    rows = [".kkkkkkk.", "kwwwwwwwk", "kwwwrwwwk", "kwwwrwwwk", "kwwwrwwwk", "kwwwrwwwk", "kwwwwwwwk",
            "kwwwrwwwk", "kwwwwwwwk", ".kkkwkkk.", "...kwk...", "....k...."]
    cmap = {".": None, "k": K, "w": P["fw"], "r": P["fr"]}
    cv = Canvas(9, 12)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if cmap[ch]:
                cv.put(x, y, cmap[ch])
    save(cv, "bite_mark", FX)
    # reel side view 13x13 (spool with rim and bolt), crank drawn in code
    cv = Canvas(13, 13)
    for y in range(13):
        for x in range(13):
            dx, dy = (x + 0.5 - 6.5) / 6, (y + 0.5 - 6.5) / 6
            d = dx * dx + dy * dy
            if d <= 1:
                l = shade_sphere(dx, dy)
                c = P["s5"] if l > 0.8 else (P["s4"] if l > 0.55 else (P["s3"] if l > 0.3 else P["s2"]))
                if 0.36 < d < 0.55:
                    c = P["s1"]
                cv.put(x, y, c)
    cv.put(6, 6, P["s6"]); cv.put(5, 5, P["white"])
    save(outline(cv, K), "reel", FX)


def cursor():
    rows = ["k.........", "kk........", "kwk.......", "kwwk......", "kwwwk.....", "kwwwwk....", "kwwwwwk...",
            "kwwwwwwk..", "kwwwwkkkk.", "kwkwwk....", "kk.kwwk...", "k...kwk...", "....kk...."]
    cmap = {".": None, "k": P["w0"], "w": P["p0"]}
    cv = Canvas(10, 13)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if cmap[ch]:
                cv.put(x, y, cmap[ch])
    for x, y in ((1, 2), (1, 3), (1, 4)):
        cv.put(x, y, P["gold3"])
    for sc in (1, 2, 3, 4):
        cv.save(os.path.join(UI, f"cursor_{sc}x.png"), sc)


def app_icon():
    cv = Canvas(32, 32)
    for y in range(32):
        for x in range(32):
            dx, dy = (x + 0.5 - 16) / 14.5, (y + 0.5 - 16) / 14.5
            d = dx * dx + dy * dy
            if d <= 1:
                t = 0.5 + dy * 0.35 - dx * 0.15
                c = P["a3"] if t > 0.62 else (P["a4"] if t > 0.4 else P["a5"])
                if 0.84 < d:
                    c = P["g4"] if dy < 0.2 else P["g3"]
                cv.put(x, y, c)
    for (cx, cy, rx, ry) in ((16, 22, 9, 3), (16, 22, 5, 1.6)):
        for a in range(0, 360, 4):
            cv.put(int(cx + math.cos(math.radians(a)) * rx), int(cy + math.sin(math.radians(a)) * ry), P["a7"])
    bob = Image.open(os.path.join(FX, "bobber.png"))
    cv.img.alpha_composite(bob, (13, 11))
    rnd = random.Random(2)
    leaf(cv, 7, 7, math.radians(-30), 4, rnd)
    leaf(cv, 24, 25, math.radians(150), 3, rnd)
    cv = outline(cv, K)
    big = cv.img.resize((256, 256), Image.NEAREST)
    big.save(os.path.join(UI, "app_icon.png"))
    big.save(os.path.join(UI, "app_icon.ico"), sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])


def main():
    panel_wood("panel_wood", leaves=True)
    panel_wood("panel_wood_plain", leaves=False, seed=5)
    panel_wood("panel_header", size=32, frame=4, inner=(P["w2"], P["w3"], P["w4"]), leaves=True, seed=9)
    panel_parchment("panel_parchment")
    panel_dark("panel_dark")
    button("btn_normal", [P["w3"], P["w4"], P["w5"]], P["w6"], P["w2"])
    button("btn_hover", [P["w4"], P["w5"], P["w6"]], P["p0"], P["w3"], accent=None)
    button("btn_pressed", [P["w2"], P["w3"], P["w4"]], P["w5"], P["w1"], pressed=True)
    button("btn_disabled", [P["s2"], P["s3"], P["s3"]], P["s4"], P["s1"])
    button("btn_green", [P["g3"], P["g4"], P["g5"]], P["g7"], P["g2"])
    button("btn_green_hover", [P["g4"], P["g5"], P["g6"]], P["g8"], P["g3"])
    button("btn_green_pressed", [P["g2"], P["g3"], P["g4"]], P["g5"], P["g1"], pressed=True)
    focus_frame("focus_frame")
    bars()
    icons()
    logo()
    fx()
    cursor()
    app_icon()
    print("ui done")


if __name__ == "__main__":
    main()
