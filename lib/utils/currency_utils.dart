import 'package:intl/intl.dart';

class CurrencyUtils {
  static String format(
    num amount, {
    required String currencyCode,
    String? localeCode,
    int decimalDigits = 2,
  }) {
    try {
      String formatted = NumberFormat.currency(
        locale: localeCode ?? Intl.getCurrentLocale(),
        name: currencyCode,
        decimalDigits: decimalDigits,
      ).format(amount);
      
      // Ensure space between digit and non-digit (currency symbol/letters)
      return formatted.replaceAllMapped(
          RegExp(r'(?<=[0-9])(?=[^\d\s.,\-])|(?<=[^\d\s.,\-])(?=[0-9])'), 
          (match) => ' ');
    } catch (_) {
      return '${amount.toStringAsFixed(decimalDigits)} $currencyCode';
    }
  }
}
