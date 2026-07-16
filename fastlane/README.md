fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios build_ipa

```sh
[bundle exec] fastlane ios build_ipa
```

Build the obfuscated iOS IPA for the current pubspec version

### ios upload_metadata

```sh
[bundle exec] fastlane ios upload_metadata
```

Push iOS localized metadata and What's New text to App Store Connect

### ios release

```sh
[bundle exec] fastlane ios release
```

Build, upload, and submit the iOS app version for App Store review

----


## Android

### android build_aab

```sh
[bundle exec] fastlane android build_aab
```

Build the obfuscated Android App Bundle for the current pubspec version

### android upload_metadata

```sh
[bundle exec] fastlane android upload_metadata
```

Push Android localized metadata to Google Play Console

### android release

```sh
[bundle exec] fastlane android release
```

Build, upload, and submit the Android app bundle to Google Play

### android deploy

```sh
[bundle exec] fastlane android deploy
```

Alias for android release

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
