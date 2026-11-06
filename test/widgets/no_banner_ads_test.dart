import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // The published privacy policy promises rewarded ads only.
  test('no banner ads anywhere in the app', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (src.contains('BannerAd') || src.contains('banner_ad_widget')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
