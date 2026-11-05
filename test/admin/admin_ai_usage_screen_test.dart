import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/screens/admin/admin_ai_usage_screen.dart';
import 'package:split_bill_app/services/admin_ai_usage_service.dart';
import 'package:split_bill_app/utils/app_theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

import 'admin_ai_usage_service_test.dart' show sampleBody;

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

Future<void> _mount(
  WidgetTester tester,
  AiUsageLoader loader, {
  ThemeMode themeMode = ThemeMode.light,
  String locale = 'en',
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(locale),
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
          home: AdminAiUsageScreen(loader: loader),
        ),
      ),
    ),
  );
  // Let translations load and the loader future resolve; the skeleton
  // shimmer loops, so no pumpAndSettle.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

AiUsageReport _report() => AiUsageReport.fromJson(sampleBody);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('shows total, chart and per-feature rows (${mode.name})', (
      tester,
    ) async {
      final asked = <int>[];
      await _mount(tester, (days) async {
        asked.add(days);
        return AiUsageLoaded(_report());
      }, themeMode: mode);

      expect(tester.takeException(), isNull);
      expect(asked, [7]);
      expect(find.byKey(const ValueKey('ai-total')), findsOneWidget);
      expect(find.text(r'$2.75'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is AiCostChartPainter,
        ),
        findsOneWidget,
      );
      // receipt + voice_assign rows show their costs.
      expect(find.text(r'$2.50'), findsOneWidget);
      expect(find.text(r'$0.25'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ai-range-30')));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(asked, [7, 30]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('404 shows the not-deployed empty state (${mode.name})', (
      tester,
    ) async {
      await _mount(
        tester,
        (_) async => const AiUsageNotDeployed(),
        themeMode: mode,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-total')), findsNothing);
    });
  }

  testWidgets('unauthorized and failure show an error state', (tester) async {
    await _mount(tester, (_) async => const AiUsageUnauthorized());
    expect(find.byType(ErrorState), findsOneWidget);
    await _mount(tester, (_) async => const AiUsageFailed('x'));
    expect(find.byType(ErrorState), findsOneWidget);
  });

  testWidgets('renders right to left', (tester) async {
    await _mount(tester, (_) async => AiUsageLoaded(_report()), locale: 'ar');
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('ai-total')), findsOneWidget);
  });
}
