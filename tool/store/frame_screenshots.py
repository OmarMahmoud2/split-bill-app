#!/usr/bin/env python3 -I
"""Frames build/store_raw/<profile>/<n>-<slug>.png into store images.

  python3 -I tool/store/frame_screenshots.py [profile ...]        (none = all)
  python3 -I tool/store/frame_screenshots.py --parse-captions     (ASO.md -> captions.json "head" lists)

Each raw render comes with build/store_raw/<profile>/meta.json (localized
strings and amounts for the callouts; written by the store screenshot test).

Outputs (existing store images are never touched):
  iOS 6.9"     1320x2868 -> fastlane/screenshots_2_0/<ios-locale>/<n>-<slug>.png
  Google Play  1080x2400 -> fastlane/metadata_v2/android/<play-locale>/images/phoneScreenshots_2_0/<n>.png

Design: Midnight & Mint. Light frames on a soft canvas with blurred mint/sky
shapes (frames 1-2 share one continuous panorama), dark frames (4 and 7) on
#0A0F1C with a mint glow. Headline + sub-line on top, a large phone, and one
floating callout per frame that repeats the key UI element enlarged. The
status bar (9:41, signal/wifi/battery) and the camera pill are drawn here.
"""
import json
import os
import re
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

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
DARK = {3, 6}          # frames drawn on the Midnight canvas
PANO = {0, 1}          # frames sharing one continuous background
# Where the key element sits on the screen (fraction of screen height).
# (Chosen so the card covers the original completely or sits in empty space.)
CALLOUT_Y = [0.87, 0.29, 0.64, 0.26, 0.93, 0.80, 0.61]

INK, MUTED = "#0E1526", "#5B6478"
MINT, MINT_D = "#0B7268", "#34D7C0"
CORAL, CORAL_D = "#C2452D", "#FF8A70"


def parse_captions():
    """Refresh the "head" lists from docs/2.0/ASO.md; "sub" lists are kept."""
    old = json.load(open(CAPTIONS, encoding="utf-8")) if os.path.exists(CAPTIONS) else {}
    text = open(os.path.join(ROOT, "docs/2.0/ASO.md"), encoding="utf-8").read()
    sec = text.split("## 3. Screenshot caption set", 1)[1].split("\n## 4.", 1)[0]
    for line in sec.splitlines():
        if line.startswith("|") and not line.startswith("|---") and "Locale" not in line:
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            old.setdefault(cells[0], {})["head"] = cells[1:8]
    json.dump(old, open(CAPTIONS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def caption_font(profile, size, light=False):
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
        return ImageFont.truetype(os.path.join(ROOT, "assets/fonts/Inter/Inter-%s.ttf" % ("Medium" if light else "Bold")), size)
    if pick is None:
        return ImageFont.truetype(JAKARTA.replace("ExtraBold", "SemiBold") if light else JAKARTA, size)
    path, idx = pick
    try:
        f = ImageFont.truetype(path, size, index=idx)
    except OSError:
        f = ImageFont.truetype(path, size)
    if profile in RTL:
        try:
            f.set_variation_by_name("Bold")
        except Exception:
            pass
    return f


def line_factor(profile):
    """Line height / font size; Thai, Devanagari and Arabic stack marks."""
    return {"th": 1.4, "hi": 1.4, "ar-SA": 1.3, "ar": 1.3, "ur": 1.45}.get(profile, 1.2 if profile in ("ja", "ko", "zh-Hans", "zh-Hant") else 1.14)


def tlen(draw, text, font, rtl):
    return draw.textlength(text, font=font, direction="rtl" if rtl else None)


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
        if tlen(draw, t, font, rtl) <= max_w:
            cur = t
        else:
            if cur:
                lines.append(cur)
            cur = w
    lines.append(cur)
    return lines


def balance(draw, lines, font, rtl):
    """Two lines: re-split at the word boundary that evens out the widths."""
    if len(lines) != 2 or " " not in " ".join(lines):
        return lines
    words = " ".join(lines).split(" ")
    best = min(range(1, len(words)), key=lambda k: max(
        tlen(draw, " ".join(words[:k]), font, rtl), tlen(draw, " ".join(words[k:]), font, rtl)))
    return [" ".join(words[:best]), " ".join(words[best:])]


def fit_head(draw, text, profile, max_w, rtl):
    """One line up to 124px, two lines up to 108px, shrinking until it fits."""
    for size in range(124, 55, -4):
        font = caption_font(profile, size)
        lines = wrap_lines(draw, text, font, max_w, rtl)
        if len(lines) == 1 or (len(lines) == 2 and size <= 108):
            return font, balance(draw, lines, font, rtl), size
    font = caption_font(profile, 56)
    return font, wrap_lines(draw, text, font, max_w, rtl)[:2], 56


def fit_sub(draw, text, profile, max_w, rtl):
    for size in range(46, 29, -2):
        font = caption_font(profile, size, light=True)
        lines = wrap_lines(draw, text, font, max_w, rtl)
        if len(lines) <= 2:
            return font, balance(draw, lines, font, rtl), size
    font = caption_font(profile, 30, light=True)
    return font, wrap_lines(draw, text, font, max_w, rtl)[:2], 30


# ------------------------------------------------------------- raw -> phone

def prep_raw(path):
    """Raw render + iOS-style status bar and camera pill (all drawn shapes)."""
    im = Image.open(path).convert("RGB")
    k = im.size[0] / 440.0  # pixels per logical point
    r, g, b = im.getpixel((int(20 * k), int(6 * k)))
    fg = (14, 21, 38) if (r + g + b) / 3 > 128 else (245, 247, 251)
    d = ImageDraw.Draw(im)

    def P(v):
        return int(round(v * k))

    d.text((P(54), P(31)), "9:41", font=ImageFont.truetype(JAKARTA, P(17)), fill=fg, anchor="lm")
    # Battery.
    d.rounded_rectangle([P(384), P(25), P(410), P(37)], P(3.5), outline=fg + (255,), width=max(2, P(1)))
    d.rounded_rectangle([P(386), P(27), P(404), P(35)], P(2), fill=fg)
    d.rounded_rectangle([P(411.5), P(29), P(413), P(33)], P(1), fill=fg)
    # Wi-Fi: three arcs and a dot.
    cx, cy = 360, 38
    for rad in (11, 7.5, 4):
        d.arc([P(cx - rad), P(cy - rad), P(cx + rad), P(cy + rad)], 225, 315, fill=fg, width=max(2, P(1.8)))
    d.ellipse([P(cx - 1.6), P(cy - 2.2), P(cx + 1.6), P(cy + 1.0)], fill=fg)
    # Signal bars.
    for n, hgt in enumerate((4, 6.5, 9, 11.5)):
        x = 330 + n * 4.6
        d.rounded_rectangle([P(x), P(37 - hgt), P(x + 3.2), P(37)], P(0.9), fill=fg)
    # Camera pill.
    d.rounded_rectangle([P(157), P(11), P(283), P(48)], P(18.5), fill="#05070D")
    return im


def phone(raw, scr_w, rim="#3A4565"):
    """Raw image inside a rounded dark bezel; RGBA, transparent outside."""
    scr_h = round(raw.size[1] * scr_w / raw.size[0])
    bz = round(scr_w * 0.022)
    dw, dh = scr_w + 2 * bz, scr_h + 2 * bz
    rad = round(dw * 0.135)
    ss = 2
    body = Image.new("RGBA", (dw * ss, dh * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle([0, 0, dw * ss - 1, dh * ss - 1], rad * ss, fill="#0B1020")
    d.rounded_rectangle([2 * ss, 2 * ss, dw * ss - 1 - 2 * ss, dh * ss - 1 - 2 * ss], (rad - 2) * ss,
                        outline=rim, width=3 * ss)
    body = body.resize((dw, dh), Image.LANCZOS)
    mask = Image.new("L", (dw * ss, dh * ss), 0)
    ImageDraw.Draw(mask).rounded_rectangle([bz * ss, bz * ss, (bz + scr_w) * ss - 1, (bz + scr_h) * ss - 1],
                                           (rad - bz) * ss, fill=255)
    mask = mask.resize((dw, dh), Image.LANCZOS)
    scr = Image.new("RGB", (dw, dh), "#000")
    scr.paste(raw.resize((scr_w, scr_h), Image.LANCZOS), (bz, bz))
    body.paste(scr, (0, 0), mask)
    return body, bz


# --------------------------------------------------------------- background

_bg_cache = {}


def _blob(base, cx, cy, rx, ry, color, alpha, q):
    w, h = base.size
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).ellipse([(cx - rx) / q, (cy - ry) / q, (cx + rx) / q, (cy + ry) / q], fill=alpha)
    m = m.filter(ImageFilter.GaussianBlur(min(rx, ry) / q * 0.45))
    return Image.composite(Image.new("RGB", (w, h), color), base, m)


def background(i, dark, S, ch):
    """Frame-sized background; frames in PANO are halves of one wide canvas."""
    key = (i, dark, S, ch)
    if key in _bg_cache:
        return _bg_cache[key]
    q = 6
    wide = S * 2 if i in PANO else S
    w, h = wide // q, ch // q
    if dark:
        base = Image.new("RGB", (w, h), "#0A0F1C")
        base = _blob(base, S * 0.5, ch * 0.62, S * 0.75, ch * 0.30, "#34D7C0", 70, q)
        base = _blob(base, S * (0.15 if i % 2 else 0.9), ch * 0.08, S * 0.5, ch * 0.12, "#7AA2FF", 55, q)
    else:
        top, bot = (245, 247, 251), (255, 255, 255)
        base = Image.new("RGB", (w, h))
        px = base.load()
        for y in range(h):
            t = y / max(1, h - 1)
            c = tuple(round(a + (b - a) * t) for a, b in zip(top, bot))
            for x in range(w):
                px[x, y] = c
        if i in PANO:
            shapes = [(S * 1.0, ch * 0.70, S * 0.85, ch * 0.20, "#34D7C0", 95),
                      (S * 0.2, ch * 0.10, S * 0.55, ch * 0.10, "#7AA2FF", 70),
                      (S * 1.85, ch * 0.30, S * 0.55, ch * 0.14, "#7AA2FF", 60),
                      (S * 1.7, ch * 0.92, S * 0.6, ch * 0.10, "#34D7C0", 60)]
        else:
            side = 0.88 if i % 2 else 0.12
            shapes = [(S * side, ch * 0.72, S * 0.75, ch * 0.20, "#34D7C0", 90),
                      (S * (1 - side), ch * 0.12, S * 0.5, ch * 0.09, "#7AA2FF", 65)]
        for sh in shapes:
            base = _blob(base, *sh, q)
    img = base.resize((wide, ch), Image.BICUBIC)
    if i in PANO:
        x0 = S * i
        img = img.crop((x0, 0, x0 + S, ch))
    _bg_cache[key] = img
    return img


# ----------------------------------------------------------------- callouts

def _icon(d, kind, cx, cy, r, fg):
    w = int(max(8, r // 7))
    if kind == "check":
        d.line([(cx - r * .42, cy + r * .02), (cx - r * .1, cy + r * .34), (cx + r * .46, cy - r * .3)], fill=fg, width=w, joint="curve")
    elif kind == "plus":
        d.line([(cx - r * .4, cy), (cx + r * .4, cy)], fill=fg, width=w)
        d.line([(cx, cy - r * .4), (cx, cy + r * .4)], fill=fg, width=w)
    elif kind == "mic":
        d.rounded_rectangle([cx - r * .18, cy - r * .5, cx + r * .18, cy + r * .12], r * .18, fill=fg)
        d.arc([cx - r * .38, cy - r * .3, cx + r * .38, cy + r * .36], 0, 180, fill=fg, width=w)
        d.line([(cx, cy + r * .36), (cx, cy + r * .54)], fill=fg, width=w)
    elif kind == "person":
        d.ellipse([cx - r * .17, cy - r * .46, cx + r * .17, cy - r * .12], fill=fg)
        d.pieslice([cx - r * .4, cy - r * .02, cx + r * .4, cy + r * .78], 180, 360, fill=fg)
    elif kind == "swap":
        for sgn, yy in ((1, -.18), (-1, .2)):
            x1, x2 = cx - sgn * r * .42, cx + sgn * r * .42
            d.line([(x1, cy + r * yy), (x2, cy + r * yy)], fill=fg, width=w)
            d.line([(x2 - sgn * r * .18, cy + r * yy - r * .16), (x2, cy + r * yy), (x2 - sgn * r * .18, cy + r * yy + r * .16)], fill=fg, width=w, joint="curve")
    elif kind == "owe":  # arrow pointing out of a wallet-ish corner
        d.line([(cx - r * .3, cy + r * .3), (cx + r * .3, cy - r * .3)], fill=fg, width=w)
        d.line([(cx + r * .3, cy - r * .3 + r * .0), (cx + r * .3, cy - r * .02)], fill=fg, width=w)
        d.line([(cx + r * .3, cy - r * .3), (cx + r * .02, cy - r * .3)], fill=fg, width=w)


def callout_spec(i, meta):
    """(icon, primary text, primary size, max lines, secondary text, color key)"""
    return [
        ("check", meta["total"], 92, 1, meta["total_label"], "ink"),
        ("mic", "“" + meta["transcript"] + "”", 54, 3, None, "ink"),
        ("person", meta["leo"], 78, 1, None, "ink"),
        ("owe", meta["owe"], 68, 2, None, "coral"),
        ("swap", meta["settle"], 62, 3, None, "ink"),
        ("plus", meta["owed"], 96, 1, meta["owed_label"], "mint"),
        ("check", meta["paid"], 72, 1, None, "mint"),
    ][i]


def add_callout(canvas, i, meta, prof, rtl, dark, box, ch, S):
    icon, text, psize, maxl, sec, ckey = callout_spec(i, meta)
    # Direction marks keep amounts with symbols in one piece in RTL text.
    pad, gap, ic = 46, 34, 124
    max_card = 760 if maxl > 1 else 700
    tw_max = max_card - 2 * pad - ic - gap
    d = ImageDraw.Draw(canvas)
    for size in range(psize, 33, -4):
        f = caption_font(prof, size)
        lines = wrap_lines(d, text, f, tw_max, rtl)
        if len(lines) <= maxl:
            break
    lh = int(size * line_factor(prof))
    sf = caption_font(prof, 40)
    slh = int(40 * line_factor(prof))
    tw = max(tlen(d, ln, f, rtl) for ln in lines)
    if sec:
        tw = max(tw, tlen(d, sec, sf, rtl))
    th = lh * len(lines) + (slh + 6 if sec else 0)
    cw, chh = int(tw + 2 * pad + ic + gap), int(max(th + 2 * pad - 8, ic + 2 * pad - 8))
    surf = "#121A2B" if dark else "#FFFFFF"
    edge = "#2A3D5E" if dark else "#E3E7EF"
    col = {"ink": "#E8EDF7" if dark else INK, "coral": CORAL_D if dark else CORAL,
           "mint": MINT_D if dark else MINT}[ckey]
    mint = MINT_D if dark else MINT
    soft = "#14343A" if dark else "#E3F7F3"
    if ckey == "coral":
        mint, soft = (CORAL_D, "#3A2326") if dark else ("#E8664A", "#FFECE6")
    # Card placement: overhangs the phone edge on the end side (start side on odd frames).
    x0p, y0p, x1p, y1p, scr_top, scr_h = box
    end_right = (i % 2 == 0) != rtl
    over = 120
    cx0 = x1p + over - cw if end_right else x0p - over
    cx0 = max(48, min(S - 48 - cw, cx0))
    cy_mid = scr_top + CALLOUT_Y[i] * scr_h
    cy0 = int(max(y0p + 60, min(ch - 120 - chh, cy_mid - chh / 2)))
    # Shadow and glow.
    pad_s = 120
    lay = Image.new("RGBA", (cw + 2 * pad_s, chh + 2 * pad_s), (0, 0, 0, 0))
    ImageDraw.Draw(lay).rounded_rectangle([pad_s, pad_s + 22, pad_s + cw, pad_s + chh + 22], 54,
                                          fill=(52, 215, 192, 90) if dark else (14, 21, 38, 70))
    lay = lay.filter(ImageFilter.GaussianBlur(34))
    canvas.alpha_composite(lay, (cx0 - pad_s, cy0 - pad_s))
    card = Image.new("RGBA", (cw * 2, chh * 2), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle([0, 0, cw * 2 - 1, chh * 2 - 1], 108, fill=surf, outline=edge, width=4)
    card = card.resize((cw, chh), Image.LANCZOS)
    cd = ImageDraw.Draw(card)
    # Icon circle (supersampled).
    ics = Image.new("RGBA", (ic * 3, ic * 3), (0, 0, 0, 0))
    idr = ImageDraw.Draw(ics)
    idr.ellipse([0, 0, ic * 3 - 1, ic * 3 - 1], fill=soft)
    _icon(idr, icon, ic * 1.5, ic * 1.5, ic * 1.5, mint)
    ics = ics.resize((ic, ic), Image.LANCZOS)
    icx = cw - pad - ic if rtl else pad
    icy = (chh - ic) // 2
    card.alpha_composite(ics, (icx, icy))
    # Text block.
    ty = (chh - th) // 2
    tx0, tx1 = (pad, cw - pad - ic - gap) if rtl else (pad + ic + gap, cw - pad)
    if sec:
        sx = tx1 - tlen(cd, sec, sf, rtl) if rtl else tx0
        cd.text((sx, ty), sec, font=sf, fill="#9AA4B8" if dark else MUTED, direction="rtl" if rtl else None)
        ty += slh + 6
    for ln in lines:
        x = tx1 - tlen(cd, ln, f, rtl) if rtl else tx0
        cd.text((x, ty), ln, font=f, fill=col, direction="rtl" if rtl else None)
        ty += lh
    canvas.alpha_composite(card, (cx0, cy0))


# -------------------------------------------------------------------- frame

def frame(raw_path, meta, head, sub, profile, i, w, h):
    """Compose one store image at w x h (design laid out on 1320 wide, scaled)."""
    S = 1320
    ch = round(S * h / w)
    rtl = profile in RTL
    dark = i in DARK
    canvas = background(i, dark, S, ch).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    margin, tw = 96, S - 192
    hf, hl, hs = fit_head(draw, head, profile, tw, rtl)
    sf, sl, ss = fit_sub(draw, sub, profile, tw, rtl)
    fg = "#F5F7FB" if dark else INK
    y = 124
    for ln in hl:
        x = S - margin - tlen(draw, ln, hf, rtl) if rtl else margin
        draw.text((x, y), ln, font=hf, fill=fg, direction="rtl" if rtl else None)
        y += int(hs * line_factor(profile))
    y += 14
    for ln in sl:
        x = S - margin - tlen(draw, ln, sf, rtl) if rtl else margin
        draw.text((x, y), ln, font=sf, fill="#9AA4B8" if dark else MUTED, direction="rtl" if rtl else None)
        y += int(ss * line_factor(profile) * 1.04)
    # Phone: ~79% of the image height.
    top = max(540, y + 30)
    raw = prep_raw(raw_path)
    dev_h = ch - top - 50
    # dev_h = scr_h + 2*bz, bz = 0.022*scr_w, scr_w = scr_h*aspect.
    asp = raw.size[0] / raw.size[1]
    scr_h = dev_h / (1 + 2 * 0.022 * asp)
    scr_w = min(int(scr_h * asp), 1040)
    ph, bz = phone(raw, scr_w, "#7C8CB0" if dark else "#3A4565")
    px, py = (S - ph.size[0]) // 2, ch - 50 - ph.size[1]
    a = ph.getchannel("A")
    ring = Image.new("RGBA", ph.size, (0, 0, 0, 0))
    ring.putalpha(a)
    glow = Image.new("RGBA", (ph.size[0] + 240, ph.size[1] + 240), (0, 0, 0, 0))
    gcol = (52, 215, 192) if dark else (10, 20, 40)
    glow.paste(Image.new("RGBA", ph.size, gcol + (255,)), (120, 120 + (0 if dark else 34)), a)
    ga = glow.getchannel("A").point(lambda v: int(v * (0.38 if dark else 0.30))).filter(ImageFilter.GaussianBlur(44))
    glow.putalpha(ga)
    canvas.alpha_composite(glow, (px - 120, py - 120))
    canvas.alpha_composite(ph, (px, py))
    box = (px, py, px + ph.size[0], py + ph.size[1], py + bz, ph.size[1] - 2 * bz)
    add_callout(canvas, i, meta, profile, rtl, dark, box, ch, S)
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
        meta = json.load(open(os.path.join(RAW, prof, "meta.json"), encoding="utf-8"))
        for i, raw_name in enumerate(RAW_NAMES):
            raw = os.path.join(RAW, prof, raw_name + ".png")
            head, sub = caps[label]["head"][i], caps[label]["sub"][i]
            for size, folder, out in (
                ((1320, 2868), ios, lambda f: os.path.join(ROOT, "fastlane/screenshots_2_0", f, f"{i + 1}-{SLUGS[i]}.png")),
                ((1080, 2400), play, lambda f: os.path.join(ROOT, "fastlane/metadata_v2/android", f, "images/phoneScreenshots_2_0", f"{i + 1}.png")),
            ):
                if not folder:
                    continue
                path = out(folder)
                os.makedirs(os.path.dirname(path), exist_ok=True)
                frame(raw, meta, head, sub, prof, i, *size).save(path)
                if size[0] == 1320:
                    n_ios += 1
                else:
                    n_play += 1
        print(f"{prof}: ok", flush=True)
    print(f"ios images: {n_ios}, play images: {n_play}")


if __name__ == "__main__":
    main()
