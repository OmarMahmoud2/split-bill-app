#!/usr/bin/env python3
"""Generate fastlane/metadata_v2 (iOS + android) from the copy modules."""
import os
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from copy_en import EN  # noqa: E402
from copy_eu import EU  # noqa: E402
from copy_asia import ASIA  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(REPO, "fastlane", "metadata_v2")
OLD = os.path.join(REPO, "fastlane", "metadata")
NAME = "Evens"
NEXT_VERSION_CODE = 24  # pubspec 1.2.0+23 -> 24

URL_FILES = ["marketing_url.txt", "support_url.txt", "privacy_url.txt"]
TOKEN = re.compile(r"\{([A-Z_]+)\}")


def fill(text, vars_):
    def rep(m):
        key = m.group(1)
        if key not in vars_:
            raise KeyError(f"unknown token {{{key}}}")
        return vars_[key]
    return TOKEN.sub(rep, text)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text.strip("\n") + "\n")


def main():
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    ios_written, play_written = [], []
    for entry in EN + EU + ASIA:
        base = {"NAME": NAME, "FLAT": entry.get("flat", "")}
        base.update(entry.get("vars", {}))
        ios_vars = dict(base, PAY=entry["pay"], LEGAL=entry.get("legal", ""))
        play_vars = dict(base, PAY=entry.get("pay_play") or entry["pay"], LEGAL="")

        for loc in entry["ios"]:
            d = os.path.join(OUT, loc)
            write(os.path.join(d, "name.txt"), NAME + entry["name"])
            write(os.path.join(d, "subtitle.txt"), entry["subtitle"])
            write(os.path.join(d, "keywords.txt"), entry["keywords"])
            write(os.path.join(d, "promotional_text.txt"), fill(entry["promo"], ios_vars))
            write(os.path.join(d, "description.txt"), fill(entry["desc"], ios_vars))
            write(os.path.join(d, "release_notes.txt"), fill(entry["release"], ios_vars))
            for uf in URL_FILES:  # unchanged from the existing metadata
                shutil.copyfile(os.path.join(OLD, "en-US", uf), os.path.join(d, uf))
            ios_written.append(loc)

        for loc in entry["play"]:
            d = os.path.join(OUT, "android", loc)
            write(os.path.join(d, "title.txt"), NAME + entry["name"])
            write(os.path.join(d, "short_description.txt"), fill(entry["short"], play_vars))
            write(os.path.join(d, "full_description.txt"), fill(entry["desc"], play_vars))
            changelog = fill(entry["changelog"], play_vars)
            if len(changelog) > 500:  # Play limit; drop the split-methods bullet (always line 6)
                lines = changelog.split("\n")
                del lines[5]
                changelog = "\n".join(lines)
            write(os.path.join(d, "changelogs", f"{NEXT_VERSION_CODE}.txt"), changelog)
            play_written.append(loc)

    print(f"iOS locales ({len(ios_written)}): {' '.join(sorted(ios_written))}")
    print(f"Play locales ({len(play_written)}): {' '.join(sorted(play_written))}")


if __name__ == "__main__":
    main()
