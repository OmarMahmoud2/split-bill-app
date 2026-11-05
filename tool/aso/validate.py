#!/usr/bin/env python3
"""Validate fastlane/metadata_v2 against App Store Connect and Google Play limits.

Characters are counted as Unicode code points after NFC normalisation, which is how
both consoles count. UTF-16 code units are reported as a warning when they differ
materially (emoji / astral characters), since neither store uses them for the limit.
{{APP_NAME}} is substituted with a 9-character placeholder before counting.
"""
import os
import re
import sys
import unicodedata

REPO = "/Users/omarmahmoud/FlutterProjects/VsCodePros/split_bill_app"
OUT = os.path.join(REPO, "fastlane", "metadata_v2")
PLACEHOLDER = "X" * 9  # overridden below when APP_NAME is set

IOS_LIMITS = {
    "name.txt": 30,
    "subtitle.txt": 30,
    "keywords.txt": 100,
    "promotional_text.txt": 170,
    "description.txt": 4000,
    "release_notes.txt": 4000,
}
IOS_REQUIRED = list(IOS_LIMITS) + ["marketing_url.txt", "support_url.txt", "privacy_url.txt"]
PLAY_LIMITS = {
    "title.txt": 30,
    "short_description.txt": 80,
    "full_description.txt": 4000,
    "changelogs/24.txt": 500,
}

EXPECTED_IOS = {
    "ar-SA", "da", "de-DE", "en-US", "en-GB", "en-AU", "en-CA", "es-ES", "es-MX", "fr-FR", "fr-CA",
    "hi", "id", "it", "ja", "ko", "no", "nl-NL", "pl", "pt-BR", "pt-PT", "ru", "sv", "th", "tr", "vi",
    "zh-Hans", "zh-Hant",
}
EXPECTED_PLAY = {
    "ar", "da-DK", "de-DE", "en-US", "en-GB", "es-ES", "es-419", "fr-FR", "hi-IN", "id", "it-IT",
    "ja-JP", "ko-KR", "no-NO", "nl-NL", "pl-PL", "pt-BR", "pt-PT", "ru-RU", "sv-SE", "th", "tr-TR",
    "ur", "vi", "zh-CN", "zh-TW",
}

# Competitor and third-party trademarks that must not appear in the keyword field.
BANNED_KEYWORDS = {
    "splitwise", "tricount", "settleup", "settle up", "splid", "spliit", "tab", "tabb", "bunq",
    "venmo", "paypal", "revolut", "wise", "zelle", "cashapp", "cash app", "monzo", "tikkie", "swish",
    "mobilepay", "vipps", "bizum", "pix", "upi", "paypay", "toss", "kakaopay", "promptpay", "momo",
    "wechat", "alipay", "apple", "google", "whatsapp", "imessage",
}

# Scripts without word spaces: compare keywords by substring against the name + subtitle.
CJK_THAI = re.compile(r"[぀-ヿ㐀-䶿一-鿿가-힯฀-๿]")


# Once the name is final, pass it as APP_NAME (e.g. APP_NAME=Evens): it is
# mapped back to the token so every check runs on the real text.
FINAL_NAME = os.environ.get("APP_NAME", "")
if FINAL_NAME:
    PLACEHOLDER = FINAL_NAME


def read(path):
    with open(path, encoding="utf-8") as f:
        text = f.read().rstrip("\n")
    return text.replace(FINAL_NAME, "{{APP_NAME}}") if FINAL_NAME else text


def count(text):
    text = unicodedata.normalize("NFC", text.replace("{{APP_NAME}}", PLACEHOLDER))
    return len(text), len(text.encode("utf-16-le")) // 2


def words(text):
    text = text.replace("{{APP_NAME}}", "")
    # Split on whitespace and punctuation only, so combining marks (Devanagari, Thai) stay inside words.
    return {w for w in re.split(r"[\s,.;:!?()\"/&+|«»„“”-]+", text.lower()) if w and not w.isdigit()}


def check_keywords(loc, kw, name, subtitle, errors, warnings):
    if ", " in kw or kw != kw.strip():
        errors.append(f"[{loc}] keywords: space after a comma or leading/trailing space")
    if " ," in kw:
        errors.append(f"[{loc}] keywords: space before a comma")
    items = [k for k in kw.split(",") if k]
    if len(items) != len(set(i.lower() for i in items)):
        errors.append(f"[{loc}] keywords: duplicate entry")
    for k in items:
        kl = k.lower()
        if kl in BANNED_KEYWORDS or any(b in kl.split() for b in BANNED_KEYWORDS if " " not in b):
            errors.append(f"[{loc}] keywords: trademark or competitor term '{k}'")
    title_text = (name + " " + subtitle).replace("{{APP_NAME}}", "")
    title_words = words(title_text)
    for k in items:
        if CJK_THAI.search(k) or CJK_THAI.search(title_text):
            if len(k) >= 2 and (k in title_text or any(k in w for w in title_text.split())):
                errors.append(f"[{loc}] keywords: '{k}' already in name/subtitle")
        for w in words(k):
            if w in title_words:
                errors.append(f"[{loc}] keywords: word '{w}' repeats name/subtitle")


def main():
    errors, warnings = [], []
    ios_found, play_found = set(), set()

    for loc in sorted(os.listdir(OUT)):
        if loc == "android":
            continue
        ios_found.add(loc)
        d = os.path.join(OUT, loc)
        for fn in IOS_REQUIRED:
            p = os.path.join(d, fn)
            if not os.path.isfile(p) or not read(p).strip():
                errors.append(f"[{loc}] missing or empty {fn}")
        name = read(os.path.join(d, "name.txt")) if os.path.isfile(os.path.join(d, "name.txt")) else ""
        if "{{APP_NAME}}" not in name:
            errors.append(f"[{loc}] name.txt lacks {{{{APP_NAME}}}}")
        for fn, limit in IOS_LIMITS.items():
            p = os.path.join(d, fn)
            if not os.path.isfile(p):
                continue
            text = read(p)
            n, u16 = count(text)
            if n > limit:
                errors.append(f"[{loc}] {fn}: {n} chars > {limit}")
            if u16 != n:
                warnings.append(f"[{loc}] {fn}: {u16} UTF-16 units vs {n} code points")
            if re.search(r"\{[A-Z_]+\}", text.replace("{{APP_NAME}}", "")):
                errors.append(f"[{loc}] {fn}: unfilled template token")
            if fn in ("description.txt", "release_notes.txt") and "{{APP_NAME}}" not in text:
                warnings.append(f"[{loc}] {fn}: does not mention {{{{APP_NAME}}}}")
        if os.path.isfile(os.path.join(d, "keywords.txt")):
            check_keywords(loc, read(os.path.join(d, "keywords.txt")), name,
                           read(os.path.join(d, "subtitle.txt")), errors, warnings)

    for loc in sorted(os.listdir(os.path.join(OUT, "android"))):
        play_found.add(loc)
        d = os.path.join(OUT, "android", loc)
        for fn, limit in PLAY_LIMITS.items():
            p = os.path.join(d, fn)
            if not os.path.isfile(p) or not read(p).strip():
                errors.append(f"[android/{loc}] missing or empty {fn}")
                continue
            text = read(p)
            n, u16 = count(text)
            if n > limit:
                errors.append(f"[android/{loc}] {fn}: {n} chars > {limit}")
            if u16 != n:
                warnings.append(f"[android/{loc}] {fn}: {u16} UTF-16 units vs {n} code points")
            if re.search(r"\{[A-Z_]+\}", text.replace("{{APP_NAME}}", "")):
                errors.append(f"[android/{loc}] {fn}: unfilled template token")
            if fn == "title.txt" and "{{APP_NAME}}" not in text:
                errors.append(f"[android/{loc}] title.txt lacks {{{{APP_NAME}}}}")
            if fn == "full_description.txt" and re.search(r"Apple ID|Apple Cash", text):
                errors.append(f"[android/{loc}] full_description mentions Apple ID / Apple Cash")

    if ios_found != EXPECTED_IOS:
        errors.append(f"iOS locale set mismatch: missing {sorted(EXPECTED_IOS - ios_found)}, extra {sorted(ios_found - EXPECTED_IOS)}")
    if play_found != EXPECTED_PLAY:
        errors.append(f"Play locale set mismatch: missing {sorted(EXPECTED_PLAY - play_found)}, extra {sorted(play_found - EXPECTED_PLAY)}")

    # Summary table for the tightest fields.
    print("locale        name  sub  kw   promo | play-title short changelog")
    for loc in sorted(ios_found):
        d = os.path.join(OUT, loc)
        vals = [count(read(os.path.join(d, fn)))[0] for fn in ("name.txt", "subtitle.txt", "keywords.txt", "promotional_text.txt")]
        print(f"{loc:12s}  {vals[0]:3d}  {vals[1]:3d}  {vals[2]:3d}  {vals[3]:4d}")
    for loc in sorted(play_found):
        d = os.path.join(OUT, "android", loc)
        vals = [count(read(os.path.join(d, fn)))[0] for fn in ("title.txt", "short_description.txt", "changelogs/24.txt")]
        print(f"android/{loc:12s}                     | {vals[0]:3d}        {vals[1]:3d}   {vals[2]:3d}")

    for w in warnings:
        print("WARN", w)
    for e in errors:
        print("ERROR", e)
    print(f"\n{len(ios_found)} iOS locales, {len(play_found)} Play locales, {len(errors)} errors, {len(warnings)} warnings")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
