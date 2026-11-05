import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/services/notification_payload.dart';

void main() {
  group('normalizeIanaTimezone', () {
    test('keeps IANA zone names', () {
      for (final zone in [
        'Africa/Cairo',
        'America/Argentina/Buenos_Aires',
        'America/Port-au-Prince',
        'Etc/GMT+2',
        ' Asia/Kolkata ',
      ]) {
        expect(normalizeIanaTimezone(zone), zone.trim());
      }
    });

    test('maps UTC aliases to Etc/UTC', () {
      for (final zone in ['UTC', 'utc', 'GMT', 'Zulu']) {
        expect(normalizeIanaTimezone(zone), 'Etc/UTC');
      }
    });

    test('rejects abbreviations, offsets and empty values', () {
      for (final zone in [
        null,
        '',
        '  ',
        'EET',
        'PST',
        'GMT+02:00',
        '+02:00',
        '+0200',
        'UTC+3',
        'Africa/',
        '/Cairo',
        'Africa/Cairo; drop',
      ]) {
        expect(normalizeIanaTimezone(zone), isNull, reason: '$zone');
      }
    });
  });

  group('normalizeLocaleCode', () {
    test('accepts every app locale and matches the campaign list', () {
      final appCodes = supportedLocaleOptions.map((o) => o.code).toSet();
      expect(appCodes, reminderLocaleCodes);
      for (final code in appCodes) {
        expect(normalizeLocaleCode(code), code);
      }
    });

    test('strips region/script and case', () {
      expect(normalizeLocaleCode('pt_BR'), 'pt');
      expect(normalizeLocaleCode('zh-Hans'), 'zh');
      expect(normalizeLocaleCode('AR'), 'ar');
      expect(normalizeLocaleCode('nb_NO'), 'nb');
    });

    test('maps generic Norwegian and Nynorsk to Bokmål', () {
      expect(normalizeLocaleCode('no'), 'nb');
      expect(normalizeLocaleCode('nn-NO'), 'nb');
    });

    test('rejects unsupported languages', () {
      expect(normalizeLocaleCode('he'), isNull);
      expect(normalizeLocaleCode(''), isNull);
      expect(normalizeLocaleCode(null), isNull);
    });
  });

  group('notificationsEnabledUpdate', () {
    test('writes false whenever OS permission is missing', () {
      expect(
        notificationsEnabledUpdate(
          permitted: false,
          hasStoredValue: true,
          storedValue: true,
        ),
        isFalse,
      );
    });

    test('writes true when the field is missing', () {
      expect(
        notificationsEnabledUpdate(permitted: true, hasStoredValue: false),
        isTrue,
      );
    });

    test('lifts a permission-derived false once permission is granted', () {
      expect(
        notificationsEnabledUpdate(
          permitted: true,
          hasStoredValue: true,
          storedValue: false,
          storedSource: notificationsEnabledSystemSource,
        ),
        isTrue,
      );
    });

    test('never undoes an explicit user opt-out', () {
      expect(
        notificationsEnabledUpdate(
          permitted: true,
          hasStoredValue: true,
          storedValue: false,
          storedSource: 'user',
        ),
        isNull,
      );
    });

    test('leaves an enabled value untouched', () {
      expect(
        notificationsEnabledUpdate(
          permitted: true,
          hasStoredValue: true,
          storedValue: true,
        ),
        isNull,
      );
    });
  });

  group('notificationTapTarget', () {
    test('engagement reminders open the notifications screen', () {
      expect(
        notificationTapTarget({
          'type': 'engagement_reminder',
          'event_id': 'split-launch-1',
          'campaign': 'launch',
          'locale': 'en',
        }),
        NotificationTapTarget.notifications,
      );
    });

    test('bill payloads open the bill', () {
      expect(
        notificationTapTarget({'billId': 'abc', 'uid': 'u1'}),
        NotificationTapTarget.bill,
      );
    });

    test('unknown or empty payloads do nothing', () {
      expect(notificationTapTarget({}), NotificationTapTarget.none);
      expect(
        notificationTapTarget({'type': 'other', 'billId': ''}),
        NotificationTapTarget.none,
      );
    });
  });
}
