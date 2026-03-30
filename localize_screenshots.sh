#!/bin/bash
set -e

LOCALES=("en-US" "ar" "de" "es" "fr" "hi" "id" "it" "ja" "ko" "pl" "pt" "ru" "ur" "zh")

echo "Starting Screenshot Automation..."

# Prepare standard Fastlane screenshot directories
for LOC in "${LOCALES[@]}"; do
  mkdir -p "fastlane/metadata/android/$LOC/images/phoneScreenshots"
  mkdir -p "fastlane/screenshots/$LOC"
done

# Run the Flutter integration test loop
for LOC in "${LOCALES[@]}"; do
  echo "======================================"
  echo "Capturing Screenshots for Locale: $LOC"
  echo "======================================"
  
  # Ensure the screenshots dir is clear before each run
  rm -rf screenshots/
  mkdir -p screenshots

  # NOTE: To use LOCALE in app, update your main.dart to read:
  # const String forceLocale = String.fromEnvironment('LOCALE', defaultValue: 'en-US');
  # and pass it to MaterialApp(locale: Locale(forceLocale), ...)

  # Run flutter drive to capture screenshots
  # (If taking screenshots on a specific platform, add -d <deviceId>)
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/app_test.dart \
    --dart-define=LOCALE=$LOC

  # Move generated screenshots to the correct fastlane location for Android
  cp screenshots/*.png "fastlane/metadata/android/$LOC/images/phoneScreenshots/" 2>/dev/null || true
  
  # Move generated screenshots to the correct fastlane location for iOS
  cp screenshots/*.png "fastlane/screenshots/$LOC/" 2>/dev/null || true
done

echo "Screenshot generation finished."

# Optional: Trigger Fastlane UI tools to package/format them if needed
# fastlane snapshot # iOS
# fastlane screengrab # Android

echo "Automation loop complete!"
