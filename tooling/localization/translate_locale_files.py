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
    "add": "Add",
    "add_payment_method": "Add payment method",
    "add_people": "Add people",
    "added_members_count": "Added {count} members!",
    "added_people_count": "Added {count} people!",
    "add_participants_to_play_bill_roulette": "Add participants to play Bill Roulette.",
    "ad_server_connection_issue_try_again_later": "We're having trouble reaching the ad server right now. Please ensure you have an active internet connection or try again later.",
    "assign_bill": "Assign bill",
    "assign_items": "Assign items",
    "assign_quantities": "Assign quantities",
    "analyzing_audio": "Listening to what you said...",
    "analyzing_receipt": "Getting your receipt ready...",
    "apple": "Apple",
    "apple_sign_in_failed": "Apple Sign-In Failed: {error}",
    "big_loser": "Big loser",
    "bill_roulette": "Bill Roulette",
    "bill_roulette_2": "Bill Roulette",
    "bill_split_equally_among_all_members": "Bill split equally among all members.",
    "bill_successfully_assigned_to_the_loser": "Bill assigned successfully.",
    "camera": "Camera",
    "cancel": "Cancel",
    "checking_app_status": "Getting things ready...",
    "checking_onboarding": "Getting your welcome screens ready...",
    "checking_payments": "Getting the latest payment updates...",
    "common_cancel": "Cancel",
    "common_continue": "Continue",
    "common_edit": "Edit",
    "common_remove": "Remove",
    "confirm_quantities": "Confirm quantities",
    "create_bill": "Create bill",
    "current_password": "Current password",
    "contacts": "Contacts",
    "contact_support": "Contact support",
    "creating_your_squad": "Creating your squad...",
    "days_ago": "{count}d ago",
    "display_name": "Display Name",
    "delete_saved_draft": "Delete saved draft",
    "delete_saved_draft_message": "This will remove the saved receipt and its draft bill from your device and account.",
    "delete_account_requires_password": "For safety, enter your current password to delete this account.",
    "delete_account_warning_message": "This action is extremely destructive and irreversible. You will lose all your bills and data forever.\n\nYou'll be asked to sign in again to confirm this action.\n\nAre you absolutely sure?",
    "delivery_fee": "Delivery Fee",
    "delivery_portion": "Delivery Portion",
    "delivery_share": "Delivery Share",
    "discount": "Discount",
    "discount_portion": "Discount Portion",
    "discount_share": "Discount Share",
    "download_split_bill_for_android": "Download Split Bill for Android\n\n{url}",
    "download_split_bill_for_iphone": "Download Split Bill for iPhone\n\n{url}",
    "done": "Done",
    "edit_profile_benefits_message": "Benefits of completing profile:\n\n- Better bill splitting experience\n- Easier for friends to find you\n- Personalized app experience\n- Access to premium features",
    "edit_payment_method": "Edit payment method",
    "edit_final_share": "Edit final share",
    "egypt_instant_account_to_account_payments": "Egypt instant account-to-account payments",
    "egypt_mobile_wallet_and_payment_card_details": "Egypt mobile wallet and payment card details",
    "enter_final_amount": "Enter the final amount for this person.",
    "enter_current_password_to_continue": "Enter your current password to continue.",
    "equals_sign": " = ",
    "error_adding_contacts": "Error adding contacts: {error}",
    "error_adding_group": "Error adding group: {error}",
    "error_saving": "Error saving: {error}",
    "error_saving_payment_methods": "Error saving payment methods: {error}",
    "error_scanning_qr": "Error scanning QR: {error}",
    "error_with_details": "Error: {error}",
    "final_share_amount": "Total share: {amount}",
    "final_share_for_name": "Final share for {name}",
    "final_steps": "Final steps",
    "for_all": "For all",
    "full_name": "Full Name",
    "full_item": "Full item",
    "gallery": "Gallery",
    "guest": "Guest",
    "get_started_rocket": "Get Started 🚀",
    "google": "Google",
    "google_sign_in_failed": "Google Sign-In Failed: {error}",
    "grand_total": "Grand total",
    "great_when_you_want_people_to_pay_via_mobile_wallet": "Great when you want people to pay via mobile wallet",
    "got_qty_of_total": "Got {assigned} of {total}",
    "groups": "Groups",
    "global_wallet_requests_and_payment_links": "Global wallet requests and payment links",
    "good_for_cross_border_settlements": "Good for cross-border settlements",
    "have_a_question_or_feedback_nreach_out_to_us_anytime": "Have a question or feedback?\nReach out to us anytime.",
    "hours_ago": "{count}h ago",
    "iban_account_number_or_routing_details": "IBAN, account number, or routing details",
    "item_not_fully_assigned": "Item \"{item}\" is not fully assigned! ({assigned}/{total})",
    "item_breakdown": "Item breakdown",
    "item_assignment_ratio": "{name} (1/{count})",
    "items_subtotal": "Items subtotal",
    "in_review": "In review",
    "international_transfer_details_and_links": "International transfer details and links",
    "international_transfers_and_payment_links": "International transfers and payment links",
    "iphone_wallet_payments_and_requests": "iPhone wallet payments and requests",
    "just_now": "Just now",
    "later": "Later",
    "listening": "Listening...",
    "loading_bill_details": "Getting bill details...",
    "loading_contacts": "Getting your contacts...",
    "loading_groups": "Getting your groups...",
    "loading_history": "Getting your history...",
    "loading_notifications": "Getting your updates...",
    "loading_squad_members": "Getting your squad...",
    "loading_your_dashboard": "Getting your dashboard ready...",
    "loading_your_methods": "Getting your payment methods...",
    "loading_your_squads": "Getting your squads...",
    "manual_entry_quick_tips": "Quick tips:\n\n- Add store name at the top\n- Enter each item with quantity and price\n- Tap Add to List or press Enter\n- Swipe items left to delete\n- Review total at bottom\n- Tap Continue when done",
    "marked_as_status": "Marked as {status}",
    "members_count": "{count} members",
    "mercy_shown_bill_splitting_remains_as_is": "Mercy shown. The current split stays as it is.",
    "minutes_ago": "{count}m ago",
    "manual_share_needed": "Share manually",
    "mobile_money_wallet_for_east_africa": "Mobile money wallet for East Africa",
    "need_at_least_two_people_for_bill_roulette": "Add at least two people to play Bill Roulette.",
    "next": "Next",
    "no_email_linked": "No email linked",
    "no_bills_found": "No bills found.",
    "no_phone_set": "No phone set",
    "not_available_short": "n/a",
    "notification": "Notification",
    "notification_via_method": " via {method}",
    "notified_via_app": "Notified via app",
    "open_history": "Open history",
    "one_lucky_person_pays_the_whole_bill": "One lucky person pays the whole bill.",
    "onboarding_notifications_description": "Get instant notifications when bills are shared or payments are confirmed.",
    "onboarding_ready_description": "Join thousands splitting bills effortlessly. No more awkward math!",
    "onboarding_scan_description": "Just snap a photo and let AI extract all items and prices automatically.",
    "onboarding_split_description": "Assign items to friends or split evenly. Everyone pays what they owe.",
    "onboarding_track_description": "See who paid and who has not. Send reminders with one tap.",
    "ready_to_nget_started": "Ready to\nGet Started?",
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
    "premium_feature_unlimited_scans_title": "Unlimited Scans",
    "premium_feature_unlimited_scans_subtitle": "No limits, scan receipts forever.",
    "premium_feature_remove_ads_title": "Remove Ads",
    "premium_feature_remove_ads_subtitle": "Enjoy a distraction-free experience.",
    "premium_feature_support_development_title": "Support Development",
    "premium_feature_support_development_subtitle": "Help us verify your receipts faster.",
    "payment_accepted_body": "Your payment for \"{bill_name}\" has been approved by the host.",
    "payment_marked_as_sent_body": "{payer} marked {amount} as paid (No proof).",
    "payment_received_body": "{payer} paid {amount}{method_suffix} for {store}.",
    "please_enter_email_and_password": "Please enter email and password.",
    "please_enter_your_email_first": "Please enter your email first.",
    "scan_receipts_ninstantly": "Scan Receipts\nInstantly",
    "reminder_body": "You still owe {amount}. Tap to pay.",
    "reminder_sent_to": "Reminder sent to {name}! 🔔",
    "reminder_title": "Reminder: {bill_name}",
    "required": "Required",
    "save_changes": "Save changes",
    "receipt_delivery_fee": "Delivery Fee",
    "receipt_discount": "Discount",
    "receipt_other_charges": "Other Charges",
    "receipt_other_charge_label": "Other charge",
    "receipt_charges": "Charges",
    "receipt_edit_item": "Edit item",
    "receipt_ready": "Receipt ready",
    "receipt_review_recommended": "Review recommended",
    "receipt_review_subtitle": "Some lines may need a quick check before you continue.",
    "receipt_review_chip": "Review",
    "receipt_check_chip": "Check",
    "receipt_line_total": "Line total",
    "receipt_flagged_items_count": "{count} items to review",
    "receipt_flagged_charges_count": "{count} charges to review",
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
    "scan_completed": "Receipt ready",
    "scan_failed": "Scan failed: {error}",
    "scan_qr": "Scan QR",
    "scanning_receipt_with_ai": "Reading your receipt...",
    "pulling_the_details_from_your_receipt": "Pulling the details from your receipt...",
    "select_contacts": "Select contacts",
    "selection_copied": "{label} selected & copied!",
    "service_charge": "Service Charge",
    "saving_for_later": "Saving this for later...",
    "saving_payment_methods": "Saving your payment methods...",
    "saving_your_changes": "Saving your changes...",
    "send_reminder_confirmation": "This will send a notification to \"{name}\" about their remaining {amount} share.",
    "setting_up_secure_connection": "Getting things ready...",
    "service_portion": "Service Portion",
    "service_share": "Service Share",
    "share": "Share",
    "share_the_contact_people_should_use_to_find_you": "Share the contact people should use to find you",
    "share_the_wallet_number_people_send_to": "Share the wallet number people send to",
    "share_your_cashtag_exactly_as_it_appears": "Share your cashtag exactly as it appears",
    "sign_in": "Sign In",
    "signing_out": "Signing you out...",
    "signing_you_in": "Welcome back...",
    "snap_now_and_split_later": "Snap now and split later",
    "split_bill_equally": "Split bill equally",
    "split_bills_nfairly": "Split Bills\nFairly",
    "split_bill_notification_body": "Your share is {amount}. Tap to view details.",
    "split_bill_notification_title": "Split Bill: {store}",
    "split_bill_on_google_play": "Split Bill on Google Play",
    "split_bill_on_the_app_store": "Split Bill on the App Store",
    "split_between_people": "Split between {count} people",
    "split_equally": "Split equally",
    "split_with_others": "Split with {count} others",
    "shared_with_people_count": "Shared with {count} people",
    "stay_updated_nalways": "Stay Updated\nAlways",
    "status_paid": "Paid",
    "sub_total": "Sub total",
    "success": "Success",
    "support_request_split_bill_app": "Support Request - Split Bill App",
    "start_a_new_bill": "Start a new bill",
    "start_with_the_receipt_not_the_people_you_can_add_participants_right_after_the_bill_is_ready": "Start with the receipt, not the people. You can add participants right after the bill is ready.",
    "tax_vat": "Tax / VAT",
    "tax_portion": "Tax Portion",
    "tax_share": "Tax Share",
    "tap_to_analyze_results": "Tap to analyze results",
    "tap_to_scan": "Tap to scan",
    "tip_portion": "Tip Portion",
    "tip_share": "Tip Share",
    "syncing_contacts": "Matching your contacts...",
    "thinking": "Just a moment...",
    "this_will_assign_all_current_members_to_every_item_on_the_receipt_existing_assignments_will_be_cleared": "This will assign all current members to every item on the receipt. Existing assignments will be cleared.",
    "tip": "Tip",
    "store_name_required": "Store name required",
    "unfinished": "Unfinished",
    "unattempted_receipt": "Unattempted receipt",
    "update_total": "Update total",
    "unknown_item": "Unknown item",
    "unknown_time": "Unknown time",
    "unknown_store": "Unknown store",
    "use_a_custom_payment_method_name": "Use a custom payment method name",
    "use_only_the_details_you_are_comfortable_sharing": "Use only the details you are comfortable sharing",
    "use_the_exact_handle_or_link_you_want_shared": "Use the exact handle or link you want shared",
    "use_the_handle_friends_search_for_in_venmo": "Use the handle friends search for in Venmo",
    "use_the_phone_or_email_your_bank_uses_for_zelle": "Use the phone or email your bank uses for Zelle",
    "use_your_paypal_me_or_the_address_people_pay": "Use your PayPal.Me or the address people pay",
    "use_your_revtag_or_a_payment_link": "Use your Revtag or a payment link",
    "user": "User",
    "a_friend": "A friend",
    "us_bank_linked_transfers": "US bank-linked transfers",
    "us_payments_with_cashtag_support": "US payments with cashtag support",
    "user_already_added": "{name} is already added.",
    "view_details": "View details",
    "we_re_here_to_help": "We're here to help",
    "we_have_a_winner": "We have a winner!",
    "welcome_back": "Welcome back",
    "welcome_back_2": "Welcome back,",
    "who_split_this_item": "Who split this item?",
    "participant_bill_title": "{name}'s bill",
    "participant_details_title": "{name}'s details",
    "quantity_suffix": "{qty}x",
    "charge_portion": "{label} Portion",
    "best_for_methods_not_listed_here": "Best for methods not listed here",
    "fast_social_payments_in_the_us": "Fast social payments in the US",
    "point_your_camera_at_the_receipt_for_magic_processing": "Point your camera at the receipt for magic processing.",
    "our_backend_is_extracting_items_quantities_and_charges_securely": "Pulling the details from your receipt...",
    "retrieving_payment_methods": "Getting payment options...",
    "track_payments_neasily": "Track Payments\nEasily",
    "uploading_proof": "Uploading your screenshot...",
    "quantity_times": "x{qty}",
    "unit_price_at": "@ {price}",
    "your_bill_has_been_created_and_sent": "Your bill has been created and sent.",
    "settings_profile_notice": "These preferences apply across the app and are saved to your profile.",
}

CONTRACTION_REPLACEMENTS = {
    "don t": "don't",
    "doesn t": "doesn't",
    "didn t": "didn't",
    "isn t": "isn't",
    "aren t": "aren't",
    "wasn t": "wasn't",
    "weren t": "weren't",
    "won t": "won't",
    "can t": "can't",
    "couldn t": "couldn't",
    "shouldn t": "shouldn't",
    "wouldn t": "wouldn't",
    "it s": "it's",
    "that s": "that's",
    "what s": "what's",
    "here s": "here's",
    "there s": "there's",
    "let s": "let's",
    "i m": "I'm",
    "i ve": "I've",
    "i ll": "I'll",
    "you re": "you're",
    "you ve": "you've",
    "you ll": "you'll",
    "we re": "we're",
    "we ve": "we've",
    "we ll": "we'll",
    "they re": "they're",
    "they ve": "they've",
    "they ll": "they'll",
    "hasn t": "hasn't",
}

TR_KEY_PATTERNS = [
    re.compile(r"""['"]([a-z0-9_]+)['"]\s*\.tr\("""),
    re.compile(r"""Text\(\s*['"]([a-z0-9_]+)['"][\s\S]{0,400}?\)\s*\.tr\("""),
    re.compile(r"""\b\w+Key\s*:\s*['"]([a-z0-9_]+)['"]"""),
]


def normalize_translation_text(text: str) -> str:
    if "\\n" in text or "\\r" in text:
        return text.replace("\\r\\n", "\n").replace("\\n", "\n").replace("\\r", "\r")
    return text


def load_json(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    return {
        key: normalize_translation_text(value)
        for key, value in data.items()
        if not key.startswith("src_")
    }


def collect_used_keys() -> set[str]:
    used: set[str] = set()
    for path in LIB_ROOT.rglob("*.dart"):
        source = path.read_text(encoding="utf-8")
        for pattern in TR_KEY_PATTERNS:
            used.update(pattern.findall(source))
    return used


def humanize_key(key: str) -> str:
    normalized = key.replace("_n_", "\n")
    normalized = re.sub(r"_\d+$", "", normalized)
    text = normalized.replace("_", " ").strip()

    for source, target in CONTRACTION_REPLACEMENTS.items():
        text = re.sub(rf"\b{re.escape(source)}\b", target, text, flags=re.IGNORECASE)

    text = re.sub(r"\bqr\b", "QR", text, flags=re.IGNORECASE)
    text = re.sub(r"\bvat\b", "VAT", text, flags=re.IGNORECASE)
    text = re.sub(r"\bapp\b", "app", text, flags=re.IGNORECASE)
    text = re.sub(r"\bpro\b", "Pro", text, flags=re.IGNORECASE)
    text = re.sub(r"\s+", " ", text).strip()

    if not text:
        return key

    return text[0].upper() + text[1:]


def write_json(path: Path, data: dict[str, str]) -> None:
    path.write_text(
        json.dumps(dict(sorted(data.items())), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def should_refresh_translation(key: str, english_text: str) -> bool:
    if not english_text.strip():
        return False
    if not re.search(r"[A-Za-z]", english_text):
        return False
    return True


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
    result = {
        item["key"]: normalize_translation_text(item["text"])
        for item in parsed["translations"]
    }
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
    parser.add_argument("--fallback-only", action="store_true")
    args = parser.parse_args()

    api_key = os.getenv("OPENAI_API_KEY")

    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    used_keys = collect_used_keys()
    english_entries = {
        entry["key"]: normalize_translation_text(entry["template"])
        for entry in catalog.values()
        if entry["key"] in used_keys
    }
    english_entries.update(
        {key: normalize_translation_text(value) for key, value in MANUAL_ENGLISH.items()}
    )

    missing_english = sorted(key for key in used_keys if key not in english_entries)
    for key in missing_english:
        english_entries[key] = humanize_key(key)

    english_path = TRANSLATIONS_DIR / "en.json"
    write_json(english_path, english_entries)
    print(f"Synchronized {english_path}")

    target_locales = [args.only_locale] if args.only_locale else [code for code in LOCALES if code != "en"]

    for locale in target_locales:
        path = TRANSLATIONS_DIR / f"{locale}.json"
        data = load_json(path)
        missing = [(key, text) for key, text in english_entries.items() if key not in data]
        stale = [
            (key, text)
            for key, text in english_entries.items()
            if key in data and data[key] == text and should_refresh_translation(key, text)
        ]
        pending = missing + stale
        print(f"{locale}: {len(missing)} missing translations, {len(stale)} stale english fallbacks")
        if pending and not args.fallback_only and api_key:
            for index in range(0, len(pending), args.batch_size):
                batch = pending[index:index + args.batch_size]
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
