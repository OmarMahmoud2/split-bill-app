import os
import re

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUBSPEC_PATH = os.path.join(PROJECT_ROOT, "pubspec.yaml")

version_code = "15"
if os.path.exists(PUBSPEC_PATH):
    with open(PUBSPEC_PATH, "r", encoding="utf-8") as f:
        match = re.search(r"^version:\s*[0-9A-Za-z.\-]+\+(\d+)", f.read(), re.MULTILINE)
        if match:
            version_code = match.group(1)

NOTES_BY_LOCALE = {
    'default': 'Bug fixes and stability improvements.',
    'en': 'Bug fixes and stability improvements.',
    'en-US': 'Bug fixes and stability improvements.',
    'en-GB': 'Bug fixes and stability improvements.',
    'en-AU': 'Bug fixes and stability improvements.',
    'en-CA': 'Bug fixes and stability improvements.',
    'ar': 'إصلاح الأخطاء وتحسين استقرار التطبيق.',
    'ar-SA': 'إصلاح الأخطاء وتحسين استقرار التطبيق.',
    'de': 'Fehlerbehebungen und Stabilitätsverbesserungen.',
    'de-DE': 'Fehlerbehebungen und Stabilitätsverbesserungen.',
    'es': 'Corrección de errores y mejoras de estabilidad.',
    'es-ES': 'Corrección de errores y mejoras de estabilidad.',
    'es-MX': 'Corrección de errores y mejoras de estabilidad.',
    'es-US': 'Corrección de errores y mejoras de estabilidad.',
    'fr': 'Corrections de bugs et améliorations de la stabilité.',
    'fr-FR': 'Corrections de bugs et améliorations de la stabilité.',
    'fr-CA': 'Corrections de bugs et améliorations de la stabilité.',
    'hi': 'बग फिक्स और स्थिरता में सुधार।',
    'hi-IN': 'बग फिक्स और स्थिरता में सुधार।',
    'hr': 'Ispravci programskih pogrešaka i poboljšanja stabilnosti.',
    'id': 'Perbaikan bug dan peningkatan stabilitas.',
    'it': 'Correzioni di bug e miglioramenti della stabilità.',
    'it-IT': 'Correzioni di bug e miglioramenti della stabilità.',
    'ja': 'バグの修正と安定性の向上。',
    'ja-JP': 'バグの修正と安定性の向上。',
    'ko': '버그 수정 및安定性改善.',
    'ko-KR': '버그 수정 및 안정성 개선.',
    'pl': 'Poprawki błędów i ulepszenia stabilności.',
    'pl-PL': 'Poprawki błędów i ulepszenia stabilności.',
    'pt': 'Correções de bugs e melhorias de estabilidade.',
    'pt-BR': 'Correções de bugs e melhorias de estabilidade.',
    'pt-PT': 'Correções de bugs e melhorias de estabilidade.',
    'ru': 'Исправление ошибок и повышение стабильности.',
    'ru-RU': 'Исправление ошибок и повышение стабильности.',
    'ur': 'بگ کی اصلاحات اور استحکام میں بہتری۔',
    'zh-CN': '问题修复和稳定性改进。',
    'zh-Hans': '问题修复和稳定性改进。',
    'zh-TW': '錯誤修復與穩定性改進。',
    'zh-Hant': '錯誤修復與穩定性改進。',
}

# Android Changelogs
android_path = os.path.join(PROJECT_ROOT, "fastlane", "metadata", "android")
if os.path.exists(android_path):
    for locale in os.listdir(android_path):
        loc_dir = os.path.join(android_path, locale)
        if not os.path.isdir(loc_dir):
            continue
        changelog_dir = os.path.join(loc_dir, "changelogs")
        os.makedirs(changelog_dir, exist_ok=True)
        changelog_path = os.path.join(changelog_dir, f"{version_code}.txt")
        note = NOTES_BY_LOCALE.get(locale, NOTES_BY_LOCALE.get(locale.split('-')[0], NOTES_BY_LOCALE['default']))
        with open(changelog_path, 'w', encoding='utf-8') as f:
            f.write(note)

# iOS Release Notes
ios_path = os.path.join(PROJECT_ROOT, "fastlane", "metadata")
if os.path.exists(ios_path):
    for locale in os.listdir(ios_path):
        if locale == 'android':
            continue
        loc_dir = os.path.join(ios_path, locale)
        if not os.path.isdir(loc_dir):
            continue
        release_notes_path = os.path.join(loc_dir, "release_notes.txt")
        note = NOTES_BY_LOCALE.get(locale, NOTES_BY_LOCALE.get(locale.split('-')[0], NOTES_BY_LOCALE['default']))
        with open(release_notes_path, 'w', encoding='utf-8') as f:
            f.write(note)

print(f"Updated all Android & iOS changelogs for version code {version_code}.")
