#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
LIB_ROOT = REPO_ROOT / "lib"
CATALOG_PATH = REPO_ROOT / "tooling" / "localization" / "key_catalog.json"
HELPER_IMPORT = "package:split_bill_app/localization/source_text_localizer.dart"

STRING_LITERAL_PATTERN = re.compile(r"""(?P<quote>['"])(?P<text>(?:\\.|(?! (?P=quote) ).)*) (?P=quote)""", re.X)


def load_catalog() -> dict[str, dict[str, object]]:
    raw = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    return {key: value for key, value in raw.items()}


def replacement_for_source(source: str, catalog: dict[str, dict[str, object]]) -> str | None:
    if source not in catalog:
        return None
    entry = catalog[source]
    key = entry["key"]
    placeholders = entry["placeholders"]
    if placeholders:
        named_args = ", ".join(
            f"'{item['name']}': ({item['expression']}).toString()"
            for item in placeholders
        )
        return f"'{key}'.tr(namedArgs: {{{named_args}}})"
    return f"'{key}'.tr()"


def find_matching_paren(text: str, start_index: int) -> int:
    depth = 0
    quote: str | None = None
    escape = False
    for index in range(start_index, len(text)):
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


def replace_translate_source_text(content: str, catalog: dict[str, dict[str, object]]) -> str:
    pattern = re.compile(r"translateSourceText\((?P<quote>['\"])(?P<text>(?:\\.|(?! (?P=quote) ).)*) (?P=quote)\)", re.X)

    def repl(match: re.Match[str]) -> str:
        source = match.group("text")
        replacement = replacement_for_source(source, catalog)
        return replacement or match.group(0)

    content = pattern.sub(repl, content)
    content = re.sub(r"(['\"][a-z0-9_]+['\"]\.tr\([^)]*\))\.tr\(\)", r"\1", content)
    return content


def replace_localized_text_widgets(content: str, catalog: dict[str, dict[str, object]]) -> str:
    token = "LocalizedText.source("
    index = 0
    while True:
        start = content.find(token, index)
        if start == -1:
            break

        const_start = start - 6 if content[max(0, start - 6):start] == "const " else start
        open_paren = start + len("LocalizedText.source")
        close_paren = find_matching_paren(content, open_paren)
        segment = content[start:close_paren + 1]
        first_string = STRING_LITERAL_PATTERN.search(segment)
        if not first_string:
            index = close_paren + 1
            continue

        source = first_string.group("text")
        replacement = replacement_for_source(source, catalog)
        if not replacement:
            index = close_paren + 1
            continue

        before = segment[:first_string.start()]
        after = segment[first_string.end():]
        new_widget = f"Text({replacement}{after}).tr()"
        content = content[:const_start] + new_widget + content[close_paren + 1:]
        index = const_start + len(new_widget)

    return content


def replace_localized_text_span(content: str, catalog: dict[str, dict[str, object]]) -> str:
    pattern = re.compile(
        r"localizedTextSpan\((?P<quote>['\"])(?P<text>(?:\\.|(?! (?P=quote) ).)*) (?P=quote)",
        re.X,
    )

    def repl(match: re.Match[str]) -> str:
        source = match.group("text")
        replacement = replacement_for_source(source, catalog)
        if not replacement:
            return match.group(0)
        return f"TextSpan(text: {replacement}"

    return pattern.sub(repl, content)


def replace_key_style_tr_calls(content: str) -> str:
    return re.sub(
        r"translateSourceText\((['\"])([a-z0-9_]+)\1\)\.tr\(\)",
        lambda match: f"'{match.group(2)}'.tr()",
        content,
    )


def cleanup_imports(content: str) -> str:
    lines = content.splitlines()
    if "translateSourceText(" not in content and "LocalizedText.source(" not in content and "localizedTextSpan(" not in content:
        lines = [line for line in lines if HELPER_IMPORT not in line]
    return "\n".join(lines) + ("\n" if content.endswith("\n") else "")


def rewrite_file(path: Path, catalog: dict[str, dict[str, object]]) -> bool:
    original = path.read_text(encoding="utf-8")
    content = original

    content = replace_translate_source_text(content, catalog)
    content = replace_key_style_tr_calls(content)
    content = replace_localized_text_widgets(content, catalog)
    content = replace_localized_text_span(content, catalog)
    content = cleanup_imports(content)

    if content == original:
        return False

    path.write_text(content, encoding="utf-8")
    return True


def main() -> None:
    catalog = load_catalog()
    changed = 0
    for path in sorted(LIB_ROOT.rglob("*.dart")):
        if path.match("lib/localization/*"):
            continue
        if rewrite_file(path, catalog):
            changed += 1
            print(f"updated {path.relative_to(REPO_ROOT)}")
    print(f"Updated {changed} files")


if __name__ == "__main__":
    main()
