import 'package:intl/intl.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/domain/money.dart' as domain;

/// How the sign of an amount is shown.
enum MoneySign {
  /// `+` for positive, `−` (U+2212) for negative, nothing for zero.
  always,

  /// `−` for negative only.
  negativeOnly,

  /// Absolute value, no sign (the word or color next to it carries meaning).
  none,
}

/// The true minus sign (U+2212), wider than a hyphen and read as "minus".
const String kMinusSign = '\u2212';

const String _nbsp = '\u00A0';

final RegExp _arabicScript = RegExp(r'[؀-ۿ]');
const Set<String> _suffixSymbols = {'kr', 'zł', 'Kč', 'Ft', 'lei', 'лв'};

/// Formats [minor] units of [currency] for display.
///
/// * Decimals come from ISO 4217 via `currencyDecimals` (JPY 0, USD/EGP 2,
///   KWD 3), never from a double, so no rounding drift.
/// * The symbol comes from `supportedCurrencyOptions` (custom codes show the
///   code). Arabic-script symbols and a few Nordic/Central-European ones go
///   after the number; others go before (`$12.00`, `E£12.00`, `CHF 12.00`).
/// * Grouping and decimal separators follow [locale] (default: the current
///   Intl locale), digits stay Latin so amounts read the same everywhere.
String formatMoneyMinor(
  int minor,
  String currency, {
  MoneySign sign = MoneySign.negativeOnly,
  bool showSymbol = true,
  String? locale,
}) {
  final code = domain.normalizeCurrency(currency);
  final decimals = domain.currencyDecimals(code);
  final abs = minor.abs();
  final unit = _pow10(decimals);
  final whole = abs ~/ unit;
  final frac = abs % unit;

  final resolvedLocale = _resolveLocale(locale);
  var symbols = NumberFormat.decimalPattern(resolvedLocale).symbols;
  // Digits stay Latin; locales with native digits keep Latin separators too
  // so "1٬234.50" never mixes scripts.
  if (symbols.ZERO_DIGIT != '0') {
    symbols = NumberFormat.decimalPattern('en').symbols;
  }
  final grouped = NumberFormat.decimalPattern('en').format(whole);
  final wholeText = grouped.replaceAll(',', symbols.GROUP_SEP);
  final number = decimals == 0
      ? wholeText
      : '$wholeText${symbols.DECIMAL_SEP}'
            '${frac.toString().padLeft(decimals, '0')}';

  var body = number;
  if (showSymbol) {
    final symbol = findCurrencyOption(code).symbol;
    if (_arabicScript.hasMatch(symbol) || _suffixSymbols.contains(symbol)) {
      body = '$number$_nbsp$symbol';
    } else if (RegExp(r'^[A-Za-z]+$').hasMatch(symbol)) {
      body = '$symbol$_nbsp$number';
    } else {
      body = '$symbol$number';
    }
  }

  final prefix = switch (sign) {
    MoneySign.none => '',
    MoneySign.negativeOnly => minor < 0 ? kMinusSign : '',
    MoneySign.always =>
      minor > 0
          ? '+'
          : minor < 0
          ? kMinusSign
          : '',
  };
  return '$prefix$body';
}

/// [formatMoneyMinor] for a domain [domain.Money].
String formatMoney(
  domain.Money money, {
  MoneySign sign = MoneySign.negativeOnly,
  bool showSymbol = true,
  String? locale,
}) => formatMoneyMinor(
  money.minor,
  money.currency,
  sign: sign,
  showSymbol: showSymbol,
  locale: locale,
);

int _pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

String _resolveLocale(String? locale) {
  final candidate = locale ?? Intl.getCurrentLocale();
  try {
    return NumberFormat.localeExists(candidate)
        ? Intl.canonicalizedLocale(candidate)
        : 'en';
  } catch (_) {
    return 'en';
  }
}
