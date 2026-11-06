import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every iOS target (incl. the widget extension) is named Evens', () {
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final names = RegExp(
      r'INFOPLIST_KEY_CFBundleDisplayName = "?([^";]+)"?;',
    ).allMatches(pbx).map((m) => m.group(1)).toSet();
    expect(names, {'Evens'});
  });
}
