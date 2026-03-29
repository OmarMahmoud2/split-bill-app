import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/services/user_preferences_service.dart';
import 'package:split_bill_app/utils/currency_utils.dart';

void main() {
  group('UserPreferencesService', () {
    test('exposes stable default locale and currency values', () {
      expect(UserPreferencesService.defaultLocaleCode, 'en');
      expect(UserPreferencesService.defaultCurrencyCode, 'USD');
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

  test('resolves device locale to the closest supported locale', () {
    final locale = resolveSupportedLocale(
      const [Locale('es', 'MX'), Locale('fr', 'FR')],
    );

    expect(locale.languageCode, 'es');
  });
}
