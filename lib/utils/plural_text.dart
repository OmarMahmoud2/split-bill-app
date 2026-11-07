import 'package:easy_localization/easy_localization.dart';

/// `key.plural(count)` with the count filled in. Falls back to the key when
/// localization is not set up (widget tests).
String pluralText(String key, int count) {
  try {
    return key.plural(count);
  } catch (_) {
    return key;
  }
}
