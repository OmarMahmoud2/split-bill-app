#!/usr/bin/env python3
"""Phone-only images for the landing page (raw render + status bar + bezel).

  python3 tool/store/export_landing_images.py [out_dir]   (default build/landing_images)

Writes <out_dir>/<lang>/<n>-<slug>-<width>.{png,webp} for width 400 and 800
(transparent outside the rounded bezel), for the 22 landing languages. Needs
build/store_raw/<profile>/ from tool/store/run_store_screenshots.sh.
"""
import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("frame_screenshots", os.path.join(HERE, "frame_screenshots.py"))
fs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fs)

# landing language -> store render profile
LANGS = {
    "en": "en-US", "ar": "ar-SA", "da": "da", "de": "de", "es": "es-ES", "fr": "fr-FR",
    "hi": "hi", "id": "id", "it": "it", "ja": "ja", "ko": "ko", "nb": "no", "nl": "nl",
    "pl": "pl", "pt": "pt-BR", "ru": "ru", "sv": "sv", "th": "th", "tr": "tr", "ur": "ur",
    "vi": "vi", "zh": "zh-Hans",
}
WIDTHS = (400, 800)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(fs.ROOT, "build", "landing_images")
    n = 0
    for lang, prof in LANGS.items():
        d = os.path.join(out, lang)
        os.makedirs(d, exist_ok=True)
        for i, raw_name in enumerate(fs.RAW_NAMES):
            path = os.path.join(fs.RAW, prof, raw_name + ".png")
            if not os.path.exists(path):
                print(f"missing {path}", file=sys.stderr)
                continue
            raw = fs.prep_raw(path)
            big, _ = fs.phone(raw, 1000)  # render once large, downscale per width
            for w in WIDTHS:
                img = big.resize((w, round(big.size[1] * w / big.size[0])), fs.Image.LANCZOS)
                base = os.path.join(d, f"{i + 1}-{fs.SLUGS[i]}-{w}")
                img.save(base + ".png", optimize=True)
                img.save(base + ".webp", quality=88, method=6)
                n += 2
        print(f"{lang}: ok", flush=True)
    print(f"{n} files in {out}")


if __name__ == "__main__":
    main()
