#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from urllib import error, request
import re


REPO_ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = REPO_ROOT / "tooling" / "localization" / "key_catalog.json"
TRANSLATIONS_DIR = REPO_ROOT / "assets" / "translations"
LIB_ROOT = REPO_ROOT / "lib"

LOCALES = ["en", "ar", "fr", "de", "ru", "id", "ur", "hi", "pl", "es", "it", "pt", "zh", "ko", "ja"]

SYSTEM_PROMPT = (
    "You translate mobile app UI strings for a bill-splitting app. "
    "Return natural, concise product copy. Preserve placeholders exactly as {name}. "
    "Preserve punctuation, emoji, and brand names. Return strict JSON only."
)

MANUAL_ENGLISH = {
    "add_payment_method": "Add payment method",
    "added_members_count": "Added {count} members!",
    "added_people_count": "Added {count} people!",
    "analyzing_audio": "Analyzing audio...",
    "analyzing_receipt": "Analyzing receipt...",
    "apple": "Apple",
    "apple_sign_in_failed": "Apple Sign-In Failed: {error}",
    "camera": "Camera",
    "contacts": "Contacts",
    "days_ago": "{count}d ago",
    "delivery_fee": "Delivery Fee",
    "discount": "Discount",
    "edit_profile_benefits_message": "Benefits of completing profile:\n\n- Better bill splitting experience\n- Easier for friends to find you\n- Personalized app experience\n- Access to premium features",
    "edit_payment_method": "Edit payment method",
    "error_adding_contacts": "Error adding contacts: {error}",
    "error_adding_group": "Error adding group: {error}",
    "error_saving": "Error saving: {error}",
    "error_saving_payment_methods": "Error saving payment methods: {error}",
    "error_scanning_qr": "Error scanning QR: {error}",
    "error_with_details": "Error: {error}",
    "full_name": "Full Name",
    "gallery": "Gallery",
    "get_started_rocket": "Get Started 🚀",
    "google": "Google",
    "google_sign_in_failed": "Google Sign-In Failed: {error}",
    "groups": "Groups",
    "hours_ago": "{count}h ago",
    "item_not_fully_assigned": "Item \"{item}\" is not fully assigned! ({assigned}/{total})",
    "just_now": "Just now",
    "later": "Later",
    "listening": "Listening...",
    "manual_entry_quick_tips": "Quick tips:\n\n- Add store name at the top\n- Enter each item with quantity and price\n- Tap Add to List or press Enter\n- Swipe items left to delete\n- Review total at bottom\n- Tap Continue when done",
    "marked_as_status": "Marked as {status}",
    "members_count": "{count} members",
    "minutes_ago": "{count}m ago",
    "next": "Next",
    "no_bills_found": "No bills found.",
    "notification": "Notification",
    "open_history": "Open history",
    "onboarding_notifications_description": "Get instant notifications when bills are shared or payments are confirmed.",
    "onboarding_ready_description": "Join thousands splitting bills effortlessly. No more awkward math!",
    "onboarding_scan_description": "Just snap a photo and let AI extract all items and prices automatically.",
    "onboarding_split_description": "Assign items to friends or split evenly. Everyone pays what they owe.",
    "onboarding_track_description": "See who paid and who has not. Send reminders with one tap.",
    "payment_method_copied": "{method} copied to clipboard!",
    "payment_method_instapay": "InstaPay",
    "payment_method_instapay_value_label": "InstaPay username or payment link",
    "payment_method_instapay_placeholder": "e.g. omar@instapay or https://...",
    "payment_method_other": "Other",
    "payment_method_other_value_label": "Payment details",
    "payment_method_other_placeholder": "Add the link, tag, or instructions",
    "payment_method_vodafone_cash": "Vodafone Cash",
    "payment_method_vodafone_cash_value_label": "Wallet number or payment instructions",
    "payment_method_vodafone_cash_placeholder": "e.g. +20 10 1234 5678",
    "payment_method_paypal": "PayPal",
    "payment_method_paypal_value_label": "PayPal email, username, or link",
    "payment_method_paypal_placeholder": "e.g. paypal.me/yourname",
    "payment_method_venmo": "Venmo",
    "payment_method_venmo_value_label": "Venmo username",
    "payment_method_venmo_placeholder": "e.g. @omarmahmoud",
    "payment_method_cash_app": "Cash App",
    "payment_method_cash_app_value_label": "Cash App cashtag",
    "payment_method_cash_app_placeholder": "e.g. $OmarMahmoud",
    "payment_method_zelle": "Zelle",
    "payment_method_zelle_value_label": "Email or phone linked to Zelle",
    "payment_method_zelle_placeholder": "e.g. yourname@email.com",
    "payment_method_apple_cash": "Apple Cash",
    "payment_method_apple_cash_value_label": "Apple Cash phone or Apple ID hint",
    "payment_method_apple_cash_placeholder": "e.g. +1 555 123 4567",
    "payment_method_revolut": "Revolut",
    "payment_method_revolut_value_label": "Revtag, account, or payment link",
    "payment_method_revolut_placeholder": "e.g. @omarmahmoud",
    "payment_method_wise": "Wise",
    "payment_method_wise_value_label": "Wise email or account details",
    "payment_method_wise_placeholder": "e.g. your@email.com",
    "payment_method_mpesa": "M-Pesa",
    "payment_method_mpesa_value_label": "M-Pesa number",
    "payment_method_mpesa_placeholder": "e.g. +254 7XX XXX XXX",
    "payment_method_bank_transfer": "Bank Transfer",
    "payment_method_bank_transfer_value_label": "Bank transfer details",
    "payment_method_bank_transfer_placeholder": "e.g. IBAN or account number",
    "payment_methods_info_message": "Add the payment handles, links, or account details you want friends to use when settling a bill.",
    "payment_methods_saved_count": "{count} saved methods",
    "please_enter_email_and_password": "Please enter email and password.",
    "please_enter_your_email_first": "Please enter your email first.",
    "reminder_body": "You still owe {amount}. Tap to pay.",
    "reminder_sent_to": "Reminder sent to {name}! 🔔",
    "reminder_title": "Reminder: {bill_name}",
    "required": "Required",
    "save_changes": "Save changes",
    "receipt_delivery_fee": "Delivery Fee",
    "receipt_discount": "Discount",
    "receipt_other_charges": "Other Charges",
    "receipt_ready": "Receipt ready",
    "receipt_service_charge": "Service Charge",
    "receipt_subtotal": "Subtotal",
    "receipt_tax": "Tax",
    "receipt_thank_you": "THANK YOU",
    "receipt_tip": "Tip",
    "receipt_total": "Total",
    "receipt_total_payment": "Total Payment",
    "recent": "Recent",
    "say_your_command": "Say your command...",
    "scan_next_step": "Next Step",
    "scan_save_changes": "Save Changes",
    "scan_completed": "Scan Completed",
    "scan_failed": "Scan failed: {error}",
    "scan_qr": "Scan QR",
    "scanning_receipt_with_ai": "Scanning receipt with AI...",
    "selection_copied": "{label} selected & copied!",
    "service_charge": "Service Charge",
    "saving_for_later": "Saving for later...",
    "sign_in": "Sign In",
    "snap_now_and_split_later": "Snap now and split later",
    "start_a_new_bill": "Start a new bill",
    "start_with_the_receipt_not_the_people_you_can_add_participants_right_after_the_bill_is_ready": "Start with the receipt, not the people. You can add participants right after the bill is ready.",
    "tax_vat": "Tax / VAT",
    "tap_to_analyze_results": "Tap to analyze results",
    "tap_to_scan": "Tap to scan",
    "thinking": "Thinking...",
    "tip": "Tip",
    "unfinished": "Unfinished",
    "unknown_time": "Unknown time",
    "user": "User",
    "user_already_added": "{name} is already added.",
    "welcome_back": "Welcome back",
    "welcome_back_2": "Welcome back,",
    "point_your_camera_at_the_receipt_for_magic_processing": "Point your camera at the receipt for magic processing.",
    "our_backend_is_extracting_items_quantities_and_charges_securely": "Our backend is extracting items, quantities, and charges securely.",
    "settings_profile_notice": "These preferences apply across the app and are saved to your profile.",
}

TR_KEY_PATTERNS = [
    re.compile(r"""['"]([a-z0-9_]+)['"]\s*\.tr\("""),
    re.compile(r"""Text\(\s*['"]([a-z0-9_]+)['"][\s\S]{0,400}?\)\s*\.tr\("""),
]


def load_json(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    return {key: value for key, value in data.items() if not key.startswith("src_")}


def collect_used_keys() -> set[str]:
    used: set[str] = set()
    for path in LIB_ROOT.rglob("*.dart"):
        source = path.read_text(encoding="utf-8")
        for pattern in TR_KEY_PATTERNS:
            used.update(pattern.findall(source))
    return used


def write_json(path: Path, data: dict[str, str]) -> None:
    path.write_text(
        json.dumps(dict(sorted(data.items())), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def translate_batch(locale: str, items: list[tuple[str, str]], model: str, api_key: str) -> dict[str, str]:
    payload = {
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
                                "items": [{"key": key, "text": text} for key, text in items],
                                "instructions": [
                                    "Translate every text to the target locale.",
                                    "Do not change the keys.",
                                    "Return an object with one field named translations.",
                                    "translations must be an array of objects with fields key and text.",
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
                "name": "locale_translation_batch",
                "schema": {
                    "type": "object",
                    "properties": {
                        "translations": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "key": {"type": "string"},
                                    "text": {"type": "string"},
                                },
                                "required": ["key", "text"],
                                "additionalProperties": False,
                            },
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
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    with request.urlopen(req) as response:
        data = json.loads(response.read().decode("utf-8"))

    output_text = ""
    for item in data.get("output", []):
        for content in item.get("content", []):
            if content.get("type") == "output_text":
                output_text += content.get("text", "")

    parsed = json.loads(output_text)
    result = {item["key"]: item["text"] for item in parsed["translations"]}
    if len(result) != len(items):
        raise RuntimeError(
            f"Translation batch size mismatch for locale {locale}: "
            f"expected {len(items)}, got {len(result)}"
        )
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--openai-model", default="gpt-5.4-mini")
    parser.add_argument("--batch-size", type=int, default=25)
    parser.add_argument("--only-locale")
    args = parser.parse_args()

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise SystemExit("OPENAI_API_KEY is required")

    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    used_keys = collect_used_keys()
    english_entries = {
        entry["key"]: entry["template"]
        for entry in catalog.values()
        if entry["key"] in used_keys
    }
    english_entries.update(MANUAL_ENGLISH)

    missing_english = sorted(key for key in used_keys if key not in english_entries)
    if missing_english:
        raise SystemExit(
            "Missing English templates for keys: " + ", ".join(missing_english)
        )

    english_path = TRANSLATIONS_DIR / "en.json"
    write_json(english_path, english_entries)
    print(f"Synchronized {english_path}")

    target_locales = [args.only_locale] if args.only_locale else [code for code in LOCALES if code != "en"]

    for locale in target_locales:
        path = TRANSLATIONS_DIR / f"{locale}.json"
        data = load_json(path)
        missing = [(key, text) for key, text in english_entries.items() if key not in data]
        print(f"{locale}: {len(missing)} missing translations")
        for index in range(0, len(missing), args.batch_size):
            batch = missing[index:index + args.batch_size]
            if not batch:
                continue
            translated = translate_batch(
                locale=locale,
                items=batch,
                model=args.openai_model,
                api_key=api_key,
            )
            data.update(translated)
        trimmed = {key: data.get(key, english_entries[key]) for key in english_entries}
        write_json(path, trimmed)
        print(f"Synchronized {path}")


if __name__ == "__main__":
    try:
        main()
    except error.URLError as exc:
        print(f"Network error: {exc}", file=sys.stderr)
        raise SystemExit(1)
