#!/usr/bin/env python3
"""Generate Yaip's macOS app icon and web favicon family."""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
APPICON = ROOT / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
CATALOG = ROOT / "Resources" / "Assets.xcassets"
BRAND = ROOT / "Brand"

CANVAS = (19, 24, 21)
SURFACE = (26, 32, 28)
SURFACE_RAISED = (35, 42, 37)
INK = (236, 240, 237)
INK_MUTED = (168, 180, 171)
ACCENT = (124, 201, 131)
ACCENT_STRONG = (101, 178, 110)
LINE = (56, 66, 59)


def rounded(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], radius: int,
            fill: tuple[int, ...]) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    ramp = Image.linear_gradient("L").resize((size, size))
    return Image.composite(Image.new("RGB", (size, size), bottom),
                           Image.new("RGB", (size, size), top), ramp).convert("RGBA")


def draw_mark(layer: Image.Image, size: int, compact: bool) -> None:
    draw = ImageDraw.Draw(layer)
    scale = size / 1024

    if compact:
        # The small mark keeps only the silhouette-bearing parts.
        bars = [(276, 102), (346, 226), (416, 148)]
        bar_width = 48
        centre = 512
        for index, (x, height) in enumerate(bars):
            colour = ACCENT if index == 1 else ACCENT_STRONG
            rounded(
                draw,
                tuple(round(value * scale) for value in (
                    x - bar_width / 2, centre - height / 2,
                    x + bar_width / 2, centre + height / 2,
                )),
                max(1, round(bar_width * scale / 2)),
                colour + (255,),
            )
        rounded(draw, tuple(round(v * scale) for v in (550, 338, 590, 686)),
                max(1, round(20 * scale)), INK + (255,))
        for y, width in ((410, 170), (555, 126)):
            rounded(draw, tuple(round(v * scale) for v in (632, y, 632 + width, y + 42)),
                    max(1, round(21 * scale)), INK + (255,))
        return

    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse(
        tuple(round(v * scale) for v in (170, 225, 590, 800)),
        fill=ACCENT + (52,),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(max(1, round(58 * scale))))
    layer.alpha_composite(glow)

    draw = ImageDraw.Draw(layer)
    centre = 512
    bars = [
        (246, 104, ACCENT_STRONG),
        (306, 194, ACCENT),
        (366, 318, ACCENT),
        (426, 226, ACCENT),
        (486, 126, ACCENT_STRONG),
    ]
    bar_width = 34
    for x, height, colour in bars:
        rounded(
            draw,
            tuple(round(value * scale) for value in (
                x - bar_width / 2, centre - height / 2,
                x + bar_width / 2, centre + height / 2,
            )),
            max(1, round(bar_width * scale / 2)),
            colour + (255,),
        )

    # A cursor and text strokes complete the speech-to-text transformation.
    rounded(draw, tuple(round(v * scale) for v in (566, 318, 594, 706)),
            max(1, round(14 * scale)), INK + (255,))
    for y, width in ((378, 184), (492, 134), (606, 194)):
        rounded(draw, tuple(round(v * scale) for v in (642, y, 642 + width, y + 34)),
                max(1, round(17 * scale)), INK + (255,))


def render_icon(size: int) -> Image.Image:
    work = max(256, size * 4)
    margin = round(work * 0.075)
    radius = round(work * 0.205)
    compact = size <= 64

    canvas = Image.new("RGBA", (work, work), (0, 0, 0, 0))

    shadow = Image.new("RGBA", (work, work), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_box = (margin, margin + round(work * 0.025), work - margin, work - margin + round(work * 0.025))
    rounded(shadow_draw, shadow_box, radius, (0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(max(1, round(work * 0.035))))
    canvas.alpha_composite(shadow)

    mask = Image.new("L", (work, work), 0)
    mask_draw = ImageDraw.Draw(mask)
    rounded(mask_draw, (margin, margin, work - margin, work - margin), radius, 255)

    face = gradient(work, SURFACE_RAISED, CANVAS)
    face.putalpha(mask)
    canvas.alpha_composite(face)

    # A restrained inner sheen gives the squircle native macOS depth.
    sheen = Image.new("RGBA", (work, work), (0, 0, 0, 0))
    sheen_draw = ImageDraw.Draw(sheen)
    inset = margin + round(work * 0.012)
    sheen_draw.rounded_rectangle(
        (inset, inset, work - inset, work - inset),
        radius=max(1, radius - round(work * 0.012)),
        outline=INK_MUTED + (60,),
        width=max(1, round(work * 0.004)),
    )
    sheen.putalpha(ImageChops.multiply(sheen.getchannel("A"), mask))
    canvas.alpha_composite(sheen)

    mark = Image.new("RGBA", (work, work), (0, 0, 0, 0))
    draw_mark(mark, work, compact)
    mark.putalpha(ImageChops.multiply(mark.getchannel("A"), mask))
    canvas.alpha_composite(mark)

    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def svg_mark() -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img">
  <title>Yaip, voice becomes text</title>
  <defs>
    <linearGradient id="surface" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#232a25"/>
      <stop offset="1" stop-color="#131815"/>
    </linearGradient>
  </defs>
  <rect x="2" y="2" width="60" height="60" rx="14" fill="url(#surface)" stroke="#526057"/>
  <rect x="14" y="27" width="3" height="10" rx="1.5" fill="#65b26e"/>
  <rect x="19" y="21" width="3" height="22" rx="1.5" fill="#7cc983"/>
  <rect x="24" y="25" width="3" height="14" rx="1.5" fill="#65b26e"/>
  <rect x="34" y="20" width="3" height="24" rx="1.5" fill="#ecf0ed"/>
  <rect x="40" y="25" width="12" height="3" rx="1.5" fill="#ecf0ed"/>
  <rect x="40" y="35" width="9" height="3" rx="1.5" fill="#ecf0ed"/>
</svg>
'''


def write_catalogue() -> None:
    CATALOG.mkdir(parents=True, exist_ok=True)
    APPICON.mkdir(parents=True, exist_ok=True)
    (CATALOG / "Contents.json").write_text(json.dumps({
        "info": {"author": "xcode", "version": 1}
    }, indent=2) + "\n")

    slots = [
        (16, 1, "icon_16x16.png"),
        (16, 2, "icon_16x16@2x.png"),
        (32, 1, "icon_32x32.png"),
        (32, 2, "icon_32x32@2x.png"),
        (128, 1, "icon_128x128.png"),
        (128, 2, "icon_128x128@2x.png"),
        (256, 1, "icon_256x256.png"),
        (256, 2, "icon_256x256@2x.png"),
        (512, 1, "icon_512x512.png"),
        (512, 2, "icon_512x512@2x.png"),
    ]
    images = []
    for points, scale, filename in slots:
        pixels = points * scale
        render_icon(pixels).save(APPICON / filename, optimize=True)
        images.append({
            "filename": filename,
            "idiom": "mac",
            "scale": f"{scale}x",
            "size": f"{points}x{points}",
        })
    (APPICON / "Contents.json").write_text(json.dumps({
        "images": images,
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")


def write_brand_assets() -> None:
    BRAND.mkdir(parents=True, exist_ok=True)
    master = render_icon(1024)
    master.save(BRAND / "yaip-app-icon-1024.png", optimize=True)
    (BRAND / "yaip-mark.svg").write_text(svg_mark())
    (BRAND / "favicon.svg").write_text(svg_mark())

    for size in (16, 32, 48):
        image = render_icon(size)
        image.save(BRAND / f"favicon-{size}x{size}.png", optimize=True)
    render_icon(48).save(
        BRAND / "favicon.ico",
        format="ICO",
        sizes=[(16, 16), (32, 32), (48, 48)],
    )
    render_icon(180).save(BRAND / "apple-touch-icon.png", optimize=True)
    render_icon(512).save(BRAND / "icon-512.png", optimize=True)
    (BRAND / "site.webmanifest").write_text(json.dumps({
        "name": "Yaip",
        "short_name": "Yaip",
        "icons": [
            {"src": "icon-512.png", "sizes": "512x512", "type": "image/png"}
        ],
        "theme_color": "#131815",
        "background_color": "#131815",
        "display": "standalone",
    }, indent=2) + "\n")


def main() -> None:
    write_catalogue()
    write_brand_assets()
    print(f"Generated AppIcon catalogue at {APPICON}")
    print(f"Generated reusable brand assets at {BRAND}")


if __name__ == "__main__":
    main()
