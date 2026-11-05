"""App Store retention message image (3840x2160): the Evens mark and 'Evens Pro'.
Run from the repo root:  python3 tool/brand/make_retention_image.py
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).parent))
from make_brand_assets import FONT, TEAL, WHITE, mark  # noqa: E402

W, H = 3840, 2160


def main():
    img = Image.new('RGBA', (W, H), TEAL)
    m = mark(1500, WHITE, WHITE, scale=1.0, line_alpha=180)
    img.alpha_composite(m, (430, (H - 1500) // 2))
    d = ImageDraw.Draw(img)
    big = ImageFont.truetype(FONT, 330)
    small = ImageFont.truetype('assets/fonts/Inter/Inter-Medium.ttf', 120)
    d.text((2050, 760), 'Evens Pro', font=big, fill=WHITE)
    d.text((2060, 1180), 'Unlimited scans, trips,', font=small, fill=(255, 255, 255, 215))
    d.text((2060, 1340), 'exports and no ads', font=small, fill=(255, 255, 255, 215))
    out = Path('docs/2.0/store/evens_retention_3840x2160.png')
    img.convert('RGB').save(out)
    print('wrote', out)


if __name__ == '__main__':
    main()
