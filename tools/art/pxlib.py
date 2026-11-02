"""Small pixel-art toolkit used by all PONDLIGHT art scripts.

Everything is drawn at native resolution (1 image pixel = 1 game pixel),
with a fixed palette, ordered dithering and cluster shading - the same
techniques you would use by hand in Aseprite.
"""
from __future__ import annotations

import json
import math
import os
import random
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GAME = os.path.join(ROOT, "pondlight")
ART = os.path.join(GAME, "assets", "art")


def hexc(h: str, a: int = 255) -> tuple:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# ---------------------------------------------------------------- palette
P = {k: hexc(v) for k, v in {
    # saturated forest greens (owner: rich, vivid)
    "g0": "#0b2418", "g1": "#123821", "g2": "#18502a", "g3": "#1f6a31",
    "g4": "#2a8536", "g5": "#3aa23b", "g6": "#56c043", "g7": "#86dc4c",
    "g8": "#bdf06a", "g9": "#e6fb9a",
    # earth / bark
    "e0": "#1f130c", "e1": "#3a2414", "e2": "#56361f", "e3": "#74492a",
    "e4": "#946036", "e5": "#b57f4b", "e6": "#d6a96f", "e7": "#ecd2a0",
    # wood UI
    "w0": "#2a170c", "w1": "#4a2b17", "w2": "#6b4021", "w3": "#8c592d",
    "w4": "#ad7439", "w5": "#cc934e", "w6": "#e8b86f",
    # parchment
    "p0": "#fff6dc", "p1": "#f4e6c0", "p2": "#e3cc98", "p3": "#c7a670", "p4": "#9a7a4c",
    # water (willow)
    "a0": "#082a35", "a1": "#0c3c48", "a2": "#105160", "a3": "#136a74",
    "a4": "#1a8689", "a5": "#28a39d", "a6": "#46c1ad", "a7": "#7fdcc2", "a8": "#c4f5e2",
    # stone
    "s0": "#1c1d26", "s1": "#33363f", "s2": "#4c5059", "s3": "#686e77",
    "s4": "#8a919a", "s5": "#b0b7bd", "s6": "#d6dbde",
    # flowers & accents
    "fp": "#ff6f91", "fp2": "#c9406a", "fy": "#ffd84a", "fy2": "#e09a1f", "fw": "#fff8ee",
    "fv": "#a57bf0", "fv2": "#6c4bbd", "fo": "#ff9a3c", "fr": "#e2433a",
    "gold0": "#7a4a12", "gold1": "#c07a1c", "gold2": "#f2a531", "gold3": "#ffd04a", "gold4": "#fff0a0",
    # snow / ice (frostmere)
    "n0": "#141c38", "n1": "#1f2c52", "n2": "#2c406f", "n3": "#3d5a8f",
    "n4": "#5a7db0", "n5": "#7fa3cf", "n6": "#a7c6e6", "n7": "#cfe3f5", "n8": "#eef7ff", "n9": "#ffffff",
    "i0": "#0a2a3e", "i1": "#0f4058", "i2": "#165a78", "i3": "#2a7fa3", "i4": "#56a9cc",
    "i5": "#8fd0e8", "i6": "#bde8f5", "i7": "#e2f8ff",
    # pine
    "q0": "#0a1f22", "q1": "#0f2f30", "q2": "#15423f", "q3": "#1d5850", "q4": "#287063", "q5": "#3a8a74",
    # jungle river (emerald delta)
    "j0": "#0b2218", "j1": "#103224", "j2": "#174a32", "j3": "#1f6844", "j4": "#2f8a56", "j5": "#54ad66", "j6": "#8fd67a",
    "m0": "#2a2010", "m1": "#3d3018", "m2": "#5a4822", "m3": "#7a6632", "m4": "#9c8848",
    "k0": "#070d0a", "k1": "#0c1712", "k2": "#12231a", "k3": "#1b3326",
    # open sea (leviathan trench)
    "o0": "#040a1c", "o1": "#08142e", "o2": "#0e2246", "o3": "#163464", "o4": "#1f4c86", "o5": "#2c6aa6",
    "o6": "#3f8cc2", "o7": "#5fb8d8", "o8": "#8edcea",
    "t0": "#1e8a96", "t1": "#34b0b0", "t2": "#62d2c6", "t3": "#9aeadc",
    "c0": "#8a2a4a", "c1": "#c9406a", "c2": "#ff7a6a", "c3": "#ffb08a",
    "y0": "#c8a868", "y1": "#e0c488", "y2": "#f2dcaa", "y3": "#fff0cc",
    "ink": "#120c08", "black": "#000000", "white": "#ffffff",
}.items()}

CLEAR = (0, 0, 0, 0)

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def bayer(x: int, y: int) -> float:
    return (BAYER4[y & 3][x & 3] + 0.5) / 16.0


def ramp_pick(ramp: list, t: float, x: int, y: int) -> tuple:
    """Pick a colour from a ramp with ordered dithering between steps."""
    t = max(0.0, min(0.9999, t))
    f = t * (len(ramp) - 1)
    i = int(f)
    frac = f - i
    if i + 1 < len(ramp) and frac > bayer(x, y):
        return ramp[i + 1]
    return ramp[i]


# ---------------------------------------------------------------- noise
class Noise:
    def __init__(self, seed: int, scale: float):
        self.r = random.Random(seed)
        self.scale = scale
        self.cache: dict = {}
        self.seed = seed

    def _g(self, ix: int, iy: int) -> float:
        k = (ix, iy)
        v = self.cache.get(k)
        if v is None:
            h = (ix * 374761393 + iy * 668265263 + self.seed * 2147483647) & 0xFFFFFFFF
            h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
            v = (h & 0xFFFF) / 65535.0
            self.cache[k] = v
        return v

    def at(self, x: float, y: float) -> float:
        x /= self.scale
        y /= self.scale
        ix, iy = math.floor(x), math.floor(y)
        fx, fy = x - ix, y - iy
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        a = self._g(ix, iy)
        b = self._g(ix + 1, iy)
        c = self._g(ix, iy + 1)
        d = self._g(ix + 1, iy + 1)
        return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy

    def fbm(self, x: float, y: float, octaves: int = 3) -> float:
        tot, amp, norm, s = 0.0, 1.0, 0.0, 1.0
        for _ in range(octaves):
            tot += amp * self.at(x * s, y * s)
            norm += amp
            amp *= 0.5
            s *= 2.0
        return tot / norm


# ---------------------------------------------------------------- canvas
class Canvas:
    def __init__(self, w: int, h: int, fill=CLEAR):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), fill)
        self.px = self.img.load()

    def put(self, x: int, y: int, c) -> None:
        if c is None:
            return
        if 0 <= x < self.w and 0 <= y < self.h:
            if len(c) == 4 and c[3] < 255:
                if c[3] == 0:
                    return
                o = self.px[x, y]
                a = c[3] / 255.0
                oa = o[3] / 255.0
                na = a + oa * (1 - a)
                if na <= 0:
                    return
                r = tuple(int((c[i] * a + o[i] * oa * (1 - a)) / na) for i in range(3))
                self.px[x, y] = (*r, int(na * 255))
            else:
                self.px[x, y] = c

    def get(self, x: int, y: int):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return CLEAR

    def rect(self, x0, y0, w, h, c):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                self.put(x, y, c)

    def hline(self, x0, x1, y, c):
        for x in range(x0, x1 + 1):
            self.put(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(y0, y1 + 1):
            self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def ellipse_fill(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.put(x, y, c)

    def blit(self, other: "Canvas", ox: int, oy: int):
        for y in range(other.h):
            for x in range(other.w):
                c = other.px[x, y]
                if c[3] > 0:
                    self.put(ox + x, oy + y, c)

    def save(self, path: str, scale: int = 1):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img = self.img
        if scale != 1:
            img = img.resize((self.w * scale, self.h * scale), Image.NEAREST)
        img.save(path)


def outline(cv: Canvas, color, diagonal: bool = False) -> Canvas:
    """Return a new canvas with a 1-px outline around opaque pixels."""
    out = Canvas(cv.w, cv.h)
    nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if diagonal:
        nb += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
    for y in range(cv.h):
        for x in range(cv.w):
            if cv.px[x, y][3] > 0:
                out.px[x, y] = cv.px[x, y]
                continue
            for dx, dy in nb:
                if cv.get(x + dx, y + dy)[3] > 0:
                    out.px[x, y] = color
                    break
    return out


def mask_from_canvas(cv: Canvas) -> Image.Image:
    return cv.img.split()[3].point(lambda a: 255 if a > 0 else 0)


def load_json(rel: str):
    with open(os.path.join(GAME, rel), "r", encoding="utf-8") as f:
        return json.load(f)


def mix(c1, c2, t: float):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)) + (255,)


def shade_sphere(nx: float, ny: float, light=(-0.6, -0.8)) -> float:
    """Lambert-ish light for a normalized position inside a blob (-1..1)."""
    d2 = nx * nx + ny * ny
    nz = math.sqrt(max(0.0, 1.0 - min(1.0, d2)))
    lx, ly = light
    lz = 0.6
    ln = math.sqrt(lx * lx + ly * ly + lz * lz)
    return max(0.0, (nx * lx + ny * ly + nz * lz) / ln)
