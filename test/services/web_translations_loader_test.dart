import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:split_bill_app/services/web_translations_loader.dart';

void main() {
  test('builds a versioned URL from the site root, even on deep links', () {
    final url = translationsUrl(
      Uri.parse('https://example.web.app/bill/abc'),
      'assets/translations',
      const Locale('ar'),
    );
    expect(url.path, '/assets/assets/translations/ar.json');
    expect(url.host, 'example.web.app');
    expect(url.queryParameters['v'], kTranslationsVersion);
  });

  test('on the web it fetches the versioned file', () async {
    Uri? asked;
    final loader = VersionedTranslationsLoader(
      isWeb: true,
      client: MockClient((req) async {
        asked = req.url;
        return http.Response.bytes(utf8.encode('{"app_title":"Evens"}'), 200);
      }),
    );
    final map = await loader.load('assets/translations', const Locale('en'));
    expect(map, {'app_title': 'Evens'});
    expect(asked!.queryParameters['v'], kTranslationsVersion);
    expect(asked!.path, endsWith('/assets/assets/translations/en.json'));
  });
}
