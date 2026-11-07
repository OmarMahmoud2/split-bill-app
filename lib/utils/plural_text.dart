import 'package:easy_localization/easy_localization.dart';

/// Plural-aware text from flat keys `<key>_one|two|few|many|other`, each with
/// a `{count}` placeholder. The CLDR rule for the current locale picks the
/// form (Arabic, Russian and Polish have more than one/other). Falls back to
/// the key when localization is not set up (widget tests).
String pluralText(String key, int count) {
  try {
    String form(String suffix) =>
        '${key}_$suffix'.tr(namedArgs: {'count': '$count'});
    return Intl.plural(
      count,
      one: form('one'),
      two: form('two'),
      few: form('few'),
      many: form('many'),
      other: form('other'),
    );
  } catch (_) {
    return key;
  }
}
