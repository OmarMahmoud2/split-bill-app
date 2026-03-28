import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/services/user_preferences_service.dart';
import 'package:split_bill_app/utils/currency_utils.dart';
import 'package:flutter/material.dart';

void main() {
  group('UserPreferencesService', () {
    final service = UserPreferencesService();

    test('parses stored theme mode values', () {
      expect(service.parseThemeMode('light'), ThemeMode.light);
      expect(service.parseThemeMode('dark'), ThemeMode.dark);
      expect(service.parseThemeMode('system'), ThemeMode.system);
      expect(service.parseThemeMode(null), ThemeMode.system);
    });

    test('serializes theme mode values', () {
      expect(service.serializeThemeMode(ThemeMode.light), 'light');
      expect(service.serializeThemeMode(ThemeMode.dark), 'dark');
      expect(service.serializeThemeMode(ThemeMode.system), 'system');
    });
  });

  test('formats currency values with code fallback support', () {
    final formatted = CurrencyUtils.format(
      42.5,
      currencyCode: 'USD',
      decimalDigits: 1,
    );

    expect(formatted, contains('42.5'));
    expect(formatted, isNotEmpty);
  });
}
