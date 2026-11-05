import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/screens/admin/admin_user_filters.dart';
import 'package:split_bill_app/screens/admin/admin_users_screen.dart';
import 'package:split_bill_app/screens/admin/user_admin_detail_screen.dart';
import 'package:split_bill_app/services/admin_user_actions.dart';
import 'package:split_bill_app/services/admin_users_source.dart';
import 'package:split_bill_app/utils/app_theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

import 'fake_admin_backend.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

class _FakeSource implements AdminUsersSource {
  _FakeSource(this.all);
  final List<AdminUserEntry> all;
  int pages = 0;

  @override
  Future<AdminUsersPage> fetchPage({Object? cursor, int limit = 50}) async {
    pages++;
    final start = (cursor as int?) ?? 0;
    final end = (start + limit).clamp(0, all.length);
    return AdminUsersPage(
      all.sublist(start, end),
      cursor: end,
      hasMore: end < all.length,
    );
  }

  @override
  Future<List<AdminUserEntry>> search(String query) async => const [];
}

Future<void> _mount(
  WidgetTester tester,
  Widget home, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      startLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const _Translations(),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: home,
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

List<AdminUserEntry> _users(int n) => [
  for (var i = 0; i < n; i++)
    AdminUserEntry('uid$i', {
      'displayName': 'User $i',
      'email': 'user$i@x.com',
      if (i == 1) 'isPremium': true,
      'fcmPlatform': i.isEven ? 'ios' : 'android',
      'points': i,
    }),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  tearDown(AppToast.hide);

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('users list paginates and filters (${mode.name})', (
      tester,
    ) async {
      final source = _FakeSource(_users(60));
      await _mount(
        tester,
        AdminUsersScreen(source: source, debugIsAdmin: true),
        themeMode: mode,
      );
      expect(find.text('50 users loaded'), findsOneWidget);
      expect(find.text('User 0'), findsOneWidget);

      // Scrolling near the end loads the next page (infinite scroll; the
      // "Load more" button is the fallback).
      for (var i = 0; i < 8; i++) {
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -1500),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(source.pages, 2);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 20000));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('60 users loaded'), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-users-load-more')), findsNothing);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 5000));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        find.byKey(const ValueKey('admin-users-search')),
        'User 5',
      );
      await tester.pump(const Duration(milliseconds: 400));
      // "User 5" plus "User 50".."User 59".
      expect(find.text('11 of 60 users'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('admin-users-filters')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.tap(find.text('Android'));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-filters-apply')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('admin-filters-apply')));
      await tester.pump(const Duration(milliseconds: 400));
      // Odd numbers only: 5, 51, 53, 55, 57, 59.
      expect(find.text('6 of 60 users'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('non-admins see the admins-only state', (tester) async {
    await _mount(
      tester,
      AdminUsersScreen(source: _FakeSource(const []), debugIsAdmin: false),
    );
    expect(find.text('Admins only'), findsOneWidget);
  });

  group('user detail', () {
    late FakeAdminBackend backend;
    late StreamController<Map<String, dynamic>?> stream;
    const user = {
      'displayName': 'Ali',
      'email': 'ali@x.com',
      'phoneNumber': '+201000000001',
      'points': 5,
      'fcmPlatform': 'ios',
    };

    setUp(() {
      backend = FakeAdminBackend({'users/u1': Map<String, dynamic>.of(user)});
      stream = StreamController<Map<String, dynamic>?>.broadcast();
    });
    tearDown(() => stream.close());

    Widget detail({String adminUid = 'admin'}) => UserAdminDetailScreen(
      uid: 'u1',
      userData: user,
      userStream: stream.stream,
      adminUid: adminUid,
      actions: AdminUserActions(backend: backend, adminUid: adminUid),
      loadCounts: () async => const AdminUserCounts(bills: 3, groups: 2),
      loadBills: () async => const [],
    );

    Future<void> tapAction(WidgetTester tester, String key) async {
      final f = find.byKey(ValueKey(key));
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
      await tester.pump(const Duration(milliseconds: 400));
    }

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('shows info and counts (${mode.name})', (tester) async {
        await _mount(tester, detail(), themeMode: mode);
        expect(find.text('Ali'), findsOneWidget);
        expect(find.text('ali@x.com'), findsOneWidget);
        expect(find.text('iOS'), findsWidgets);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Not available yet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('cancelling a confirmation writes nothing', (tester) async {
      await _mount(tester, detail());
      await tapAction(tester, 'admin-suspend');
      expect(find.text('Suspend account'), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(backend.commits, isEmpty);
    });

    testWidgets('confirming grant points writes change and audit', (
      tester,
    ) async {
      await _mount(tester, detail());
      await tapAction(tester, 'admin-grant-10');
      expect(find.text('Change points from 5 to 15?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('admin-confirm')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(backend.docs['users/u1']!['points'], 15);
      expect(backend.audits.single['action'], 'points.set');
      expect(find.text('Points set to 15'), findsOneWidget);
    });

    testWidgets('delete needs the typed email', (tester) async {
      await _mount(tester, detail());
      await tapAction(tester, 'admin-delete-data');
      FilledButton confirm() => tester.widget<FilledButton>(
        find.byKey(const ValueKey('admin-confirm')),
      );
      expect(confirm().onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('admin-delete-confirm-field')),
        'wrong',
      );
      await tester.pump();
      expect(confirm().onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('admin-delete-confirm-field')),
        'ali@x.com',
      );
      await tester.pump();
      expect(confirm().onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('admin-confirm')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(backend.docs.containsKey('users/u1'), isFalse);
      expect(backend.audits.single['action'], 'user.deleteData');
    });

    testWidgets('own account: remove admin, suspend and delete disabled', (
      tester,
    ) async {
      backend.docs['users/u1']!['isAdmin'] = true;
      await _mount(
        tester,
        UserAdminDetailScreen(
          uid: 'u1',
          userData: const {...user, 'isAdmin': true},
          userStream: stream.stream,
          adminUid: 'u1',
          actions: AdminUserActions(backend: backend, adminUid: 'u1'),
          loadCounts: () async => const AdminUserCounts(),
          loadBills: () async => const [],
        ),
      );
      for (final key in ['admin-role', 'admin-suspend', 'admin-delete-data']) {
        final f = find.byKey(ValueKey(key));
        await tester.ensureVisible(f);
        await tester.pump();
        expect(tester.widget<OutlinedButton>(f).onPressed, isNull, reason: key);
      }
    });
  });
}
