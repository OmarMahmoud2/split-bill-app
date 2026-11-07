import 'dart:convert';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Bumped with each release (or passed with --dart-define=L10N_VERSION=...).
/// Flutter web does not hash asset names, so the guest web asks for
/// `assets/translations/<lang>.json?v=<version>`: browsers that cached an
/// older file never reuse it after a release.
const String kTranslationsVersion = String.fromEnvironment(
  'L10N_VERSION',
  defaultValue: '2.0.0+24',
);

/// Builds the versioned URL for one language file. The guest web is served
/// from the site root (base href "/"), so deep links like /bill/abc still
/// resolve to /assets/...
Uri translationsUrl(Uri base, String path, Locale locale) => base
    .resolve('/assets/$path/${locale.languageCode}.json')
    .replace(queryParameters: {'v': kTranslationsVersion});

/// Loads translations over HTTP with a version query on the web and from the
/// app bundle everywhere else (and as the web fallback).
class VersionedTranslationsLoader extends AssetLoader {
  const VersionedTranslationsLoader({this.client, this.isWeb = kIsWeb});

  final http.Client? client;
  final bool isWeb;

  static const _bundle = RootBundleAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    if (isWeb) {
      final c = client ?? http.Client();
      try {
        // no-cache = revalidate every load (a cheap 304 when unchanged): a
        // redeploy that keeps the same version must not serve stale strings.
        final res = await c.get(
          translationsUrl(Uri.base, path, locale),
          headers: const {'Cache-Control': 'no-cache'},
        );
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        }
      } catch (_) {
        // Fall back to the bundled file below.
      } finally {
        if (client == null) c.close();
      }
    }
    return _bundle.load(path, locale);
  }
}
