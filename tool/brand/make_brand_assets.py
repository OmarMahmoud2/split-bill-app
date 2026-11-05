"""Draws the Evens brand assets: app icon, Android adaptive foreground,
native splash marks and wordmarks (light and dark).

The mark: a coin split into two equal halves on one line ("we're even").
Run from the repo root:  python3 tool/brand/make_brand_assets.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path('assets/brand')
FONT = 'assets/fonts/InterTight/InterTight-Bold.ttf'

TEAL = (15, 118, 110, 255)        # #0F766E
TEAL_DARK = (52, 197, 176, 255)   # #34C5B0
INK = (17, 19, 18, 255)           # #111312
INK_DARK = (242, 243, 241, 255)   # #F2F3F1
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)
SS = 4  # supersampling for smooth edges


def mark(size, block, line, *, scale=1.0, line_alpha=255):
    """A coin split into two equal halves, resting on one shared line."""
    s = size * SS
    img = Image.new('RGBA', (s, s), CLEAR)
    d = ImageDraw.Draw(img)
    u = s * scale / 180  # proportions from the 180 px design tile
    cx, cy = s / 2, s / 2
    dia, gap = 86 * u, 11 * u
    line_h, line_gap = 7 * u, 12 * u
    top = cy - (dia + line_gap + line_h) / 2
    left = cx - dia / 2
    d.ellipse([left, top, left + dia, top + dia], fill=block)
    # The split: a clear vertical gap through the middle.
    d.rectangle([cx - gap / 2, top - 1, cx + gap / 2, top + dia + 1], fill=CLEAR)
    ly = top + dia + line_gap
    lc = line[:3] + (line_alpha,)
    d.rounded_rectangle([left, ly, left + dia, ly + line_h], line_h / 2, fill=lc)
    return img.resize((size, size), Image.LANCZOS)


def icon(size=1024):
    """Full-bleed teal square: iOS and the stores apply their own corner mask."""
    bg = Image.new('RGBA', (size, size), TEAL)
    bg.alpha_composite(mark(size, WHITE, WHITE, scale=1.0, line_alpha=180))
    return bg.convert('RGB')


def wordmark(color, height=160):
    font = ImageFont.truetype(FONT, int(height * 0.72 * SS))
    text = 'Evens'
    box = font.getbbox(text)
    w, h = box[2] - box[0], box[3] - box[1]
    pad = int(height * 0.12 * SS)
    img = Image.new('RGBA', (w + pad * 2, h + pad * 2), CLEAR)
    ImageDraw.Draw(img).text((pad - box[0], pad - box[1]), text, font=font, fill=color)
    return img.resize((img.width // SS, img.height // SS), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    icon().save(OUT / 'evens_icon_1024.png')
    # Android adaptive foreground: the mark inside the 66% safe zone.
    mark(1024, WHITE, WHITE, scale=0.62, line_alpha=180).save(OUT / 'evens_adaptive_foreground.png')
    # Native splash marks (blocks teal, baseline ink) for light and dark.
    mark(768, TEAL, INK, scale=0.9).save(OUT / 'evens_splash_light.png')
    mark(768, TEAL_DARK, INK_DARK, scale=0.9).save(OUT / 'evens_splash_dark.png')
    # Android 12 splash icon: the mark inside its circular mask.
    mark(1152, TEAL, INK, scale=0.6).save(OUT / 'evens_splash_android12_light.png')
    mark(1152, TEAL_DARK, INK_DARK, scale=0.6).save(OUT / 'evens_splash_android12_dark.png')
    wordmark(INK).save(OUT / 'evens_wordmark_light.png')
    wordmark(INK_DARK).save(OUT / 'evens_wordmark_dark.png')
    print('written to', OUT)


if __name__ == '__main__':
    main()
