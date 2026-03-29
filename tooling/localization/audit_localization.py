#!/usr/bin/env python3
from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
LIB_ROOT = REPO_ROOT / "lib"

STRING_PATTERN = re.compile(r"""(?P<quote>['"])(?P<text>(?:\\.|(?! (?P=quote) ).)*) (?P=quote)""", re.X)

IGNORE_EXACT = {
    "apple.com",
    "google.com",
    "PENDING",
    "PAID",
    "PARTIAL",
    "UNPAID",
    "guest",
    "host",
    "app_user",
    "hostId",
    "storeName",
    "billId",
    "uid",
    "fcmToken",
    "currencyCode",
    "assignedTo",
    "data:image",
    "data:image/jpeg;base64,${base64Encode(imageBytes)}",
    "FLUTTER_NOTIFICATION_CLICK",
    "USD",
    "EG",
    "REVIEW",
    "UNATTEMPTED",
}

IGNORE_PREFIXES = (
    "package:",
    "dart:",
    "assets/",
    "http://",
    "https://",
    "api/",
    "images/",
    "lib/",
    "users",
    "bills",
    "groups",
    "notifications",
    "ca-app-pub-",
    "@mipmap/",
)

IGNORE_SUFFIXES = (".png", ".jpg", ".jpeg", ".json", ".svg")


def should_ignore(line: str, literal: str) -> bool:
    if not re.search(r"[A-Za-z]", literal):
        return True
    if literal in IGNORE_EXACT:
        return True
    if literal.startswith(IGNORE_PREFIXES):
        return True
    if literal.endswith(IGNORE_SUFFIXES):
        return True
    if re.fullmatch(r"[a-z0-9_]+", literal):
        return True
    if re.fullmatch(r"[a-z]+(?:[A-Z][A-Za-z0-9]*)+", literal):
        return True
    if "debugPrint(" in line or "print(" in line:
        return True
    if line.strip().startswith(("import ", "export ")):
        return True
    return False


def main() -> None:
    findings: dict[str, list[str]] = defaultdict(list)

    for path in sorted(LIB_ROOT.rglob("*.dart")):
      if "config/" in str(path) or path.name == "firebase_options.dart":
        continue

      for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        for match in STRING_PATTERN.finditer(line):
          literal = match.group("text")
          if should_ignore(line, literal):
            continue
          findings[str(path.relative_to(REPO_ROOT))].append(
            f"{line_number}: {literal}"
          )

    total = sum(len(items) for items in findings.values())
    print(f"Potential raw UI strings: {total}")
    for file_path, items in sorted(findings.items(), key=lambda item: (-len(item[1]), item[0])):
      print(f"\n{file_path} ({len(items)})")
      for sample in items[:20]:
        print(f"  {sample}")


if __name__ == "__main__":
    main()
