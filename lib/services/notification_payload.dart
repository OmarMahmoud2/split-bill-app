/// Pure helpers shared by the client and the server-side Split reminder
/// campaign contract (users/{uid}: timezone, localeCode, notificationsEnabled).
library;

/// Locale codes the reminder campaign has copy for.
const Set<String> reminderLocaleCodes = {
  'en', 'ar', 'fr', 'de', 'ru', 'id', 'ur', 'hi', //
  'pl', 'es', 'it', 'pt', 'zh', 'ko', 'ja',
};

/// Source marker for `notificationsEnabled` values derived from the OS
/// notification permission (as opposed to an explicit user opt-out).
const String notificationsEnabledSystemSource = 'system';

final RegExp _ianaZonePattern = RegExp(
  r'^[A-Za-z][A-Za-z0-9_+\-]*(/[A-Za-z0-9_+\-]+)+$',
);

/// Returns an IANA zone name (e.g. `Africa/Cairo`) or null when [value] is an
/// abbreviation (`EET`), a raw offset (`GMT+02:00`, `+0200`) or empty.
/// `UTC`/`GMT`/`Etc/UTC` style values normalize to `Etc/UTC`.
String? normalizeIanaTimezone(String? value) {
  final zone = value?.trim();
  if (zone == null || zone.isEmpty) return null;
  const utcAliases = {'UTC', 'GMT', 'ZULU', 'UCT', 'UNIVERSAL'};
  if (utcAliases.contains(zone.toUpperCase())) return 'Etc/UTC';
  if (!_ianaZonePattern.hasMatch(zone)) return null;
  if (zone.length > 64) return null;
  return zone;
}

/// Returns a supported campaign locale code for values like `pt_BR`,
/// `zh-Hans` or `AR`, or null when the language is not supported.
String? normalizeLocaleCode(String? value) {
  final code = value
      ?.trim()
      .replaceAll('_', '-')
      .split('-')
      .first
      .toLowerCase();
  if (code == null || !reminderLocaleCodes.contains(code)) return null;
  return code;
}

/// Decides the `notificationsEnabled` value to write on token sync, or null
/// to leave the stored value untouched.
///
/// - OS permission missing: always `false`.
/// - Field missing: `true`.
/// - Stored `false` that came from the OS permission (any source other than
///   an explicit user opt-out): re-enable now that permission is granted.
/// - Anything else (stored `true`, or an explicit user opt-out): untouched.
bool? notificationsEnabledUpdate({
  required bool permitted,
  required bool hasStoredValue,
  Object? storedValue,
  Object? storedSource,
}) {
  if (!permitted) return false;
  if (!hasStoredValue) return true;
  if (storedValue == false && storedSource != 'user') return true;
  return null;
}

enum NotificationTapTarget { bill, notifications, none }

/// Where a tapped push notification with [data] should navigate.
NotificationTapTarget notificationTapTarget(Map<String, dynamic> data) {
  final billId = data['billId'];
  if (billId is String && billId.isNotEmpty) return NotificationTapTarget.bill;
  if (data['type'] == 'engagement_reminder') {
    return NotificationTapTarget.notifications;
  }
  return NotificationTapTarget.none;
}
