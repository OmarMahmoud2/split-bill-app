# Store Release Commands

Current app version is read from `pubspec.yaml`: `1.1.9+22`.

Build 22 fixes the iOS contacts plugin crash during launch. The iOS review notes
describe this fix. Fastlane checks the IPA version, build number, and bundle ID
before upload, including when `skip_build:true` is used. Build 22 restores the
animated auth background, floating logo, and welcome animation while retaining
the official Google and Apple sign-in buttons.

Android changelogs retain these release notes. iOS What's New also includes the
launch crash fix:

```text
Redesigned onboarding for scanning, voice assignment, and currencies.
Improved currency picker and official Google and Apple sign-in buttons.
Android now uses the system Contact Picker instead of contacts permission.
Stability improvements and polish.
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
flutter build aab --release --obfuscate --split-debug-info=build/symbols/1.1.9+22 --build-name=1.1.9 --build-number=22
```

## iOS

Required environment:

```sh
export APP_STORE_CONNECT_API_KEY_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_KEY_FILEPATH="/absolute/path/to/AuthKey_KEYID.p8"
```

Build only (native compilation defaults to two jobs; override with `IOS_BUILD_JOBS`):

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

If the build already uploaded to App Store Connect but submit failed on missing
What's New/release notes, patch the metadata and submit the existing uploaded
build without uploading the IPA again. This also resubmits a rejected review
when its sole item is the current app version. Submission waits for Apple to
finish processing the exact version and build number, for up to 15 minutes:

```sh
fastlane ios submit_existing
```

Optional overrides:

```sh
APP_IDENTIFIER=com.example.splitBillApp fastlane ios release
FASTLANE_APPLE_ID=omarmali306@gmail.com fastlane ios release
IOS_AUTOMATIC_RELEASE=true fastlane ios release
```

Fastlane prepares Flutter release settings with obfuscation and symbols in
`build/symbols/1.1.9+22`, archives with Xcode using two compiler jobs, exports
an App Store IPA, and verifies the version, build number, and bundle identifier.

## Launch regression checklist

Run `flutter run -d <simulator-id>` on the latest iPhone and iPad simulators.

1. Delete the app, install it again, and launch from the Home Screen. Confirm it
   reaches onboarding without closing or leaving a blank screen.
2. Complete onboarding, sign in, close the app, and launch it again several times.
3. Add a simulator contact with a phone number. Create a bill and open the
   contact picker. Check granted, denied, and limited
   contacts access; select a contact and confirm the name and phone number.
4. Cancel the contact picker and reopen it. Check receipt scanning and Premium /
   Restore purchases still open normally.
5. Before resubmission, test the signed release on a physical iPhone through
   TestFlight or Xcode, as requested in Apple's review message. Simulator tests
   do not cover the distributed release build.

## Notes

- Keep the App Store Connect `.p8` key and Google Play service account JSON out of git.
- If Google Play managed publishing is enabled, Play Console may still require pressing the final publish/review button after Fastlane commits the edit.
- Confirm the App Store Connect bundle ID matches `fastlane/Appfile` and `ios/Runner.xcodeproj` before upload.
