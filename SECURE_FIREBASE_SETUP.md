# Secure Firebase Setup

This repository does not track Firebase client configuration files anymore.

## Local Native Files

Place these files locally before running native builds:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`

These files are intentionally ignored by git.

## Web / Windows

Web and Windows can be configured with dart-defines instead of committed config.

Example web run:

```bash
flutter run -d chrome \
  --dart-define=FIREBASE_WEB_API_KEY=... \
  --dart-define=FIREBASE_WEB_APP_ID=... \
  --dart-define=FIREBASE_WEB_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_WEB_PROJECT_ID=... \
  --dart-define=FIREBASE_WEB_AUTH_DOMAIN=... \
  --dart-define=FIREBASE_WEB_STORAGE_BUCKET=... \
  --dart-define=FIREBASE_WEB_MEASUREMENT_ID=...
```

## Why

This keeps Google API keys and generated Firebase config files out of the public git history while still allowing local development.
