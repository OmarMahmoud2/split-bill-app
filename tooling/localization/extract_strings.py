#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
LIB_ROOT = REPO_ROOT / "lib"
OUTPUT_PATH = REPO_ROOT / "tooling" / "localization" / "string_catalog.json"

CONTEXT_PATTERNS = [
    r"\bText\(",
    r"\bconst\s+Text\(",
    r"\btitle:\s*",
    r"\bsubtitle:\s*",
    r"\bmessage:\s*",
    r"\bcontent:\s*",
    r"\bemptyTitle:\s*",
    r"\bemptyMessage:\s*",
    r"\bsearchHint:\s*",
    r"\bactionLabel:\s*",
    r"\bhintText:\s*",
    r"\blabelText:\s*",
    r"\bhelperText:\s*",
    r"\berrorText:\s*",
    r"\btooltip:\s*",
    r"\bTextSpan\(\s*text:\s*",
]

STRING_PATTERN = re.compile(
    rf"(?x)(?:{'|'.join(CONTEXT_PATTERNS)})(?:const\s+)?(?:Text\()?(?P<quote>['\"])(?P<text>(?:\\.|(?! (?P=quote) ).)*) (?P=quote)"
)


@dataclass(frozen=True)
class Occurrence:
    file: str
    line: int
    context: str


def normalize_source_text(source: str) -> str:
    return source.replace("\r\n", "\n").strip()


def source_text_key(source: str) -> str:
    normalized = normalize_source_text(source)
    hash_value = 0xCBF29CE484222325
    for byte in normalized.encode("utf-8"):
        hash_value ^= byte
        hash_value = (hash_value * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return f"src_{hash_value:016x}"


def is_probably_user_facing(source: str) -> bool:
    stripped = source.strip()
    if not stripped:
        return False
    if stripped.startswith(("assets/", "http://", "https://")):
        return False
    if "/" in stripped and " " not in stripped and "_" in stripped:
        return False
    if stripped.endswith((".png", ".jpg", ".jpeg", ".json", ".svg")):
        return False
    return True


def build_catalog() -> dict[str, dict[str, object]]:
    catalog: dict[str, dict[str, object]] = {}
    occurrences: dict[str, list[Occurrence]] = defaultdict(list)

    for path in sorted(LIB_ROOT.rglob("*.dart")):
        content = path.read_text(encoding="utf-8")
        for match in STRING_PATTERN.finditer(content):
            source = normalize_source_text(match.group("text"))
            if not is_probably_user_facing(source):
                continue

            key = source_text_key(source)
            line = content.count("\n", 0, match.start()) + 1
            occurrences[key].append(
                Occurrence(
                    file=str(path.relative_to(REPO_ROOT)),
                    line=line,
                    context=content[max(0, match.start() - 30) : match.end() + 30],
                )
            )
            catalog[key] = {
                "key": key,
                "source": source,
                "hasInterpolation": "$" in source,
            }

    for key, item in catalog.items():
        item["occurrences"] = [
            {"file": occ.file, "line": occ.line} for occ in occurrences[key]
        ]

    return dict(sorted(catalog.items()))


def main() -> None:
    catalog = build_catalog()
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {len(catalog)} entries to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
