import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/services/contact_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const contactsChannel = MethodChannel('flutter_contacts');
  const pickerChannel = MethodChannel('net.omarmali.splitapp/contact_picker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(contactsChannel, null);
    messenger.setMockMethodCallHandler(pickerChannel, null);
  });

  for (final permission in ['granted', 'limited']) {
    test('reads iOS contact details with $permission permission', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      messenger.setMockMethodCallHandler(contactsChannel, (call) async {
        if (call.method == 'permissions.request') {
          expect(call.arguments, {'type': 'read'});
          return permission;
        }
        expect(call.method, 'crud.getAll');
        expect(
          (call.arguments as Map)['properties'],
          unorderedEquals(['name', 'phone', 'email']),
        );
        return [
          {
            'id': 'contact-1',
            'displayName': 'Mona',
            'phones': [
              {
                'number': '+201012345678',
                'label': {'label': 'mobile'},
              },
            ],
            'emails': [
              {
                'address': 'mona@example.com',
                'label': {'label': 'home'},
              },
            ],
          },
        ];
      });

      final contacts = await ContactService().getAllContacts();
      expect(contacts, hasLength(1));
      expect(contacts!.single.id, 'contact-1');
      expect(contacts.single.displayName, 'Mona');
      expect(contacts.single.phones.single.number, '+201012345678');
      expect(contacts.single.emails.single.address, 'mona@example.com');
    });
  }

  test('does not fetch contacts after iOS permission is denied', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(contactsChannel, (call) async {
      expect(call.method, 'permissions.request');
      return 'permanentlyDenied';
    });

    expect(await ContactService().getAllContacts(), isNull);
  });

  test('preserves Android system picker without contacts permission', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(contactsChannel, (call) async {
      fail('Android must use the system picker without reading contacts.');
    });
    messenger.setMockMethodCallHandler(pickerChannel, (call) async {
      expect(call.method, 'pickContacts');
      expect(call.arguments, {'selectionLimit': 50});
      return [
        {
          'id': 'picker-1',
          'displayName': 'Mona',
          'phones': [' +201012345678 ', ''],
          'emails': ['mona@example.com'],
        },
        {'id': 'picker-2', 'displayName': 'No phone', 'phones': <String>[]},
      ];
    });

    final contacts = await ContactService().getAllContacts();
    expect(contacts, hasLength(1));
    expect(contacts!.single.id, 'picker-1');
    expect(contacts.single.phones.single.number, '+201012345678');
    expect(contacts.single.emails.single.address, 'mona@example.com');
  });
}
