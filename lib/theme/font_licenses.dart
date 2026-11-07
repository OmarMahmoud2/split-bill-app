import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the SIL Open Font License texts of the bundled fonts to Flutter's
/// [LicenseRegistry] so they show on the licenses page (OFL 1.1 requires the
/// license to accompany redistributed fonts).
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, path) in const [
      ('Inter', 'assets/fonts/Inter/OFL.txt'),
      ('Plus Jakarta Sans', 'assets/fonts/PlusJakartaSans/OFL.txt'),
      ('IBM Plex Mono', 'assets/fonts/IBMPlexMono/OFL.txt'),
    ]) {
      final text = await rootBundle.loadString(path);
      yield LicenseEntryWithLineBreaks([family], text);
    }
  });
}
