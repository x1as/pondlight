"""Polish SpriteCook outputs into PONDLIGHT-ready pixel art (Aseprite-style cleanup).

For every raw asset in pondlight/assets/art/spritecook/_raw:
  1. crop to content,
  2. downsample to the game's shared pixel density by taking the dominant colour of each block
     (no blurring, no bilinear smear),
  3. quantize to a limited palette,
  4. remove stray single pixels and re-ink a clean 1-px outline,
and write the result next to _raw. Also writes spritecook-assets.json (asset_id + sha12).
"""
from __future__ import annotations

import hashlib
import json
import os
from collections import Counter

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SC = os.path.join(ROOT, "pondlight", "assets", "art", "spritecook")
RAW = os.path.join(SC, "_raw")
INK = (18, 12, 8, 255)

# raw file -> (output name, target width in game pixels, palette size, SpriteCook asset id)
JOBS = {
    "fish_bluegill_sc.png": ("fish_bluegill.png", 46, 20, "3709d88c-05c4-4075-bfe7-6a93141e361c"),
    "fish_river_perch_sc.png": ("fish_river_perch.png", 54, 20, "d4a228ca-d7d9-4a0c-b46a-202ae534bdd3"),
    "fish_silver_carp_sc.png": ("fish_silver_carp.png", 60, 30, "4f093783-a37d-4b2a-8318-d8be23e80221"),
    "fish_golden_tench_sc.png": ("fish_golden_tench.png", 58, 18, "5bacf0b5-e0ea-46c1-93f9-da72a05caf18"),
    "fish_moonlit_eel_sc.png": ("fish_moonlit_eel.png", 74, 16, "aed76803-5afa-4dc8-804a-37179cca8b5f"),
    "fish_willow_pike_sc.png": ("fish_willow_pike.png", 78, 18, "03a3e90b-8aec-4f15-ad45-870b26733fd8"),
    "reel_sc.png": ("reel.png", 24, 16, "e68ac078-a242-4feb-bcc1-3b652627fb0d"),
    "bobber_raw.png": ("bobber.png", 11, 10, "d8eced1a-dfba-420e-830f-55d81c61d428"),
    "trophy_gold_sc.png": ("trophy_gold.png", 22, 14, "6fc5cb9f-c277-411e-bb66-07c38cf63dcc"),
    "frog_guide_sc.png": ("frog_guide.png", 40, 24, "fd3d0ce9-0b50-4152-838c-53a03ce3cc10"),
    # v0.4: Frostmere re-done + two new ponds + treasure chest (second SpriteCook account)
    "fish_ice_minnow_sc.png": ("fish_ice_minnow.png", 36, 16, "4746fd79-43ac-4806-889e-5656a1e48181"),
    "fish_arctic_char_sc.png": ("fish_arctic_char.png", 54, 20, "008eb815-b293-4ce4-9607-231294b62b73"),
    "fish_snow_whitefish_sc.png": ("fish_snow_whitefish.png", 54, 18, "fe2b61f9-a301-4aa3-b250-e0a7e57a4054"),
    "fish_glass_pike_sc.png": ("fish_glass_pike.png", 74, 18, "f3b620b8-0a70-4ca8-b120-497f431f713d"),
    "fish_aurora_salmon_sc.png": ("fish_aurora_salmon.png", 68, 24, "85a8b3fb-4ea3-46f3-bdda-75557846b2ac"),
    "fish_frost_sturgeon_sc.png": ("fish_frost_sturgeon.png", 88, 18, "3a5b8753-dcca-40ad-a578-024790d0c6f0"),
    "fish_piranha_sc.png": ("fish_piranha.png", 46, 20, "d2bc1d50-7e87-40a4-b0cb-c74219474c55"),
    "fish_peacock_bass_sc.png": ("fish_peacock_bass.png", 58, 22, "2d748a7b-aa7b-4fdd-a24e-d4ae109750d0"),
    "fish_arowana_sc.png": ("fish_arowana.png", 74, 18, "13f653da-22cf-45cd-88b1-2792efe35b4c"),
    "fish_electric_eel_sc.png": ("fish_electric_eel.png", 76, 18, "59a3cd9e-8727-449a-ae31-aae87a109f09"),
    "fish_goliath_catfish_sc.png": ("fish_goliath_catfish.png", 82, 18, "94120882-458d-4ded-bf82-3482b80198d1"),
    "fish_arapaima_sc.png": ("fish_arapaima.png", 88, 22, "a2fa30af-093e-492f-aaa9-7278c3e29182"),
    "fish_bluefin_tuna_sc.png": ("fish_bluefin_tuna.png", 70, 20, "f063a62b-3507-42fa-9eb4-11557ea14604"),
    "fish_swordfish_sc.png": ("fish_swordfish.png", 92, 18, "b82a61b4-b25d-469e-9c08-4b7bb052c327"),
    "fish_anglerfish_sc.png": ("fish_anglerfish.png", 52, 20, "10eeb219-82af-491c-b3a6-47f5dc89027f"),
    "fish_coelacanth_sc.png": ("fish_coelacanth.png", 70, 18, "6afec893-601e-4579-888c-c957f7594a1b"),
    "fish_kraken_sc.png": ("fish_kraken.png", 96, 26, "fb1cf93d-4640-4cc1-b853-68eefbd767a9"),
    "fish_megalodon_sc.png": ("fish_megalodon.png", 100, 22, "d759b13e-b406-44da-9ed6-c865c963d06c"),
    "treasure_chest_sc.png": ("treasure_chest.png", 34, 28, "739bcd8e-6bb1-4d52-b5f7-cf4c67ec21b0"),
}
EXTRA = {"trophy_gold_big.png": ("trophy_gold_sc.png", 44, 16)}
# metal ramps (dark -> light) for palette-swapped trophy tiers
TIERS = {
    "bronze": [(70, 34, 12), (120, 64, 22), (168, 98, 40), (206, 138, 66), (234, 180, 108)],
    "silver": [(60, 66, 78), (112, 120, 134), (166, 174, 186), (208, 214, 222), (246, 248, 252)],
    "platinum": [(36, 70, 96), (70, 140, 170), (120, 206, 222), (186, 240, 246), (250, 255, 255)],
}


def retint(img: Image.Image, ramp) -> Image.Image:
    """Map golden (warm, saturated) pixels onto another metal ramp by luminance; keep wood/ink."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if r > 110 and g > 70 and r > b + 40 and g > b + 15:  # gold metal
                lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
                i = min(len(ramp) - 1, int(lum * len(ramp) * 1.05))
                px[x, y] = ramp[i] + (255,)
    return out
ANIM = ("bobber_bob_pixel.webp", "bobber_bob.png", 11, 10, "a0c50c7d-93cf-4ecb-9b95-85cad525b2f9")


def dominant_downsample(img: Image.Image, tw: int, th: int, box=None) -> Image.Image:
    src = img.load()
    bx0, by0, bx1, by1 = box if box else (0, 0, img.width, img.height)
    sx = (bx1 - bx0) / tw
    sy = (by1 - by0) / th
    out = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    op = out.load()
    for y in range(th):
        for x in range(tw):
            x0, x1 = int(bx0 + x * sx), max(int(bx0 + x * sx) + 1, int(bx0 + (x + 1) * sx))
            y0, y1 = int(by0 + y * sy), max(int(by0 + y * sy) + 1, int(by0 + (y + 1) * sy))
            cols = []
            total = 0
            for yy in range(y0, y1):
                for xx in range(x0, x1):
                    total += 1
                    c = src[xx, yy]
                    if c[3] >= 128:
                        # bucket colours so near-identical dither pixels vote together
                        cols.append((c[0] // 12, c[1] // 12, c[2] // 12, c))
            if total == 0 or len(cols) * 2 < total:
                continue
            votes = Counter((a, b, c) for a, b, c, _ in cols)
            key = votes.most_common(1)[0][0]
            members = [c for a, b, cc, c in cols if (a, b, cc) == key]
            r = sum(m[0] for m in members) // len(members)
            g = sum(m[1] for m in members) // len(members)
            b = sum(m[2] for m in members) // len(members)
            op[x, y] = (r, g, b, 255)
    return out


def quantize(img: Image.Image, n: int) -> Image.Image:
    alpha = img.split()[3]
    rgb = Image.new("RGB", img.size, (0, 0, 0))
    rgb.paste(img.convert("RGB"), mask=alpha)
    q = rgb.quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    q.putalpha(alpha.point(lambda a: 255 if a >= 128 else 0))
    return q


def clean_and_ink(img: Image.Image) -> Image.Image:
    px = img.load()
    w, h = img.size

    def solid(x, y):
        return 0 <= x < w and 0 <= y < h and px[x, y][3] > 0

    # drop stray pixels (opaque with at most one opaque 4-neighbour)
    for _ in range(2):
        kill = [(x, y) for y in range(h) for x in range(w)
                if solid(x, y) and sum(solid(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) <= 1]
        for x, y in kill:
            px[x, y] = (0, 0, 0, 0)
    # fill single transparent holes inside the body
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if not solid(x, y) and all(solid(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = px[x - 1, y]
    # re-ink the silhouette: every opaque pixel touching transparency becomes the outline colour
    edge = [(x, y) for y in range(h) for x in range(w)
            if solid(x, y) and not all(solid(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in edge:
        px[x, y] = INK
    return img


SOFT = {"reel.png"}  # tiny props keep their own outline: re-inking would erase their detail


def polish(img: Image.Image, target_w: int, colors: int, box=None, ink: bool = True) -> Image.Image:
    bbox = box or img.getbbox()
    bw, bh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    th = max(4, round(target_w * bh / bw))
    out = dominant_downsample(img, target_w, th, bbox)
    out = quantize(out, colors)
    return clean_and_ink(out) if ink else out


def sha12(path: str) -> str:
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()[:12]


def main():
    manifest = {}
    for raw, (name, tw, n, aid) in JOBS.items():
        img = Image.open(os.path.join(RAW, raw)).convert("RGBA")
        out = polish(img, tw, n, ink=name not in SOFT)
        p = os.path.join(SC, name)
        out.save(p)
        manifest[name] = {"asset_id": aid, "sha12": sha12(p), "label": name.replace(".png", "")}
        print(name, out.size)
    for name, (raw, tw, n) in EXTRA.items():
        out = polish(Image.open(os.path.join(RAW, raw)).convert("RGBA"), tw, n)
        out.save(os.path.join(SC, name))
    for size in ("", "_big"):
        gold = Image.open(os.path.join(SC, "trophy_gold%s.png" % size)).convert("RGBA")
        for tier, ramp in TIERS.items():
            retint(gold, ramp).save(os.path.join(SC, "trophy_%s%s.png" % (tier, size)))
        # animation: every frame polished against the union bbox so the loop stays registered
    raw, name, tw, n, aid = ANIM
    anim = Image.open(os.path.join(RAW, raw))
    frames = []
    for i in range(anim.n_frames):
        anim.seek(i)
        frames.append(anim.convert("RGBA"))
    union = None
    for f in frames:
        b = f.getbbox()
        union = b if union is None else (min(union[0], b[0]), min(union[1], b[1]), max(union[2], b[2]), max(union[3], b[3]))
    polished = [polish(f, tw, n, union) for f in frames]
    fw, fh = polished[0].size
    sheet = Image.new("RGBA", (fw * len(polished), fh), (0, 0, 0, 0))
    for i, f in enumerate(polished):
        sheet.alpha_composite(f, (i * fw, 0))
    p = os.path.join(SC, name)
    sheet.save(p)
    manifest[name] = {"asset_id": aid, "sha12": sha12(p), "label": "bobber_bob_loop", "frames": len(polished),
                      "frame_size": [fw, fh], "fps": 8}
    print(name, sheet.size, len(polished), "frames")
    with open(os.path.join(ROOT, "spritecook-assets.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)


if __name__ == "__main__":
    main()
