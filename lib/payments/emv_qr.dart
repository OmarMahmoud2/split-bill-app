/// EMV® QR Code (Merchant-Presented Mode) payload builders for the national
/// instant-payment QR standards that publish their tags: Pix (BR Code),
/// PromptPay (TH), PayNow (SGQR) and VietQR (NAPAS).
///
/// Pure Dart. Every payload ends with tag 63 holding a CRC16/CCITT-FALSE
/// checksum (poly 0x1021, init 0xFFFF) over the whole string including "6304".
library;

import 'dart:convert';

/// CRC16/CCITT-FALSE as 4 upper-case hex digits.
String crc16Ccitt(String data) {
  var crc = 0xFFFF;
  for (final byte in utf8.encode(data)) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1;
      crc &= 0xFFFF;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}

/// One EMV TLV field: 2-digit id, 2-digit length, value.
String emvField(String id, String value) {
  if (value.length > 99) {
    throw ArgumentError.value(value, 'value', 'EMV field longer than 99');
  }
  return '$id${value.length.toString().padLeft(2, '0')}$value';
}

/// Appends the "6304" CRC field to [body].
String withEmvCrc(String body) {
  final withTag = '${body}6304';
  return '$withTag${crc16Ccitt(withTag)}';
}

/// Parses a flat EMV TLV string into id -> value (top level only).
Map<String, String> parseEmvFields(String payload) {
  final fields = <String, String>{};
  var i = 0;
  while (i + 4 <= payload.length) {
    final id = payload.substring(i, i + 2);
    final len = int.parse(payload.substring(i + 2, i + 4));
    fields[id] = payload.substring(i + 4, i + 4 + len);
    i += 4 + len;
  }
  return fields;
}

/// True when [payload] carries a correct trailing CRC.
bool hasValidEmvCrc(String payload) {
  if (payload.length < 8) return false;
  final body = payload.substring(0, payload.length - 4);
  if (!body.endsWith('6304')) return false;
  return crc16Ccitt(body) == payload.substring(payload.length - 4);
}

/// Strips accents and keeps printable ASCII, as Pix name/city fields require.
String asciiFold(String input) {
  const from = 'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖòóôõöÙÚÛÜùúûüÇçÑñÝýÿ';
  const to = 'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNnYyy';
  final buffer = StringBuffer();
  for (final ch in input.split('')) {
    final idx = from.indexOf(ch);
    final mapped = idx >= 0 ? to[idx] : ch;
    final code = mapped.codeUnitAt(0);
    if (code >= 0x20 && code < 0x7F) buffer.write(mapped);
  }
  return buffer.toString().trim();
}

String _cut(String s, int max) => s.length <= max ? s : s.substring(0, max);

/// Static Pix "copia e cola" / QR payload (Banco Central do Brasil,
/// Manual de Padrões para Iniciação do Pix, BR Code section).
///
/// [amount] is the major-unit decimal string ("16.38") or null for an
/// open-amount code. [txid] defaults to "***" (no identifier).
String buildPixPayload({
  required String key,
  required String merchantName,
  required String merchantCity,
  String? amount,
  String? description,
  String txid = '***',
}) {
  final account = StringBuffer()
    ..write(emvField('00', 'br.gov.bcb.pix'))
    ..write(emvField('01', key.trim()));
  final desc = description == null ? '' : asciiFold(description);
  if (desc.isNotEmpty) {
    // Keep tag 26 within 99 characters.
    final room = 99 - account.length - 4;
    if (room > 0) account.write(emvField('02', _cut(desc, room)));
  }
  final name = _cut(
    asciiFold(merchantName).isEmpty ? 'N' : asciiFold(merchantName),
    25,
  );
  final city = _cut(
    asciiFold(merchantCity).isEmpty
        ? 'BRASIL'
        : asciiFold(merchantCity).toUpperCase(),
    15,
  );
  final cleanTxid = _cut(
    txid == '***' ? txid : txid.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''),
    25,
  );
  final body = StringBuffer()
    ..write(emvField('00', '01'))
    ..write(emvField('26', account.toString()))
    ..write(emvField('52', '0000'))
    ..write(emvField('53', '986'));
  if (amount != null) body.write(emvField('54', amount));
  body
    ..write(emvField('58', 'BR'))
    ..write(emvField('59', name))
    ..write(emvField('60', city))
    ..write(
      emvField('62', emvField('05', cleanTxid.isEmpty ? '***' : cleanTxid)),
    );
  return withEmvCrc(body.toString());
}

/// PromptPay proxy kinds (tag 29 sub-ids 01/02/03).
enum PromptPayProxy { mobile, nationalId, eWallet }

/// Classifies a PromptPay id by digit count: 10 or fewer digits (Thai
/// mobile), 13 (national/tax id), 15 (e-wallet id).
PromptPayProxy? promptPayProxyFor(String id) {
  final digits = id.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 13) return PromptPayProxy.nationalId;
  if (digits.length == 15) return PromptPayProxy.eWallet;
  if (digits.length >= 9 && digits.length <= 11) return PromptPayProxy.mobile;
  return null;
}

/// PromptPay (Thai QR Payment, tag 29, AID A000000677010111).
///
/// Mobile numbers are sent as 0066 + number without the leading 0, padded
/// to 13 characters. Point of initiation is 11 (static) without an amount and
/// 12 with one, matching the widely used reference implementation.
String buildPromptPayPayload({required String id, String? amount}) {
  final digits = id.replaceAll(RegExp(r'\D'), '');
  final kind = promptPayProxyFor(digits);
  if (kind == null) {
    throw ArgumentError.value(id, 'id', 'Not a PromptPay id');
  }
  final String target;
  final String subId;
  switch (kind) {
    case PromptPayProxy.mobile:
      var local = digits;
      if (local.startsWith('66')) local = local.substring(2);
      if (local.startsWith('0')) local = local.substring(1);
      target = '0066$local'.padLeft(13, '0');
      subId = '01';
    case PromptPayProxy.nationalId:
      target = digits;
      subId = '02';
    case PromptPayProxy.eWallet:
      target = digits;
      subId = '03';
  }
  final merchant = emvField('00', 'A000000677010111') + emvField(subId, target);
  final body = StringBuffer()
    ..write(emvField('00', '01'))
    ..write(emvField('01', amount == null ? '11' : '12'))
    ..write(emvField('29', merchant))
    ..write(emvField('58', 'TH'))
    ..write(emvField('53', '764'));
  if (amount != null) body.write(emvField('54', amount));
  return withEmvCrc(body.toString());
}

/// PayNow proxy kinds (SGQR tag 26 sub-id 01).
enum PayNowProxy { mobile, uen }

/// PayNow (Singapore SGQR, tag 26 with "SG.PAYNOW").
///
/// [proxy] is "+6591234567" for mobile or a UEN for businesses.
/// [editable] lets the payer change the amount.
String buildPayNowPayload({
  required String proxy,
  required String merchantName,
  String? amount,
  bool editable = false,
  String? reference,
}) {
  final compact = proxy.replaceAll(RegExp(r'[\s-]'), '');
  final isMobile = RegExp(r'^\+?(65)?[89]\d{7}$').hasMatch(compact);
  final value = isMobile
      ? '+65${compact.replaceFirst(RegExp(r'^\+?65'), '')}'
      : compact.toUpperCase();
  final merchant = StringBuffer()
    ..write(emvField('00', 'SG.PAYNOW'))
    ..write(emvField('01', isMobile ? '0' : '2'))
    ..write(emvField('02', value))
    ..write(emvField('03', editable || amount == null ? '1' : '0'));
  final body = StringBuffer()
    ..write(emvField('00', '01'))
    ..write(emvField('01', amount == null ? '11' : '12'))
    ..write(emvField('26', merchant.toString()))
    ..write(emvField('52', '0000'))
    ..write(emvField('53', '702'));
  if (amount != null) body.write(emvField('54', amount));
  body
    ..write(emvField('58', 'SG'))
    ..write(
      emvField(
        '59',
        _cut(
          asciiFold(merchantName).isEmpty ? 'NA' : asciiFold(merchantName),
          25,
        ),
      ),
    )
    ..write(emvField('60', 'Singapore'));
  final ref = reference == null
      ? ''
      : asciiFold(reference).replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '');
  if (ref.isNotEmpty) body.write(emvField('62', emvField('01', _cut(ref, 25))));
  return withEmvCrc(body.toString());
}

/// VietQR (NAPAS 247, tag 38 with AID A000000727, service QRIBFTTA =
/// transfer to account). [bankBin] is the 6-digit NAPAS bank BIN.
String buildVietQrPayload({
  required String bankBin,
  required String accountNumber,
  String? amount,
  String? message,
}) {
  final beneficiary = emvField('00', bankBin) + emvField('01', accountNumber);
  final merchant = StringBuffer()
    ..write(emvField('00', 'A000000727'))
    ..write(emvField('01', beneficiary))
    ..write(emvField('02', 'QRIBFTTA'));
  final body = StringBuffer()
    ..write(emvField('00', '01'))
    ..write(emvField('01', amount == null ? '11' : '12'))
    ..write(emvField('38', merchant.toString()))
    ..write(emvField('53', '704'));
  if (amount != null) body.write(emvField('54', amount));
  body.write(emvField('58', 'VN'));
  final msg = message == null ? '' : asciiFold(message);
  if (msg.isNotEmpty) body.write(emvField('62', emvField('08', _cut(msg, 25))));
  return withEmvCrc(body.toString());
}
