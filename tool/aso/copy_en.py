# English store copy (en-US, en-GB, en-AU, en-CA). {NAME} = {{APP_NAME}}, {PAY} = local payment list.

NAME = "{{APP_NAME}}"

DESC_EN = """Split any bill with anyone, on any phone, in any country.

{NAME} scans the receipt, lets you say who had what, and keeps a running balance for trips, {FLAT}s and dinners. Friends pay from a link in the apps they already use. No download, no account.

SCAN IT
Snap a receipt and AI reads every line, plus tax, service and tip. Subtotal and total rows are detected and kept out of your items.

SAY WHO HAD WHAT
"Ali had the burger, Mona and I shared the fries." Voice assignment puts each item on the right person. Prefer tapping? Split by item, equally, by exact amounts, by percentage or by shares. Quick IOUs need no bill at all.

EVERY CENT ACCOUNTED FOR
Each share shows exactly which items, tax and tip it includes, and every edit is in the history. Totals always add up, in the currency's real decimals.

FRIENDS PAY FROM A LINK
Send a personal link or a share card on WhatsApp or iMessage. Guests open it on the web, see their share, pay with {PAY}, and attach proof of payment. Payment methods match each friend's country, with the amount filled in where the app allows it.

SETTLE IN FEWER PAYMENTS
Groups keep a running balance across bills. Settle up with the fewest transfers, record payments, and get a gentle reminder for open balances, never more than one a week.

ANY CURRENCY, 22 LANGUAGES
Every world currency with the right decimals, right-to-left Arabic and Urdu, dark mode, and local payment methods for more than 60 countries.

FREE TO USE
Unlimited bills, groups, balances and guest links, and typing bills in by hand is always free. AI scans and voice commands are included to start, with more by watching a short ad. No interstitial ads.

PRO
Unlimited AI scans and voice, multi-currency groups with daily exchange rates, recurring bills such as rent and utilities, and CSV and PDF export. Choose monthly, yearly with a free trial, or a one-time lifetime purchase.{LEGAL}"""

LEGAL_IOS_EN = """

Subscriptions are charged to your Apple ID account when you confirm the purchase and renew automatically unless auto-renew is turned off at least 24 hours before the end of the current period. Manage or cancel them in your App Store account settings.

Privacy Policy: https://omarmali.net/split-bill/privacy/
Terms of Use: https://omarmali.net/split-bill/terms/"""

RELEASE_EN = """{NAME} 2.0 is a new app from the ground up.

- Scan a receipt, then say who had what. Voice assignment is new.
- Groups with a running balance for trips, {FLAT}s and dinners.
- Settle up in the fewest payments and record payments with proof.
- Friends pay from a link, no app needed, with payment methods for their country.
- Every cent accounted for: a full breakdown on every share, with edit history.
- Split by item, equally, by exact amounts, percentages or shares. Quick IOUs.
- Every world currency, 22 languages, right-to-left support and dark mode.
- Pro: multi-currency with daily rates, recurring bills, CSV and PDF export.
- Free plan: unlimited bills, groups and guest links, with AI scans included to start."""

CHANGELOG_EN = """2.0 is a new app from the ground up.
- Scan a receipt, then say who had what (voice assignment).
- Groups with running balances; settle up in the fewest payments, record payments with proof.
- Friends pay from a link, no app needed, with payment methods for their country.
- Every cent accounted for: full breakdown on every share, edit history.
- Split by item, equally, exact, percentage or shares. Quick IOUs.
- Every currency, 22 languages, RTL, dark mode.
- Pro: multi-currency, recurring bills, CSV/PDF export. Free: AI scans included."""

PROMO_EN = "Scan it. Say who had what. Every cent accounted for. Friends pay from a link in the apps their country uses, no download needed. Free, AI scans included."

SHORT_EN = "Scan receipts, say who had what, settle up. Friends pay from a link, no app."


def en_variant(ios, play, *, name, subtitle, keywords, pay, pay_play=None, flat="flat",
               promo=PROMO_EN, short=SHORT_EN):
    return {
        "ios": ios,
        "play": play,
        "name": name,
        "subtitle": subtitle,
        "keywords": keywords,
        "promo": promo,
        "desc": DESC_EN,
        "flat": flat,
        "pay": pay,
        "pay_play": pay_play or pay,
        "legal": LEGAL_IOS_EN,
        "release": RELEASE_EN,
        "short": short,
        "changelog": CHANGELOG_EN,
    }


EN = [
    en_variant(
        ["en-US"], ["en-US"],
        name=": Split Group Bills",
        subtitle="AI Receipt Scanner & Settle Up",
        keywords="expense,trip,roommate,friends,dinner,tip,owe,iou,share,travel,voice,dutch,pay,calculator,debt,check",
        pay="Venmo, Cash App, PayPal, Zelle or Apple Cash",
        pay_play="Venmo, Cash App, PayPal or Zelle",
        flat="apartment",
    ),
    en_variant(
        ["en-GB"], ["en-GB"],
        name=": Split Group Bills",
        subtitle="AI Receipt Scanner & Settle Up",
        keywords="expense,holiday,flatmate,friends,dinner,tip,owe,iou,share,travel,voice,pay,calculator,debt,kitty",
        pay="a bank transfer, Monzo, PayPal, Revolut or Wise",
        flat="flat",
    ),
    en_variant(
        ["en-AU"], [],
        name=": Split Group Bills",
        subtitle="AI Receipt Scanner & Settle Up",
        keywords="expense,holiday,housemate,mates,dinner,tip,owe,iou,share,travel,voice,pay,calculator,debt,kitty,trip",
        pay="PayID, PayPal, Revolut or Wise",
        flat="share house",
    ),
    en_variant(
        ["en-CA"], [],
        name=": Split Group Bills",
        subtitle="AI Receipt Scanner & Settle Up",
        keywords="expense,trip,roommate,friends,dinner,tip,owe,iou,share,travel,voice,pay,calculator,debt,etransfer",
        pay="Interac e-Transfer, PayPal or Wise",
        flat="apartment",
    ),
]
