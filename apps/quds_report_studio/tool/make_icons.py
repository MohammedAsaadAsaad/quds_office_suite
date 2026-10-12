#!/usr/bin/env python3
"""Draws the Quds Report Studio app icon and the .qrep document icon.

Writes every platform size from one design (needs Pillow + numpy):

    python3 tool/make_icons.py

Outputs: assets/icon/*.png, windows/runner/resources/*.ico,
packaging/linux/icons/{apps,mimetypes}/<size>.png, the macOS AppIcon set and
the web icons.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT.parent.parent / "packages/quds_office_editor/fonts/LiberationSans-Bold.ttf"
SS = 4  # supersampling factor
N = 1024 * SS

NAVY = (14, 34, 64)
BLUE = (43, 87, 151)
GOLD_HI = (248, 205, 96)
GOLD_LO = (196, 132, 12)
DOME = (18, 53, 91)


def s(v):
    return int(round(v * SS))


def gradient(size, c0, c1, angle_xy=(1, 1)):
    w, h = size
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    ax, ay = angle_xy
    t = (x * ax / w + y * ay / h) / (ax + ay)
    t = np.clip(t, 0, 1)[..., None]
    a = np.array(c0, np.float32)
    b = np.array(c1, np.float32)
    rgb = a + (b - a) * t
    alpha = np.full((h, w, 1), 255, np.float32)
    return Image.fromarray(np.concatenate([rgb, alpha], 2).astype(np.uint8), "RGBA")


def mask_rrect(box, r):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).rounded_rectangle([s(v) for v in box], s(r), fill=255)
    return m


def paste_fill(base, mask, fill):
    layer = fill if isinstance(fill, Image.Image) else Image.new("RGBA", (N, N), fill)
    base.paste(layer, (0, 0), mask)


def shadow(base, mask, offset, blur, opacity):
    sh = Image.new("RGBA", (N, N), (5, 12, 28, 0))
    m = mask.point(lambda v: int(v * opacity))
    m = m.transform(m.size, Image.AFFINE, (1, 0, -s(offset[0]), 0, 1, -s(offset[1])))
    m = m.filter(ImageFilter.GaussianBlur(s(blur)))
    sh.putalpha(m)
    base.alpha_composite(sh)


def page_mask(x0, y0, x1, y1, fold, r):
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([s(x0), s(y0), s(x1), s(y1)], s(r), fill=255)
    d.polygon([(s(x1 - fold), s(y0) - 2), (s(x1) + 2, s(y0) - 2), (s(x1) + 2, s(y0 + fold))], fill=0)
    return m


def fold_mask(x1, y0, fold, r):
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    d.polygon([(s(x1 - fold), s(y0)), (s(x1 - fold), s(y0 + fold - r)),
               (s(x1 - fold + r), s(y0 + fold)), (s(x1), s(y0 + fold))], fill=255)
    return m


def badge(img, cx, cy, r):
    """Gold seal with the dome, the brand mark of the suite."""
    d = ImageDraw.Draw(img)
    ring = Image.new("L", (N, N), 0)
    ImageDraw.Draw(ring).ellipse([s(cx - r), s(cy - r), s(cx + r), s(cy + r)], fill=255)
    shadow(img, ring, (0, 14), 22, 0.45)
    d.ellipse([s(cx - r), s(cy - r), s(cx + r), s(cy + r)], fill=(255, 255, 255, 255))
    inner = r - 16
    gm = Image.new("L", (N, N), 0)
    ImageDraw.Draw(gm).ellipse([s(cx - inner), s(cy - inner), s(cx + inner), s(cy + inner)], fill=255)
    paste_fill(img, gm, gradient((N, N), GOLD_HI, GOLD_LO, (0.6, 1)))
    # Dome: drum, cupola and finial with crescent.
    k = inner / 150
    base_y = cy + 58 * k
    d.rounded_rectangle([s(cx - 92 * k), s(base_y - 34 * k), s(cx + 92 * k), s(base_y + 22 * k)],
                        s(6 * k), fill=DOME)
    d.rectangle([s(cx - 70 * k), s(base_y - 50 * k), s(cx + 70 * k), s(base_y - 30 * k)], fill=DOME)
    d.pieslice([s(cx - 70 * k), s(base_y - 120 * k), s(cx + 70 * k), s(base_y + 20 * k)],
               180, 360, fill=DOME)
    d.rectangle([s(cx - 4 * k), s(base_y - 142 * k), s(cx + 4 * k), s(base_y - 116 * k)], fill=DOME)
    cr = 13 * k
    ccy = base_y - 150 * k
    d.ellipse([s(cx - cr), s(ccy - cr), s(cx + cr), s(ccy + cr)], fill=DOME)
    d.ellipse([s(cx - cr + 6 * k), s(ccy - cr - 4 * k), s(cx + cr + 6 * k), s(ccy + cr - 4 * k)],
              fill=GOLD_HI)
    # Windows of the drum.
    for i in range(5):
        wx = cx - 64 * k + i * 32 * k
        d.rounded_rectangle([s(wx - 7 * k), s(base_y - 20 * k), s(wx + 7 * k), s(base_y + 8 * k)],
                            s(7 * k), fill=GOLD_HI)


def app_icon(detail=True):
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    tile = mask_rrect((48, 48, 976, 976), 220)
    shadow(img, tile, (0, 10), 18, 0.35)
    paste_fill(img, tile, gradient((N, N), BLUE, NAVY))
    glow = Image.new("L", (N, N), 0)
    ImageDraw.Draw(glow).ellipse([s(-200), s(-260), s(700), s(520)], fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(s(90)))
    glow = Image.composite(glow, Image.new("L", (N, N), 0), tile)
    img.alpha_composite(Image.merge("RGBA", (Image.new("L", (N, N), 255),) * 3 + (glow,)))

    x0, y0, x1, y1, fold = 236, 176, 712, 820, 132
    pm = page_mask(x0, y0, x1, y1, fold, 40)
    shadow(img, pm, (10, 22), 26, 0.55)
    paste_fill(img, pm, gradient((N, N), (255, 255, 255), (232, 239, 249), (0.3, 1)))
    paste_fill(img, fold_mask(x1, y0, fold, 30), (197, 213, 236, 255))

    d = ImageDraw.Draw(img)
    d.rounded_rectangle([s(296), s(262), s(560), s(316)], s(14), fill=(43, 87, 151, 255))
    if detail:
        d.rounded_rectangle([s(296), s(352), s(520), s(374)], s(11), fill=(196, 208, 226, 255))
        d.rounded_rectangle([s(296), s(400), s(468), s(422)], s(11), fill=(196, 208, 226, 255))
    bars = [(296, 230, (20, 184, 166)), (370, 330, (79, 157, 255)),
            (444, 270, (232, 168, 38)), (518, 400, (43, 87, 151))]
    base = 748
    for bx, h, c in bars:
        top = base - (h if detail else h * 1.15)
        d.rounded_rectangle([s(bx), s(top), s(bx + 56), s(base)], s(12), fill=c + (255,))
    d.rounded_rectangle([s(284), s(base + 8), s(640), s(base + 20)], s(6), fill=(160, 176, 200, 255))
    badge(img, 724, 724, 182)
    return img


def doc_icon(detail=True):
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    x0, y0, x1, y1, fold = 168, 56, 856, 968, 210
    pm = page_mask(x0, y0, x1, y1, fold, 44)
    shadow(img, pm, (0, 14), 20, 0.4)
    edge = page_mask(x0 - 10, y0 - 10, x1 + 10, y1 + 10, fold + 14, 52)
    paste_fill(img, edge, (150, 168, 196, 255))
    paste_fill(img, pm, gradient((N, N), (255, 255, 255), (236, 242, 250), (0.2, 1)))
    paste_fill(img, fold_mask(x1, y0, fold, 40), (197, 213, 236, 255))
    band = Image.new("L", (N, N), 0)
    ImageDraw.Draw(band).rounded_rectangle([s(x0), s(700), s(x1), s(y1)], s(44), fill=255)
    ImageDraw.Draw(band).rectangle([s(x0), s(700), s(x1), s(760)], fill=255)
    band = Image.composite(band, Image.new("L", (N, N), 0), pm)
    paste_fill(img, band, gradient((N, N), BLUE, NAVY, (1, 0.4)))
    mini = app_icon(detail=detail).resize((s(470), s(470)), Image.LANCZOS)
    img.alpha_composite(mini, (s(277), s(150)))
    if detail:
        d = ImageDraw.Draw(img)
        font = ImageFont.truetype(str(FONT), s(150))
        text = "QREP"
        w = d.textlength(text, font=font)
        d.text(((N - w) / 2, s(752)), text, font=font, fill=(255, 255, 255, 255))
    return img


def sized(master, size):
    return master.resize((size, size), Image.LANCZOS)


def main():
    app_full, app_small = app_icon(True), app_icon(False)
    doc_full, doc_small = doc_icon(True), doc_icon(False)
    pick = lambda full, small, n: sized(full if n >= 48 else small, n)

    assets = ROOT / "assets/icon"
    assets.mkdir(parents=True, exist_ok=True)
    sized(app_full, 1024).save(assets / "app_icon.png", optimize=True)
    sized(app_full, 256).save(assets / "app_icon_256.png", optimize=True)
    sized(doc_full, 512).save(assets / "qrep_file.png", optimize=True)

    ico = [16, 20, 24, 32, 40, 48, 64, 128, 256]
    res = ROOT / "windows/runner/resources"
    for name, full, small in (("app_icon", app_full, app_small), ("qrep_file", doc_full, doc_small)):
        imgs = [pick(full, small, n) for n in ico]
        imgs[-1].save(res / f"{name}.ico", sizes=[(n, n) for n in ico], append_images=imgs[:-1])

    linux = ROOT / "packaging/linux/icons"
    for kind, full, small in (("apps", app_full, app_small), ("mimetypes", doc_full, doc_small)):
        (linux / kind).mkdir(parents=True, exist_ok=True)
        for n in (16, 24, 32, 48, 64, 128, 256, 512):
            pick(full, small, n).save(linux / kind / f"{n}.png", optimize=True)

    mac = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for n in (16, 32, 64, 128, 256, 512, 1024):
        pick(app_full, app_small, n).save(mac / f"app_icon_{n}.png", optimize=True)

    web = ROOT / "web"
    pick(app_full, app_small, 32).save(web / "favicon.png", optimize=True)
    for n in (192, 512):
        sized(app_full, n).save(web / f"icons/Icon-{n}.png", optimize=True)
        bg = Image.new("RGBA", (1024, 1024), NAVY + (255,))
        bg.alpha_composite(sized(app_full, 820), (102, 102))
        sized(bg, n).save(web / f"icons/Icon-maskable-{n}.png", optimize=True)


if __name__ == "__main__":
    main()
