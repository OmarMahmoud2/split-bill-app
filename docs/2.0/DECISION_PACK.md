# Split Bill 2.0 — Decision Pack

Prepared 2026-11-05. Research only: no code, store listings, domains or servers were changed, and no live AI calls were made.

Verification labels used throughout:

- **Verified**: I checked it directly on 2026-11-05 (whois, the Google Registry RDAP endpoint, the iTunes Search API, an App Store page, a Google Play search page, or the vendor's own page).
- **Third-party**: the source is a blog or review site, often one written by a competitor. Treat it as indicative.
- **Unverified**: I could not check it. It is an estimate or needs a human to look.

---

## 0. Decisions needed (recommended defaults)

| # | Decision | Recommended default | Confidence / what to check first |
|---|---|---|---|
| 1 | **App name** | **Halbo** (replaces Nusso; the owner asked for a global name). Store title: `Halbo: Split Bills & Receipts` (29 chars). Subtitle: `AI Receipt Scanner & Settle Up` (30 chars). | `halbo.app` and `gethalbo.com` are unregistered, and no similar app exists on the App Store (US/GB/DE/SA) or Google Play (US, partial) (verified). `halbo.com` is taken and its use is unknown. Still needed: a registry trademark search (classes 9 and 36, not done) and a native-speaker check (section 1.3). The runner-up is **Tabzu**. |
| 2 | **Pro prices (USD base)** | **Decided by owner: $2.99/month, $24.99/year, $59.99 lifetime** (lifetime keeps fair-use limits on AI scans). Recommended: a 7-day free trial on the yearly plan only. | Decided. Below Splitwise ($4.99 / $39.99) and Settle Up's monthly ($3.99). Yearly is about $2.08/mo, 30% off monthly. Set local price tiers separately in App Store Connect and Play Console. Section 2.2 still shows the earlier $3.99 monthly recommendation for reference. |
| 3 | **Support email** | DECIDED by owner: `support@omarmali.net` (live in app and backend on release/2.0.0). | A product-domain address can be added later after the rename, forwarding to support@omarmali.net. |
| 4 | **Anthropic: `voice/assign/`** | **Switch to Claude Haiku 5.5** on a short production trial. Fall back to Sonnet if matching is weak. | Low risk: the output is sanitized, and a bad answer costs the user one tap. The privacy policy must be updated first (section 5.4). |
| 5 | **Anthropic: `receipts/scan/`** | **Stay on OpenAI until the 20–30 receipt bake-off in section 5 passes.** | This is the core paid feature, and there is no quality data for Claude on it yet. The estimated Claude cost is not clearly lower. |
| 6 | **Anthropic: `voice/transcribe/`** | **Stay on OpenAI.** | No choice here: the Claude API has no speech-to-text. |
| 7 | **Firestore Stage B (tighter rules)** | Ship it **when at least 90% of 30-day active users are on 1.2.0 or later, and not before 2026-12-02** (4 weeks after the 1.2.0 release). Add a soft force-update prompt for versions below 1.2.0 two weeks before Stage B. | Measure adoption by app version in Firebase Analytics or Crashlytics. Expect a long tail of Android users on old versions. 4 weeks is typical for 85–90% adoption, but this is unverified for this app's audience. |

---

## 1. Name shortlist

Revised 2026-11-05. The owner rejected the Arabic-root-only list and asked for **global** names. The earlier Arabic-root candidates are kept only as a footnote (section 1.6).

Criteria:

- Short: 8 letters or fewer, ideally 6 or fewer. With the store title pattern `<Name>: Split Bills & Receipts`, the suffix is 24 characters, so **only names of 6 letters or fewer fit the 30-character iOS and Play title limit.** Longer names need a shorter suffix, such as `<Name>: Split Bills & Scans` (21 characters).
- Easy to say in English, Spanish, German, Japanese, Arabic and Hindi. Avoid hard consonant clusters. Prefer names with no **P** or **V**, because Arabic has neither sound (speakers say B and F instead), and Japanese merges V with B.
- No negative meaning in the 22 app languages.
- Evokes splitting, sharing, settling, being even, or a tab.
- No same-niche app, website or brand with a confusingly similar name.

### 1.1 Candidates (12, across three styles)

| # | Name | Style | Letters | Meaning / rationale | Pronunciation and meaning notes (see 1.3 for what was checked) |
|---|---|---|---|---|---|
| 1 | **Halbo** | Coined | 5 | From German *halb* ("half"), with cognates in Dutch *half/halve* and Swedish, Danish and Norwegian *halv*. That gives it an instant meaning in DE, CH, AT, NL and the Nordics, and it reads as "half-o" in English. | No P, V or clusters, so it is easy in all six test languages (ja ハルボ *harubo*, ar هالبو, hi हाल्बो). Spanish *albo* means "white" (poetic), which is harmless. No negative meaning found. |
| 2 | **Tabzu** | Coined | 5 | "Tab" plus *-zu*. In German, *Tab zu* reads as "tab closed", which suits settling up. Short and punchy. | Easy everywhere (ja タブズ, ar تابزو, hi टैब्ज़ू). No negative meaning found. The *z* is said as "s" by some Arabic and Spanish speakers, which does no harm. |
| 3 | **Tabaroo** | Coined | 7 | "Tab" plus the playful Australian *-aroo* ending (as in *kangaroo*). Friendly and memorable in the US, UK and AU. | Easy (ja タバルー, ar تبارو). Italian *tabarro* means "cloak", which is harmless. Some people may hear "taboo" in it, which is mild. **At 7 letters it does not fit the standard title** (31 characters). |
| 4 | **Kwittle** | Coined | 7 | From *quitt* (German, "we're even"), *kvitt* (Swedish, Danish, Norwegian), *quitte* (Dutch, *quitte spelen* = "break even"), *квиты* (Russian, "we're quits") and Polish *kwit* ("receipt"). It has the strongest multi-market meaning of any candidate. | The *-ttl* cluster is hard in Japanese (クウィトル) and Spanish. Arabic speakers write كويتل, which looks a little like الكويت (Kuwait), a neutral association. Avoid the *Kwitta* spelling, which is close to Hindi/Urdu कुत्ता / کتا *kutta* ("dog", an insult). Too long for the standard title. |
| 5 | **Evenkin** | Compound | 7 | "Even" plus "kin": settling up with your people. Warm and clear in English. | Arabic speakers say "ifinkin" (no V). Russian speakers may hear *Evenki* (an Indigenous people of Siberia), a neutral association. Too long for the standard title. |
| 6 | **Tabhop** | Compound | 6 | "Tab" plus "hop", as in bar-hopping or a group night out. Fits the title in exactly 30 characters. | Arabic speakers say "tabhob" (no P), which is harmless. Japanese タブホップ is fine. German *hopp* means "quick", which is positive. |
| 7 | **Evenbee** | Compound | 7 | "Even" plus "bee" (busy and organized). Good mascot potential. | One letter from **Eventbee**, an existing event-ticketing brand with several apps on Play. Too long for the standard title. |
| 8 | **Evenkit** | Compound | 7 | "Even" plus "kit": a toolkit for getting even. | Close to "evenTickit" (event tickets on Play). `evenkit.com` was registered in 2024 and shows a blank page. Too long for the standard title. |
| 9 | **Fiftee** | Real-word twist | 6 | From "fifty-fifty", a loanword in Arabic, Hindi, Spanish and many other languages. | Easy everywhere (ja フィフティー). **Fiftee SRL**, a sports social app from Belgium/France, exists on both stores and owns `fiftee.com`, so the EU trademark risk is real. |
| 10 | **Halvee** | Real-word twist | 6 | From "halve" and "halvsies". | It sounds like *halva* (Arabic *ḥalāwa*, Turkish *helva*, Hindi *halwa*), a sweet, which is mostly positive. In Turkish culture, though, helva is also cooked at funerals. "Halvee - Cozy Match Puzzle" (a game) and "CoHalve" (Finance) are on the App Store. |
| 11 | **Tabclear** | Real-word twist | 8 | From "clear the tab". The meaning is self-explanatory. | It is descriptive, so a trademark would be weak. Several "Tab Clear" browser extensions exist. Too long for the standard title. |
| 12 | **Quidsies** | Real-word twist | 8 | British *quid* ("pound") plus *-sies*, as in "halfsies". | The meaning is lost outside the UK and Ireland, and it is hard in Japanese. It is close to **Quidsi** (the former Amazon subsidiary behind Diapers.com). Too long for the standard title. |

### 1.2 Availability checks (2026-11-05)

Methods:

- `.app`: Google Registry RDAP (`pubapi.registry.google/rdap/domain/<name>.app`). A 404 means not registered and a 200 means registered. I checked twice, the second time just before writing this.
- `.com` and `get<name>.com`: the `whois` CLI. Where the `.com` was taken, I fetched the homepage to see what it is.
- App Store: the iTunes Search API (`entity=software`, limit 50) for `country=us`, `gb`, `de` and `sa`. I flagged any result whose first word contains the name or is at least 75% similar to it (difflib).
- Google Play: the web search page (`gl=US`, `hl=en`), scraped for titles containing the name. **Partial**: the page relies on JavaScript, so I only see what the server returns.
- Trademark: a web search for the exact name. The USPTO Trademark Search site needs JavaScript and **was not reachable** from this environment, and EUIPO, WIPO, the GCC registers and Saudi SAIP were not checked. **All trademark cells are unverified** apart from the web search.

| # | Name | `.app` (verified) | `.com` (verified) | Alternatives (verified) | App Store, US/GB/DE/SA (verified) | Google Play, US (verified, partial) | Trademark / web (web search only, unverified) |
|---|---|---|---|---|---|---|---|
| 1 | **Halbo** | **Free** | Taken (2015). The site is behind a Cloudflare challenge, so its use is unknown. | `gethalbo.com` free | No similar app in any of the 4 countries | No exact match. Nearest: "Habbo" (a game), "Halvo — BTC Cycle" | No company, app or mark found. Habbo (Sulake, games) is the nearest well-known mark, in a different class. |
| 2 | **Tabzu** | **Free** | Taken (2019), for sale on HugeDomains | `gettabzu.com` free | No similar app | No exact match. Near: "TAPZU: Food Delivery", "**Tapzum: Expense Budget Tracker**" | Nothing found. TABZOO (a UK accessories mark) is dead. |
| 3 | **Tabaroo** | **Free** | Taken (2013), no site | `gettabaroo.com` free | No similar app | No exact match | "Tabaroo: AI Tab Manager", a Chrome extension for browser tabs (a different product, low risk) |
| 4 | **Kwittle** | **Free** | **Free** | `getkwittle.com` free | No similar app | No exact match | Nothing found. Note that **"Kwitsy: Split Bills"** (same niche, on Play and `kwitsy.com`) and "Kwit" (quit smoking) share the *kwit-* stem. |
| 5 | **Evenkin** | **Free** | Taken **2026-08-30** (Cloudflare, an app host that returns 404). Someone may be building on it. | `getevenkin.com` free | **No results at all** | No exact match (only Evenki language apps) | Nothing found |
| 6 | **Tabhop** | **Free** | Taken (2016), no site | `gettabhop.com` free | No similar app | No exact match | A Chrome extension "Tab Hop" (about 2 users), low risk |
| 7 | **Evenbee** | **Free** | Taken (2026-06), for sale on HugeDomains | `getevenbee.com` free | No results at all | No exact match. **Eventbee** event apps rank first | Eventbee is a confusingly similar brand |
| 8 | **Evenkit** | **Free** | Taken (2024), blank site | `getevenkit.com` free | No similar app | No exact match. "evenTickit" appears | Nothing found |
| 9 | **Fiftee** | **Free** | Taken; used by **Fiftee SRL** (a sports app) | `getfiftee.com` free | **"Fiftee"** (Sports) in all 4 countries | **"Fiftee"** listed | Fiftee SRL is an active company, so the EU risk is high |
| 10 | **Halvee** | **Free** | Taken (2025), no site | `gethalvee.com` free | **"Halvee - Cozy Match Puzzle"** (Games) in the US and GB, and "CoHalve" (Finance) | No exact match | Nothing beyond the game |
| 11 | **Tabclear** | **Free** | Taken (2005), placeholder | `gettabclear.com` free | No similar app | No exact match. Same-niche "Tab - The simple bill splitter" and "TabTap" rank near it | "Tab Clear" browser extensions. Descriptive, so weak |
| 12 | **Quidsies** | **Free** | **Free** | `getquidsies.com` free | No similar app | No exact match | Close to Quidsi (Amazon). "Quidly" (3 Finance apps) and "Quid: UK Student Life" (Finance) share the stem |

Caveats that apply to every row:

- An RDAP 404 means the domain is not registered. It does not tell you the price: the name could be a registry premium or reserved name. **Unverified until you try to buy it at a registrar.**
- Availability can change at any moment. Several near-miss `.com` names in this niche were registered in mid-to-late 2026 (see 1.5), which suggests other people are naming bill-split apps right now. Register the `.app` and `get<name>.com` domains as soon as a name is chosen.
- **No registry trademark search was done.** Before the rename, search at least the USPTO, EUIPO and the WIPO Global Brand Database in classes 9 (software) and 36 (financial services). Add the UK IPO, CIPO (Canada), IP Australia, JPO, KIPO and the GCC/SAIP registers for the target markets.

### 1.3 Language check: what was and was not checked

- **Checked from my own language knowledge (not by native speakers):** en, es, de, fr, it, pt, nl, sv, da, nb, pl, ru, tr, ar, hi, ur, ja, ko and id. For each, I looked for real words, slang or obscenities that match or nearly match each name. I found no negative meaning for **Halbo, Tabzu, Tabhop, Evenkin or Tabaroo**. The issues I did find (Kwitta and *kutta*, Halvee and the Turkish funeral *helva*) are noted in 1.1.
- **Checked for pronunciation only, not for meaning:** zh, vi and th. For these I am not confident about slang, tones or near-homophones.
- **Ask a native speaker** to sense-check the chosen name and the runner-up in at least ar (Gulf), hi/ur, ja, ko, zh, th, vi and tr before committing.

### 1.4 Top 5 (ranked)

| Rank | Name | One-line rationale |
|---|---|---|
| 1 | **Halbo** | It means "half" to German, Dutch and Nordic speakers, has no P, V or clusters so it is easy in all 22 languages, and it is clean on both stores in all 4 countries checked. `halbo.app` and `gethalbo.com` are free. |
| 2 | **Tabzu** | It is short, punchy and universally pronounceable, and both domains are free. The near-namesake "Tapzum" expense tracker on Play is the only flag. |
| 3 | **Tabhop** | It has a clear "group night out, then split the tab" story and fits the standard title in exactly 30 characters, with only a tiny Chrome extension nearby. |
| 4 | **Evenkin** | It has the cleanest store result (zero App Store hits) and a warm "even with your people" meaning. But it is 7 letters, too long for the standard title, and `evenkin.com` was registered in August 2026. |
| 5 | **Tabaroo** | It is the most fun and memorable in the US, UK and AU, but at 7 letters it needs the shorter title suffix, and there is a browser-tab Chrome extension with the same name. |

Honourable mention: **Kwittle** has the best multi-market meaning ("quits" in German, Dutch, Nordic and Russian, and "receipt" in Polish), and both its `.app` and `.com` are free. But it is hard to say in Japanese and Spanish, and it shares the *kwit-* stem with the same-niche "Kwitsy: Split Bills".

### 1.5 Recommendation

**Halbo.**

- Store title: `Halbo: Split Bills & Receipts` (29 characters).
- Subtitle (iOS) / short description lead (Play): `AI Receipt Scanner & Settle Up` (30 characters).
- Domains to register first: `halbo.app` and `gethalbo.com` (both free on 2026-11-05). `halbo.com` is taken, and its use is unknown.
- Why: it means "half" in the target markets with the highest willingness to pay (DE, CH, NL and the Nordics), it says the product's core idea in 5 letters, it is pronounceable in every app language, and no app with a similar name exists in the US, GB, DE or SA stores.
- Before committing: run a registry trademark search (classes 9 and 36), check that halbo.com is not an active business in this space, and do the native-speaker check in 1.3.

**Runner-up: Tabzu.**

### 1.6 Names checked and rejected

| Name | Why rejected (verified 2026-11-05 unless marked) |
|---|---|
| Kwitsy | **"Kwitsy: Split Bills"** exists on Google Play, and `kwitsy.com` (registered 2026-09) is a live bill-splitting site. |
| Evenpot | `evenpot.com` is a live "split bills, settle up" app (Finance), and `getevenpot.com` hosts "Even Pot". |
| Quitsies | `quitsies.com` (registered 2026-08) hosts a live web app with the same name. |
| Evenout, Evensies, Fairsies, Tab Tally, TabsUp | A same-niche Finance app with that name already exists on the App Store (for example "EvenOut: Split & Settle Up", "Evensies: Split & Settle Up", "Fairsies: Split the Bill", "Tab Tally - Split Group Bills", "TabsUp"). |
| Evenko | evenko is a major Montreal concert promoter, and Canada is a target market. Confirmed by a Play search. |
| Quidly, Quidsy, Quidd | "Quidly" is used by 3 Finance apps. `quidsy.com` is a UK "earn money" site. Quidd is a known collectibles app (from memory, unverified). |
| Fairlo | `fairlo.com` is a Swedish consumer-credit company, which matters because the Nordics are a target market. |
| Splitkin, Splitzu | There is already an App Store app called "SplitKin App", and the *split-* prefix is crowded: "Splitzy", "Splitza", "Splitr", "Splitski", "Splitko" and "Splito" all exist. |
| Tabora | "Tabora: Save Videos as Tabs" (Productivity) exists. |
| Tabso, Tabsie | Too close to the existing "Tabsy - Shared Tabs & Expenses" (Finance). |
| Tabfox, Evenfox | "TabFox" exists (Developer Tools). Foxes also suggest cunning, which is the wrong signal for a money app. |
| Evenowl | The owl is a bad omen in Arab culture, and Hindi/Urdu *ullu* ("owl") is slang for "fool". `evenowl.app` was free. |
| Tabmint, Evenmint | "Mint" is Intuit's former budgeting brand, so the trademark risk in finance is high. |
| Divvia | Close to **Divvy** (BILL's spend-management brand), and the double V is hard in Arabic. |
| Tabbo | The `.app` is free, but there is a "TABBO" app (Education), and the name reads as "taboo" in English and Arabic (تابو). |
| Kwitt, Kvitt, Quitto, Halvo, Settla, Settlo, Evenup, Sharo, Squaro, Halvsies, Quits, Splitly, Fairly, Squarely, Tabby, and others | The `.app` domain is registered (RDAP 200). |
| Tabby (idea only) | Tabby is a large BNPL fintech in Saudi Arabia and the UAE. |

### 1.7 Footnote: regional alternatives (from the earlier Arabic-root list)

If a regional sub-brand is ever needed for MENA or South Asia, these were checked on 2026-11-05. All have a free `.app` and no same-name app in US search results. No trademark search was done for any of them.

- **Nusso**: from Arabic نص *nuṣṣ*, "half". *Nuṣṣ-nuṣṣ* means "50/50" in Gulf, Levantine and Egyptian dialects.
- **Qismo**: from Arabic قسمة *qisma*, "portion". The "Q" is hard for non-Arabic speakers.
- **Hisso**: from Arabic حصة *ḥiṣṣa* and Hindi/Urdu हिस्सा / حصہ *hissa*, both meaning "share". In English it evokes a hiss.

---

## 2. Competitor pricing (checked 2026-11-05)

### 2.1 Pricing table

| App | Model | Prices (US storefront) | Free-tier limits that matter | Sources |
|---|---|---|---|---|
| **Splitwise** | Freemium subscription (Pro) | The App Store lists IAP tiers of $2.99, $3.99 and $4.99 (monthly) and $29.99 and $39.99 (yearly). Most US users see **$4.99/mo or $39.99/yr**. Prices vary by country. | **A daily cap on new expenses for free users.** Splitwise does not publish the number. Users report about 3–5 expenses per day, and 2023 reports also mention a ~10-second cooldown. Receipt scanning with itemization, currency conversion, search, charts and no ads are Pro-only. | App Store listing (verified): https://apps.apple.com/us/app/splitwise/id458023433 · Splitwise Pro page (verified; no prices on the page, confirms that Pro means unlimited expenses each day): https://www.splitwise.com/pro · Third-party, 2026-08-06: https://getfinny.app/blog/splitwise-pricing-2026 · Third-party, about the cap: https://www.itvoice.in/splitwise-has-introduced-restrictions-on-the-number-of-free-expenses-users-can-add |
| **Tricount** (owned by bunq) | **Free. No Premium tier, and the official pages say no ads.** It is monetized by pushing users to bunq bank accounts. | $0. No IAPs are listed. | No limits. Premium was discontinued, and CSV/PDF export and statistics were removed with it. | App Store (verified; "No subscription, no hidden fees", no IAPs): https://apps.apple.com/us/app/tricount-split-settle-bills/id349866256 · Help center (verified; "Free. No ads. No limits.", Premium deprecated, page timestamp 2026-11-04): https://help.tricount.com/d/61452 |
| **Settle Up** | Freemium with ads, plus per-user and per-group Premium | **Monthly Premium $3.99, Yearly Premium $19.99.** Group Premium: $5.99 for 1 week, $9.99 for 2 weeks, $14.99 for 1 month, $29.99 for 2 months, $39.99 for 1 year. **Lifetime Group Premium $149.99.** | The free tier has ads. Receipt photos (stored, not scanned), recurring expenses, Excel export and stats are Premium. Debt minimization, multi-currency, offline use and browser view are free. | App Store (verified): https://apps.apple.com/us/app/settle-up-group-expenses/id737534985 |
| **Splid** | **One-time unlocks**, no subscription | **Splid Plus $3.99** and **"2 Groups" $2.99**. | Third-party sources say the free tier allows 1 group. Excel export needs a purchase. Reviewers say there are no ads. | App Store (verified IAPs): https://apps.apple.com/us/app/splid-split-group-bills/id991473495 · Third-party (group limit): https://tabb-landing.pages.dev/compare/tabb-vs-splid |
| **Tab** (bring10) | Free | $0. No IAPs are listed. | It is a single-bill receipt splitter with no running balances. | App Store (verified): https://apps.apple.com/us/app/tab-the-simple-bill-splitter/id595068606 |
| **Spliit** | Free and open source | $0, with no account, subscription or trial. | None. | App Store (verified): https://apps.apple.com/us/app/spliit-shares-expenses/id6737742507 · Source code: https://github.com/spliit-app |

Gaps in this check:

- Google Play prices were not checked separately. They usually mirror the App Store but can differ.
- The Splitwise IAP list does not map each price to a plan or country, so the "$4.99 / $39.99 for US users" figure is a third-party reading of that list.

### 2.2 Recommended Pro pricing (USD base)

| Plan | Price | Rationale |
|---|---|---|
| Monthly | **$3.99** | Matches Settle Up and is $1 under Splitwise. Monthly is the decoy plan that makes yearly look good, and it suits one-off trip users. |
| Yearly | **$24.99** (about $2.08/mo, 48% off monthly) | 37% below Splitwise's $39.99. Above Settle Up's $19.99, which is justified because we sell AI scanning and voice, not just "no ads". Put the 7-day free trial on this plan only. |
| Lifetime | **$59.99** | About 2.4 times the yearly price, a common ratio. It undercuts Settle Up's $149.99 group lifetime, and it gives users who hate subscriptions (Splid's audience) a path to pay. **Attach a fair-use limit to AI scans and voice** (for example, a monthly allowance shown in the app), because each scan has real API cost (section 5). Without one, a heavy lifetime user loses money. |

Free tier:

- **Keep manual expenses and running balances unlimited.** Splitwise's daily cap is its most-hated feature, so "no daily limits" is a headline to use against it.
- Monetize the AI features through the existing points system (rewarded ads and a free allowance) and Pro.
- Keep the promise of no interstitial ads.

Local pricing:

- Do not rely on automatic currency conversion from the USD base.
- Set **per-store local price tiers** in App Store Connect (pricing by country or region) and in Play Console (local prices per country).
- Lower prices meaningfully in India, Pakistan, Egypt, Indonesia and LATAM. A starting point is roughly 35–50% of the USD price, based on purchasing power.
- Price SAR, AED and EUR close to the USD level.
- In RevenueCat, use Offerings and Experiments to A/B test yearly $24.99 against $29.99 once you have more than about 1,000 paywall views a month.

---

## 3. Feature gap table vs. Split Bill 2.0

Legend: **Y** = yes, **P** = partial or paid only, **N** = no, **?** = not found or unverified. Sources are the App Store pages in section 2 (checked 2026-11-05) and splitwise.com/pro. Where a cell says "not mentioned", I did not test the app myself.

| Feature | **Ours (2.0)** | Splitwise | Tricount | Settle Up | Splid | Tab | Spliit |
|---|---|---|---|---|---|---|---|
| Receipt scanning (OCR/AI) | **Y** (AI) | P (Pro only) | ? (not mentioned) | N (stores the photo only, Premium) | ? (not mentioned; third-party says no) | **Y** | P (on-device; total, date and category only) |
| Itemized splitting (per line) | **Y** | P (Pro, after a scan) | N (not mentioned) | N | N (not mentioned) | **Y** | N (not described) |
| Voice item assignment | **Y** | N | N | N | N | N | N |
| Guest web pay link + payment proof | **Y** | N (web app needs an account) | ? (the older app shared web links; not confirmed for the new app) | P (view-only browser link via share link or QR) | N (shares groups, no web version) | N | Y (web groups by link, no payment proof) |
| Multi-currency | ? (confirm 2.0 scope) | P (conversion is Pro) | Y | Y (live rates, free) | Y (150+ currencies) | N (not mentioned) | Y |
| Debt simplification | ? (2.0 "settle up"; confirm) | Y | ? (not mentioned) | Y (free) | Y | N | ? |
| Offline | ? (Firestore cache; confirm the UX) | ? | Y | Y | Y | ? | ? |
| Export (CSV/PDF/Excel) | ? (confirm 2.0 scope) | P (CSV listed; JSON backup in Pro) | N (removed) | P (CSV free, Excel Premium) | P (PDF free, Excel paid) | P (share summary) | ? |
| Running balances / groups | **Y** (2.0) | Y | Y | Y | Y | N | Y |
| Ads | Rewarded only, no interstitials | Free tier: yes | No | Free tier: yes | No | ? | No |
| Free daily limit | None (recommended) | **Yes, a cap** | None | None | 1 group (third-party) | None | None |
| Locales | 15 incl. ar, ur, hi | Many | Many | Many | Many | en, es | ? |

Takeaways:

- **Our clear moats** are three things together: AI itemized scanning, voice assignment and guest web payment with proof. Add strong Arabic, Urdu and Hindi support.
- No competitor I found does voice assignment of individual receipt lines. Some new AI apps (SplitBill AI, SplitNSettle) do voice for whole-bill or expense entry: https://apps.apple.com/us/app/splitnsettle/id6757589699
- **Table stakes to confirm in 2.0** are multi-currency, debt simplification, offline use and export. Tricount, Settle Up and Splid give most of these away free. If 2.0 lacks any of them, reviewers will call it out against Splitwise and Tricount.

---

## 4. ASO keywords (en-US)

Proposed metadata (iOS):

- **Title (30):** `Nusso: Split Bills & Receipts` (29 characters)
- **Subtitle (30):** `AI Receipt Scanner & Settle Up` (30 characters)
- **Keyword field (100):**

```
expense,group,trip,roommate,friends,dinner,tip,owe,iou,divide,tab,share,cost,travel,voice,dutch,pay
```

That is 99 characters with no spaces. It repeats no word from the title or subtitle (nusso, split, bills, receipts, ai, receipt, scanner, settle, up). Apple already indexes the title and subtitle words, and it combines words across fields, so "split expense", "group trip", "split tip" and "go dutch" are all covered.

Notes:

- **Do not put competitor brand names** (Splitwise, Tricount) in the keyword field. It risks rejection under App Review Guideline 2.3.7, and it rarely converts.
- Consider swapping words based on Apple Search Ads popularity data (free with an Apple Search Ads account): `restaurant`, `calculator`, `check`, `ledger`, `household`, `couple`.
- Google Play has no keyword field. Put "split bills", "split expenses", "receipt scanner", "settle up", "group trip" and "roommates" naturally in the short description (80 characters) and the first 2–3 lines of the full description.

### Localized keyword research (ar, es, de)

1. **Arabic (ar-SA; also used for other Arab storefronts).**
   - Research real search phrasing in Gulf and Egyptian dialects as well as Modern Standard Arabic: تقسيم الفاتورة (split the bill), تقسيم المصاريف (split expenses), حاسبة القسمة (division calculator), and دفع نص نص / "نص نص" (pay half-half). Apple's Arabic keyword index treats definite-article forms (ال-) and plain forms differently, so test both.
   - Users also search in Latin script ("split bill"). The Saudi App Store indexes the English (UK/US) locale as an extra locale, so use that secondary keyword field for transliterations and English terms rather than repeating them in Arabic.
   - With the Nusso name, the dialect phrase "نص نص" is strong for both the brand and keywords.
2. **Spanish (es-MX and es-ES are separate keyword fields).**
   - The vocabulary differs by region: *dividir la cuenta* / *dividir gastos* (general), *pagar a medias* (Spain), *hacer vaca* / *vaquita* (pooling money in parts of LATAM), *gastos compartidos*, *cuentas claras*.
   - Fill es-MX and es-ES separately, because es-MX is also indexed in the US storefront. This effectively gives you a second US keyword field for Spanish terms.
3. **German (de-DE).**
   - German is a compound-word language. People search *Kosten teilen*, *Rechnung teilen*, *Gruppenkasse*, *Reisekasse*, *WG Kosten* (shared-flat costs), *Ausgaben teilen* and *Splitten*.
   - Tricount and Splid are very strong in DACH and Benelux, so expect high competition on generic terms. Target long-tail terms like *Kassenbon scannen* (scan a receipt) and *Beleg teilen* (split a receipt), where AI scanning is the differentiator.
   - Check whether the brand name "Nusso" reads too much like "Nuss" (nut) to German users. That is probably neutral or cute, but worth a quick check.

None of these localized keywords' search volumes are verified. Use Apple Search Ads popularity scores or an ASO tool (AppTweak, Sensor Tower, Astro) before you finalize.

---

## 5. AI provider comparison plan (OpenAI vs. Claude Sonnet 5.5), receipt scanning

Background (from `/Users/omarmahmoud/pythonProjects/omarmali-net/split_bill/ANTHROPIC_ROUTE.md`, read-only):

- The Claude route is implemented behind environment variables but not deployed.
- Receipts use `claude-sonnet-5-5` for both extraction (effort `medium`) and normalization (effort `low`).
- The prompts, JSON schemas and `finalize_receipt_payload` post-processing are shared with the OpenAI path.
- Claude cost is estimated at about **$0.04–0.07 per scan**, but quality has not been measured.
- The OpenAI model prices were not priced in that document.

### 5.1 Test set (25–30 receipts)

- Use real receipts that are already stored, but only ones whose owners' consent and the privacy policy cover reuse. Otherwise collect receipts from your own team. Remove any names or card digits.
- Stratify the set so that weaknesses show up:

| Bucket | Count |
|---|---|
| English restaurant, clean | 4 |
| Arabic or bilingual Arabic/English (Gulf and Egyptian formats) | 6 |
| Other locales: de, es, fr, ja/zh/ko, hi/ur | 5 |
| Long grocery receipts (more than 25 lines) | 4 |
| Blurry, angled, crumpled or poorly lit | 4 |
| Discounts, service charge, VAT-inclusive vs. VAT-exclusive, tips | 4 |
| Handwritten or thermal-faded | 2 |
| Non-receipts (menu, random photo); the expected result is a rejection or `needs_review` | 1–2 |

- **Ground truth:** before running either provider, a human records the expected items (name, quantity, line total), subtotal, tax, service charge, tip, printed total and currency for each receipt.

### 5.2 Procedure (fair and repeatable)

1. Write an offline script that calls the existing dispatcher `scan_receipt_image` with the provider overridden. Run it on a staging host or locally, never through the production endpoint, so no points or users are affected.
2. Keep everything except the provider identical: the same JPEG bytes (re-encoded once to what the app sends, `imageQuality: 85`), the same locale and currency hints, and the same prompts and schemas.
3. Run **each receipt 3 times per provider** to measure variance, and alternate the order of providers to cancel out time-of-day latency effects.
4. Log everything from both providers: `model`, `input_tokens`, `output_tokens`, `request_id`, wall-clock latency, stop reason and the final payload.
5. Score blind. Strip the provider label before a human reviews any disagreement.

### 5.3 Metrics and pass bar

| Metric | Definition | Pass bar for switching |
|---|---|---|
| Item count accuracy | Share of receipts where the extracted line count equals the ground truth, plus line-level precision and recall on (name, line total) | Claude ≥ OpenAI, and not more than 1 point lower on any language bucket |
| Total match | `total_amount` within ±0.01 (or ±1 minor unit) of the printed total | Claude ≥ OpenAI |
| Sum consistency | Sum of items, adjusted for tax, service and discounts, equals the total | Claude ≥ OpenAI |
| `needs_review` rate | Share flagged for review, split into correct flags (the receipt really had problems) and false flags | Equal or lower false-flag rate, with no fewer correct flags |
| Hard failures | Errors, refusals (`stop_reason: refusal`), `max_tokens` cutoffs and JSON that fails the schema | 0 on the 30-receipt set, and fewer than 1% if you later scale up |
| Latency | p50 and p95 end-to-end seconds | p95 no more than 1.25 times OpenAI's p95, and p95 under 20 s in absolute terms |
| Cost per scan | (input tokens × input price + output tokens × output price) summed over both steps, using each provider's current list prices on the test date. Thinking tokens count as output on Claude. | Claude ≤ 1.2 times OpenAI's cost, unless quality is clearly better |
| Run-to-run variance | Share of receipts whose extracted total differs across the 3 runs | Claude ≤ OpenAI |

Optional extra arm: Claude Sonnet for extraction plus **Haiku 5.5 for normalization**, to reduce cost. That step checks totals, so score it on the same sheet.

**Cost to run the bake-off:** roughly 30 receipts × 3 runs × 2 providers = 180 calls. Using the document's estimate of $0.04–0.07 per Claude scan plus a similar OpenAI cost, the total is likely under $25. This is unverified until the token logs exist.

### 5.4 Privacy-policy changes required before switching any feature

What the current page says (`landingPage/templates/landingPage/terms_split.html`, last updated 2026-01-02):

- It lists "Google Cloud Vision / OpenAI: For receipt processing and intelligent OCR."
- It says receipt images are processed via OCR.

Things missing from that page **today, independent of the switch**:

- **Voice data.** It does not mention microphone audio sent to OpenAI for transcription, or transcripts sent for assignment.
- **RevenueCat** (purchases).
- **The rewarded-ad SDK.** I did not check which ad SDK is used.

Required wording changes:

1. **Third-party services.** Replace the AI bullet with a clear list:
   - "OpenAI (receipt image processing; voice transcription; voice item assignment)"
   - "Anthropic (receipt image processing and/or voice item assignment)"
   - Optionally add: "We may route a request to either provider for reliability; each request is sent to one provider."
   - Keep Google Cloud Vision only if it is still used. **Check this:** ANTHROPIC_ROUTE.md says there are no other AI calls in `split_bill/`, so the Cloud Vision mention may already be stale.
2. **Information we collect.** Add a voice item: "Voice commands: if you use voice assignment, a short audio recording is sent to our AI provider for transcription, and the transcript (with bill item names and participant names) is sent to our AI provider to match items to people."
3. **Processing purpose and limits.** Add: "Receipt images and voice data are processed only to provide the scan and assignment features. Our AI providers process this data under their commercial API terms and do not use it to train their models."
   - **Confirm this against the current OpenAI API data-usage terms and the Anthropic Commercial Terms on the day of the change.** I did not verify either provider's current data-retention periods, so do not state a retention period without checking.
4. **International transfers.** Add a line that data may be processed in the United States by these providers, with the safeguards available (for example Standard Contractual Clauses or the providers' data processing addenda). This matters for GDPR (de, fr, it, es, pl) and for Saudi PDPL users.
5. **App Store and Play disclosures.** Update Apple's App Privacy section (photos, audio data, "used for app functionality") and Play's Data safety form (audio, photos, shared with service providers) if they do not already cover voice. Since 2025, Apple's guideline 5.1.2(i) requires telling users when personal data is shared with third-party AI and getting their permission. Add a one-time in-app notice or consent before the first scan or voice use that names the AI providers. **Check the current wording of guideline 5.1.2.**
6. **Update the "Last Updated" date** and, if the policy says it notifies users of material changes, notify them.
7. **Brand rename.** The policy says "At **Split**". Change it to the new name when the rename ships, and update the support email.

### 5.5 Per-feature recommendation

This is the same as rows 4–6 of the checklist:

- Voice assignment: switch to Claude Haiku now, after the privacy update.
- Receipts: switch only if the bake-off passes.
- Transcription: stay on OpenAI.

---

## 6. Open items I could not verify

- A trademark search for any candidate name.
- Native-speaker slang checks for the names.
- Registry premium pricing for `nusso.app` and the other `.app` names.
- Whether Google Play search, which relies on JavaScript, hides same-name apps.
- Google Play prices for competitors.
- Splitwise's exact free daily cap (not officially published).
- Whether the new Tricount app has receipt scanning or guest web links.
- Search volumes for localized keywords.
- Current OpenAI model prices and both providers' data-retention terms.
- 2.0 feature scope for multi-currency, debt simplification, offline use and export (marked "?" in section 3).
