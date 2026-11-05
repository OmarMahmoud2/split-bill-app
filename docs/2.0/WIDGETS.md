# Home-screen widgets (2.0)

Split Bill ships three home-screen widgets on iOS and Android, plus a Lock
Screen widget on iOS. They are built with
[`home_widget`](https://pub.dev/packages/home_widget) 0.10.0: native UI
(SwiftUI/WidgetKit, Android RemoteViews XML), data pushed from Flutter.

| Widget | Size | Shows | Tap |
| --- | --- | --- | --- |
| Balance | small (2x2) | "You're owed" / "You owe" / "All settled up", signed net amount in teal (+) or amber (−), people count, update time | opens the app (home) |
| Quick scan | small (2x2), teal | "Scan a receipt" | opens the receipt scanner |
| Settle with | medium (4x2) | top 3 people by absolute net, signed amounts | each row opens the largest open bill with that person; elsewhere opens home |
| Net balance (iOS only) | Lock Screen `accessoryRectangular` + `accessoryInline` | label + amount + update time | opens the app |

Signed out (or an anonymous guest session): balance widgets show
"Sign in to see balances". Before the app has ever synced (fresh install):
"Open Split Bill to see your balances".

Design source: `design/project/v3/Extras.dc.html` (widgets) and
`System.dc.html` (colors). Light: surface `#FFFFFF`, ink `#111312`, muted
`#5F6360`, teal `#0F766E`, amber `#B45309`. Dark: `#171918`, `#F2F3F1`,
`#A3A8A5`, `#34C5B0`, `#F0B35E`. System font (SF Pro / Roboto) with tabular
digits.

## How data flows

```
Firestore bills (participants_uids contains me)
        │  same query as HomeScreen
        ▼
HomeWidgetService (lib/services/home_widget_service.dart)
        │  computeWidgetBalances + buildWidgetPayload
        │  (lib/services/home_widget_data.dart, pure Dart, unit tested)
        ▼
HomeWidget.saveWidgetData('sb_widget_payload', <JSON>)
HomeWidget.updateWidget(...) for every iOS kind / Android provider
        │
        ├── iOS: App Group UserDefaults (group.com.example.splitBillApp.widgets)
        │        → SplitBillHomeWidget extension (Widget.swift decodes, Widgets.swift renders)
        └── Android: HomeWidgetPreferences SharedPreferences
                 → BalanceWidgetProvider / ScanWidgetProvider / SettleWidgetProvider
```

- **Balances** use exactly the rules of `HomeScreen._calculateTotals`
  (host: every other PENDING/REVIEW share is owed to me; participant: my own
  PENDING/REVIEW share is owed to the host), so the widget and the home header
  agree. Shares are summed as integer minor units of the user's display
  currency (`AppSettingsProvider.currencyCode`) with
  `lib/domain/money.dart` (`currencyDecimals`: JPY 0, KWD 3, others 2).
- **Counterparts**: per person, net = what they owe me − what I owe them,
  across all open bills; zero nets are dropped; sorted by absolute amount.
  Each keeps the bill with the largest open share for the row's deep link.
- **Formatting** happens in Dart: the balance uses the short currency symbol
  when it is a real symbol (`+$62.40`, `−¥1,200`) and the ISO code otherwise
  (`+KWD 1.235`); rows show the signed number without symbol, as in the
  design. Negative amounts use a real minus sign (U+2212). Amounts are wrapped
  in a Unicode LTR isolate so they keep their shape in Arabic/Urdu.
- **Localization**: labels are the `widget_*` keys in `assets/translations`
  (all 22 locales), resolved with the app's in-app language and sent in the
  payload, so the widget always matches the app language even when it
  differs from the device language. The payload also carries `dir`
  (`rtl` for ar/ur) and `locale`; iOS applies `layoutDirection`/`locale`,
  Android calls `setLayoutDirection` on the root view. Gallery names and
  descriptions (and the "Open Split Bill" fallback) are native: an
  `ios/SplitBillHomeWidget/Localizable.xcstrings` String Catalog and
  `android/app/src/main/res/values*/widget_strings.xml`, both with all 22
  languages, because they are shown before the app has run.
- **When it updates**: on app start (first build of `MyApp`), on every
  Firestore snapshot of the bills query while the app is alive (create,
  edit, pay, settle), on resume, on sign-in/sign-out, and when the app
  language or display currency changes. Identical payloads are skipped.
  Widgets do not poll: iOS timelines use `.never`, Android
  `updatePeriodMillis="0"`. A change made on another device shows up the
  next time this app runs or resumes.

### Payload (v1)

```json
{
  "v": 1, "state": "ready" | "signedOut", "locale": "en", "dir": "ltr" | "rtl",
  "strings": {"youAreOwed": "...", "youOwe": "...", "allSettled": "...",
              "updatedAt": "Updated 14:32", "scan": "...", "settleWith": "...",
              "noBalances": "...", "signIn": "...", "hide": "...", "show": "..."},
  "scanUrl": "splitbill://widget/scan?homeWidget",
  "homeUrl": "splitbill://widget/home?homeWidget",
  "balance": {"label": "You're owed", "amount": "+$62.40", "sign": 1,
              "value": 62.4, "count": 3, "currency": "USD"},
  "people": [{"id": "uid", "name": "Sara", "amount": "+54.10", "sign": 1,
              "url": "splitbill://widget/friend?id=uid&billId=b1&homeWidget"}]
}
```

Natives ignore payloads with a higher `v`; bump it on breaking changes.

### Widget tap routing

All tap targets are `splitbill://widget/<route>?...&homeWidget` URIs (the
`homeWidget` query item is how home_widget's iOS plugin recognizes widget
launches; the `splitbill` scheme is already registered in
`ios/Runner/Info.plist`). Android uses `HomeWidgetLaunchIntent` (action
`es.antonborri.home_widget.action.LAUNCH`, explicit `MainActivity`).

In `lib/main.dart` the URIs arrive through `HomeWidget.widgetClicked`
(warm), `HomeWidget.initiallyLaunchedFromHomeWidget()` (cold) and, on iOS,
possibly also `app_links` — `WidgetRoute.tryParse` claims them in
`_handleDeepLink` and `WidgetLaunchDeduper` drops the duplicate.

| URI | Action |
| --- | --- |
| `/home`, `/balance`, unknown | pop to the root (home) |
| `/scan` | pop to root, push `ScanReceiptScreen` (signed-in members only; otherwise the sign-in screen stays) |
| `/friend?id=&billId=` | open that bill through the existing `_handleBillNavigation` (host → `BillDetailsScreen`, participant → `ParticipantBillScreen`, where settling happens). Without `billId` → home. |

There is no per-friend screen in the app yet; when one lands, route
`WidgetRouteKind.friend` to it in `_MyAppState._handleWidgetUri` (the URI
already carries the friend id).

## iOS

Target `SplitBillHomeWidget` (WidgetKit app extension, SwiftUI), created
with the official `home_widget_cli create` scaffold (which patches
`Runner.xcodeproj`: target, `Embed Foundation Extensions` phase in Runner,
target dependency, Thin Binary moved last, `ios/Flutter/HomeWidget.xcconfig`
so the extension's version follows `FLUTTER_BUILD_NAME/NUMBER`).

- Bundle id `com.example.splitBillApp.SplitBillHomeWidget`, team
  `U2PUCCM72U`, automatic signing, deployment target **iOS 17.0** (the app
  stays at 15.0; on iOS 15/16 the widgets are simply not offered).
- Files: `ios/SplitBillHomeWidget/{Widget.swift, Widgets.swift,
  WidgetBundle.swift, Localizable.xcstrings, Info.plist}`,
  `ios/SplitBillHomeWidget.entitlements`.
- Kinds (must match `HomeWidgetService.iOSKinds`): `SplitBillBalanceWidget`,
  `SplitBillScanWidget`, `SplitBillSettleWidget`, `SplitBillBalanceAccessory`.
- Dark mode: dynamic `UIColor`s from the palette; containerBackground per
  widget (iOS 17 API). Tinted/clear home screens on iOS 18+ get the system
  treatment.
- **Animation**: WidgetKit cannot run `withAnimation` from the extension —
  there is no imperative state change, only timeline entries. What iOS 17
  offers, and what is used: `.contentTransition(.numericText(value:))` on the
  balance (digits roll up/down when Flutter pushes a new value), on row
  amounts and the people count; `.transition(.push(from: .bottom))` on
  settle rows; implicit `.animation(.smooth, value:)` so those transitions
  play when the next timeline entry arrives; `.symbolEffect(.replace)` on the
  eye icon.
- **AppIntent**: the Balance widget has an eye button
  (`Button(intent: ToggleAmountsIntent())`, iOS 17 interactive widget) that
  hides/shows amounts (`••••`) for privacy, entirely inside the extension
  (flag `sb_hide_amounts` in the App Group; also respected by Settle with and
  the Lock Screen widget). Navigation taps stay `widgetURL`/`Link`, because
  opening the app at a route is what those are for.
- Lock Screen: `accessoryRectangular` (label, amount, time) and
  `accessoryInline`; `.widgetAccentable()` on the label.

### App Group — manual step for the owner

Both `Runner.entitlements` and `SplitBillHomeWidget.entitlements` contain
`com.apple.security.application-groups = group.com.example.splitBillApp.widgets`.

1. In the Apple Developer portal → Certificates, IDs & Profiles →
   Identifiers → **App Groups**, register
   `group.com.example.splitBillApp.widgets` (a paid account is required).
2. Enable the App Groups capability on the App ID `com.example.splitBillApp`
   and assign the group; register the new App ID
   `com.example.splitBillApp.SplitBillHomeWidget` with the same group.
   With automatic signing, opening the project in Xcode (or
   `xcodebuild -allowProvisioningUpdates`) can create the extension App ID,
   add the group and regenerate profiles for you; verify in the portal.
3. Regenerate/download the distribution provisioning profiles for both IDs
   (fastlane match / App Store Connect) before the next TestFlight build —
   the existing Runner profile does not include the App Group.

Simulator builds do not need any of this (`flutter build ios --simulator`
signs ad hoc and the App Group container works on the simulator).
Device and archive builds fail with a provisioning error until steps 1–3
are done.

## Android

RemoteViews XML widgets (not Glance: no Compose build setup needed, and
`values-night` resources give dark mode for free).

- Providers (`android/app/src/main/kotlin/net/omarmali/splitapp/widgets/`):
  `BalanceWidgetProvider`, `ScanWidgetProvider`, `SettleWidgetProvider`
  (extend `HomeWidgetProvider`), `WidgetPayload.kt` (JSON parsing, launch
  intents, color helpers). Updated by `HomeWidget.updateWidget(qualifiedAndroidName: ...)`.
- Layouts `res/layout/widget_{balance,scan,settle}.xml`; provider info
  `res/xml/widget_*_info.xml` (target cells 2x2 / 2x2 / 4x2, resizable
  horizontally and vertically within min/max sizes, description,
  `previewLayout` on Android 12+ — the layouts' default texts are a sample
  preview — and the launcher icon as `previewImage` on older versions).
- Rounded backgrounds: shape drawables with `@dimen/widget_corner_radius`
  (24dp; `system_app_widget_background_radius` on Android 12+), root view
  `@id/widget_root` with `clipToOutline`.
- Colors: `res/values/widget_colors.xml` and `res/values-night/widget_colors.xml`.
  Sign colors are applied with `RemoteViews.setColor(..., resId)` on Android
  12+, so the launcher resolves them for the current light/dark mode;
  Android 8–11 bakes the color at update time (correct after the next update).
- RTL: `android:supportsRtl="true"` added to the application (needed for
  any layout mirroring; Flutter UI is unaffected), and the payload direction
  is applied with `setLayoutDirection`.
- **Animation (honest)**: RemoteViews cannot animate arbitrary property
  changes. The Balance amount sits in a `ViewFlipper` with
  `fade_in`/`fade_out`; a new value is written into the hidden child and the
  flipper switches to it, giving a short cross-fade when the launcher
  reapplies the RemoteViews to the existing view (the common case). If the
  launcher re-inflates (restart, resize, some OEM launchers) the new value
  appears without the fade. Settle rows update without animation.
- No privacy toggle on Android (kept minimal).

## Limitations

- Totals assume one currency (the user's display currency), exactly like the
  home header today; bills carry no currency field yet.
- No background refresh: changes made elsewhere (another device, a friend
  paying) appear when this app next starts/resumes. A later step could push
  updates from FCM data messages via `HomeWidget.registerBackgroundCallback`
  or iOS background push.
- The app's in-app theme setting (light/dark/system) is not applied to
  widgets; they follow the system appearance, as widgets do.
- "Settle with" opens the largest open bill with that person, because there
  is no friend/settle screen yet.
- The update time is formatted 24h (`DateFormat.Hm`) in the app locale.
- iOS widgets require iOS 17+.

## Testing

- `flutter test test/services/home_widget_data_test.dart` — balances
  (host/participant, netting, top 3, hostName fallback, minor units for
  JPY/KWD, malformed docs), formatting (signs, decimals, locales, LTR
  isolate), payload (signed-out, ready, settled), URI routing, dedupe.
- Native logic is display-only on purpose; there is no Swift/Kotlin unit
  test target.
- Manual: add each widget, sign in/out, create/pay a bill, switch app
  language to Arabic (RTL) and back, toggle dark mode, tap scan / a row /
  the eye button.
- SwiftUI `#Preview`s for Balance and Settle are in `Widgets.swift`.
