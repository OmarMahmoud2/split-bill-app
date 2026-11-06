import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // RTL locales (ar, ur) must mirror padding: v3 screens use the
  // directional variants instead of physical left/right.
  test('v3 screens use directional insets', () {
    final physical = RegExp(r'EdgeInsets\.(fromLTRB|only\([^)]*\b(left|right)\s*:)');
    final skip = ['admin', 'debug', 'theme/', 'recurring', 'app_theme.dart'];
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (skip.any(f.path.contains)) continue;
      if (physical.hasMatch(f.readAsStringSync())) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });
}
