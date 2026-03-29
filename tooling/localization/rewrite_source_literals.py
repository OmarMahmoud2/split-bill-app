#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
LIB_ROOT = REPO_ROOT / "lib"
HELPER_IMPORT = "package:split_bill_app/localization/source_text_localizer.dart"

TEXT_LITERAL = re.compile(
    r"""(?P<const>\bconst\s+)?Text\(\s*(?P<quote>['"])(?P<value>(?:\\.|(?! (?P=quote) ).)*) (?P=quote)(?P<tail>\s*[,)])
    """,
    re.X,
)

TEXT_LITERAL_CLOSING = re.compile(
    r"""(?P<const>\bconst\s+)?Text\(\s*(?P<quote>['"])(?P<value>(?:\\.|(?! (?P=quote) ).)*) (?P=quote)(?P<tail>\s*\))
    """,
    re.X,
)

TEXT_SPAN_LITERAL = re.compile(
    r"""TextSpan\(\s*text:\s*(?P<quote>['"])(?P<value>(?:\\.|(?! (?P=quote) ).)*) (?P=quote)""",
    re.X,
)

PROPERTY_LITERAL = re.compile(
    r"""(?P<prop>hintText|labelText|helperText|errorText|tooltip|title|subtitle|message|emptyTitle|emptyMessage|searchHint|actionLabel|buttonText|infoMessage)\s*:\s*(?P<quote>['"])(?P<value>(?:\\.|(?! (?P=quote) ).)*) (?P=quote)""",
    re.X,
)


def should_translate(value: str) -> bool:
    if "$" in value:
        return False
    stripped = value.strip()
    if not stripped:
        return False
    if stripped.startswith(("assets/", "http://", "https://")):
        return False
    if "/" in stripped and " " not in stripped and "_" in stripped:
        return False
    return True


def ensure_import(content: str) -> str:
    if HELPER_IMPORT in content:
        return content
    flutter_import = "import 'package:flutter/material.dart';"
    package_import = f"import '{HELPER_IMPORT}';"
    if flutter_import in content:
        return content.replace(flutter_import, f"{flutter_import}\n{package_import}", 1)
    lines = content.splitlines()
    insert_at = 0
    while insert_at < len(lines) and lines[insert_at].startswith("import "):
        insert_at += 1
    lines.insert(insert_at, package_import)
    return "\n".join(lines) + ("\n" if content.endswith("\n") else "")


def rewrite_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    content = original

    def replace_text(match: re.Match[str]) -> str:
        value = match.group("value")
        if not should_translate(value):
            return match.group(0)
        const_prefix = match.group("const") or ""
        quote = match.group("quote")
        tail = match.group("tail")
        return f"{const_prefix}LocalizedText.source({quote}{value}{quote}{tail}"

    def replace_span(match: re.Match[str]) -> str:
        value = match.group("value")
        if not should_translate(value):
            return match.group(0)
        quote = match.group("quote")
        return f"TextSpan(text: translateSourceText({quote}{value}{quote})"

    def replace_property(match: re.Match[str]) -> str:
        prop = match.group("prop")
        value = match.group("value")
        if not should_translate(value):
            return match.group(0)
        quote = match.group("quote")
        return f"{prop}: translateSourceText({quote}{value}{quote})"

    content = TEXT_LITERAL.sub(replace_text, content)
    content = TEXT_LITERAL_CLOSING.sub(replace_text, content)
    content = TEXT_SPAN_LITERAL.sub(replace_span, content)
    content = PROPERTY_LITERAL.sub(replace_property, content)

    if content == original:
        return False

    content = ensure_import(content)
    path.write_text(content, encoding="utf-8")
    return True


def main() -> None:
    changed = 0
    for path in sorted(LIB_ROOT.rglob("*.dart")):
        if rewrite_file(path):
            changed += 1
            print(f"updated {path.relative_to(REPO_ROOT)}")
    print(f"Updated {changed} files")


if __name__ == "__main__":
    main()
