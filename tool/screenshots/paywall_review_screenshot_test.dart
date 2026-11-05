// Generates the App Store review screenshot of the paywall.
// Run: flutter test tool/screenshots/paywall_review_screenshot_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/utils/app_theme.dart';
import 'package:split_bill_app/widgets/paywall/paywall_plans.dart';
import 'package:split_bill_app/widgets/premium_modal.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/${locale.languageCode}.json')
              .readAsStringSync())
          as Map<String, dynamic>;
}

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('paywall review screenshot', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    const inter = 'assets/fonts/Inter';
    await _font('Inter', [
      '$inter/Inter-Regular.ttf',
      '$inter/Inter-Medium.ttf',
      '$inter/Inter-SemiBold.ttf',
      '$inter/Inter-Bold.ttf',
    ]);
    await _font('InterTight', [
      'assets/fonts/InterTight/InterTight-SemiBold.ttf',
      'assets/fonts/InterTight/InterTight-Bold.ttf',
    ]);
    final sdk = File(Platform.resolvedExecutable).parent.path; // unused fallback
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
    final icons = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      await _font('MaterialIcons', [icons.path]);
    }
    sdk.length;

    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: const _Translations(),
        child: Builder(
          builder: (context) => RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: AppTheme.lightTheme,
              themeMode: ThemeMode.light,
              home: PremiumModal.preview(
                loadPlans: () async => const [
                  PaywallPlan(
                    kind: PaywallPlanKind.yearly,
                    price: 24.99,
                    priceString: r'$24.99',
                    currencyCode: 'USD',
                    perMonthString: r'$2.08',
                    freeTrialDays: 7,
                  ),
                  PaywallPlan(
                    kind: PaywallPlanKind.monthly,
                    price: 2.99,
                    priceString: r'$2.99',
                    currencyCode: 'USD',
                  ),
                  PaywallPlan(
                    kind: PaywallPlanKind.lifetime,
                    price: 59.99,
                    priceString: r'$59.99',
                    currencyCode: 'USD',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    debugDefaultTargetPlatformOverride = null;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('docs/2.0/store/paywall_yearly_1290x2796.png');
      out.createSync(recursive: true);
      out.writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
