import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/services/admin_user_actions.dart';

import 'fake_admin_backend.dart';

void main() {
  late FakeAdminBackend backend;
  late AdminUserActions actions;

  setUp(() {
    backend = FakeAdminBackend({
      'users/u1': {
        'displayName': 'Ali',
        'email': 'ali@x.com',
        'phoneNumber': '+201000000001',
        'isoCode': 'EG',
        'points': 5,
      },
      'users/admin': {'isAdmin': true},
    });
    actions = AdminUserActions(backend: backend, adminUid: 'admin');
  });

  void expectAudit(String action, {Map<String, Object?>? details}) {
    final audit = backend.audits.single;
    expect(audit['action'], action);
    expect(audit['adminUid'], 'admin');
    expect(audit['targetUid'], 'u1');
    expect(audit['at'], AdminValue.serverTime);
    if (details != null) expect(audit['details'], details);
  }

  test('points are set with from/to in the same commit as the audit', () async {
    final r = await actions.setPoints('u1', currentPoints: 5, newPoints: 15);
    expect(r.auditLogged, isTrue);
    expect(backend.docs['users/u1']!['points'], 15);
    expect(backend.commits.single.length, 2);
    expectAudit('points.set', details: {'from': 5, 'to': 15, 'delta': 10});
  });

  test('points outside range are rejected', () {
    expect(
      () => actions.setPoints('u1', currentPoints: 5, newPoints: -1),
      throwsA(isA<AdminActionException>()),
    );
    expect(backend.commits, isEmpty);
  });

  test('premium grant writes override fields; revoke turns it off', () async {
    await actions.setPremium('u1', grant: true);
    final u = backend.docs['users/u1']!;
    expect(u['isPremium'], isTrue);
    expect(u['premiumStore'], 'admin_override');
    expect(u['premiumExpiresAt'], isNull);
    expectAudit('premium.grant');

    await actions.setPremium('u1', grant: false);
    expect(backend.docs['users/u1']!['isPremium'], isFalse);
    expect(backend.audits.length, 2);
  });

  test('admin role; cannot remove your own', () async {
    await actions.setAdmin('u1', admin: true);
    expect(backend.docs['users/u1']!['isAdmin'], isTrue);
    expectAudit('admin.grant');
    expect(
      () => actions.setAdmin('admin', admin: false),
      throwsA(
        isA<AdminActionException>().having(
          (e) => e.error,
          'error',
          AdminActionError.selfTarget,
        ),
      ),
    );
  });

  test('suspend and unsuspend', () async {
    await actions.setSuspended('u1', suspended: true, reason: 'spam');
    var u = backend.docs['users/u1']!;
    expect(u['suspended'], isTrue);
    expect(u['suspendedBy'], 'admin');
    expect(u['suspendedAt'], AdminValue.serverTime);
    expectAudit('user.suspend', details: {'reason': 'spam'});

    await actions.setSuspended('u1', suspended: false);
    u = backend.docs['users/u1']!;
    expect(u['suspended'], isFalse);
    expect(u.containsKey('suspendedBy'), isFalse);
    expect(
      () => actions.setSuspended('admin', suspended: true),
      throwsA(isA<AdminActionException>()),
    );
  });

  test(
    'suspend goes through the backend when it can, so Auth is disabled',
    () async {
      final calls = <(String, bool, String?)>[];
      final viaBackend = AdminUserActions(
        backend: backend,
        adminUid: 'admin',
        accountDisabler: (uid, {required disabled, reason}) async {
          calls.add((uid, disabled, reason));
          return true;
        },
      );

      final r = await viaBackend.setSuspended(
        'u1',
        suspended: true,
        reason: 'spam',
      );

      expect(calls, [('u1', true, 'spam')]);
      expect(r.authUpdated, isTrue);
      // The backend wrote the flags and audit entry; nothing local.
      expect(backend.commits, isEmpty);

      await viaBackend.setSuspended('u1', suspended: false);
      expect(calls.last, ('u1', false, null));
    },
  );

  test(
    'suspend falls back to the Firestore flag when the backend fails',
    () async {
      final fallback = AdminUserActions(
        backend: backend,
        adminUid: 'admin',
        accountDisabler: (uid, {required disabled, reason}) async => false,
      );

      final r = await fallback.setSuspended('u1', suspended: true);

      expect(r.authUpdated, isFalse);
      expect(backend.docs['users/u1']!['suspended'], isTrue);
      expectAudit('user.suspend');
    },
  );

  test('reset phone claim, optionally clearing the profile', () async {
    backend.docs['phoneClaims/+201000000001'] = {'uid': 'u1'};
    await actions.resetPhoneClaim(
      'u1',
      phone: '+201000000001',
      clearPhone: true,
    );
    expect(backend.docs.containsKey('phoneClaims/+201000000001'), isFalse);
    expect(backend.docs['users/u1']!.containsKey('phoneNumber'), isFalse);
    expectAudit(
      'phone.reset',
      details: {'phone': '+201000000001', 'clearedProfile': true},
    );
  });

  test('notification send is audit-only', () async {
    await actions.logNotificationSent('u1', title: 'Hi');
    expectAudit('notification.send', details: {'title': 'Hi'});
  });

  group('delete user data', () {
    setUp(() {
      backend.docs.addAll({
        'users/u1/notifications/n1': {'title': 'x'},
        'bills/b1': {'hostId': 'u1'},
        'bills/b2': {'hostId': 'other'},
        'groups/g1': {'createdBy': 'u1'},
        'groups/g2': {'ownerId': 'u1'},
        'groups/g3': {'createdBy': 'other'},
        'publicProfiles/u1': {'displayName': 'Ali'},
        'phoneClaims/+201000000001': {'uid': 'u1'},
      });
    });

    test('confirmation must match the email, or uid without email', () {
      expect(
        isDeleteConfirmationValid(
          typed: 'ALI@x.com ',
          uid: 'u1',
          email: 'ali@x.com',
        ),
        isTrue,
      );
      expect(
        isDeleteConfirmationValid(typed: 'u1', uid: 'u1', email: 'ali@x.com'),
        isFalse,
      );
      expect(isDeleteConfirmationValid(typed: 'u1', uid: 'u1'), isTrue);
      expect(isDeleteConfirmationValid(typed: '', uid: 'u1'), isFalse);
      expect(deleteConfirmationTarget(uid: 'u1', email: ''), 'u1');
    });

    test('mismatch deletes nothing', () async {
      await expectLater(
        actions.deleteUserData(
          'u1',
          typedConfirmation: 'nope',
          email: 'ali@x.com',
        ),
        throwsA(isA<AdminActionException>()),
      );
      expect(backend.commits, isEmpty);
    });

    test(
      'deletes owned data, keeps others, user doc last with audit',
      () async {
        await actions.deleteUserData(
          'u1',
          typedConfirmation: 'ali@x.com',
          email: 'ali@x.com',
          phone: '+201000000001',
        );
        for (final gone in [
          'users/u1',
          'users/u1/notifications/n1',
          'bills/b1',
          'groups/g1',
          'groups/g2',
          'publicProfiles/u1',
          'phoneClaims/+201000000001',
        ]) {
          expect(backend.docs.containsKey(gone), isFalse, reason: gone);
        }
        expect(backend.docs.containsKey('bills/b2'), isTrue);
        expect(backend.docs.containsKey('groups/g3'), isTrue);
        final last = backend.commits.last;
        expect(last.map((w) => w.path), contains('users/u1'));
        expect(last.any((w) => w.path.startsWith('adminAudit/')), isTrue);
        expectAudit('user.deleteData');
      },
    );

    test('a phone claim owned by someone else is kept', () async {
      backend.docs['phoneClaims/+201000000001'] = {'uid': 'someone'};
      await actions.deleteUserData(
        'u1',
        typedConfirmation: 'ali@x.com',
        email: 'ali@x.com',
        phone: '+201000000001',
      );
      expect(backend.docs.containsKey('phoneClaims/+201000000001'), isTrue);
    });
  });

  test(
    'audit refused by rules: change still applies, reported unlogged',
    () async {
      backend.denyAudit = true;
      final r = await actions.setPoints('u1', currentPoints: 5, newPoints: 6);
      expect(r.auditLogged, isFalse);
      expect(backend.docs['users/u1']!['points'], 6);
      expect(backend.audits, isEmpty);
    },
  );
}
