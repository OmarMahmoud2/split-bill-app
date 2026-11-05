import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/config/supported_preferences.dart';

const _translationsDir = 'assets/translations';
final _placeholder = RegExp(r'\{[^{}]*\}');

Map<String, String> _load(String code) {
  final file = File('$_translationsDir/$code.json');
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return decoded.map((key, value) => MapEntry(key, value as String));
}

List<String> _placeholders(String value) =>
    _placeholder.allMatches(value).map((m) => m.group(0)!).toList()..sort();

void main() {
  final translationCodes =
      Directory(_translationsDir)
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name.endsWith('.json'))
          .map((name) => name.substring(0, name.length - '.json'.length))
          .toList()
        ..sort();
  final english = _load('en');

  test('every registered locale has a translation file and vice versa', () {
    final registered = supportedLocaleOptions.map((o) => o.code).toList()
      ..sort();
    expect(translationCodes, registered);
    expect(registered.length, 22);
  });

  for (final code in translationCodes.where((c) => c != 'en')) {
    group('$code.json', () {
      final translated = _load(code);

      test('has exactly the English key set', () {
        final missing = english.keys.where((k) => !translated.containsKey(k));
        final extra = translated.keys.where((k) => !english.containsKey(k));
        expect(missing, isEmpty, reason: 'missing keys');
        expect(extra, isEmpty, reason: 'keys not in en.json');
      });

      test('keeps every placeholder', () {
        for (final entry in english.entries) {
          final value = translated[entry.key];
          if (value == null) continue;
          expect(
            _placeholders(value),
            _placeholders(entry.value),
            reason: '${entry.key}: "$value"',
          );
        }
      });

      test('has no empty values', () {
        final empty = translated.entries
            .where((e) => e.value.trim().isEmpty && english[e.key]!.isNotEmpty)
            .map((e) => e.key);
        expect(empty, isEmpty);
      });
    });
  }

  test('iOS Info.plist declares every app locale', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>CFBundleLocalizations</key>'));
    for (final option in supportedLocaleOptions) {
      final iosCode = option.code == 'zh' ? 'zh-Hans' : option.code;
      expect(plist, contains('<string>$iosCode</string>'), reason: iosCode);
    }
  });

  group('locale aliases', () {
    test('generic Norwegian and Nynorsk resolve to Bokmål', () {
      expect(
        resolveSupportedLocale(const [Locale('no', 'NO')]).languageCode,
        'nb',
      );
      expect(resolveSupportedLocale(const [Locale('nn')]).languageCode, 'nb');
      expect(findLocaleOption('no').code, 'nb');
    });

    test('new locales resolve from device locales', () {
      for (final code in ['tr', 'nl', 'sv', 'da', 'nb', 'vi', 'th']) {
        expect(resolveSupportedLocale([Locale(code)]).languageCode, code);
      }
    });
  });
}
