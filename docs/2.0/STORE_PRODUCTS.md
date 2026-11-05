# Store products (Evens Pro)

Entitlement in RevenueCat: `premium`. Default offering packages: `$rc_monthly`, `$rc_annual`, `$rc_lifetime`.

| Plan | App Store product | Play product | Price (USD) | Regional price* |
|---|---|---|---|---|
| Monthly | `split_monthly` (group "Split Monthly") | `split_monthly:splitmonthly` | $2.99 (App Store from 7 Nov 2026; existing subscribers keep $0.99) | about $0.99 |
| Yearly | `split_yearly` (same group), 7-day free trial | `split_yearly:yearly`, offer `free-trial-7d` (new customers) | $24.99 | about $7.99 (Play done; App Store after first approval) |
| Lifetime | `com.splitbill.premium_lifetime` (non-consumable) | `com.splitbill.premium_lifetime` | $59.99 | about $19.99 |

\* Regional markets: Egypt, India, Brazil, Pakistan, Indonesia, Philippines, Vietnam, Nigeria, Türkiye, Kenya, Morocco, Sri Lanka, Ghana, Colombia, and Bangladesh (Play only; not on the App Store). Set in USD so each store converts to a rounded local price, e.g. Egypt E£49.99 / EGP 60.99 a month.

## Cancellation
- App Store retention message "Evens Pro cancel save" (Monthly and Yearly, no offer attached), image `docs/2.0/store/evens_retention_3840x2160.png`. Status: ready for review, goes with the 2.0 submission.
- Google Play: no cancellation-message setting in this account's console yet (Google announced cancel-flow offers at I/O 2026). Alternative: RevenueCat Customer Center in-app with a Play developer-determined offer (needs app code).

## To do at the 2.0 submission
1. Yearly (`split_yearly`): add the review screenshot `docs/2.0/store/paywall_yearly_1290x2796.png` and submit it with the 2.0 build.
2. After Apple approves Yearly: plan a price change for the 14 regional countries to the $7.99 tier.
3. Submit the retention message with the build (it is in the draft submission).
