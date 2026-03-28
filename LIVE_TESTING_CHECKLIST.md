# Split Bill Live Testing Checklist

## Current Status

- Flutter app repo: `OmarMahmoud2/split-bill-app`
- Backend repo: `OmarMahmoud2/omarmali-net`
- Live backend base URL: `https://omarmali.net`
- Guest web base URL: `https://splitbillapp-ffc39.web.app`

## Important Notes

- The new `split_bill` backend is API-only right now.
- Because it has no Django models and no admin registrations, it does **not** create a visible new section in `omarmali.net/admin/`.
- This is expected and does **not** mean the backend failed.

## What Was Verified

### App

- `dart analyze` passes
- `flutter test` passes
- `flutter build web --release` passes

### Local Backend

- `manage.py check` passes
- `manage.py test split_bill` passes

### Live Backend

- `gunicorn2.service` is active
- `nginx.service` is active
- `https://omarmali.net/api/split-bill/health/` returns OK
- `https://omarmali.net/api/split-bill/config/` returns the expected split-bill config
- protected endpoints reject missing auth in production

## Run The App On The iOS Simulator

Booted simulator used during verification:

- `iPhone 17 Pro Max`
- UDID: `F5282ACF-EF0C-48F8-A66A-31E8C51C45D9`

Run the app against the live backend with:

```bash
cd /Users/omarmahmoud/FlutterProjects/VsCodePros/split_bill_app
flutter run -d F5282ACF-EF0C-48F8-A66A-31E8C51C45D9 --dart-define=SPLIT_BILL_API_BASE_URL=https://omarmali.net
```

### Why This Command Matters

- In debug mode, the app defaults to localhost unless you pass `SPLIT_BILL_API_BASE_URL`.
- For live testing from the simulator, you should always pass:

```bash
--dart-define=SPLIT_BILL_API_BASE_URL=https://omarmali.net
```

## Add A Receipt Image To The Simulator

You can drag an image file directly into the Simulator window, or run:

```bash
xcrun simctl addmedia F5282ACF-EF0C-48F8-A66A-31E8C51C45D9 /absolute/path/to/receipt.jpg
```

Then pick it from Photos inside the app.

## Full Test Flow

### 1. Login

Action:

- Open the app
- Sign in with Firebase using your normal login path

Expected:

- Login succeeds
- Home screen loads normally
- No backend auth error appears
- Profile data loads

### 2. App-Wide Settings

Action:

- Open profile/settings
- Change theme
- Change locale
- Change currency
- Close and reopen the app

Expected:

- Theme applies across screens
- Locale changes visible text
- Currency formatting updates across bills and summaries
- Settings persist after reopening because they are stored in Firestore

### 3. Manual Bill Entry

Action:

- Create a bill manually
- Add participants
- Add items and charges
- Save and continue

Expected:

- No crash
- Totals calculate correctly
- Delivery splits equally
- VAT/service/tax split proportionally by share

### 4. Receipt Scan

Action:

- Open scan receipt
- Choose a receipt image from Photos
- Wait for backend extraction

Expected:

- Scan request goes to `omarmali.net`
- A parsed receipt appears
- Items are editable
- Item name, quantity, and price can be changed
- You can add or delete items
- Extra charges appear separately when detected

### 5. Editable Review

Action:

- Edit at least one item name
- Edit one quantity
- Edit one price
- Add one item
- Delete one item
- Continue

Expected:

- All edits persist into the next split step
- Totals update correctly
- No duplicate or frozen state appears

### 6. Voice Assignment

Action:

- Make sure participants already exist
- Open the voice assignment flow
- Choose the language you will speak
- Record a simple command like:

`Split the burger between Omar and Sarah`

Expected:

- Microphone permission prompt appears if needed
- Transcript returns from backend
- Assignment result returns from backend
- The item assignment UI updates correctly

### 7. Bill Creation And Detail Screens

Action:

- Finish the bill
- Open it as host
- Open it as participant if possible

Expected:

- Host sees the full bill and all members
- Participant sees only their share context
- Totals and charge distribution are consistent

### 8. Notification Flow

Best tested with at least one real iPhone.

Action:

- Create/send a bill to another signed-in user who has a real device token

Expected:

- Notification history is saved in Firestore
- Push notification is sent through `omarmali.net`
- Tapping the notification opens the correct bill

### 9. Guest Link Flow

Action:

- Share a bill link from the app
- Open it outside the app

Expected:

- Link opens the hosted guest web portal
- Bill loads correctly
- Query-based share links work without needing a fresh Firebase Hosting deploy

## Simulator Limitations

- Camera testing is limited on simulator, so prefer imported receipt images
- Push notifications are not the best simulator test; use a real iPhone for final push verification
- RevenueCat purchase testing may need proper StoreKit/App Store sandbox setup beyond normal simulator flow

## Quick Pass Criteria

You can consider this live-testing pass successful if:

- login works
- theme/locale/currency persist
- manual bill flow works
- receipt scan returns editable data
- voice assignment works
- bill creation works
- guest link opens correctly
- notification history works
- real-device push works

## If Something Fails

Check these first:

- Did you run the app with `--dart-define=SPLIT_BILL_API_BASE_URL=https://omarmali.net`?
- Are you signed in before testing scan, voice, or notifications?
- Is the receipt image clear and readable?
- Are you testing push on a real device with a real `fcmToken`?

