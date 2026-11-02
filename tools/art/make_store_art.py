"""Store / press-kit art from QA screenshots and game sprites (all nearest-neighbour, pixel-perfect).

Input: release/raw/<lang>_NN_name.png (640x360 QA shots, see release/README_RELEASE.md).
Output: release/<lang>/screenshots/*.png (1920x1080), release/art/* (icons, covers, key art).
"""
import glob
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REL = os.path.join(ROOT, "release")
ART = os.path.join(ROOT, "pondlight", "assets", "art")
N = Image.NEAREST


def up(img, k):
    return img.resize((img.width * k, img.height * k), N)


def cover(size, pond="trench", fish=("megalodon", "kraken"), logo_k=None, crop_y=None):
    """Pond diorama scaled to fill, logo on top, hero fish in front."""
    w, h = size
    base = Image.open(os.path.join(ART, "world", pond, "_preview.png")).convert("RGBA")
    k = max(1, -(-max(w / base.width, h / base.height) // 1))
    k = int(k)
    big = up(base, k)
    cx = (big.width - w) // 2
    cy = (big.height - h) // 2 if crop_y is None else crop_y
    out = big.crop((cx, cy, cx + w, cy + h))
    shade = Image.new("RGBA", (w, h), (4, 10, 20, 70))
    out.alpha_composite(shade)
    logo = Image.open(os.path.join(ART, "ui", "logo.png")).convert("RGBA")
    lk = logo_k or max(1, int(w * 0.8 // logo.width))
    lg = up(logo, lk)
    out.alpha_composite(lg, ((w - lg.width) // 2, int(h * 0.06)))
    sprites = [Image.open(os.path.join(ART, "spritecook", "fish_%s.png" % f)).convert("RGBA") for f in fish]
    fk = max(1, int(min(w * 0.42 / max(s.width for s in sprites), h * 0.4 / max(s.height for s in sprites))))
    xs = [int(w * 0.27), int(w * 0.73)]
    for i, s in enumerate(sprites):
        sp = up(s, fk)
        if i == 1:
            sp = sp.transpose(Image.FLIP_LEFT_RIGHT)
        out.alpha_composite(sp, (xs[i % 2] - sp.width // 2, int(h * 0.62) - sp.height // 2))
    return out


def main():
    for lang in ("ru", "en"):
        d = os.path.join(REL, lang, "screenshots")
        os.makedirs(d, exist_ok=True)
        for f in sorted(glob.glob(os.path.join(REL, "raw", lang + "_*.png"))):
            name = os.path.basename(f)[len(lang) + 1:]
            up(Image.open(f).convert("RGB"), 3).save(os.path.join(d, name))
    a = os.path.join(REL, "art")
    os.makedirs(a, exist_ok=True)
    icon = Image.open(os.path.join(ART, "ui", "app_icon.png")).convert("RGBA") if os.path.exists(os.path.join(ART, "ui", "app_icon.png")) else None
    if icon is not None:
        k = 512 // icon.width
        ic = up(icon, k)
        canvas = Image.new("RGBA", (512, 512), (11, 36, 24, 255))
        canvas.alpha_composite(ic, ((512 - ic.width) // 2, (512 - ic.height) // 2))
        canvas.save(os.path.join(a, "icon_512.png"))
    cover((800, 470), logo_k=2).save(os.path.join(a, "cover_800x470_yandex.png"))
    cover((1920, 1080)).save(os.path.join(a, "keyart_1920x1080.png"))
    cover((920, 430), pond="willow", fish=("golden_tench", "willow_pike")).save(os.path.join(a, "header_920x430.png"))
    cover((600, 900), pond="delta", fish=("arapaima", "peacock_bass")).save(os.path.join(a, "vertical_600x900.png"))
    cover((1280, 720), pond="frostmere", fish=("aurora_salmon", "frost_sturgeon")).save(os.path.join(a, "banner_1280x720.png"))
    print("store art done")


if __name__ == "__main__":
    main()
