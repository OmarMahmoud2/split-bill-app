#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from collections import defaultdict
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
LIB_ROOT = REPO_ROOT / "lib"
TRANSLATIONS_DIR = REPO_ROOT / "assets" / "translations"
OUTPUT_PATH = REPO_ROOT / "tooling" / "localization" / "key_catalog.json"
RAW_STRING_CATALOG_PATH = REPO_ROOT / "tooling" / "localization" / "string_catalog.json"

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
    r"\btranslateSourceText\(",
    r"\bLocalizedText\.source\(",
    r"\blocalizedTextSpan\(",
]

STRING_PATTERN = re.compile(
    rf"(?x)(?:{'|'.join(CONTEXT_PATTERNS)})(?:const\s+)?(?:Text\()?(?P<quote>['\"])(?P<text>(?:\\.|(?! (?P=quote) ).)*) (?P=quote)"
)

RAW_PLACEHOLDER_PATTERN = re.compile(
    r"\$(?:\{(?P<braced>[^}]+)\}|(?P<simple>[A-Za-z_]\w*(?:\.\w+)*))"
)

COMMON_KEY_OVERRIDES = {
    "Cancel": "common_cancel",
    "Continue": "common_continue",
    "Delete": "common_delete",
    "Edit": "common_edit",
    "Remove": "common_remove",
    "Save Changes": "common_save_changes",
    "Loading history...": "loading_history",
    "Loading groups...": "loading_groups",
    "Loading contacts...": "loading_contacts",
    "Loading notifications...": "loading_notifications",
    "Checking app status...": "checking_app_status",
    "Signing in...": "signing_in",
    "Checking onboarding...": "checking_onboarding",
    "Setting up secure connection...": "setting_up_secure_connection",
    "Split Bill": "app_title",
}


def load_existing_english() -> dict[str, str]:
    path = TRANSLATIONS_DIR / "en.json"
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def normalize_source(source: str) -> str:
    return source.replace("\r\n", "\n").strip()


def is_user_facing(source: str) -> bool:
    stripped = source.strip()
    if not stripped:
        return False
    if stripped.startswith(("assets/", "http://", "https://")):
        return False
    if stripped.endswith((".png", ".jpg", ".jpeg", ".json", ".svg")):
        return False
    return True


def placeholder_name(expr: str, used: set[str]) -> str:
    expr = expr.strip()
    if expr in {"e", "error", "snapshot.error"} or "error" in expr.lower():
        base = "error"
    elif ".length" in expr:
        tokens = re.findall(r"[A-Za-z_]\w*", expr.split(".length")[0])
        base = (tokens[-1] if tokens else "count") + "_count"
    else:
        quoted = re.findall(r"""['"]([A-Za-z_]\w*)['"]""", expr)
        if quoted:
            base = quoted[-1]
        else:
            tokens = re.findall(r"[A-Za-z_]\w*", expr)
            base = tokens[-1] if tokens else "value"
    base = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", base).lower()
    base = re.sub(r"[^a-z0-9_]+", "_", base).strip("_") or "value"
    candidate = base
    index = 2
    while candidate in used:
        candidate = f"{base}_{index}"
        index += 1
    used.add(candidate)
    return candidate


def convert_placeholders(source: str) -> tuple[str, list[dict[str, str]]]:
    used: set[str] = set()
    placeholders: list[dict[str, str]] = []

    def repl(match: re.Match[str]) -> str:
        expr = match.group("braced") or match.group("simple") or ""
        name = placeholder_name(expr, used)
        placeholders.append({"name": name, "expression": expr})
        return "{" + name + "}"

    template = RAW_PLACEHOLDER_PATTERN.sub(repl, source)
    return template, placeholders


def slugify(text: str) -> str:
    text = text.lower()
    text = text.replace("&", " and ")
    text = text.replace("@", " at ")
    text = text.replace("+", " plus ")
    text = text.replace("\n", " ")
    text = re.sub(r"\{([^}]+)\}", r" \1 ", text)
    text = re.sub(r"[^a-z0-9]+", "_", text)
    text = re.sub(r"_+", "_", text).strip("_")
    return text or "text"


def collect_sources_from_code() -> dict[str, list[dict[str, object]]]:
    occurrences: dict[str, list[dict[str, object]]] = defaultdict(list)

    for path in sorted(LIB_ROOT.rglob("*.dart")):
        content = path.read_text(encoding="utf-8")
        for match in STRING_PATTERN.finditer(content):
            source = normalize_source(match.group("text"))
            if not is_user_facing(source):
                continue
            line = content.count("\n", 0, match.start()) + 1
            occurrences[source].append(
                {"file": str(path.relative_to(REPO_ROOT)), "line": line}
            )

    return occurrences


def collect_sources_from_raw_catalog() -> dict[str, list[dict[str, object]]]:
    raw_catalog = json.loads(RAW_STRING_CATALOG_PATH.read_text(encoding="utf-8"))
    occurrences: dict[str, list[dict[str, object]]] = {}
    for entry in raw_catalog.values():
        source = normalize_source(entry["source"])
        occurrences[source] = entry.get("occurrences", [])
    return occurrences


def build_catalog(source_occurrences: dict[str, list[dict[str, object]]]) -> dict[str, dict[str, object]]:
    existing_english = load_existing_english()
    existing_reverse = {
        value: key
        for key, value in existing_english.items()
        if not key.startswith("src_")
    }

    found: dict[str, dict[str, object]] = {source: {} for source in source_occurrences}
    key_counts: dict[str, int] = defaultdict(int)

    for source in sorted(found):
        if re.fullmatch(r"[a-z0-9_]+", source) and source in existing_english:
            key = source
            template = existing_english[source]
            placeholders = []
        else:
            template, placeholders = convert_placeholders(source)
            if source in existing_reverse:
                key = existing_reverse[source]
            elif template in existing_reverse:
                key = existing_reverse[template]
            elif source in COMMON_KEY_OVERRIDES:
                key = COMMON_KEY_OVERRIDES[source]
            else:
                key = slugify(template)
                key_counts[key] += 1
                if key_counts[key] > 1:
                    key = f"{key}_{key_counts[key]}"
                else:
                    key_counts[key] = 1

        found[source] = {
            "key": key,
            "source": source,
            "template": template,
            "placeholders": placeholders,
            "occurrences": source_occurrences[source],
        }

    return found


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--from-raw-catalog", action="store_true")
    args = parser.parse_args()

    if args.from_raw_catalog:
        source_occurrences = collect_sources_from_raw_catalog()
    else:
        source_occurrences = collect_sources_from_code()

    catalog = build_catalog(source_occurrences)
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {len(catalog)} entries to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
