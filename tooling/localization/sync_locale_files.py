#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from urllib import error, parse, request


REPO_ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = REPO_ROOT / "tooling" / "localization" / "string_catalog.json"
TRANSLATIONS_DIR = REPO_ROOT / "assets" / "translations"

LOCALE_FILES = {
    "en": TRANSLATIONS_DIR / "en.json",
    "ar": TRANSLATIONS_DIR / "ar.json",
    "fr": TRANSLATIONS_DIR / "fr.json",
    "de": TRANSLATIONS_DIR / "de.json",
    "ru": TRANSLATIONS_DIR / "ru.json",
    "id": TRANSLATIONS_DIR / "id.json",
    "ur": TRANSLATIONS_DIR / "ur.json",
    "hi": TRANSLATIONS_DIR / "hi.json",
    "pl": TRANSLATIONS_DIR / "pl.json",
    "es": TRANSLATIONS_DIR / "es.json",
    "it": TRANSLATIONS_DIR / "it.json",
    "pt": TRANSLATIONS_DIR / "pt.json",
    "zh": TRANSLATIONS_DIR / "zh.json",
    "ko": TRANSLATIONS_DIR / "ko.json",
    "ja": TRANSLATIONS_DIR / "ja.json",
}

SYSTEM_PROMPT = (
    "You are translating mobile app UI strings for a bill-splitting app. "
    "Keep tone concise, natural, and context-aware. Preserve placeholders like "
    "{value}, {name}, or {count}, preserve emoji, and do not translate brand names."
)

DEEPL_TARGETS = {
    "ar": "AR",
    "fr": "FR",
    "de": "DE",
    "ru": "RU",
    "id": "ID",
    "ur": "UR",
    "hi": "HI",
    "pl": "PL",
    "es": "ES",
    "it": "IT",
    "pt": "PT-PT",
    "zh": "ZH",
    "ko": "KO",
    "ja": "JA",
}


def load_json(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict[str, str]) -> None:
    path.write_text(
        json.dumps(dict(sorted(data.items())), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def translate_with_deepl(locale: str, texts: list[str]) -> list[str]:
    api_key = os.getenv("DEEPL_API_KEY")
    if not api_key:
        raise RuntimeError("DEEPL_API_KEY is required for provider=deepl")

    target_lang = DEEPL_TARGETS[locale]
    payload = parse.urlencode(
        [("text", text) for text in texts]
        + [("target_lang", target_lang), ("preserve_formatting", "1")]
    ).encode("utf-8")
    req = request.Request(
        "https://api-free.deepl.com/v2/translate",
        data=payload,
        headers={"Authorization": f"DeepL-Auth-Key {api_key}"},
        method="POST",
    )
    with request.urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return [item["text"] for item in data["translations"]]


def translate_with_openai(locale: str, texts: list[str], model: str) -> list[str]:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY is required for provider=openai")

    body = {
        "model": model,
        "input": [
            {
                "role": "system",
                "content": [{"type": "input_text", "text": SYSTEM_PROMPT}],
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "input_text",
                        "text": json.dumps(
                            {
                                "target_locale": locale,
                                "strings": texts,
                                "instructions": [
                                    "Return strict JSON only.",
                                    "Return an object with one field: translations.",
                                    "translations must be an array with the same length and order as strings.",
                                ],
                            },
                            ensure_ascii=False,
                        ),
                    }
                ],
            },
        ],
        "text": {
            "format": {
                "type": "json_schema",
                "name": "locale_translations",
                "schema": {
                    "type": "object",
                    "properties": {
                        "translations": {
                            "type": "array",
                            "items": {"type": "string"},
                        }
                    },
                    "required": ["translations"],
                    "additionalProperties": False,
                },
            }
        },
    }

    req = request.Request(
        "https://api.openai.com/v1/responses",
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with request.urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))

    output_text = ""
    for item in data.get("output", []):
        for content in item.get("content", []):
            if content.get("type") == "output_text":
                output_text += content.get("text", "")

    parsed = json.loads(output_text)
    translations = parsed["translations"]
    if len(translations) != len(texts):
        raise RuntimeError(
            f"OpenAI returned {len(translations)} translations for {len(texts)} texts"
        )
    return translations


def translate_batch(
    provider: str,
    locale: str,
    texts: list[str],
    model: str,
) -> list[str]:
    if provider == "none":
        return texts
    if provider == "deepl":
        return translate_with_deepl(locale, texts)
    if provider == "openai":
        return translate_with_openai(locale, texts, model=model)
    raise RuntimeError(f"Unsupported provider: {provider}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--provider",
        choices=["none", "deepl", "openai"],
        default="none",
    )
    parser.add_argument("--batch-size", type=int, default=25)
    parser.add_argument("--openai-model", default="gpt-5.4-mini")
    parser.add_argument("--only-locale")
    args = parser.parse_args()

    if not CATALOG_PATH.exists():
        raise SystemExit(
            f"Missing catalog file at {CATALOG_PATH}. Run extract_strings.py first."
        )

    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))

    english = load_json(LOCALE_FILES["en"])
    for entry in catalog.values():
        english[entry["key"]] = entry["source"]
    write_json(LOCALE_FILES["en"], english)
    print(f"Synchronized English catalog to {LOCALE_FILES['en']}")

    target_locales = [
        code for code in LOCALE_FILES if code != "en" and (not args.only_locale or code == args.only_locale)
    ]

    for locale in target_locales:
        locale_path = LOCALE_FILES[locale]
        locale_values = load_json(locale_path)
        missing_keys = [
            entry["key"]
            for entry in catalog.values()
            if entry["key"] not in locale_values
        ]

        if missing_keys:
            print(f"{locale}: translating {len(missing_keys)} missing strings")

        for start in range(0, len(missing_keys), args.batch_size):
            batch_keys = missing_keys[start : start + args.batch_size]
            batch_texts = [catalog[key]["source"] for key in batch_keys]
            translated = translate_batch(
                provider=args.provider,
                locale=locale,
                texts=batch_texts,
                model=args.openai_model,
            )
            if len(batch_keys) != len(translated):
                raise RuntimeError(
                    f"Translation count mismatch for {locale}: "
                    f"expected {len(batch_keys)}, got {len(translated)}"
                )
            for key, value in zip(batch_keys, translated):
                locale_values[key] = value

        write_json(locale_path, locale_values)
        print(f"Synchronized locale file {locale_path}")


if __name__ == "__main__":
    try:
        main()
    except error.URLError as exc:
        print(f"Network error: {exc}", file=sys.stderr)
        raise SystemExit(1)
