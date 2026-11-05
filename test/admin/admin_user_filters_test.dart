import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/screens/admin/admin_user_filters.dart';

final _now = DateTime(2026, 11, 5, 12);

AdminUserEntry _u(
  String uid, {
  String? name,
  String? email,
  String? phone,
  bool pro = false,
  String? platform,
  DateTime? created,
  DateTime? lastSync,
  int points = 0,
}) => AdminUserEntry(uid, {
  'displayName': ?name,
  'email': ?email,
  'phoneNumber': ?phone,
  if (pro) 'isPremium': true,
  'fcmPlatform': ?platform,
  if (created != null) 'createdAt': Timestamp.fromDate(created),
  if (lastSync != null) 'fcmTokenUpdatedAt': Timestamp.fromDate(lastSync),
  'points': points,
});

void main() {
  final users = [
    _u(
      'a1',
      name: 'Ali Hassan',
      email: 'ali@x.com',
      phone: '+201012345678',
      pro: true,
      platform: 'ios',
      created: DateTime(2026, 10, 2),
      lastSync: DateTime(2026, 11, 4),
      points: 12,
    ),
    _u(
      'b2',
      name: 'Mona',
      email: 'mona@y.org',
      platform: 'android',
      created: DateTime(2026, 6, 1),
      lastSync: DateTime(2026, 7, 1),
      points: 40,
    ),
    _u('c3', name: 'zed', platform: 'web'),
  ];

  group('query', () {
    test('matches name, email, uid case-insensitively', () {
      expect(adminUserMatchesQuery(users[0], 'ali h'), isTrue);
      expect(adminUserMatchesQuery(users[1], 'Y.ORG'), isTrue);
      expect(adminUserMatchesQuery(users[2], 'C3'), isTrue);
      expect(adminUserMatchesQuery(users[1], 'ali'), isFalse);
    });

    test('matches phone digits ignoring formatting', () {
      expect(adminUserMatchesQuery(users[0], '010 1234'), isTrue);
      expect(adminUserMatchesQuery(users[1], '010 1234'), isFalse);
    });
  });

  group('filters', () {
    List<String> ids(AdminUserFilters f) => [
      for (final e in applyAdminUserFilters(users, f, now: _now)) e.uid,
    ];

    test('plan', () {
      expect(ids(const AdminUserFilters(plan: AdminPlanFilter.pro)), ['a1']);
      expect(
        ids(const AdminUserFilters(plan: AdminPlanFilter.free)),
        unorderedEquals(['b2', 'c3']),
      );
    });

    test('platform', () {
      expect(ids(const AdminUserFilters(platform: 'android')), ['b2']);
    });

    test('activity uses 30-day window, unknown counts as inactive', () {
      expect(
        ids(const AdminUserFilters(activity: AdminActivityFilter.active)),
        ['a1'],
      );
      expect(
        ids(const AdminUserFilters(activity: AdminActivityFilter.inactive)),
        unorderedEquals(['b2', 'c3']),
      );
    });

    test('sign-up range is inclusive and drops unknown dates', () {
      final f = AdminUserFilters(
        signedUpFrom: DateTime(2026, 10, 1),
        signedUpTo: DateTime(2026, 10, 2),
      );
      expect(ids(f), ['a1']);
      expect(f.activeCount, 1);
    });

    test('sorts', () {
      expect(ids(const AdminUserFilters()), ['a1', 'b2', 'c3']);
      expect(ids(const AdminUserFilters(sort: AdminUserSort.oldest)), [
        'b2',
        'a1',
        'c3',
      ]);
      expect(ids(const AdminUserFilters(sort: AdminUserSort.nameAZ)), [
        'a1',
        'b2',
        'c3',
      ]);
      expect(ids(const AdminUserFilters(sort: AdminUserSort.pointsHigh)), [
        'b2',
        'a1',
        'c3',
      ]);
      expect(ids(const AdminUserFilters(sort: AdminUserSort.lastActive)), [
        'a1',
        'b2',
        'c3',
      ]);
    });

    test('copyWith can clear nullable fields; isDefault', () {
      final f = const AdminUserFilters(platform: 'ios');
      expect(f.isDefault, isFalse);
      expect(f.copyWith(platform: () => null).isDefault, isTrue);
    });
  });

  group('pagination and search helpers', () {
    test('merge replaces duplicates by uid', () {
      final merged = mergeAdminUserPages(users.sublist(0, 2), [
        AdminUserEntry('b2', const {'displayName': 'Mona 2'}),
        users[2],
      ]);
      expect(merged.map((e) => e.uid), ['a1', 'b2', 'c3']);
      expect(merged[1].data['displayName'], 'Mona 2');
    });

    test('search kind', () {
      expect(adminSearchKindFor(''), AdminSearchKind.none);
      expect(adminSearchKindFor('ali@x'), AdminSearchKind.email);
      expect(adminSearchKindFor('+20 101'), AdminSearchKind.phone);
      expect(
        adminSearchKindFor('Xy12Ab34Cd56Ef78Gh90Ij12'),
        AdminSearchKind.uid,
      );
      expect(adminSearchKindFor('Ali'), AdminSearchKind.text);
      expect(adminPrefixEnd('ab'), 'ab');
    });

    test('platform falls back to loginPlatform and Apple relay emails', () {
      expect(adminPlatformOf({'loginPlatform': 'Android'}), 'android');
      expect(adminPlatformOf({'email': 'x@privaterelay.appleid.com'}), 'ios');
      expect(adminPlatformOf(const {}), isNull);
    });
  });
}
