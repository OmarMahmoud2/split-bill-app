/// Bank-account formats and bank QR payloads: IBAN (ISO 13616 mod-97),
/// EPC QR / GiroCode (EPC069-12), Czech QR Platba (SPAYD), Mexican CLABE and
/// UPI deep links (NPCI linking specification). Pure Dart.
library;

/// Removes spaces/dashes and upper-cases an IBAN.
String compactIban(String iban) =>
    iban.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

/// IBAN lengths per country (ISO 13616 registry, SWIFT release 2024+).
const Map<String, int> ibanLengths = {
  'AD': 24,
  'AE': 23,
  'AL': 28,
  'AT': 20,
  'AZ': 28,
  'BA': 20,
  'BE': 16,
  'BG': 22,
  'BH': 22,
  'BR': 29,
  'BY': 28,
  'CH': 21,
  'CR': 22,
  'CY': 28,
  'CZ': 24,
  'DE': 22,
  'DK': 18,
  'DO': 28,
  'DZ': 26,
  'EE': 20,
  'EG': 29,
  'ES': 24,
  'FI': 18,
  'FO': 18,
  'FR': 27,
  'GB': 22,
  'GE': 22,
  'GI': 23,
  'GL': 18,
  'GR': 27,
  'GT': 28,
  'HR': 21,
  'HU': 28,
  'IE': 22,
  'IL': 23,
  'IQ': 23,
  'IS': 26,
  'IT': 27,
  'JO': 30,
  'KW': 30,
  'KZ': 20,
  'LB': 28,
  'LC': 32,
  'LI': 21,
  'LT': 20,
  'LU': 20,
  'LV': 21,
  'LY': 25,
  'MC': 27,
  'MD': 24,
  'ME': 22,
  'MK': 19,
  'MR': 27,
  'MT': 31,
  'MU': 30,
  'NL': 18,
  'NO': 15,
  'OM': 23,
  'PK': 24,
  'PL': 28,
  'PS': 29,
  'PT': 25,
  'QA': 29,
  'RO': 24,
  'RS': 22,
  'SA': 24,
  'SC': 31,
  'SD': 18,
  'SE': 24,
  'SI': 19,
  'SK': 24,
  'SM': 27,
  'ST': 25,
  'SV': 28,
  'TL': 23,
  'TN': 24,
  'TR': 26,
  'UA': 29,
  'VA': 22,
  'VG': 24,
  'XK': 20,
};

/// True when [iban] has a known country length and a valid mod-97 checksum.
bool isValidIban(String iban) {
  final s = compactIban(iban);
  if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{8,30}$').hasMatch(s)) return false;
  final expected = ibanLengths[s.substring(0, 2)];
  if (expected != null && expected != s.length) return false;
  final rearranged = s.substring(4) + s.substring(0, 4);
  var remainder = 0;
  for (final unit in rearranged.codeUnits) {
    final digits = unit >= 65
        ? (unit - 55).toString()
        : String.fromCharCode(unit);
    for (final d in digits.codeUnits) {
      remainder = (remainder * 10 + (d - 48)) % 97;
    }
  }
  return remainder == 1;
}

/// SEPA countries whose banks accept EPC QR SEPA Credit Transfers in EUR.
const Set<String> sepaEurCountries = {
  'AT',
  'BE',
  'CY',
  'DE',
  'EE',
  'ES',
  'FI',
  'FR',
  'GR',
  'HR',
  'IE',
  'IT',
  'LT',
  'LU',
  'LV',
  'MC',
  'MT',
  'NL',
  'PT',
  'SI',
  'SK',
  'SM',
  'VA',
  'AD',
};

/// EPC QR code ("GiroCode", EPC069-12 v3.0) for a SEPA Credit Transfer.
///
/// Version 002 (BIC optional inside the EEA), UTF-8 (character set 1).
/// [amountEur] is the decimal string ("16.38"); null leaves it open.
/// Trailing empty lines are omitted as the guideline allows.
String buildEpcQrPayload({
  required String name,
  required String iban,
  String? bic,
  String? amountEur,
  String? remittance,
  String? purpose,
}) {
  final cleanName = name.trim();
  if (cleanName.isEmpty || cleanName.length > 70) {
    throw ArgumentError.value(name, 'name', 'Must be 1-70 characters');
  }
  final cleanIban = compactIban(iban);
  if (!isValidIban(cleanIban)) {
    throw ArgumentError.value(iban, 'iban', 'Invalid IBAN');
  }
  if (amountEur != null) {
    final value = double.tryParse(amountEur);
    if (value == null || value < 0.01 || value > 999999999.99) {
      throw ArgumentError.value(amountEur, 'amountEur', 'Out of range');
    }
  }
  var text = (remittance ?? '').replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  if (text.length > 140) text = text.substring(0, 140);
  final lines = <String>[
    'BCD',
    '002',
    '1',
    'SCT',
    (bic ?? '').replaceAll(' ', '').toUpperCase(),
    cleanName,
    cleanIban,
    amountEur == null ? '' : 'EUR${_trimAmount(amountEur)}',
    (purpose ?? '').toUpperCase(),
    '', // structured creditor reference: unused for friends
    text,
  ];
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}

/// EPC wants at most 2 decimals and no needless trailing zeros ("12.3").
String _trimAmount(String amount) {
  var s = double.parse(amount).toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// Czech "QR Platba" / Short Payment Descriptor (ČBA standard v1.2).
///
/// `SPD*1.0*ACC:<IBAN>*AM:<0.00>*CC:CZK*MSG:<text>`; '*' inside values is
/// escaped as %2A. MSG is capped at 60 characters.
String buildSpaydPayload({
  required String iban,
  String? amount,
  String currency = 'CZK',
  String? message,
  String? recipientName,
}) {
  final cleanIban = compactIban(iban);
  if (!isValidIban(cleanIban)) {
    throw ArgumentError.value(iban, 'iban', 'Invalid IBAN');
  }
  String esc(String v) => v.replaceAll('*', '%2A').replaceAll('\n', ' ');
  final parts = <String>['SPD', '1.0', 'ACC:$cleanIban'];
  if (amount != null) {
    parts.add('AM:${double.parse(amount).toStringAsFixed(2)}');
  }
  parts.add('CC:${currency.toUpperCase()}');
  final name = recipientName?.trim() ?? '';
  if (name.isNotEmpty) {
    parts.add('RN:${esc(name.length > 35 ? name.substring(0, 35) : name)}');
  }
  final msg = message?.trim() ?? '';
  if (msg.isNotEmpty) {
    parts.add('MSG:${esc(msg.length > 60 ? msg.substring(0, 60) : msg)}');
  }
  return parts.join('*');
}

/// Mexican CLABE: 18 digits, last one a weighted (3,7,1) mod-10 check digit.
bool isValidClabe(String clabe) {
  final s = clabe.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^\d{18}$').hasMatch(s)) return false;
  const weights = [3, 7, 1];
  var sum = 0;
  for (var i = 0; i < 17; i++) {
    sum += (int.parse(s[i]) * weights[i % 3]) % 10;
  }
  return (10 - sum % 10) % 10 == int.parse(s[17]);
}

/// UPI VPA, e.g. "name@okhdfcbank".
final RegExp upiVpaPattern = RegExp(r'^[A-Za-z0-9.\-_]{2,256}@[A-Za-z]{2,64}$');

/// UPI intent / QR string (NPCI UPI Linking Specification):
/// `upi://pay?pa=<vpa>&pn=<name>&am=<amount>&cu=INR&tn=<note>`.
///
/// The same string is the content of a UPI QR code.
Uri buildUpiUri({
  required String vpa,
  String? payeeName,
  String? amount,
  String? note,
}) {
  final params = <String, String>{'pa': vpa.trim()};
  final name = payeeName?.trim() ?? '';
  if (name.isNotEmpty) params['pn'] = name;
  if (amount != null) params['am'] = double.parse(amount).toStringAsFixed(2);
  params['cu'] = 'INR';
  final tn = note?.trim() ?? '';
  if (tn.isNotEmpty) params['tn'] = tn.length > 50 ? tn.substring(0, 50) : tn;
  final query = params.entries
      // The VPA charset is URL-safe; keep '@' literal as the spec shows.
      .map(
        (e) =>
            '${e.key}=${e.key == 'pa' ? e.value : Uri.encodeComponent(e.value)}',
      )
      .join('&');
  return Uri.parse('upi://pay?$query');
}
