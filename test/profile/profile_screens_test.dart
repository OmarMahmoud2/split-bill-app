import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/edit_profile_screen.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/screens/profile/appearance_screen.dart';
import 'package:split_bill_app/screens/profile/reminders_screen.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_content.dart';
import 'package:split_bill_app/services/reminder_prefs.dart';
import 'package:split_bill_app/theme/theme.dart';

/// Overridable so the suite can run against a translations checkout.
const _dir = String.fromEnvironment(
  'TRANSLATIONS_DIR',
  defaultValue: 'assets/translations',
);

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$_dir/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

class _FakeSettings extends AppSettingsProvider {
  ThemeMode mode = ThemeMode.system;
  Locale current = const Locale('en');
  final List<ThemeMode> themeCalls = [];
  final List<String> localeCalls = [];

  @override
  ThemeMode get themeMode => mode;
  @override
  Locale get locale => current;
  @override
  String get currencyCode => 'USD';
  @override
  bool get hapticsEnabled => true;

  @override
  Future<void> updateThemeMode(ThemeMode m) async {
    themeCalls.add(m);
    mode = m;
    notifyListeners();
  }

  @override
  Future<void> updateLocale(Locale l) async {
    localeCalls.add(l.languageCode);
    current = l;
    notifyListeners();
  }
}

Future<_FakeSettings> _mount(
  WidgetTester tester,
  Widget home, {
  ThemeMode mode = ThemeMode.light,
  String locale = 'en',
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final settings = _FakeSettings();
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(locale),
      saveLocale: false,
      path: _dir,
      assetLoader: const _Translations(),
      child: ChangeNotifierProvider<AppSettingsProvider>.value(
        value: settings,
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            home: home,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

const _view = ProfileViewData(
  name: 'Omar M',
  points: 3,
  paymentMethodCount: 3,
  monthlyPrice: r'$2.99',
  appearanceLabel: 'System',
  languageLabel: 'English',
  currencyCode: 'EGP',
  remindersSummary: 'Fri, 7 PM',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppMotion.debugReduceMotionOverride = true;
    await EasyLocalization.ensureInitialized();
  });
  tearDown(() => AppMotion.debugReduceMotionOverride = null);

  group('ProfileContent', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('free user layout (${mode.name})', (tester) async {
        final actions = <ProfileAction>[];
        await _mount(
          tester,
          Scaffold(
            body: ProfileContent(
              data: _view,
              onAction: actions.add,
              onHapticsChanged: (_) {},
            ),
          ),
          mode: mode,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Omar M'), findsOneWidget);
        expect(find.text('Free plan · points: 3'), findsOneWidget);
        expect(find.text(r'Go Pro, $2.99 a month'), findsOneWidget);
        expect(find.text('Payment methods'), findsOneWidget);
        expect(find.text('Fri, 7 PM'), findsOneWidget);
        expect(find.text('EGP'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('profile-go-pro')));
        await tester.tap(find.byKey(const ValueKey('profile-subscription')));
        await tester.tap(find.byKey(const ValueKey('profile-appearance')));
        expect(actions, [
          ProfileAction.goPro,
          ProfileAction.subscription,
          ProfileAction.appearance,
        ]);

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('profile-export')),
          200,
        );
        expect(find.text('PRO'), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('profile-export')));
        expect(actions.last, ProfileAction.export);
        // No admin section for regular users.
        expect(find.byKey(const ValueKey('profile-admin')), findsNothing);
      });
    }

    testWidgets('Pro user: no Go Pro card or badges, admin row shown', (
      tester,
    ) async {
      await _mount(
        tester,
        Scaffold(
          body: ProfileContent(
            data: const ProfileViewData(
              name: 'Ali',
              isPro: true,
              planLabel: 'Yearly',
              appearanceLabel: 'Dark',
              languageLabel: 'English',
              currencyCode: 'USD',
              remindersSummary: 'Off',
              isAdmin: true,
            ),
            onAction: (_) {},
            onHapticsChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Pro · Yearly'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-go-pro')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-admin')),
        200,
      );
      expect(find.text('PRO'), findsNothing);
      expect(find.byKey(const ValueKey('profile-watch-ad')), findsNothing);
    });

    testWidgets('haptics switch reports changes', (tester) async {
      bool? changed;
      await _mount(
        tester,
        Scaffold(
          body: ProfileContent(
            data: _view,
            onAction: (_) {},
            onHapticsChanged: (v) => changed = v,
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-haptics')),
        200,
      );
      await tester.tap(find.byType(Switch).first);
      expect(changed, isFalse);
    });

    testWidgets('renders right to left in Arabic', (tester) async {
      await _mount(
        tester,
        Scaffold(
          body: ProfileContent(
            data: _view,
            onAction: (_) {},
            onHapticsChanged: (_) {},
          ),
        ),
        locale: 'ar',
      );
      expect(tester.takeException(), isNull);
      final dir = Directionality.of(tester.element(find.text('Omar M')));
      expect(dir, ui.TextDirection.rtl);
    });
  });

  group('AppearanceScreen', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('three options; selecting calls the provider (${mode.name})', (
        tester,
      ) async {
        final settings = await _mount(
          tester,
          const AppearanceScreen(),
          mode: mode,
        );
        expect(tester.takeException(), isNull);
        for (final m in ThemeMode.values) {
          expect(find.byKey(ValueKey('appearance-${m.name}')), findsOneWidget);
        }
        await tester.tap(find.byKey(const ValueKey('appearance-dark')));
        await tester.pump();
        expect(settings.themeCalls, [ThemeMode.dark]);
        expect(find.text('LANGUAGE · 22'), findsOneWidget);
      });
    }

    testWidgets('tapping a language applies it', (tester) async {
      final settings = await _mount(tester, const AppearanceScreen());
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('language-ar')),
        200,
      );
      await tester.tap(find.byKey(const ValueKey('language-ar')));
      await tester.pumpAndSettle();
      expect(settings.localeCalls, ['ar']);
    });
  });

  group('RemindersScreen', () {
    testWidgets('loads prefs, toggles save, failure reverts', (tester) async {
      final saved = <ReminderPrefs>[];
      var fail = false;
      await _mount(
        tester,
        RemindersScreen(
          debugUserName: 'Omar',
          debugLoad: () async => ReminderPrefs.defaults,
          debugSave: (p) async {
            if (fail) throw Exception('offline');
            saved.add(p);
          },
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Nudge friends who owe me'), findsOneWidget);
      expect(find.text('22:00–08:00'), findsOneWidget);
      expect(find.text('Omar is waiting on \$41.00'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('rem-monthly')));
      await tester.pump();
      expect(saved.single.monthlySummary, isTrue);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      fail = true;
      await tester.tap(find.byKey(const ValueKey('rem-trip')));
      await tester.pump();
      await tester.pump();
      final trip = tester.widget<Switch>(
        find.descendant(
          of: find.byKey(const ValueKey('rem-trip')),
          matching: find.byType(Switch),
        ),
      );
      expect(trip.value, isTrue, reason: 'reverted after failed save');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('dark mode renders', (tester) async {
      await _mount(
        tester,
        RemindersScreen(
          debugUserName: 'Omar',
          debugLoad: () async => const ReminderPrefs(enabled: false),
          debugSave: (_) async {},
        ),
        mode: ThemeMode.dark,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Off'), findsOneWidget);
    });
  });

  group('normalizeOptionalPhone', () {
    test('accepts E.164 with spacing, empty, rejects local numbers', () {
      expect(normalizeOptionalPhone('+20 10 1234 5678'), '+201012345678');
      expect(normalizeOptionalPhone(''), '');
      expect(normalizeOptionalPhone('  '), '');
      expect(normalizeOptionalPhone('010 1234 5678'), isNull);
      expect(normalizeOptionalPhone('+0123'), isNull);
    });
  });
}
