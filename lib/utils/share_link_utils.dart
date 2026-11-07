class ShareLinkUtils {
  static const String _overrideBaseUrl = String.fromEnvironment(
    'SPLIT_BILL_WEB_BASE_URL',
    defaultValue: '',
  );

  static String get webBaseUrl => _overrideBaseUrl.isNotEmpty
      ? _overrideBaseUrl
      : 'https://splitbillapp-ffc39.web.app';

  /// Personal link: `<web>/bill/<billId>?p=<participantId>` (guest web reads
  /// `p`). `?uid=` is also added so older web builds keep working.
  static Uri buildBillShareUri(String billId, {String? participantId}) {
    final baseUri = Uri.parse(webBaseUrl);
    final hasParticipant = participantId != null && participantId.isNotEmpty;
    return baseUri.replace(
      pathSegments: [
        ...baseUri.pathSegments.where((segment) => segment.isNotEmpty),
        'bill',
        billId,
      ],
      queryParameters: hasParticipant
          ? {'p': participantId, 'uid': participantId}
          : null,
    );
  }

  static String buildBillShareUrl(String billId, {String? participantId}) {
    return buildBillShareUri(billId, participantId: participantId).toString();
  }
}
