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
Groups keep a running balance across bills. Settle up with the fewest transfers, record payments, and get a gentle reminder for open balances, never more than one a week. Can't decide who pays? Spin the who-pays roulette.

ANY CURRENCY, 22 LANGUAGES
158 currencies with the right decimals, 80+ local payment apps, right-to-left Arabic and Urdu, and dark mode.

FREE TO USE
Unlimited bills, groups, balances and guest links, and typing a bill in is always free. You start with welcome points for AI scans and voice, and a short rewarded ad adds more when you want them. No interstitial ads.

PRO
Unlimited AI scans and voice, multi-currency groups with daily exchange rates, recurring bills such as rent and utilities, CSV and PDF export, and no ads. Choose monthly, yearly with a free trial, or a one-time lifetime purchase.

PRIVACY
{NAME} never holds your money: friends pay each other directly in their own apps. Your receipts are never used to train AI.{LEGAL}"""

LEGAL_IOS_EN = """

Subscriptions are charged to your Apple ID account when you confirm the purchase and renew automatically unless auto-renew is turned off at least 24 hours before the end of the current period. Manage or cancel them in your App Store account settings.

Privacy Policy: https://omarmali.net/split-bill/privacy/
Terms of Use: https://omarmali.net/split-bill/terms/"""

RELEASE_EN = """{NAME} 2.0 is here, rebuilt from the ground up.

- Say who had what: voice puts every item on the right person.
- Friends pay from a link in 80+ local payment apps, no app needed.
- Groups and trips settle in the fewest payments, with IOUs and gentle reminders.
- Can't decide who pays? Spin the roulette.
- 158 currencies, 22 languages, dark mode.
- Pro: unlimited scans and voice, recurring bills, PDF and CSV export, no ads."""

CHANGELOG_EN = RELEASE_EN.replace("\n\n", "\n")

PROMO_EN = "New in 2.0: say who had what and {NAME} splits the receipt for you. Friends pay from a link in the apps their country uses, no app needed. Typing a bill is always free."

SHORT_EN = "Split bills with AI: scan the receipt, say who had what, friends pay by link."


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
        name=": Split Bills & Receipts",
        subtitle="AI Scanner, Groups & Settle Up",
        keywords="expense,trip,roommate,friends,dinner,tip,owe,iou,travel,voice,splitter,pay,calculator,debt,check",
        pay="Venmo, Cash App, PayPal, Zelle or Apple Cash",
        pay_play="Venmo, Cash App, PayPal or Zelle",
        flat="apartment",
    ),
    en_variant(
        ["en-GB"], ["en-GB"],
        name=": Split Bills & Receipts",
        subtitle="AI Scanner, Groups & Settle Up",
        keywords="expense,holiday,flatmate,friends,dinner,tip,owe,iou,travel,voice,pay,calculator,debt,kitty,splitter",
        pay="a bank transfer, Monzo, PayPal, Revolut or Wise",
        flat="flat",
    ),
    en_variant(
        ["en-AU"], [],
        name=": Split Bills & Receipts",
        subtitle="AI Scanner, Groups & Settle Up",
        keywords="expense,holiday,housemate,mates,dinner,tip,owe,iou,travel,voice,pay,calculator,debt,kitty,splitter",
        pay="PayID, PayPal, Revolut or Wise",
        flat="share house",
    ),
    en_variant(
        ["en-CA"], [],
        name=": Split Bills & Receipts",
        subtitle="AI Scanner, Groups & Settle Up",
        keywords="expense,trip,roommate,friends,dinner,tip,owe,iou,travel,voice,pay,calculator,debt,etransfer,splitter",
        pay="Interac e-Transfer, PayPal or Wise",
        flat="apartment",
    ),
]
