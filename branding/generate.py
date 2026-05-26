#!/usr/bin/env python3
"""Generate every BETRIEBSSYSTEM visual asset from one source of truth.

The brand is intentionally trivial: a single filled white circle centred on a
pure-black field. This script rasterizes that mark, at the right size and with
the right background (transparent vs. black), into each place the OS needs it:

  * Plymouth boot splash logo        (transparent circle)
  * GRUB menu background             (circle on black, 1920x1080)
  * GNOME / login wallpaper          (circle on black, 3840x2160)
  * App + login + Calamares logos    (transparent circle, various sizes)

It also (re)writes branding/logo.svg as the human-editable canonical source.

Usage:  python3 branding/generate.py   (or: make branding)

Only depends on Pillow (PIL), which is already present in the build env.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parent.parent
BRAND = json.loads((REPO / "branding" / "brand.json").read_text())

BG = BRAND["background"]
FG = BRAND["foreground"]
FRAC = float(BRAND["circle_diameter_fraction"])
SS = int(BRAND["supersample"])


def _hex_to_rgba(h: str, alpha: int = 255) -> tuple[int, int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), alpha)


def circle(width: int, height: int, *, transparent_bg: bool,
           diameter_frac: float = FRAC) -> Image.Image:
    """A centred white circle, optionally on a black background."""
    w, h = width * SS, height * SS
    bg = (0, 0, 0, 0) if transparent_bg else _hex_to_rgba(BG)
    img = Image.new("RGBA", (w, h), bg)
    draw = ImageDraw.Draw(img)

    d = int(min(w, h) * diameter_frac)
    x0 = (w - d) // 2
    y0 = (h - d) // 2
    draw.ellipse([x0, y0, x0 + d, y0 + d], fill=_hex_to_rgba(FG))

    return img.resize((width, height), Image.LANCZOS)


def save(img: Image.Image, rel: str) -> None:
    out = REPO / rel
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out)
    print(f"  wrote {rel}  ({img.width}x{img.height})")


def _font(size: int):
    """A bold TTF if available, else PIL's default bitmap font."""
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def wallpaper(width: int, height: int) -> Image.Image:
    """Circle on black + a subtle bottom-right hint: the name and how to reach
    the overview (the Super key)."""
    img = circle(width, height, transparent_bg=False, diameter_frac=FRAC * 0.5)
    draw = ImageDraw.Draw(img)
    margin = int(height * 0.045)
    name_f = _font(int(height * 0.026))
    hint_f = _font(int(height * 0.018))
    name = "BETRIEBSSYSTEM"
    hint = "Press  Super (⌘)  for Activities / Overview"
    # right-aligned, stacked, dim grey so it reads but stays understated.
    nb = draw.textbbox((0, 0), name, font=name_f)
    hb = draw.textbbox((0, 0), hint, font=hint_f)
    nx = width - margin - (nb[2] - nb[0])
    hx = width - margin - (hb[2] - hb[0])
    hy = height - margin - (hb[3] - hb[1])
    ny = hy - int(height * 0.012) - (nb[3] - nb[1])
    draw.text((nx, ny), name, font=name_f, fill="#9a9a9a")
    draw.text((hx, hy), hint, font=hint_f, fill="#6a6a6a")
    return img


def write_svg() -> None:
    """Canonical, hand-editable source mark (1000x1000 viewport)."""
    r = int(1000 * FRAC / 2)
    svg = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="1000" '
        'viewBox="0 0 1000 1000">\n'
        f'  <rect width="1000" height="1000" fill="{BG}"/>\n'
        f'  <circle cx="500" cy="500" r="{r}" fill="{FG}"/>\n'
        "</svg>\n"
    )
    out = REPO / "branding" / "logo.svg"
    out.write_text(svg)
    print(f"  wrote branding/logo.svg  (r={r})")


def main() -> None:
    print(f"BETRIEBSSYSTEM branding  bg={BG} fg={FG} circle={FRAC:.0%}")
    write_svg()

    C = "config/includes.chroot"
    B = "config/includes.binary"

    # Plymouth boot splash logo: transparent circle (black comes from theme).
    save(circle(480, 480, transparent_bg=True),
         f"{C}/usr/share/plymouth/themes/betriebssystem/logo.png")

    # GRUB background: circle on black, 16:9.
    save(circle(1920, 1080, transparent_bg=False, diameter_frac=FRAC * 0.6),
         f"{B}/boot/grub/betriebssystem/background.png")

    # Desktop + login wallpaper: circle on black, 4K, with the bottom-right hint.
    save(wallpaper(3840, 2160),
         f"{C}/usr/share/backgrounds/betriebssystem/wallpaper.png")

    # App-grid / login-screen logo (transparent).
    save(circle(256, 256, transparent_bg=True, diameter_frac=0.86),
         f"{C}/usr/share/pixmaps/betriebssystem-logo.png")

    # Calamares product logo / welcome / slideshow (transparent).
    save(circle(512, 512, transparent_bg=True, diameter_frac=0.86),
         f"{C}/etc/calamares/branding/betriebssystem/logo.png")

    # A canonical copy in branding/out for docs / reuse.
    save(circle(1024, 1024, transparent_bg=False),
         "branding/out/betriebssystem-1024.png")

    print("branding: done")


if __name__ == "__main__":
    main()
