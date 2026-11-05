import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Language choice on the guest page. Guests are anonymous, so the choice
/// is kept on this browser only (never written to a profile).
class GuestLocale {
  GuestLocale._();

  /// Set once the guest picks a language; MyApp then stops syncing the
  /// locale from AppSettingsProvider (which follows the browser).
  static bool chosen = false;

  static Future<void> choose(BuildContext context, Locale locale) async {
    chosen = true;
    await context.setLocale(locale);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('localeCode', locale.languageCode);
    } on Object {
      // Private browsing: the choice lasts for this visit only.
    }
  }
}
