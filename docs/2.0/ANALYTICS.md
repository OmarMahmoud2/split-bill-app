# Analytics (Firebase Analytics)

Package: `firebase_analytics 12.6.1` (with `firebase_core 4.15.2`). Wrapper: `lib/services/analytics_service.dart`.

## Privacy choices

- No user id: `setUserId` is never called (a test scans `lib/` for it). Events are tied only to Firebase's random app-instance id.
- No PII in any event or property: no names, emails, phones, bill titles, exact amounts, uids, guest ids, bill/group ids or free text. The wrapper drops these keys (`AnalyticsService.forbiddenKeys`) and tests assert it.
- Numbers are bucketed (items 1-5/6-10/11+, people 2/3-4/5+, payments 1/2-3/4-6/7+).
- Consent: `analytics_storage` granted; `ad_storage`, `ad_user_data`, `ad_personalization` denied (set at runtime and as native defaults in Info.plist and AndroidManifest).
- No advertising ID: `GOOGLE_ANALYTICS_ADID_COLLECTION_ENABLED=false` (iOS) and `google_analytics_adid_collection_enabled=false` (Android). The IDFV is not disabled; it is the vendor id, not the IDFA, and is what the iOS SDK uses for the app-instance id. No AdSupport linkage is added by this change.
- Collection is on in release builds only (off in debug and tests). On web it is on only when a GA measurement id is configured (`FIREBASE_WEB_MEASUREMENT_ID` / `_webMeasurementId`); with an empty id it is a no-op.
- No automatic screen tracking and no NavigatorObserver. Manual `screen_view` for the four main tabs only.
- Firebase's automatic events (first_open, session_start, app_update, etc.) remain on.
- Not covered here: Google Mobile Ads (rewarded ads) and the ATT prompt are separate and keep their own behaviour.

## Events

| Event | Params | Fires |
|---|---|---|
| `onboarding_complete` | none | `new_onboarding_screen.dart` `_complete` |
| `sign_up` / `login` | `method`: google, apple, email, anonymous_guest | `auth_service.dart` after sign-in (new user vs returning, from `isNewUser`); `guest_session.dart` for guests (`sign_up`, anonymous_guest) |
| `receipt_scan` | `result`: success, fail, no_points | `scan_receipt_screen.dart` (pre-check, scan result) |
| `voice_assign` | `result`: success, fail | `split_bill_screen.dart` after the voice result is parsed (cancel logs nothing) |
| `bill_created` | `source`: scan, manual; `items_bucket`; `people_bucket`; `split_method`: items, equal, exact, percent, shares | `bill_summary_confirm_screen.dart` after the bill is saved or queued |
| `bill_shared` | `channel`: link (copy or app deep link), system_share (OS share sheet) | `bill_share_screen.dart`, `bill_details_screen.dart` |
| `guest_link_opened` | none | `guest_bill_screen.dart` initState (web guest) |
| `guest_payment_submitted` | `with_proof`: true/false | `guest_bill_screen.dart` after submit succeeds |
| `payment_marked_paid` | `by`: host, member | `bill_details_screen.dart` (host marks paid), `participant_bill_screen.dart` (member marks own) |
| `proof_rejected` | none | `bill_details_screen.dart` |
| `settle_up_done` | `payments_bucket` | `settle_actions.dart` after a payment is recorded |
| `group_created` | none | `create_group_screen.dart` |
| `recurring_created` | none | `recurring_bill_screen.dart` |
| `export` | `format`: pdf, csv | `export_screen.dart` after the share sheet completes |
| `paywall_view` | `placement`: profile, subscription, export, recurring, no_points, group_currencies, unknown | `premium_modal.dart` initState |
| `purchase_started` | `plan`: monthly, yearly, lifetime | `premium_modal.dart` |
| `purchase_success` | `plan`, `is_trial` | `premium_modal.dart` when the entitlement is active |
| `purchase_restored` | none | `premium_modal.dart`, `subscription_screen.dart` (only when Pro is restored) |
| `rewarded_ad_completed` | none | `rewarded_ad_helper.dart` on reward |
| `notification_opened` | `type`: bill | `main.dart` push tap that opens a bill |
| `reminder_opened` | `type`: engagement | `main.dart` push tap that opens the notifications screen |
| `widget_opened` | none | `main.dart` home-screen widget tap |
| `screen_view` | `screen_name`: home, groups, activity, you | `home_screen.dart` |

Booleans are sent as the strings "true"/"false".

## User properties

`app_locale` (language code), `theme_mode` (system/light/dark), `is_pro` (true/false). Updated when they change (settings provider, RevenueCat customer-info listener).

## Setup the owner must do

- iOS: `ios/Runner/GoogleService-Info.plist` currently has `IS_ANALYTICS_ENABLED = false` (it is gitignored). Enable Google Analytics for the Firebase project, re-download the plist, and confirm it is `true`; otherwise iOS sends nothing.
- Android: `android/app/google-services.json` has no `analytics_service` entry; re-download it after enabling Analytics.
- iOS: run `pod install` (new pod FirebaseAnalytics) before the next native build.
- Web: set the measurement id dart-define to enable web analytics.

## Store disclosures this implies

App Store privacy labels (not used for tracking, not linked to identity unless noted):
- Usage Data: Product Interaction (analytics), linked to identity: No, tracking: No.
- Diagnostics: only if Crashlytics or Sentry already declared; not added by this change.
- Identifiers: Device ID is not collected for tracking. Firebase uses a per-install app-instance id plus IDFV; declare Device ID (analytics, not linked, no tracking) to be conservative.
- No Advertising Data, no IDFA by Firebase. (AdMob rewarded ads are declared separately, as before.)

Play Data safety:
- Data collected: App activity (app interactions) and Device or other IDs (app-instance id). Purpose: Analytics. Shared with third parties: No (Google acts as service provider). Collection optional: No. Processed ephemerally: No. Data encrypted in transit: Yes.
- Advertising ID is not collected by Analytics.
