import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = await File(
        'build/diagnostics/screenshots/$name.png',
      ).create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
