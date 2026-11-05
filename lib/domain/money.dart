/// Integer minor-unit money handling (cents, fils, yen...).
///
/// All domain arithmetic is done on `int` minor units so that splits always
/// add up exactly. Doubles only appear at the edges (UI input, Firestore).
library;

import 'domain_errors.dart';

/// ISO 4217 minor-unit exponents for currencies that do NOT use 2 decimals.
///
/// The list of currencies the app offers lives in
/// `lib/config/supported_preferences.dart` (`supportedCurrencyOptions`).
/// That file imports `package:flutter/material.dart` and carries no decimals
/// information, so it cannot be imported from this pure-Dart layer; keep this
/// map in sync with it when currencies are added. Any code not listed here
/// (including user-defined custom codes) uses 2 decimals.
const Map<String, int> _nonDefaultDecimals = {
  // 0 decimals
  'BIF': 0,
  'CLP': 0,
  'DJF': 0,
  'GNF': 0,
  'ISK': 0,
  'JPY': 0,
  'KMF': 0,
  'KRW': 0,
  'PYG': 0,
  'RWF': 0,
  'UGX': 0,
  'VND': 0,
  'VUV': 0,
  'XAF': 0,
  'XOF': 0,
  'XPF': 0,
  // 3 decimals
  'BHD': 3,
  'IQD': 3,
  'JOD': 3,
  'KWD': 3,
  'LYD': 3,
  'OMR': 3,
  'TND': 3,
};

const int _defaultDecimals = 2;

/// Normalises a currency code (" usd " -> "USD").
String normalizeCurrency(String currency) =>
    currency.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

/// Number of minor-unit decimals for [currency] (JPY 0, USD 2, KWD 3).
int currencyDecimals(String currency) =>
    _nonDefaultDecimals[normalizeCurrency(currency)] ?? _defaultDecimals;

/// Converts a major-unit [amount] (e.g. 12.34 USD) into minor units (1234).
///
/// Rounds half away from zero on the *shortest decimal representation* of
/// the double, i.e. the number the user actually typed: 1.005 -> 101 cents,
/// where the naive `(1.005 * 100).round()` would give 100.
int toMinorUnits(double amount, String currency) {
  if (amount.isNaN || amount.isInfinite) {
    throw InvalidAmountError(amount);
  }
  final decimals = currencyDecimals(currency);
  final negative = amount < 0;
  var (digits, pointPos) = _decimalDigits(amount.abs().toString());

  // Value is 0.<digits> * 10^pointPos ... expressed as: integer part is the
  // first `pointPos` digits. We need `pointPos + decimals` digits, plus one
  // more to decide rounding.
  final keep = pointPos + decimals;
  int result;
  if (keep < 0) {
    result = 0;
  } else {
    if (digits.length < keep + 1) {
      digits = digits.padRight(keep + 1, '0');
    }
    final kept = keep == 0 ? 0 : int.parse(digits.substring(0, keep));
    final roundDigit = digits.codeUnitAt(keep) - 0x30;
    result = roundDigit >= 5 ? kept + 1 : kept;
  }
  return negative ? -result : result;
}

/// Parses a non-negative decimal string (possibly in exponent notation) into
/// its significant digits and the position of the decimal point within them.
(String, int) _decimalDigits(String s) {
  var exponent = 0;
  final eIndex = s.indexOf(RegExp('[eE]'));
  if (eIndex >= 0) {
    exponent = int.parse(s.substring(eIndex + 1));
    s = s.substring(0, eIndex);
  }
  final dot = s.indexOf('.');
  final intPart = dot >= 0 ? s.substring(0, dot) : s;
  final fracPart = dot >= 0 ? s.substring(dot + 1) : '';
  var digits = intPart + fracPart;
  var pointPos = intPart.length + exponent;
  // Strip leading zeros so int.parse never sees an overly long prefix.
  while (digits.length > 1 && digits.startsWith('0')) {
    digits = digits.substring(1);
    pointPos -= 1;
  }
  if (pointPos < 0) {
    // e.g. 0.000123: pad zeros in front so pointPos becomes 0.
    digits = '${'0' * -pointPos}$digits';
    pointPos = 0;
  }
  return (digits, pointPos);
}

/// Converts [minor] units back into a major-unit double (1234 -> 12.34).
double fromMinorUnits(int minor, String currency) {
  final decimals = currencyDecimals(currency);
  if (decimals == 0) return minor.toDouble();
  // Parse the exact decimal string to avoid 0.07 -> 0.07000000000000001.
  return double.parse(_formatMinor(minor, decimals));
}

String _formatMinor(int minor, int decimals) {
  final negative = minor < 0;
  final abs = minor.abs().toString();
  if (decimals == 0) return '${negative ? '-' : ''}$abs';
  final padded = abs.padLeft(decimals + 1, '0');
  final whole = padded.substring(0, padded.length - decimals);
  final frac = padded.substring(padded.length - decimals);
  return '${negative ? '-' : ''}$whole.$frac';
}

/// An immutable amount of money in integer minor units.
class Money implements Comparable<Money> {
  /// Amount in minor units (cents for USD, yen for JPY, fils for KWD).
  final int minor;

  /// Upper-case ISO 4217 (or custom) currency code.
  final String currency;

  const Money(this.minor, this.currency);

  factory Money.zero(String currency) => Money(0, normalizeCurrency(currency));

  factory Money.fromDouble(double amount, String currency) {
    final code = normalizeCurrency(currency);
    return Money(toMinorUnits(amount, code), code);
  }

  double toDouble() => fromMinorUnits(minor, currency);

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;
  bool get isPositive => minor > 0;

  void _checkCurrency(Money other) {
    if (other.currency != currency) {
      throw CurrencyMismatchError(currency, other.currency);
    }
  }

  Money operator +(Money other) {
    _checkCurrency(other);
    return Money(minor + other.minor, currency);
  }

  Money operator -(Money other) {
    _checkCurrency(other);
    return Money(minor - other.minor, currency);
  }

  Money operator -() => Money(-minor, currency);

  @override
  int compareTo(Money other) {
    _checkCurrency(other);
    return minor.compareTo(other.minor);
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() =>
      '${_formatMinor(minor, currencyDecimals(currency))} $currency';
}
