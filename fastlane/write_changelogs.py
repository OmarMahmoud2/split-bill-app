import os

translations = {
    'en-US': 'Improved flow, Bug Fixes, more languages and currencies added ',
    'en': 'Improved flow, Bug Fixes, more languages and currencies added ',
    'ar-SA': 'تحسين التدفق، إصلاح الأخطاء، إضافة المزيد من اللغات والعملات ',
    'ar': 'تحسين التدفق، إصلاح الأخطاء، إضافة المزيد من اللغات والعملات ',
    'de-DE': 'Verbesserter Ablauf, Fehlerbehebungen, weitere Sprachen und Währungen hinzugefügt ',
    'de': 'Verbesserter Ablauf, Fehlerbehebungen, weitere Sprachen und Währungen hinzugefügt ',
    'es-ES': 'Flujo mejorado, corrección de errores, más idiomas y monedas añadidos ',
    'es': 'Flujo mejorado, corrección de errores, más idiomas y monedas añadidos ',
    'fr-FR': 'Flux amélioré, corrections de bugs, ajout de nouvelles langues et devises ',
    'fr': 'Flux amélioré, corrections de bugs, ajout de nouvelles langues et devises ',
    'hi-IN': 'बेहतर प्रवाह, बग फिक्स, अधिक भाषाएं और मुद्राएं जोड़ी गईं ',
    'hi': 'बेहतर प्रवाह, बग फिक्स, अधिक भाषाएं और मुद्राएं जोड़ी गईं ',
    'id': 'Alur ditingkatkan, perbaikan bug, penambahan lebih banyak bahasa dan mata uang ',
    'it-IT': 'Flusso migliorato, correzioni di bug, aggiunte nuove lingue e valute ',
    'it': 'Flusso migliorato, correzioni di bug, aggiunte nuove lingue e valute ',
    'ja-JP': 'フローの改善、バグ修正、新しい言語と通貨の追加 ',
    'ja': 'フローの改善、バグ修正、新しい言語と通貨の追加 ',
    'ko-KR': '흐름 개선, 버그 수정, 더 많은 언어와 통화 추가 ',
    'ko': '흐름 개선, 버그 수정, 더 많은 언어와 통화 추가 ',
    'pl-PL': 'Ulepszony przepływ, poprawki błędów, dodano więcej języków i walut ',
    'pl': 'Ulepszony przepływ, poprawki błędów, dodano więcej języków i walut ',
    'pt-BR': 'Fluxo melhorado, correções de bugs, mais idiomas e moedas adicionados ',
    'pt': 'Fluxo melhorado, correções de bugs, mais idiomas e moedas adicionados ',
    'ru-RU': 'Улучшенный интерфейс, исправления ошибок, добавлено больше языков и валют ',
    'ru': 'Улучшенный интерфейс, исправления ошибок, добавлено больше языков и валют ',
    'ur': 'بہتر روانی، بگ فکسز، مزید زبانیں اور کرنسیاں شامل کی گئیں ',
    'zh-CN': '改进了流程，修复了错误，添加了更多语言和货币 ',
    'zh-Hans': '改进了流程，修复了错误，添加了更多语言和货币 ',
    'zh': '改进了流程，修复了错误，添加了更多语言和货币 '
}

# Android Changelogs (Requires a folder called changelogs with the version code .txt inside)
# versionCode from pubspec is 8
VERSION_CODE = "8"
android_path = "fastlane/metadata/android"

if os.path.exists(android_path):
    for locale in os.listdir(android_path):
        if locale not in translations:
            continue
        changelog_dir = os.path.join(android_path, locale, "changelogs")
        os.makedirs(changelog_dir, exist_ok=True)
        changelog_path = os.path.join(changelog_dir, f"{VERSION_CODE}.txt")
        with open(changelog_path, 'w', encoding='utf-8') as f:
            f.write(translations[locale])

# iOS Release Notes (Requires a file called release_notes.txt directly in the locale folder)
ios_path = "fastlane/metadata"
if os.path.exists(ios_path):
    for locale in os.listdir(ios_path):
        if locale == 'android' or locale not in translations:
            continue
        release_notes_path = os.path.join(ios_path, locale, "release_notes.txt")
        with open(release_notes_path, 'w', encoding='utf-8') as f:
            f.write(translations[locale])
