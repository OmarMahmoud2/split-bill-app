import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/services/reminder_prefs.dart';

void main() {
  group('ReminderPrefs', () {
    test('defaults match the spec', () {
      const d = ReminderPrefs.defaults;
      expect(d.enabled, isTrue);
      expect(d.weekday, DateTime.friday);
      expect(d.hour, 19);
      expect(d.quietHours.label, '22:00–08:00');
      expect(d.tripEndPrompt, isTrue);
      expect(d.monthlySummary, isFalse);
    });

    test('toMap / fromMap round-trip', () {
      const prefs = ReminderPrefs(
        enabled: false,
        weekday: 2,
        hour: 8,
        quietHours: QuietHours(start: ClockTime(23, 30), end: ClockTime(7, 0)),
        tripEndPrompt: false,
        monthlySummary: true,
      );
      final map = prefs.toMap();
      expect(map, {
        'enabled': false,
        'weekday': 2,
        'hour': 8,
        'quietHours': {'start': '23:30', 'end': '07:00'},
        'tripEndPrompt': false,
        'monthlySummary': true,
      });
      expect(ReminderPrefs.fromMap(map), prefs);
    });

    test('missing or invalid values fall back to defaults', () {
      expect(ReminderPrefs.fromMap(null), ReminderPrefs.defaults);
      expect(ReminderPrefs.fromMap('nope'), ReminderPrefs.defaults);
      final parsed = ReminderPrefs.fromMap({
        'enabled': 'yes',
        'weekday': 9,
        'hour': -1,
        'quietHours': {'start': '25:00', 'end': '6:15'},
        'monthlySummary': true,
      });
      expect(parsed.enabled, isTrue);
      expect(parsed.weekday, 5);
      expect(parsed.hour, 19);
      expect(parsed.quietHours.start, const ClockTime(22, 0));
      expect(parsed.quietHours.end, const ClockTime(6, 15));
      expect(parsed.monthlySummary, isTrue);
    });

    test('accepts numeric strings and doubles from Firestore', () {
      final parsed = ReminderPrefs.fromMap({'weekday': 3.0, 'hour': '21'});
      expect(parsed.weekday, 3);
      expect(parsed.hour, 21);
    });

    test('fromUserDoc reads the reminderPrefs field', () {
      final prefs = ReminderPrefs.fromUserDoc({
        'displayName': 'Omar',
        'reminderPrefs': {'enabled': false},
      });
      expect(prefs.enabled, isFalse);
      expect(ReminderPrefs.fromUserDoc(null), ReminderPrefs.defaults);
    });

    test('summary shows day and hour, or off', () {
      // intl may use a narrow no-break space before AM/PM.
      expect(
        ReminderPrefs.defaults
            .summary(offLabel: 'Off', locale: 'en')
            .replaceAll('\u202f', ' '),
        'Fri, 7 PM',
      );
      expect(
        const ReminderPrefs(enabled: false).summary(offLabel: 'Off'),
        'Off',
      );
      expect(ReminderPrefs.weekdayLabel(1, locale: 'en'), 'Mon');
      expect(ReminderPrefs.weekdayLabel(7, locale: 'en'), 'Sun');
    });
  });

  group('QuietHours', () {
    test('window that wraps midnight', () {
      const q = QuietHours.defaults;
      expect(q.contains(const ClockTime(23, 0)), isTrue);
      expect(q.contains(const ClockTime(3, 0)), isTrue);
      expect(q.contains(const ClockTime(8, 0)), isFalse);
      expect(q.contains(const ClockTime(12, 0)), isFalse);
      expect(q.contains(const ClockTime(22, 0)), isTrue);
    });

    test('same-day window and empty window', () {
      const q = QuietHours(start: ClockTime(13, 0), end: ClockTime(15, 0));
      expect(q.contains(const ClockTime(14, 0)), isTrue);
      expect(q.contains(const ClockTime(15, 0)), isFalse);
      const empty = QuietHours(start: ClockTime(9, 0), end: ClockTime(9, 0));
      expect(empty.contains(const ClockTime(9, 0)), isFalse);
    });

    test('ClockTime parsing', () {
      expect(ClockTime.tryParse('07:05'), const ClockTime(7, 5));
      expect(ClockTime.tryParse('7:05')?.toStorage(), '07:05');
      expect(ClockTime.tryParse('24:00'), isNull);
      expect(ClockTime.tryParse('12:60'), isNull);
      expect(ClockTime.tryParse(1200), isNull);
    });
  });
}
