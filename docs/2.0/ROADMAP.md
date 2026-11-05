# Split Bill 2.0 roadmap

Updated 2026-11-05. Companion to `DECISION_PACK.md` (names, pricing, competitors, ASO, AI comparison).
Design direction mockups: https://claude.ai/artifact/R9dGrpfqb1pCPLHywf183r (review before any screen is rebuilt).

Positioning: **AI receipt splitter with running balances.** Scan, say who had what, settle with the fewest payments. Guests pay from a link without the app. Slightly cheaper than Splitwise, more generous free tier, better service.

## Status

| Area | State |
|---|---|
| 1.2.0 security hotfix | Shipped 2026-11-04, in review on both stores |
| Domain layer (`lib/domain`: money, split methods, itemized split, balances, debt simplification) | Done, 93 tests, merged to `release/2.0.0`. Not wired into screens yet |
| Dead code removal, auth wrapper rebuild fix | Done on `release/2.0.0` |
| Design tokens + dark mode | In progress (agent) |
| Support email `support@omarmali.net`, terms link `/split-bill/terms/` | Done in app and backend (backend commit local, not deployed) |
| Landing page bug fixes | Done in backend, local, not deployed |
| iOS dSYM fix | Testing |

## Decisions for the owner

1. **Name** (recommended *Nusso*, runner-up *Qismo*) — blocks icon, palette final, store titles, landing, domain, support address on the new domain.
2. **Design direction** — approve or redirect the mockups (colors, type, home layout, settle up, guest page, landing hero).
3. **Pro pricing** — DECIDED: $2.99/month, $24.99/year (7-day trial on yearly), $59.99 lifetime with AI fair use; per-country tiers in each store.
4. **Free tier limits** — recommended: unlimited manual bills, balances, guest links; 5 AI scans and 10 voice commands a month; rewarded ad = +1 scan.
5. **New locales** (to reach 22) — DECIDED, done on release/2.0.0: Turkish, Dutch, Swedish, Danish, Norwegian, Vietnamese, Thai. Swap for others if you prefer (e.g. Hebrew, Malay, Filipino, Persian).
6. **Anthropic** — DECIDED: move every AI feature that Claude supports (receipt scan, voice assign) with a hardened pipeline; voice input moves to on-device speech recognition (Claude has no speech-to-text), OpenAI transcription kept only as a fallback.
7. **Firestore Stage B** — not before 2026-12-02 and ≥90% of active users on 1.2.0+.
8. **Governing law** for the terms page (country/jurisdiction).
9. **Deploy approval** for the backend commits (landing fixes, subscription terms, support email migration, Anthropic route switched off by default).

## Work plan

### A. Core product (after design approval)
- Wire `lib/domain` into bill creation, participant view and guest web; store shares in minor units; fix the 9 split-logic bugs found (rounding, lost money for unknown assignees, over-assignment, charges vanishing at zero subtotal, quantity assignments lost on save, `split_method`/`splitMethod`, breakdown mismatch, manual overrides changing totals, negative shares).
- Display amounts with each currency's real decimals (today everything shows 1 decimal).
- **Ledgers** (trips, flats, groups): running balances across bills, settle-up screen with fewest transfers, record payments with proof.
- Split methods in the UI: by item, equal, exact, percentages, shares.
- Home redesign around balances; paged bill history (totals come from ledgers, so paging no longer breaks them).
- Personalized guest links ("Hi Mona, your share is…") with name picker fallback.
- Multi-currency ledgers with daily FX from a cached backend endpoint (Pro).
- Recurring bills (rent, utilities), CSV/PDF export (Pro).
- iOS/Android quick actions ("Scan receipt"), home-screen balance widget (stretch).

### B. Experience, motion, quality
- Motion system: count-up balances, chip hop on assign, settle roll-to-zero with haptic, hero transitions, skeleton loaders; Reduce Motion respected.
- Flow tests (`integration_test`): onboarding → scan → assign → share → guest pays → settle.
- Accessibility: semantics labels, dynamic type, contrast in both themes, RTL (ar, ur).
- Sign-in audit: cold-start time, Apple/Google/email latency, phone step made optional (asked only for contact matching), App Check on Firestore and backend.
- Performance: image compression, Firestore reads per screen, lazy lists, web bundle size for the guest page.
- Store compliance pass: account deletion in app, subscription disclosure on paywall, privacy labels, data safety form, AI disclosure.

### C. Reminders and FCM
- Smart nudges: one reminder per open balance per week max, at a sensible local time (Fri 7 pm default), quiet hours, per-friend mute.
- Scheduled: recurring-bill due dates, "trip ended, settle up?" 24 h after the last expense in a ledger, monthly summary.
- Re-engagement for inactive users (Celery campaign already exists in the backend; move targeting and caps server-side).
- Notification preferences screen; all copy localized.

### D. Admin and analytics (admins only)
- Backend: log every AI call (feature, provider, model, tokens, cost, latency, outcome) — the Anthropic route already logs tokens; add the same for OpenAI.
- Admin dashboard (web, staff-only Django admin views, plus the existing in-app admin screens): DAU/MAU, new users, bills created, scans, voice commands, guest-link opens and payments, conversion to Pro, AI cost per day and per feature, cost per active user, top error reasons.
- Firebase Analytics funnel events + Crashlytics in the app.

### E. Localization (target 22 locales: app, guest web, landing)
- Add 7 locales (see decision 5), translated in context, reviewed for tone; RTL checks.
- Fill missing keys across the existing 15; remove the `hr` store folder (English copy).
- Currencies: full ISO 4217 list with correct decimals and symbols; local formatting via `intl`.

### F. Stores (ASO and promotion)
- Titles, subtitles, keywords and descriptions per locale (research per market, not literal translation), prioritising high-paying markets: US, UK, CA, AU, DE, NL, SE, NO, DK, CH, AE, SA, KW, QA, JP, KR.
- Localized screenshots from the simulator with a demo account (integration-test screenshot driver), App Store preview video.
- Apple: in-app events (e.g. "Ramadan iftar splitting", "Summer trips"), custom product pages per audience (trips, roommates, dinners), product page optimization A/B tests, promotional and win-back offers, introductory offer on yearly.
- Google Play: store listing experiments, custom store listings per country, promotional content (LiveOps), Play Points eligibility, pre-registration not needed.
- In-app review prompt after a successful settle-up.

### G. Landing page, SEO and GEO (after name)
- Rebuild on the new brand; localized pages with hreflang for all 22 locales.
- Schema: SoftwareApplication with real offers, FAQPage, Organization; 1200×630 OG image.
- Comparison and alternatives pages (vs Splitwise, vs Tricount, Settle Up alternatives), use-case pages (trips, roommates, dinners).
- llms.txt, citable answers ("how to split a bill with receipt scanning"), Smart App Banner, store badges, performance (srcset, font preload).
- Render the DB-driven features/FAQs/hero (currently ignored by templates) or remove them.
- Replace duplicated screenshots with the new localized set.

## Security and backend notes
- Stage B Firestore rules after adoption threshold.
- Remove the legacy FCM token path in `notifications/send` after Stage B.
- RevenueCat webhook HMAC secret to be set in production.
- Privacy policy update before any AI provider change (voice audio, RevenueCat, ads SDK, providers list).
