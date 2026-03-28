class ShareLinkUtils {
  static const String _overrideBaseUrl = String.fromEnvironment(
    'SPLIT_BILL_WEB_BASE_URL',
    defaultValue: '',
  );

  static String get webBaseUrl => _overrideBaseUrl.isNotEmpty
      ? _overrideBaseUrl
      : 'https://splitbillapp-ffc39.web.app';

  static Uri buildBillShareUri(String billId, {String? participantId}) {
    final baseUri = Uri.parse(webBaseUrl);
    final queryParameters = <String, String>{
      'billId': billId,
    };

    if (participantId != null && participantId.isNotEmpty) {
      queryParameters['uid'] = participantId;
    }

    return baseUri.replace(
      pathSegments: baseUri.pathSegments.where((segment) => segment.isNotEmpty).toList(),
      queryParameters: queryParameters,
    );
  }

  static String buildBillShareUrl(String billId, {String? participantId}) {
    return buildBillShareUri(
      billId,
      participantId: participantId,
    ).toString();
  }
}
