# Store Release Commands

Current app version is read from `pubspec.yaml`: `1.1.5+13`.

All Android changelogs and iOS What's New text are:

```text
UI Improvements and Bug Fixes
```

## Android

Required environment:

```sh
export SUPPLY_JSON_KEY="/absolute/path/to/google-play-service-account.json"
```

Build only:

```sh
fastlane android build_aab
```

Build, upload the AAB, upload metadata/changelog, and commit the Play Console edit:

```sh
fastlane android release
```

If the AAB is already built:

```sh
fastlane android release skip_build:true
```

Optional overrides:

```sh
ANDROID_TRACK=production ANDROID_RELEASE_STATUS=completed fastlane android release
ANDROID_PACKAGE_NAME=net.omarmali.splitapp fastlane android release
```

The AAB is built with:

```sh
flutter build aab --release --obfuscate --split-debug-info=build/symbols/1.1.5+13 --build-name=1.1.5 --build-number=13
```

## iOS

Required environment:

```sh
export APP_STORE_CONNECT_API_KEY_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_KEY_FILEPATH="/absolute/path/to/AuthKey_KEYID.p8"
```

Build only:

```sh
fastlane ios build_ipa
```

Build, upload the IPA, upload metadata/What's New, and submit for App Store review:

```sh
fastlane ios release
```

If the IPA is already built:

```sh
fastlane ios release skip_build:true
```

Optional overrides:

```sh
APP_IDENTIFIER=com.example.splitBillApp fastlane ios release
FASTLANE_APPLE_ID=omarmali306@gmail.com fastlane ios release
IOS_AUTOMATIC_RELEASE=true fastlane ios release
```

The IPA is built with:

```sh
flutter build ipa --release --obfuscate --split-debug-info=build/symbols/1.1.5+13 --build-name=1.1.5 --build-number=13
```

## Notes

- Keep the App Store Connect `.p8` key and Google Play service account JSON out of git.
- If Google Play managed publishing is enabled, Play Console may still require pressing the final publish/review button after Fastlane commits the edit.
- Confirm the App Store Connect bundle ID matches `fastlane/Appfile` and `ios/Runner.xcodeproj` before upload.
