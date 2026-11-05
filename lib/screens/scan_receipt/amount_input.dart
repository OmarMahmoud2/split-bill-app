/// Parsing and formatting of typed amounts for the scan / manual screens.
///
/// Everything here is pure and works in integer minor units with the
/// currency's own decimals (JPY 0, USD 2, KWD 3).
library;

import 'package:split_bill_app/domain/money.dart';

const Map<String, String> _nativeDigits = {
  // Arabic-Indic
  '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
  '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
  // Extended Arabic-Indic (Persian / Urdu)
  '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
  '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
};

/// Parses what the user typed into minor units of [currency].
///
/// Accepts `12.5`, `12,50`, `1,234.50`, `1.234,50`, `1 234,5`, Arabic-Indic
/// digits and the Arabic decimal separator. A lone separator is read as a
/// decimal point when the digits after it fit the currency's decimals, and
/// as a thousands separator otherwise (`1,234` in USD is 1234.00, `1,5` is
/// 1.50). Returns `null` for empty or invalid input and negative numbers.
int? parseMinorInput(String raw, String currency) {
  final code = normalizeCurrency(currency);
  final decimals = currencyDecimals(code);
  var s = raw.trim();
  if (s.isEmpty) return null;
  final buffer = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    final native = _nativeDigits[ch];
    if (native != null) {
      buffer.write(native);
    } else if (ch == '٫') {
      buffer.write('.');
    } else if (ch == '٬' || ch == ' ' || ch == ' ' || ch == ' ') {
      // Arabic thousands separator and spaces are grouping.
      continue;
    } else if (ch == "'") {
      // Swiss grouping.
      continue;
    } else if (RegExp(r'[0-9.,\-]').hasMatch(ch)) {
      buffer.write(ch);
    }
    // Currency symbols and letters are ignored.
  }
  s = buffer.toString();
  if (s.isEmpty || s.contains('-')) return null;

  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');
  String normalized;
  if (lastDot >= 0 && lastComma >= 0) {
    // Both present: the last one is the decimal separator.
    final decimalSep = lastDot > lastComma ? '.' : ',';
    final groupSep = decimalSep == '.' ? ',' : '.';
    normalized = s.replaceAll(groupSep, '').replaceAll(decimalSep, '.');
  } else if (lastDot >= 0 || lastComma >= 0) {
    final sep = lastDot >= 0 ? '.' : ',';
    final count = sep.allMatches(s).length;
    final tail = s.substring(s.lastIndexOf(sep) + 1);
    // Exactly three digits after a lone separator reads as grouping
    // ("1,234"), unless the currency itself has three decimals (KWD).
    final isGrouping = count > 1 || (tail.length == 3 && decimals != 3);
    normalized = isGrouping ? s.replaceAll(sep, '') : s.replaceAll(sep, '.');
  } else {
    normalized = s;
  }
  if (normalized.startsWith('.')) normalized = '0$normalized';
  if (normalized.endsWith('.')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(normalized)) return null;
  final value = double.tryParse(normalized);
  if (value == null || value.isNaN || value.isInfinite) return null;
  return toMinorUnits(value, code);
}

/// [minor] as plain editable text with the currency's decimals and a `.`
/// separator, no grouping, no symbol: 1250 USD -> "12.50", 500 JPY -> "500",
/// 1500 KWD -> "1.500".
String minorToInputText(int minor, String currency) {
  final code = normalizeCurrency(currency);
  final decimals = currencyDecimals(code);
  final negative = minor < 0;
  final abs = minor.abs();
  var unit = 1;
  for (var i = 0; i < decimals; i++) {
    unit *= 10;
  }
  final whole = abs ~/ unit;
  final frac = abs % unit;
  final body = decimals == 0
      ? '$whole'
      : '$whole.${frac.toString().padLeft(decimals, '0')}';
  return negative ? '-$body' : body;
}

/// A quantity the user typed: a whole number of at least 1, or `null`.
int? parseQuantityInput(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final buffer = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_nativeDigits[ch] ?? ch);
  }
  final text = buffer.toString().replaceAll(',', '.');
  final asInt = int.tryParse(text);
  if (asInt != null) return asInt >= 1 ? asInt : null;
  final asDouble = double.tryParse(text);
  if (asDouble == null || asDouble.isNaN || asDouble.isInfinite) return null;
  final rounded = asDouble.round();
  return rounded >= 1 ? rounded : null;
}
