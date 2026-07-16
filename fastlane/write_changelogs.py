import os

RELEASE_NOTES = "UI Improvements and Bug Fixes"

# Android Changelogs (Requires a folder called changelogs with the version code .txt inside)
# versionCode from pubspec is 13
VERSION_CODE = "13"
android_path = "fastlane/metadata/android"

if os.path.exists(android_path):
    for locale in os.listdir(android_path):
        changelog_dir = os.path.join(android_path, locale, "changelogs")
        os.makedirs(changelog_dir, exist_ok=True)
        changelog_path = os.path.join(changelog_dir, f"{VERSION_CODE}.txt")
        with open(changelog_path, 'w', encoding='utf-8') as f:
            f.write(RELEASE_NOTES)

# iOS Release Notes (Requires a file called release_notes.txt directly in the locale folder)
ios_path = "fastlane/metadata"
if os.path.exists(ios_path):
    for locale in os.listdir(ios_path):
        if locale == 'android':
            continue
        release_notes_path = os.path.join(ios_path, locale, "release_notes.txt")
        with open(release_notes_path, 'w', encoding='utf-8') as f:
            f.write(RELEASE_NOTES)
