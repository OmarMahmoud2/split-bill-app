import 'package:split_bill_app/utils/share_link_utils.dart';

/// Personal pay link: `<web>/bill/<billId>?p=<participantId>`.
///
/// The guest web page reads `p` and opens straight on that person's share.
/// Without [participantId] it is the table link (everyone picks their name).
Uri personalBillUri(String billId, {String? participantId}) {
  final base = Uri.parse(ShareLinkUtils.webBaseUrl);
  return base.replace(
    pathSegments: [
      ...base.pathSegments.where((s) => s.isNotEmpty),
      'bill',
      billId,
    ],
    queryParameters: participantId == null || participantId.isEmpty
        ? null
        : {'p': participantId},
  );
}

String personalBillUrl(String billId, {String? participantId}) =>
    personalBillUri(billId, participantId: participantId).toString();

/// WhatsApp deep link with [text] prefilled (and an optional phone).
Uri whatsAppUri(String text, {String? phone}) {
  final digits = phone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
  return Uri.parse(
    'https://wa.me/${digits.isEmpty ? '' : digits}'
    '?text=${Uri.encodeComponent(text)}',
  );
}

/// SMS / iMessage link with [text] prefilled.
Uri smsUri(String text, {String? phone}) {
  final number = phone?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';
  // Built by hand: Uri(queryParameters:) encodes spaces as '+', which some
  // Messages apps show literally.
  return Uri.parse('sms:$number?body=${Uri.encodeComponent(text)}');
}
