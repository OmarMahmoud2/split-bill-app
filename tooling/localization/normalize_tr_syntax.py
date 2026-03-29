#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
LIB_ROOT = REPO_ROOT / "lib"
EASY_IMPORT = "package:easy_localization/easy_localization.dart"
SOURCE_HELPER_IMPORT = "package:split_bill_app/localization/source_text_localizer.dart"


def find_matching_paren(text: str, open_index: int) -> int:
    depth = 0
    quote: str | None = None
    escape = False
    for index in range(open_index, len(text)):
        char = text[index]
        if quote:
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == quote:
                quote = None
            continue
        if char in {"'", '"'}:
            quote = char
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index
    raise ValueError("No matching parenthesis found")


FIRST_ARG_TR = re.compile(
    r"^\s*(?P<quote>['\"])(?P<key>[a-z0-9_]+)(?P=quote)\.tr\(\)(?P<rest>[\s\S]*)$"
)


def normalize_text_widgets(content: str) -> str:
    token = "Text("
    index = 0
    while True:
        start = content.find(token, index)
        if start == -1:
            break
        open_paren = start + len("Text")
        close_paren = find_matching_paren(content, open_paren)
        inner = content[open_paren + 1:close_paren]
        match = FIRST_ARG_TR.match(inner)
        if not match:
            index = close_paren + 1
            continue

        key = match.group("key")
        rest = match.group("rest")
        after = content[close_paren + 1:]

        if after.startswith(").tr("):
            tr_open = close_paren + 2 + len(".tr")
            tr_close = find_matching_paren(content, tr_open)
            tr_suffix = content[close_paren + 2:tr_close + 1]
            replacement = f"Text('{key}'{rest}){tr_suffix}"
            content = content[:start] + replacement + content[tr_close + 1:]
            index = start + len(replacement)
            continue

        if after.startswith(".tr("):
            replacement = f"Text('{key}'{rest})"
            content = content[:start] + replacement + content[close_paren + 1:]
            index = start + len(replacement)
            continue

        index = close_paren + 1

    return content


def strip_const_before_tr(content: str) -> str:
    patterns = [
        r"const\s+Scaffold\((?=[\s\S]{0,180}\.tr\()",
        r"const\s+Center\((?=[\s\S]{0,180}\.tr\()",
        r"const\s+LoadingStateWidget\((?=[\s\S]{0,180}\.tr\()",
        r"const\s+ProfileSectionTitle\((?=[\s\S]{0,180}\.tr\()",
        r"const\s+CustomAppHeader\((?=[\s\S]{0,240}\.tr\()",
        r"const\s+InputDecoration\((?=[\s\S]{0,180}\.tr\()",
        r"const\s+SnackBar\((?=[\s\S]{0,220}\.tr\()",
        r"const\s+AlertDialog\((?=[\s\S]{0,260}\.tr\()",
        r"const\s+TextButton\((?=[\s\S]{0,220}\.tr\()",
        r"const\s+ElevatedButton\((?=[\s\S]{0,220}\.tr\()",
        r"const\s+EmptyStateWidget\((?=[\s\S]{0,220}\.tr\()",
    ]
    for pattern in patterns:
        content = re.sub(pattern, lambda match: match.group(0).replace("const ", "", 1), content)
    return content


def ensure_easy_import(content: str) -> str:
    if ".tr(" not in content:
        return content
    if EASY_IMPORT in content:
        return content
    lines = content.splitlines()
    insert_at = 0
    while insert_at < len(lines) and lines[insert_at].startswith("import "):
        insert_at += 1
    lines.insert(insert_at, f"import '{EASY_IMPORT}';")
    return "\n".join(lines) + ("\n" if content.endswith("\n") else "")


def cleanup_source_helper_import(content: str) -> str:
    if "translateSourceText(" in content or "LocalizedText.source(" in content or "localizedTextSpan(" in content:
        return content
    return "\n".join(
        line for line in content.splitlines() if SOURCE_HELPER_IMPORT not in line
    ) + ("\n" if content.endswith("\n") else "")


def rewrite_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    content = original
    content = normalize_text_widgets(content)
    content = strip_const_before_tr(content)
    content = ensure_easy_import(content)
    content = cleanup_source_helper_import(content)
    if content == original:
        return False
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
