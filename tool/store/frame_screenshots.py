#!/usr/bin/env python3 -I
"""Frames build/store_raw/<profile>/<n>-<slug>.png into store images.

  python3 -I tool/store/frame_screenshots.py [profile ...]        (none = all)
  python3 -I tool/store/frame_screenshots.py --parse-captions     (ASO.md -> captions.json)

Outputs (existing store images are never touched):
  iOS 6.9"     1320x2868 -> fastlane/screenshots_2_0/<ios-locale>/<n>-<slug>.png
  Google Play  1080x2400 -> fastlane/metadata_v2/android/<play-locale>/images/phoneScreenshots_2_0/<n>.png
"""
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW = os.path.join(ROOT, "build", "store_raw")
CAPTIONS = os.path.join(ROOT, "tool", "store", "captions.json")
SYS = "/System/Library/Fonts"
JAKARTA = os.path.join(ROOT, "assets/fonts/PlusJakartaSans/PlusJakartaSans-ExtraBold.ttf")

# profile -> (ASO.md table row label, iOS folder or None, Play folder or None)
PROFILES = {
    "en-US": ("en-US / en-CA", "en-US", "en-US"),
    "en-CA": ("en-US / en-CA", "en-CA", None),
    "en-GB": ("en-GB / en-AU", "en-GB", "en-GB"),
    "en-AU": ("en-GB / en-AU", "en-AU", None),
    "de": ("de-DE", "de-DE", "de-DE"),
    "nl": ("nl-NL", "nl-NL", "nl-NL"),
    "sv": ("sv", "sv", "sv-SE"),
    "da": ("da", "da", "da-DK"),
    "no": ("no", "no", "no-NO"),
    "fr-FR": ("fr-FR", "fr-FR", "fr-FR"),
    "fr-CA": ("fr-CA", "fr-CA", None),
    "es-ES": ("es-ES", "es-ES", "es-ES"),
    "es-MX": ("es-MX / es-419", "es-MX", "es-419"),
    "it": ("it", "it", "it-IT"),
    "pt-BR": ("pt-BR", "pt-BR", "pt-BR"),
    "pt-PT": ("pt-PT", "pt-PT", "pt-PT"),
    "pl": ("pl", "pl", "pl-PL"),
    "ru": ("ru", "ru", "ru-RU"),
    "tr": ("tr", "tr", "tr-TR"),
    "ar-SA": ("ar-SA / ar", "ar-SA", None),
    "ar": ("ar-SA / ar", None, "ar"),
    "hi": ("hi / hi-IN", "hi", "hi-IN"),
    "ur": ("ur (Play)", None, "ur"),
    "id": ("id", "id", "id"),
    "ja": ("ja", "ja", "ja-JP"),
    "ko": ("ko", "ko", "ko-KR"),
    "th": ("th", "th", "th"),
    "vi": ("vi", "vi", "vi"),
    "zh-Hans": ("zh-Hans / zh-CN", "zh-Hans", "zh-CN"),
    "zh-Hant": ("zh-Hant / zh-TW", "zh-Hant", "zh-TW"),
}

SLUGS = ["scan", "voice", "breakdown", "guest", "settle", "home", "home-dark"]
RAW_NAMES = ["1-scan", "2-voice", "3-breakdown", "4-guest", "5-settle", "6-home", "7-home-dark"]
RTL = {"ar-SA", "ar", "ur"}


def parse_captions():
    out = {}
    text = open(os.path.join(ROOT, "docs/2.0/ASO.md"), encoding="utf-8").read()
    sec = text.split("## 3. Screenshot caption set", 1)[1].split("\n## 4.", 1)[0]
    for line in sec.splitlines():
        if line.startswith("|") and not line.startswith("|---") and "Locale" not in line:
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            out[cells[0]] = cells[1:8]
    json.dump(out, open(CAPTIONS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return out


def caption_font(profile, size):
    """(font path, ttc index) per script; Latin uses Plus Jakarta Sans."""
    pick = {
        # Arial Bold: Arabic letters AND Latin digits (SF Arabic drew "22" as boxes).
        "ar-SA": (f"{SYS}/Supplemental/Arial Bold.ttf", 0),
        "ar": (f"{SYS}/Supplemental/Arial Bold.ttf", 0),
        "ur": (f"{SYS}/Supplemental/Arial Bold.ttf", 0),
        "ja": (f"{SYS}/ヒラギノ角ゴシック W6.ttc", 0),
        "zh-Hans": (f"{SYS}/Hiragino Sans GB.ttc", 2),
        "zh-Hant": (f"{SYS}/STHeiti Medium.ttc", 0),
        "ko": (f"{SYS}/AppleSDGothicNeo.ttc", 6),
        "th": (f"{SYS}/Supplemental/Thonburi.ttc", 1),
        "hi": (f"{SYS}/Kohinoor.ttc", 3),
    }.get(profile)
    if profile == "ru":  # Plus Jakarta Sans has no Cyrillic
        return ImageFont.truetype(os.path.join(ROOT, "assets/fonts/Inter/Inter-Bold.ttf"), size)
    if pick is None:
        return ImageFont.truetype(JAKARTA, size)
    path, idx = pick
    try:
        f = ImageFont.truetype(path, size, index=idx)
    except OSError:
        f = ImageFont.truetype(path, size)
    if profile in ("ar-SA", "ar", "ur"):
        try:
            f.set_variation_by_name("Bold")
        except Exception:
            pass
    return f


def wrap_lines(draw, text, font, max_w, rtl):
    """Greedy wrap by words; CJK (no spaces) wraps by character."""
    words = text.split(" ")
    if len(words) == 1 or not re.search(r"\s", text):
        words = list(text)
        joiner = ""
    else:
        joiner = " "
    lines, cur = [], ""
    for w in words:
        t = (cur + joiner + w) if cur else w
        if draw.textlength(t, font=font, direction="rtl" if rtl else None) <= max_w:
            cur = t
        else:
            lines.append(cur)
            cur = w
    lines.append(cur)
    return lines


def fit_caption(draw, text, profile, max_w, rtl, start=120, min_size=56):
    for size in range(start, min_size - 1, -4):
        font = caption_font(profile, size)
        lines = wrap_lines(draw, text, font, max_w, rtl)
        if len(lines) <= 2:
            return font, lines, size
    font = caption_font(profile, min_size)
    return font, wrap_lines(draw, text, font, max_w, rtl)[:2], min_size


def background(dark, w, h):
    if dark:
        return Image.new("RGB", (w, h), "#0A0F1C")
    bg = Image.new("RGB", (w, h), "#F5F7FB")
    glow = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(glow)
    d.ellipse([int(w * 0.35), int(h * 0.38), int(w * 1.35), int(h * 0.98)], fill=70)
    d.ellipse([int(-w * 0.35), int(-h * 0.12), int(w * 0.55), int(h * 0.2)], fill=40)
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.12))
    mint = Image.new("RGB", (w, h), "#0B7268")
    return Image.composite(mint, bg, glow)


def frame(raw_path, caption, profile, dark, w, h):
    """Compose one store image at w x h (design laid out on 1320 wide, scaled)."""
    S = 1320
    canvas = background(dark, S, int(S * h / w))
    ch = canvas.size[1]
    rtl = profile in RTL
    draw = ImageDraw.Draw(canvas)
    margin = 96
    fg = "#F5F7FB" if dark else "#0E1526"
    font, lines, size = fit_caption(draw, caption, profile, S - 2 * margin, rtl)
    y = 150
    lh = int(size * 1.2)
    for ln in lines:
        tw = draw.textlength(ln, font=font, direction="rtl" if rtl else None)
        x = S - margin - tw if rtl else margin
        draw.text((x, y), ln, font=font, fill=fg, direction="rtl" if rtl else None)
        y += lh
    # Device: bezel around the screenshot, bottom-aligned with a margin.
    bezel = 22
    raw = Image.open(raw_path).convert("RGB")
    top = max(y + 70, 470)
    avail_h = ch - top - 90
    dev_h = avail_h
    scr_h = dev_h - 2 * bezel
    scr_w = int(raw.size[0] * scr_h / raw.size[1])
    scr_w = min(scr_w, S - 2 * 110)
    scr_h = int(raw.size[1] * scr_w / raw.size[0])
    dev_w, dev_h = scr_w + 2 * bezel, scr_h + 2 * bezel
    x0, y0 = (S - dev_w) // 2, ch - 90 - dev_h
    radius = int(dev_w * 0.09)
    # Soft shadow.
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(
        [x0, y0 + 30, x0 + dev_w, y0 + dev_h + 30], radius, fill=(8, 14, 30, 90 if not dark else 160))
    sh = sh.filter(ImageFilter.GaussianBlur(36))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), sh)
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle([x0, y0, x0 + dev_w, y0 + dev_h], radius, fill="#0E1526")
    d.rounded_rectangle([x0 + 3, y0 + 3, x0 + dev_w - 3, y0 + dev_h - 3], radius - 3,
                        outline="#26304A", width=3)
    scr = raw.resize((scr_w, scr_h), Image.LANCZOS)
    mask = Image.new("L", (scr_w, scr_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, scr_w, scr_h], radius - bezel, fill=255)
    canvas.paste(scr, (x0 + bezel, y0 + bezel), mask)
    return canvas.convert("RGB").resize((w, h), Image.LANCZOS)


def main():
    args = sys.argv[1:]
    if args == ["--parse-captions"]:
        parse_captions()
        return
    caps = json.load(open(CAPTIONS, encoding="utf-8"))
    todo = args or [p for p in PROFILES if os.path.isdir(os.path.join(RAW, p))]
    n_ios = n_play = 0
    for prof in todo:
        label, ios, play = PROFILES[prof]
        for i, raw_name in enumerate(RAW_NAMES):
            raw = os.path.join(RAW, prof, raw_name + ".png")
            text = caps[label][i]
            dark = i == 6
            if ios:
                out = os.path.join(ROOT, "fastlane/screenshots_2_0", ios, f"{i + 1}-{SLUGS[i]}.png")
                os.makedirs(os.path.dirname(out), exist_ok=True)
                frame(raw, text, prof, dark, 1320, 2868).save(out)
                n_ios += 1
            if play:
                out = os.path.join(ROOT, "fastlane/metadata_v2/android", play,
                                   "images/phoneScreenshots_2_0", f"{i + 1}.png")
                os.makedirs(os.path.dirname(out), exist_ok=True)
                frame(raw, text, prof, dark, 1080, 2400).save(out)
                n_play += 1
        print(f"{prof}: ok")
    print(f"ios images: {n_ios}, play images: {n_play}")


if __name__ == "__main__":
    main()
