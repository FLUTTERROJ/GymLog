"""Regenerates the PWA icon set in web/icons and web/favicon.png.

Run with `python tool/generate_icons.py` from frontend/, after installing
Pillow (`python -m pip install pillow`). Lives outside web/ deliberately --
`flutter build web` copies that directory verbatim into the public build
output, and this script has no reason to be publicly served.

Placeholder art: a solid brand-colour square with a simple dumbbell mark.
Swap in real artwork later by replacing the PNGs in web/icons/ directly --
nothing else references this script.
"""

from pathlib import Path

from PIL import Image, ImageDraw

BRAND = (0x3E, 0x63, 0xDD, 0xFF)  # matches core/theme.dart's seed color
MARK = (255, 255, 255, 255)

WEB_DIR = Path(__file__).resolve().parent.parent / "web"
ICONS_DIR = WEB_DIR / "icons"


def draw_dumbbell(draw: ImageDraw.ImageDraw, size: int, scale: float) -> None:
    """Draws a centered dumbbell glyph sized to `scale` * icon size."""
    w = size * scale
    cx, cy = size / 2, size / 2

    bar_h = w * 0.16
    bar_w = w * 0.62
    draw.rounded_rectangle(
        [cx - bar_w / 2, cy - bar_h / 2, cx + bar_w / 2, cy + bar_h / 2],
        radius=bar_h / 2,
        fill=MARK,
    )

    plate_w = w * 0.22
    plate_h = w
    for dx in (-1, 1):
        plate_cx = cx + dx * (bar_w / 2)
        draw.rounded_rectangle(
            [
                plate_cx - plate_w / 2,
                cy - plate_h / 2,
                plate_cx + plate_w / 2,
                cy + plate_h / 2,
            ],
            radius=plate_w * 0.35,
            fill=MARK,
        )


def make_icon(size: int, *, maskable: bool) -> Image.Image:
    img = Image.new("RGBA", (size, size), BRAND)
    draw = ImageDraw.Draw(img)
    # Maskable icons get cropped to a circle/rounded-square by the OS, so the
    # glyph has to sit inside a smaller "safe zone"; plain icons can use more
    # of the canvas.
    draw_dumbbell(draw, size, scale=0.42 if maskable else 0.56)
    return img


def main() -> None:
    ICONS_DIR.mkdir(parents=True, exist_ok=True)

    make_icon(192, maskable=False).save(ICONS_DIR / "Icon-192.png")
    make_icon(512, maskable=False).save(ICONS_DIR / "Icon-512.png")
    make_icon(192, maskable=True).save(ICONS_DIR / "Icon-maskable-192.png")
    make_icon(512, maskable=True).save(ICONS_DIR / "Icon-maskable-512.png")
    make_icon(32, maskable=False).save(WEB_DIR / "favicon.png")

    print(f"Wrote icons to {ICONS_DIR} and {WEB_DIR / 'favicon.png'}")


if __name__ == "__main__":
    main()
