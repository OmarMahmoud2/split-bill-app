import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// A time of day stored as "HH:mm" (24 h).
@immutable
class ClockTime {
  const ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  /// Parses "HH:mm" / "H:mm"; null when malformed or out of range.
  static ClockTime? tryParse(Object? raw) {
    if (raw is! String) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return ClockTime(h, min);
  }

  String toStorage() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Minutes after midnight.
  int get minutes => hour * 60 + minute;

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => toStorage();
}

/// Quiet window during which no reminder is delivered. May wrap midnight.
@immutable
class QuietHours {
  const QuietHours({required this.start, required this.end});

  static const QuietHours defaults = QuietHours(
    start: ClockTime(22, 0),
    end: ClockTime(8, 0),
  );

  final ClockTime start;
  final ClockTime end;

  factory QuietHours.fromMap(Object? raw) {
    if (raw is! Map) return defaults;
    return QuietHours(
      start: ClockTime.tryParse(raw['start']) ?? defaults.start,
      end: ClockTime.tryParse(raw['end']) ?? defaults.end,
    );
  }

  Map<String, String> toMap() => {
    'start': start.toStorage(),
    'end': end.toStorage(),
  };

  /// Whether [time] falls inside the window (start inclusive, end exclusive).
  bool contains(ClockTime time) {
    final t = time.minutes;
    final s = start.minutes;
    final e = end.minutes;
    if (s == e) return false;
    return s < e ? (t >= s && t < e) : (t >= s || t < e);
  }

  /// "22:00–08:00".
  String get label => '${start.toStorage()}–${end.toStorage()}';

  QuietHours copyWith({ClockTime? start, ClockTime? end}) =>
      QuietHours(start: start ?? this.start, end: end ?? this.end);

  @override
  bool operator ==(Object other) =>
      other is QuietHours && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// The user's reminder settings, stored at `users/{uid}.reminderPrefs`
/// (an owner-writable, non-protected field). The server reminder campaign
/// reads it.
///
/// ```
/// reminderPrefs: {
///   enabled: true, weekday: 5, hour: 19,
///   quietHours: {start: '22:00', end: '08:00'},
///   tripEndPrompt: true, monthlySummary: false
/// }
/// ```
@immutable
class ReminderPrefs {
  const ReminderPrefs({
    this.enabled = true,
    this.weekday = DateTime.friday,
    this.hour = 19,
    this.quietHours = QuietHours.defaults,
    this.tripEndPrompt = true,
    this.monthlySummary = false,
  });

  static const ReminderPrefs defaults = ReminderPrefs();

  static const String field = 'reminderPrefs';

  /// "Nudge friends who owe me".
  final bool enabled;

  /// ISO weekday, Monday = 1 … Sunday = 7.
  final int weekday;

  /// Hour of day (0–23) in the recipient's local time.
  final int hour;
  final QuietHours quietHours;

  /// "Trip ended, settle up?" 24 h after the last bill.
  final bool tripEndPrompt;

  /// Summary on the first of the month.
  final bool monthlySummary;

  /// Tolerant parse; missing or invalid values fall back to [defaults].
  factory ReminderPrefs.fromMap(Object? raw) {
    if (raw is! Map) return defaults;
    int? intIn(Object? v, int min, int max) {
      final n = v is num ? v.toInt() : int.tryParse('$v');
      return (n == null || n < min || n > max) ? null : n;
    }

    bool boolOr(Object? v, bool fallback) => v is bool ? v : fallback;

    return ReminderPrefs(
      enabled: boolOr(raw['enabled'], defaults.enabled),
      weekday: intIn(raw['weekday'], 1, 7) ?? defaults.weekday,
      hour: intIn(raw['hour'], 0, 23) ?? defaults.hour,
      quietHours: QuietHours.fromMap(raw['quietHours']),
      tripEndPrompt: boolOr(raw['tripEndPrompt'], defaults.tripEndPrompt),
      monthlySummary: boolOr(raw['monthlySummary'], defaults.monthlySummary),
    );
  }

  /// Reads the prefs from a users/{uid} document map.
  factory ReminderPrefs.fromUserDoc(Map<String, dynamic>? doc) =>
      ReminderPrefs.fromMap(doc?[field]);

  Map<String, Object> toMap() => {
    'enabled': enabled,
    'weekday': weekday,
    'hour': hour,
    'quietHours': quietHours.toMap(),
    'tripEndPrompt': tripEndPrompt,
    'monthlySummary': monthlySummary,
  };

  ReminderPrefs copyWith({
    bool? enabled,
    int? weekday,
    int? hour,
    QuietHours? quietHours,
    bool? tripEndPrompt,
    bool? monthlySummary,
  }) => ReminderPrefs(
    enabled: enabled ?? this.enabled,
    weekday: weekday ?? this.weekday,
    hour: hour ?? this.hour,
    quietHours: quietHours ?? this.quietHours,
    tripEndPrompt: tripEndPrompt ?? this.tripEndPrompt,
    monthlySummary: monthlySummary ?? this.monthlySummary,
  );

  /// Short weekday name in [locale] ("Fri", "الجمعة").
  static String weekdayLabel(int weekday, {String? locale}) {
    // 1 Jan 2024 was a Monday.
    final date = DateTime(2024, 1, weekday);
    try {
      return DateFormat.E(locale).format(date);
    } catch (_) {
      return DateFormat.E().format(date);
    }
  }

  /// Long weekday name in [locale] ("Friday").
  static String weekdayLongLabel(int weekday, {String? locale}) {
    final date = DateTime(2024, 1, weekday);
    try {
      return DateFormat.EEEE(locale).format(date);
    } catch (_) {
      return DateFormat.EEEE().format(date);
    }
  }

  /// Hour in [locale]'s clock style ("7 PM", "19").
  static String hourLabel(int hour, {String? locale}) {
    final date = DateTime(2024, 1, 1, hour);
    try {
      return DateFormat.j(locale).format(date);
    } catch (_) {
      return DateFormat.j().format(date);
    }
  }

  /// "Fri, 7 PM"; [offLabel] when nudges are off.
  String summary({required String offLabel, String? locale}) {
    if (!enabled) return offLabel;
    return '${weekdayLabel(weekday, locale: locale)}, '
        '${hourLabel(hour, locale: locale)}';
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderPrefs &&
      other.enabled == enabled &&
      other.weekday == weekday &&
      other.hour == hour &&
      other.quietHours == quietHours &&
      other.tripEndPrompt == tripEndPrompt &&
      other.monthlySummary == monthlySummary;

  @override
  int get hashCode => Object.hash(
    enabled,
    weekday,
    hour,
    quietHours,
    tripEndPrompt,
    monthlySummary,
  );
}

/// Reads and writes [ReminderPrefs] for the signed-in user.
class ReminderPrefsService {
  ReminderPrefsService._();

  static DocumentReference<Map<String, dynamic>>? _doc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  static Future<ReminderPrefs> load() async {
    final doc = _doc();
    if (doc == null) return ReminderPrefs.defaults;
    final snap = await doc.get();
    return ReminderPrefs.fromUserDoc(snap.data());
  }

  /// Merges the whole map so the server always sees a complete object.
  static Future<void> save(ReminderPrefs prefs) async {
    final doc = _doc();
    if (doc == null) throw StateError('not signed in');
    await doc.set({
      ReminderPrefs.field: prefs.toMap(),
    }, SetOptions(merge: true));
  }
}
