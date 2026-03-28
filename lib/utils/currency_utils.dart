import 'package:intl/intl.dart';

class CurrencyUtils {
  static String format(
    num amount, {
    required String currencyCode,
    String? localeCode,
    int decimalDigits = 2,
  }) {
    try {
      return NumberFormat.currency(
        locale: localeCode ?? Intl.getCurrentLocale(),
        name: currencyCode,
        decimalDigits: decimalDigits,
      ).format(amount);
    } catch (_) {
      return '${amount.toStringAsFixed(decimalDigits)} $currencyCode';
    }
  }
}
