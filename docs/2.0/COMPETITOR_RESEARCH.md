# Split Bill 2.0: competitor and design research

Checked 2026-11-05. This doc goes with `DECISION_PACK.md`, which has the pricing table, name shortlist and the first feature gap table, and with `ROADMAP.md`. Pricing is not repeated here unless something changed.

**Source labels**
- **Verified**: I read the official source (store listing, help page, company page or press release) on 2026-11-05.
- **Third-party**: a blog, review site or comparison page, often run by a competitor. Treat it as indicative.
- **Unverified**: from memory of earlier app versions or inferred. A person should check it on a device before relying on it.

**Research limits**
- Reddit could not be fetched or searched with my tools; the domain blocks the crawler. Sentiment comes from App Store reviews, Trustpilot and press coverage instead. A person should skim r/Splitwise, r/personalfinance and r/travel before the design review.
- I could not see store screenshots, only listing text. Design notes on navigation, color and layout for each app are **unverified** unless a source is given. Check them on a device: install each app and screenshot onboarding, home, add expense, balances and settle up in both light and dark mode.
- Google Play listings did not render through my tools.

---

## 0. Two market changes since the decision pack

These two changes affect our positioning more than anything else in this doc.

1. **Splitwise "Itemize" (16 Oct 2026, verified via press):** free for all users in the **US and UK**. One person photographs the receipt. Diners join **by QR code without an account** and claim their items, with proportional tax and tip. They pay through Splitwise Pay, in cash, or by adding it to a Splitwise balance. More markets are promised "in the coming months". This is close to our core loop: AI itemized split plus guest participation. Source: https://thepaypers.com/payments/news/splitwise-launches-itemize-receipt-splitting-feature-in-the-us-and-uk
   - **What still sets us apart:** voice assignment, guest **payment proof** and a guest web page, 22 locales with Arabic and Urdu RTL, markets outside the US and UK, payment links for each country, and no daily expense cap. Splitwise's free tier still caps manual expenses (section 3).
2. **Apple Cash Split Bill (shipped with iOS 26.x/27; release date conflicts in third-party sources):** you start a split from Messages, Wallet, Camera or Photos. Apple Intelligence transcribes the receipt, you edit items and quantities, add a tip, and split by item or evenly. Requests stay open for 30 days. You can pay from Apple Watch only for even splits. Apple Cash is **US-only** and does not work for Android users. Sources: https://support.apple.com/en-gb/127565 (verified) · https://www.pymnts.com/apple/2026/apple-set-to-accelerate-wallet-war-with-automated-bill-splitting/ (press, June 2026) · https://apple.gadgethacks.com/news/ios-27-apple-wallet-bill-splitting-what-apple-confirmed/ (third-party)
   - **What this means for us:** a one-off restaurant split in the US is now free and built into iOS. We win where Apple cannot: mixed iPhone and Android groups, non-US users, running balances over trips and flats, guests on the web, and currencies other than USD. Our marketing should lead with "everyone, every phone, every country", not "scan a receipt".

---

## 1. Competitor profiles

### 1.1 Splitwise (market leader)
- **Platforms:** iOS, iPadOS, Apple Watch (third-party says you can view balances and send reminders from the watch), Vision, Android, web. No home-screen widget found (unverified).
- **Pricing:** the App Store lists Pro at $2.99 to $4.99 a month and $29.99 to $39.99 a year. Most US users see $4.99 or $39.99. The free tier has a **daily expense cap** that is not published: about 2 to 5 entries a day, varying by region. The free tier also shows interstitial ads. Sources: https://apps.apple.com/us/app/splitwise/id458023433 (verified) · https://getfinny.app/blog/splitwise-pricing-2026 (third-party, 2026-08-06)
- **Pro features:** 10 GB of receipt storage, receipt OCR and itemizing, JSON backup, currency conversion, category charts, search, card import (US), and no ads. Itemize for restaurant bills is now free in the US and UK (section 0).
- **Core flows (listing, verified):** split equally, by percentage, by shares or by exact amount; multiple payers; debt simplification; recurring bills (weekly, fortnightly, monthly, yearly); comments; edit history; restoring deleted items; CSV export; offline entry; 100+ currencies.
- **Payments:** Venmo and PayPal (US), Paytm (India), Pay by Bank via Tink (UK since 2024; FR, DE and AT since Oct 2025), Splitwise Pay plus a Splitwise Card (US, staged rollout, requires an SSN). Sources: https://fintech.global/2025/10/20/splitwise-and-tink-expand-pay-by-bank-across-europe/ · https://dx0qysuen8cbs.cloudfront.net/pay
- **Rating:** 4.0 from about 29K ratings (US App Store). Trustpilot 2.0 from 72 reviews.
- **Design (unverified):** a green brand with a white UI. Bottom tabs are Groups, Friends, Activity and Account, with an "Add expense" button floating at the bottom. Lists are dense and look like a ledger. Balances are shown as green "you are owed" and orange "you owe" text. Flat, utilitarian and dated; little motion. Dark mode is supported.

### 1.2 Tricount (bunq)
- **Platforms:** iOS and Android. Trustpilot users say the web app was removed.
- **Pricing:** free, with no limits, no subscription and no ads. Premium was discontinued. Source: https://apps.apple.com/us/app/tricount-split-settle-bills/id349866256 (verified)
- **Core flows:** uneven splits, balances, payment requests inside the app, a calculator, expense photos, offline use, multi-currency, sharing amounts with people outside the app (v14.3.0), importing from Splitwise, and linking a bunq account so card payments become expenses automatically.
- **Rating:** 4.9 from 7.6K ratings (US App Store). Trustpilot 3.4 from 46 reviews, polarized.
- **Design (unverified):** a blue brand with a card-based list of tricounts. A tricount has tabs for Expenses and Balances. The add button sits at the bottom. Friendly but fairly generic, and it has looked more like bunq since the acquisition.

### 1.3 Settle Up (Step Up Labs)
- **Platforms:** iOS, iPad, Mac (Apple silicon), Vision, Android, web view. No widget or watch app is listed (verified listing).
- **Pricing:** Premium $3.99 a month or $19.99 a year. Group Premium from $5.99 for a week up to $149.99 lifetime. The free tier has ads. Source: https://apps.apple.com/app/id737534985 (verified)
- **Core flows:** weighted splits, multiple payers, fewest transfers, offline use, **group balances in a browser via a share link without the app**, invites by link or **QR code**, live FX, CSV export, automatic reminders. Premium adds receipt photos, recurring and future expenses, custom categories, Excel export and charts.
- **Rating:** 4.8 from 1.8K ratings.
- **Design:** one reviewer says it "looks a little dated" (App Store review). Groups are color-coded, and extra colors are a Premium perk (Step Up Labs blog).

### 1.4 Splid
- **Platforms:** iOS 16+ and Android. No web version, which reviewers ask for.
- **Pricing:** one-time purchases: Splid Plus $3.99 and "2 Groups" $2.99. Third-party sources say the free tier allows one group. No ads.
- **Core flows:** no sign-up; offline groups by default with optional sync; 150+ currencies with automatic conversion; PDF summary (Excel is paid); categories; search.
- **Rating:** 4.9 from 4.2K ratings. Praise: "much more user friendly than Splitwise" (App Store review, Gillorai).
- **Design (unverified):** minimal and light, with few screens. Strong on clarity and low on brand.

### 1.5 Tab (bring10). Note that `tab.travel` is a different company.
- `tab.travel` redirects to business.tab.travel, a card-payments platform for tourism businesses, not a bill splitter (verified). The consumer receipt splitter called "Tab" is made by bring10.
- **Tab (bring10):** free, iPhone only. Scan a receipt, people with the app claim items in real time, shared items are supported, tax and tip are divided proportionally, and there is a "birthday" mode. It has no running balances and no payment integration. Rating 4.2 from about 1.2K. Complaints: subtotal and tax get scanned as line items, there is a mystery tip, and you cannot edit tax. Source: https://apps.apple.com/us/app/tab-the-simple-bill-splitter/id595068606 (verified)
- **Tab – Trip & Group Expenses** (com.watak.tab, Android): you can add expenses by typing, voice or receipt photo. The first 5 expenses per group are free; after that you buy a **pass per trip**, not a subscription. This is a pricing model worth testing. Source: https://play.google.com/store/apps/details?id=com.watak.tab (search snippet, third-party)

### 1.6 Spliit (open source)
- A free, MIT-licensed web PWA. No account is needed. Features: groups shared by link, uneven splits, reimbursements, categories, search, attached images, receipt scanning (needs an OpenAI key on self-hosted instances). Planned: recurring expenses and Splitwise import. About 3.0K GitHub stars. Built with Next.js, Tailwind and shadcn/ui, so it looks clean and minimal like a SaaS product. Source: https://github.com/spliit-app/spliit (verified)

### 1.7 Others in the brief
| App | What it is | Notes / source |
|---|---|---|
| **Kittysplit** | Web-first with no account; groups by link | Free up to 9 people. A one-time "Super Kitty" upgrade of about €3 **per group** unlocks 10+ people, multi-currency and receipts; one person pays and the whole group gets it. EU servers. https://kittysplit.com/en/splid-alternative (verified) |
| **Cino** | Shared **virtual card** that splits the payment at checkout | Each member's share is debited from their own linked card. Launched in Estonia in 2023, raised a €3.5M seed in March 2025, expanding to the UK. https://techcrunch.com/2025/03/04/cino-has-cracked-bill-splitting-at-the-moment-of-payment-raises-seed |
| **Venmo Groups** | Group ledger inside Venmo (since Nov 2023) | Up to 30 members per group and 20 groups per user. Any member can add expenses; settle up with Venmo. US only. https://techcrunch.com/2023/11/14/venmo-gets-a-new-way-to-split-expenses-among-groups-like-clubs-teams-trip-buddies-and-more |
| **Revolut Group Bills / Split Bill** | Groups of 2 to 20 Revolut users; one-off splits also reach non-users | https://help.revolut.com/en-AU/help/app-features/splitting-expenses-with-group-bills/ |
| **Monzo Split** | Single Split (one-off) and Running Split (ongoing); non-users pay via a request link | UK only. https://monzo.com/help/monzo-with-friends/split-costs-with-pals |
| **Google Pay (India)** | "Split an expense" inside a group chat, up to 20 people, a progress bar showing who has paid, UPI | Most sources are from 2021. https://support.google.com/pay/india/answer/11420982 |
| **Apple Cash** | Section 0 | US only |
| **Plates, Billr, Steward, SplitMyExpenses** | **Not found** or not current | Plates: no current listing found (Product Hunt URL now shows Splitwise). Billr: 2013-era app with manual entry, no current listing. Steward and SplitMyExpenses: no listing found. **Unverified**: may exist under other names. |
| **Divvy** (id6759842063) | New AI receipt splitter, iPhone, weekly or annual subscription | One of dozens of 2025–26 "AI receipt splitter" clones (SplitSnap, Billie, Checkify, Splitty, Untabbed). They are single-bill only, with no balances or groups. https://apps.apple.com/app/id6759842063 |

### 1.8 Fintech design references (quality bar)
| App | What to learn | Source |
|---|---|---|
| **Copilot Money** | The current benchmark for "premium personal finance". Apple Design Award finalist 2024 and Editor's Choice. Only two tabs; adopted Liquid Glass without losing legibility. Dark-first, with charts that feel cinematic. | https://www.copilot.money/faq · https://9to5mac.com/2026/01/01/copilot-money-brings-clarity-to-your-finances-now-on-the-web/ |
| **Revolut** | Near-black and white with one accent; pill-shaped buttons; almost no shadows; a geometric grotesque display face (Aeonik Pro) with Inter for body text. (Third-party analysis of the marketing site, not the app.) | https://getdesign.md/design-md/revolut/preview |
| **Wise** | A distinctive brand color (lime #9fe870 on dark green #163300) instead of fintech blue. The design system targets 146+ languages and strong accessibility. | https://www.creativereview.co.uk/wise-rebrand-ragged-edge/ |
| **Monzo** | Cut its tabs to Home, Payments and Help. The Home screen is customizable (choose and reorder sections). The feed can collapse to reveal card actions. The forum reaction was mixed, which shows that merging too much into one screen annoys power users. | https://monzo.com/blog/the-new-and-improved-home-screen |
| **Cash App, Lunch Money** | Cash App: one huge number, a keypad-first home, bold type. Lunch Money: dense, calm, data-first, built for the web. (Unverified from memory.) | — |

---

## 2. Design patterns across competitors

| Pattern | Who does it | Verdict for us |
|---|---|---|
| A bottom tab bar with 4 or 5 tabs plus a floating "Add" button | Splitwise, Tricount (unverified) | **Adapt.** Use 3 tabs (Home, Groups, Activity) and one primary **Scan** action in the center or as a large button on Home. Put profile and settings behind the avatar. Copilot shows that fewer tabs feel more premium. |
| Lists of balance lines in red and green | Splitwise | **Avoid as the main view.** Red and green alone fail for color-blind users and read as alarming. Use a direction word ("You get back" / "You owe") plus a neutral or signed amount, and a small accent dot, never color alone. |
| One big number at the top of Home | Cash App, Revolut, Copilot | **Adopt.** Show your net balance across all groups as the hero, with "You're owed X · You owe Y" underneath and one main action (Settle up / Remind). |
| Browser view of a group, invite by QR | Settle Up, Kittysplit, Spliit, Splitwise Itemize | **Table stakes.** Ours must be better: a personalized guest page, pay buttons for each country, and an upload for payment proof. |
| Interstitial ads during a task | Splitwise free tier, Settle Up free tier | **Avoid.** It is the second most common complaint. Keep only opt-in rewarded ads. |
| Daily caps that block entry | Splitwise | **Avoid.** It is the top complaint (section 3). Limit AI usage (it costs us money), never manual entry. |
| Paying per trip or per group | Settle Up Group Premium, Kittysplit, Tab (watak) | **Test.** A "Trip Pass" for one ledger suits people who travel once a year and hate subscriptions. |
| Claiming items in real time on a shared receipt | Tab, Splitwise Itemize, Apple Cash | **Adopt.** Show other people's claims live on the guest page: avatars hop onto items. |
| Change history / audit trail | Splitwise has it; Tricount reviewers complain it is missing | **Adopt.** Show "Edited by Mona · 2 min ago" on each bill. It builds trust when money is involved. |
| Group colors as a paid perk | Settle Up | Avoid. It looks petty. Offer cover photos and emoji for groups for free. |
| A customizable Home | Monzo | Later. Start with a strong default; let users pin groups. |

**Empty states (unverified across apps):** most competitors show a plain illustration plus "Add your first expense". Ours should be an **interactive sample**: a demo receipt the user can scan or tap through in 20 seconds, then delete.

**Motion:** none of the split apps stand out for motion. Copilot and Revolut set the bar. Section 4.6 lists the moments worth animating.

---

## 3. User sentiment

### Splitwise
**Complaints**
- Daily cap on the free tier, by far the most common: "Can't add more than 2 expenses a day" (Trustpilot, 2026-08-27); "the new limit of only 3 transactions per day is ridiculous" (Trustpilot, 2026-02-26).
- Upselling: "kept prompting us to go pro" (Trustpilot, 2026-04-27); "paywalled nearly everything useful" (App Store review, Aug 2026).
- Confusing splits and distrust of the totals: "so bad and confusing" (Trustpilot, 2026-08-27); "don't believe the reconciliations" (Trustpilot, 2025-10-10).
- Support: "customer service … nonexistent" (Trustpilot, 2026-04-08).
- You cannot itemize from an existing photo, and there is no iPad split screen (App Store, 2025).

**Praise**
- "great for holidays and splitting bills with housemates" (Trustpilot, 2026-04-28)
- "makes adding expenses effortless" (Trustpilot, 2025-04-01)
- "Paying for premium is 100% worth it" (App Store, 2025)

Sources: https://www.trustpilot.com/review/splitwise.com · https://apps.apple.com/us/app/splitwise/id458023433

### Tricount (since bunq)
**Complaints**
- Wrong balances and rounding: "the balances were wrong" (Trustpilot, 2026-05-30); a 9-person split had rounding errors (Trustpilot, Sep 2025).
- Features removed: CSV export and the web app are gone. "removed the feature to export data as CSV files" (Trustpilot, 2026-09-12).
- Support handled by AI: "customer support is 100% handled by AI" (Trustpilot, 2026-01-20).
- Transfers and fees through bunq: "Fees are applied without any warning" (Trustpilot, 2025-10-25).
- No edit history; one user lost a week of trip data after an update (App Store, 2024).

**Praise:** simple, free and unlimited. One review says it "saved my relationship" (App Store). Another calls it "very good for knowing how much was spent on a trip" (Trustpilot, 2026-10-28).

Sources: https://nl-be.trustpilot.com/review/tricount.com · App Store listing above

### Settle Up
- Praise: "a game changer on a recent group trip"; reviewers call adding an expense the fastest they have used, and like that export is free.
- Complaints: "looks a little dated"; categories, receipts and recurring expenses are behind the paywall; feature requests go unanswered.

### Splid
- Praise: no limits, no ads, works without signal, "Easier than Venmo", the currency converter.
- Complaints: no web version; settlement amounts a few dollars off from rounding.

### Tab (bring10)
- Praise: easy for large group dinners.
- Complaints: subtotal and tax scanned as items, a mystery tip, tax not editable, no audit trail, no partial shares of an item.

**What this means for us**
1. **Correct rounding and arithmetic you can check** win trust. Show the breakdown of each share and where every cent went. Our `lib/domain` work on minor units and rounding fixes this directly; we should market it ("every cent accounted for").
2. **Never cap manual entry** and never show interstitial ads.
3. **Export, edit history and a web view** are things users miss when they are taken away. Keep CSV free; PDF can be Pro.
4. **OCR mistakes** (subtotal, tax or tip read as items) are the main failure in receipt apps. Detect them and offer "Looks like tax, move it to charges?" automatically.
5. **Human support** is a real gap. Splitwise and Tricount are both criticized for it.

---

## 4. Recommended visual direction: "Quiet ledger"

Goal: it should feel as trustworthy as a banking app and as warm as a messaging app. Calm surfaces, one confident accent, generous numbers, and motion that confirms money moving. Not playful, not clay, not glassy for its own sake.

### 4.1 Principles
1. **The money is the hero.** Large tabular figures for amounts; everything else steps back.
2. **One accent, used sparingly.** Color marks meaning (an action, or your own share), not decoration.
3. **Flat and layered.** Show depth with tonal surfaces and hairline borders, not drop shadows.
4. **Friendly through words and small moments**, not cartoon illustrations.
5. **Mirror for RTL, never translate the numbers.** Digits and currency follow the locale; layout mirrors.

### 4.2 Palette approach
- **Neutrals carry about 90% of the UI.** Use a warm-tinted gray ramp from 0 to 950, not pure gray; a slight warm or green tint feels more human than slate blue. Light mode: background `#FAFAF8`, surface `#FFFFFF`, surface-2 `#F3F3F0`, border `#E6E6E1`, text `#121412` / `#5B605B`. Dark mode: background `#0E0F0E` (not pure black, to avoid OLED smearing), surface `#161816`, surface-2 `#1F221F`, border `#2A2E2A`, text `#F2F3F1` / `#A3A8A3`.
- **One brand accent, distinctive, not fintech blue.** Recommended: a **deep teal-green** (for example `#0F766E` in light mode and `#2DD4BF` tuned down to about `#34C5B0` in dark mode). It suggests money and "settled", stays clear of Splitwise's mint and Wise's lime, and works across cultures, since green is positive in MENA. Alternatives to show the owner: ink indigo `#3B3FD8`, or saffron `#E08A1E` for a warmer brand. The final choice depends on the name (Nusso).
- **Semantic colors, never alone:** positive "you get back" uses the accent; "you owe" uses a muted amber `#B45309` / `#F59E0B`, not alarm red. Red is only for destructive actions and errors. Always pair color with a word or sign.
- **Person colors:** 8 desaturated avatar tints (like pastel chips at about 12% opacity, with text at full strength) to tell people apart on itemized receipts. Check them for color-blind safety.
- **Contrast:** body text at least 4.5:1 in both themes; amount text at least 7:1. Generate the ramps with a perceptual tool (OKLCH) so light and dark match in perceived lightness.

### 4.3 Typography (Google Fonts, all available in `google_fonts`)
| Role | Recommendation | Why |
|---|---|---|
| Latin, Cyrillic, Greek, Vietnamese UI | **Inter** (keep it; it is already in `app_typography.dart`), with **tabular figures** (`FontFeature.tabularFigures()`) on every amount | Neutral, excellent at small sizes, broad language coverage including Vietnamese, has a `tnum` feature. |
| Display (hero numbers, titles) | **Inter Tight** or **Manrope** at weight 600–700 with tight tracking. Alternative: **Instrument Sans** for more character. | Gives a premium "editorial" feel without a second family to load. Revolut-like geometry without the license (Aeonik is commercial). |
| Arabic (ar) | **IBM Plex Sans Arabic** (UI). Alternative: **Readex Pro**, which has matched Latin and Arabic. | Plex Arabic was designed alongside a grotesque, so it sits well beside Inter; it has several weights. **Unverified:** check its Urdu-specific glyphs (ٹ ڈ ڑ ں ے). |
| Urdu (ur) | **Noto Nastaliq Urdu** for headings and long text if line height allows; otherwise **Noto Naskh Arabic** or Plex Arabic for dense UI | Urdu readers expect Nastaliq, but it needs about 1.8–2.2× line height. Test both with native speakers. |
| Hindi (hi) | **Noto Sans Devanagari** or **IBM Plex Sans Devanagari** | Matched x-height with Inter. |
| Thai (th) | **IBM Plex Sans Thai** or **Noto Sans Thai** (looped style) | Thai users find loopless fonts harder to read in body text. |
| CJK (ja, ko, zh) | **Noto Sans JP / KR / SC** | Standard; set the font per locale to avoid wrong Han glyph forms. |

Type scale (suggestion): hero amount 44/48 w700 with tight tracking; title 22/28 w600; body 16/24 w400; caption 13/18 w500. Increase line height by about 15–25% for Arabic, Urdu, Thai and Hindi. Support Dynamic Type up to accessibility sizes, and let hero amounts shrink to fit instead of wrapping.

### 4.4 Shape, elevation, iconography
- **Radii:** 6 (chips, inputs), 12 (list rows and small cards), 20 (cards and sheets), 28 (bottom-sheet top corners), full pill for primary buttons and avatars. Use rounded rectangles consistently; never mix sharp and soft corners on one screen.
- **Elevation:** level 0 is a flat surface. Level 1 is a tonal surface plus a 1 px hairline border, with no shadow. Level 2 (sheets and menus) gets one soft shadow (y 8, blur 24, about 8% opacity) in light mode only; in dark mode use a lighter surface tone instead of a shadow. No inner shadows, no clay, no neumorphism. Use background blur only for the navigation bar and sheets (fits iOS 26 Liquid Glass) and keep text on solid fills.
- **Icons:** **Phosphor** (regular and bold weights, with a Flutter package) or **Lucide**, at a 1.5–2 px stroke and a 24 px grid. Use filled variants only for the selected tab. Mirror directional icons (arrows, send, chevrons) in RTL, but **do not mirror** check marks, the camera, receipts or clocks.
- **Illustration:** none, or minimal line spot art in neutral tones plus the accent. Use real receipt photos and avatars as the imagery.

### 4.5 Layout and density
- Home, top to bottom: net balance (the hero), a row of quick actions (Scan, Add, Settle, Request), "People to settle with" as a horizontal avatar strip with amounts, groups, then recent activity.
- An 8 pt grid, a 16 pt page gutter, list rows at least 56 pt high, touch targets at least 44 pt.
- Bottom sheets with detents for adding an expense, choosing a split method and payment options. This keeps context and fits iOS and Material 3.
- Medium density: more airy than Splitwise, less sparse than Splid. Data screens (group ledger, export) can be denser.

### 4.6 Motion principles
- **Purposeful and short:** 150–250 ms for UI and 300–450 ms for "money moved" moments; use standard ease-out or spring curves (damping about 0.8–0.9), no bounces beyond one small overshoot.
- **Signature moments (only these get special treatment):**
  1. Receipt scan: the line items "type in" from top to bottom as they are recognized (shimmer, then text).
  2. Assigning: the person's avatar hops onto the item; a subtle haptic tick.
  3. Balance changes: the numbers count up or roll.
  4. Settled: the balance rolls to zero, the row collapses with a check mark, and a medium haptic fires. A **quiet** confetti only for "whole group settled", at most once per group.
- Shared-element transitions from a group card to the group screen and from a receipt thumbnail to the full view.
- Respect Reduce Motion: replace movement with crossfades and keep the haptics.

### 4.7 Dark mode and RTL checks
- Design both themes together from tokens; no "inverted" afterthought. The accent needs separate light and dark values.
- RTL: mirror the layout with `Directionality`; use start/end padding everywhere; check amounts with mixed digits (Arabic-Indic or Latin per user setting, defaulting to the locale), `‏` direction marks around currency codes, and that charts and progress bars fill from the start side.
- Test screens: Home, itemized receipt, guest page, settle up, paywall, in ar, ur, ja and th at the largest Dynamic Type.

---

## 5. Feature gap matrix (us vs the top 6)

Legend: **Y** = yes, **P** = partial or paid only, **N** = no, **?** = unverified. "Us" means planned for 2.0 (from ROADMAP.md) unless marked "new".

| Feature | Us | Splitwise | Tricount | Settle Up | Splid | Apple Cash | Spliit |
|---|---|---|---|---|---|---|---|
| AI receipt scan + itemized | Y | Y (free Itemize in US and UK; Pro elsewhere) | N | N (photo only) | N | Y (US) | P (total and category) |
| Voice item assignment | **Y (unique)** | N | N | N | N | N (Siri unverified) | N |
| Guest join without app | Y (web) | Y (QR, Itemize) | P (share amount) | P (view-only web) | N | N (needs Apple Cash) | Y (web) |
| Guest payment proof | **Y (unique)** | N | N | N | N | N | N |
| Running balances / groups | Y (2.0) | Y | Y | Y | Y | N | Y |
| Debt simplification | Y (2.0) | Y | Y | Y | Y | N | ? |
| Split by percentage / shares / exact | Y (2.0) | Y | P (uneven) | Y (weights) | Y | P (item or even) | Y |
| IOU without a bill | new | Y | Y | Y | Y | Y (request) | Y |
| Multi-currency + FX | Y (Pro) | P (conversion Pro) | Y | Y | Y (150+) | N | Y |
| Recurring bills | Y (Pro) | Y | ? | P (Premium) | N | N | N (planned) |
| Offline mode | ? | Y | Y | Y | Y | N | N |
| CSV / PDF export | Y (Pro) | P (CSV free) | N (removed) | P (Excel Premium) | P (PDF free) | N | ? |
| Receipt photo archive | new | P (Pro, 10 GB) | Y (photo) | P | N | N | Y |
| Per-item tip/tax rules | new | P (proportional) | N | N | N | Y (tip) | N |
| Payment deep links for each country | new | P (Venmo, PayPal, Paytm, Pay by Bank) | P (bunq) | N | N | Y (Apple Cash) | N |
| Smart reminders / nudges | Y (2.0 FCM) | Y (manual) | ? | Y (automatic) | N | N | N |
| Edit history / audit | new | Y | N | ? | ? | N | ? |
| Spending insights | new | P (Pro charts) | ? | P (Premium) | P (totals) | N | N |
| Trip mode with budgets | new | N | N | N | N | N | N |
| Shared shopping list | new | N | N | N | N | N | N |
| Home-screen widget | new | ? | ? | N | ? | N | N |
| Live Activities | new | N | N | N | N | N | N |
| Siri / Shortcuts / App Intents | new | ? | ? | ? | ? | Y (system) | N |
| Apple Watch | new | Y (balances, reminders) | ? | N | ? | Y (pay) | N |
| Wallet pass | new | N | N | N | N | n/a | N |
| iMessage / WhatsApp share cards | new | ? | ? | ? | ? | Y (iMessage) | N |
| QR friend add | Y | Y (Itemize QR) | ? | Y | ? | N | N |
| Free daily limit | None | **Cap** | None | None | 1 group | None | None |
| Ads | Rewarded only | Free: yes | No | Free: yes | No | No | No |
| Locales / RTL | 22, ar + ur RTL | 12 | Many | Many | 5 | Many | ? |

---

## 6. New features, prioritized

### Quick wins (days to about 2 weeks each)
1. **Payment deep links for each country on the guest page and settle-up** (InstaPay, PayPal.me, Venmo, Revolut.me, UPI `upi://pay`, Pix "copia e cola", Bizum, Swish, MobilePay, Vipps, Twint, Wise). The user stores their handles once; guests see only the methods that work in their country. Nobody covers more than 4. **Has it:** Splitwise (US and India only), Apple Cash (US). **Unverified:** some schemes (Bizum, Swish, MobilePay, Vipps, Twint) have no public URL to request an amount; fall back to copying the phone number or IBAN plus the amount.
2. **Rich share cards for WhatsApp, iMessage and Telegram**: an Open Graph image per guest link showing "Mona, your share is EGP 240 · 3 items" in the brand style. This is the main growth loop in MENA and South Asia, where WhatsApp dominates. **Has it:** none verified.
3. **Edit history plus a "where every cent went" breakdown** on each bill and share. It answers the top Tricount and Splitwise trust complaints. **Has it:** Splitwise (history).
4. **Smart OCR clean-up**: detect subtotal, tax, service and tip rows and move them to charges; per-item tip and tax rules ("tax only on food", "service on everything"). **Has it:** partly Splitwise and Apple.
5. **IOU without a bill** ("I owe Ali 50") and split by percentage or shares: table stakes everywhere. **Has it:** all ledger apps.
6. **Free CSV export, PDF report in Pro.** It wins the users Tricount lost. **Has it:** Splitwise (CSV), Settle Up, Splid.
7. **Home-screen widget (balance and Scan button) plus quick actions.** Flutter supports it through `home_widget`. **Has it:** none verified.

### Medium bets (2 to 6 weeks)
8. **Trip mode**: a ledger with dates, a base currency, an optional budget, a daily spend chart, "trip ended, settle up?", and a recap card at the end of the trip that can be shared. Combine it with a **Trip Pass** one-time purchase (pricing to test). **Has it:** none fully; Tab (watak) sells per-trip passes.
9. **Offline-first entry with a visible sync state.** Splid, Tricount and Settle Up all have it; travelers need it.
10. **Receipt photo archive with search** (merchant, date, amount) in Pro. **Has it:** Splitwise Pro (storage).
11. **Siri, Shortcuts and App Intents** ("Split last receipt with Ali and Mona") plus Android App Actions. They fit our voice moat. **Has it:** not verified for any competitor.
12. **Live Activity and Dynamic Island for an open bill** ("3 of 5 paid") and Android ongoing notifications. **Has it:** none.

### Big bets (6+ weeks)
13. **Household plan** (shared Pro for up to 5 people) with recurring rent, utilities and a shared shopping list that turns into expenses. **Has it:** none in this form.
14. **Spending insights across groups** (by category, by person, by month) in Pro. **Has it:** Splitwise Pro, Settle Up Premium.
15. **Apple Watch**: balances, nudges and "mark as paid". **Has it:** Splitwise.
16. **Wallet pass for a trip or group** (QR to join and live balance). **Has it:** none. Novel, but the benefit is unproven.
17. **Business and expense reports** (a PDF with receipts for a manager). A niche worth a Pro+ tier later.
18. **Light gamification**: a "settled streak" per group and a "fastest payer" badge visible only to the group. Keep it subtle, and skip it if it feels childish in user tests.

### Top 10 (recommended order)
1. Payment deep links for each country on the guest page and settle-up
2. WhatsApp and iMessage share cards with a personalized OG image
3. "Every cent accounted for" breakdown plus edit history
4. Smart OCR clean-up plus per-item tax and tip rules
5. IOU without a bill, and split by percentage or shares (complete the 2.0 split methods)
6. Trip mode (budget, recap card, settle prompt) plus a Trip Pass test
7. Offline-first entry with sync status
8. Home-screen widget plus quick actions, then a Live Activity for an open bill
9. Siri, Shortcuts and App Intents built on voice assignment
10. Household plan with recurring bills and a shared shopping list

---

## 7. Open items

- Reddit sentiment check by a person (blocked for my tools).
- A hands-on design teardown on a device of Splitwise (including Itemize), Tricount, Settle Up, Splid, Copilot and Revolut, light and dark, with screenshots saved to `docs/2.0/teardown/`.
- Confirm when Splitwise Itemize reaches markets outside the US and UK, and whether its QR guest flow works on the web or needs an App Clip or Instant App.
- Confirm Apple Cash Split Bill's shipping version, and whether non-Apple-Cash recipients can do anything.
- Check whether the URL schemes for Bizum, Swish, MobilePay, Vipps and Twint support an amount.
- Check IBM Plex Sans Arabic's Urdu glyph coverage, and do a Nastaliq vs Naskh test with Urdu speakers.
- Splitwise widget and Siri support, Tricount recurring expenses: not verified.
