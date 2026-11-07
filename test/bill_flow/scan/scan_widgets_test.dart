import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/screens/scan_receipt/review_banner_content.dart';
import 'package:split_bill_app/screens/scan_receipt/scan_error_content.dart';
import 'package:split_bill_app/screens/scan_receipt/widgets/review_banner.dart';
import 'package:split_bill_app/screens/scan_receipt/widgets/scan_error_card.dart';
import 'package:split_bill_app/screens/scan_receipt/widgets/scan_reading_view.dart';
import 'package:split_bill_app/services/receipt_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/receipt_result_view.dart';

Widget _app(Widget child, {bool dark = false, bool reduceMotion = true}) =>
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: c!,
      ),
      home: Scaffold(body: child),
    );

String _plain(String s) => s.replaceAll(RegExp(r'[\u2066\u2069]'), '');

Finder _textPlain(String value) => find.byWidgetPredicate(
  (w) => w is Text && _plain(w.data ?? w.textSpan?.toPlainText() ?? '') == value,
);

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('ReviewBanner', () {
    ReviewBannerContent warning() => buildReviewBanner(
      items: [
        {'name': 'Kunafa', 'price': 7, 'qty': 1, 'confidence_score': 0.4},
      ],
      currency: 'EGP',
      currentTotalMinor: 700,
      reasons: const ['blurry_item'],
      reconciliation: const {'printed_total': 7},
      locale: 'en',
    )!;

    testWidgets('warning uses the coral owe colors', (tester) async {
      await tester.pumpWidget(_app(ReviewBanner(content: warning())));
      final context = tester.element(find.byType(ReviewBanner));
      final p = context.palette;
      final box = tester.widget<Container>(
        find.byKey(const ValueKey('scan-review-banner')),
      );
      expect((box.decoration! as BoxDecoration).color, p.oweSoft);
      // easy_localization is not initialized: keys render as text.
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(ReviewBanner),
          matching: find.byType(Text),
        ),
      );
      expect(text.data, contains('bf_scan_review_total_matches'));
      expect(text.data, contains('bf_scan_review_check_items_blurry'));
      expect(text.style!.color, p.oweInk);
      expect(find.byIcon(AppIcons.warning), findsOneWidget);
    });

    testWidgets('calm tone in dark mode', (tester) async {
      final calm = buildReviewBanner(
        items: const [],
        currency: 'USD',
        currentTotalMinor: 500,
        reconciliation: const {'printed_total': 5},
        locale: 'en',
      )!;
      await tester.pumpWidget(_app(ReviewBanner(content: calm), dark: true));
      final p = tester.element(find.byType(ReviewBanner)).palette;
      expect(p.isDark, isTrue);
      final box = tester.widget<Container>(
        find.byKey(const ValueKey('scan-review-banner')),
      );
      expect((box.decoration! as BoxDecoration).color, p.accentSoft);
      expect(find.byIcon(AppIcons.success), findsOneWidget);
    });
  });

  group('ScanErrorCard', () {
    testWidgets('not a receipt: refund line and both actions', (tester) async {
      final actions = <ScanErrorAction>[];
      final content = scanErrorContentFor(
        classifyScanError(422, {'errorCode': 'too_dark'}),
      );
      await tester.pumpWidget(
        _app(ScanErrorCard(content: content, onAction: actions.add)),
      );
      expect(find.text('bf_scan_err_not_receipt_title'), findsOneWidget);
      expect(
        find.text('bf_scan_err_too_dark bf_scan_err_refunded'),
        findsOneWidget,
      );
      await tester.tap(find.text('bf_scan_retake'));
      await tester.tap(find.text('bf_scan_type_it_in'));
      expect(actions, [ScanErrorAction.retakePhoto, ScanErrorAction.typeItIn]);
    });

    testWidgets('never shows raw server text', (tester) async {
      const e = ReceiptScanException(
        ReceiptScanFailure.unknown,
        serverMessage: 'TypeError: undefined is not a function',
      );
      await tester.pumpWidget(
        _app(ScanErrorCard(content: scanErrorContentFor(e), onAction: (_) {})),
      );
      expect(find.textContaining('TypeError'), findsNothing);
      expect(find.text('bf_scan_err_unknown_title'), findsOneWidget);
      expect(find.text('feedback_try_again'), findsOneWidget);
    });

    testWidgets('camera access off offers settings and choose photo', (
      tester,
    ) async {
      final actions = <ScanErrorAction>[];
      await tester.pumpWidget(
        _app(
          ScanErrorCard(
            content: scanAccessContentFor(
              ScanAccessProblem.cameraDenied,
              canOpenSettings: true,
            ),
            onAction: actions.add,
          ),
        ),
      );
      expect(find.text('bf_scan_err_camera_title'), findsOneWidget);
      await tester.tap(find.text('bf_scan_open_settings'));
      await tester.tap(find.text('bf_scan_choose_photo'));
      expect(actions, [
        ScanErrorAction.openSettings,
        ScanErrorAction.choosePhoto,
      ]);
    });
  });

  testWidgets('reading view shows the wait, privacy note and Cancel', (
    tester,
  ) async {
    var cancelled = false;
    await tester.pumpWidget(
      _app(ScanReadingView(onCancel: () => cancelled = true)),
    );
    expect(find.text('bf_scan_reading_title'), findsOneWidget);
    expect(find.text('bf_scan_reading_eta'), findsOneWidget);
    expect(find.text('bf_scan_privacy_note'), findsOneWidget);
    await tester.tap(find.text('common_cancel'));
    expect(cancelled, isTrue);
  });

  group('ReceiptResultView', () {
    late List<TextEditingController> owned;

    TextEditingController c(String text) {
      final controller = TextEditingController(text: text);
      owned.add(controller);
      return controller;
    }

    setUp(() => owned = []);
    tearDown(() {
      for (final o in owned) {
        o.dispose();
      }
    });

    testWidgets('highlights flagged items and totals in minor units', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final data = <String, dynamic>{
        'restaurant_name': 'Sea Breeze Grill',
        'items': [
          {'name': 'Grilled fish', 'price': 18.5, 'qty': 1},
          {'name': 'Kunafa', 'price': 7.0, 'qty': 1, 'confidence_score': 0.5},
        ],
        'needs_review_reasons': ['blurry_item'],
        'reconciliation': {'printed_total': 29.07},
      };
      await tester.pumpWidget(
        _app(
          ReceiptResultView(
            receiptData: data,
            itemControllers: [
              {'name': c('Grilled fish'), 'qty': c('1'), 'price': c('18.50')},
              {'name': c('Kunafa'), 'qty': c('1'), 'price': c('7.00')},
            ],
            currencyCode: 'EGP',
            restaurantController: c('Sea Breeze Grill'),
            taxController: c('3.57'),
            serviceController: c(''),
            discountController: c(''),
            tipController: c(''),
            deliveryController: c(''),
            onSave: () {},
            onAddItem: (_, _, _) {},
            onUpdateItem: (_, _, _, _) {},
            onDeleteItem: (_) {},
            selectedDate: DateTime(2026, 11, 4),
            onDateChanged: (_) {},
          ),
        ),
      );
      final p = tester.element(find.byType(ReceiptResultView)).palette;

      expect(find.text('Sea Breeze Grill'), findsOneWidget);
      expect(find.textContaining('EGP'), findsWidgets);
      expect(find.byType(ReviewBanner), findsOneWidget);

      final flagged = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('scan-review-item-1')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(flagged.color, p.oweSoft);
      final normal = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('scan-review-item-0')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(normal.color, Colors.transparent);

      // 18.50 + 7.00 + 3.57 = 29.07, two decimals (never one).
      final total = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('scan-review-total')),
          matching: find.byType(Text),
        ),
      );
      expect(_plain(total.data!), contains('29.07'));
      expect(_textPlain('25.50'), findsOneWidget); // subtotal
      expect(find.text('bf_scan_review_add_tip'), findsOneWidget);
      expect(find.text('receipt_add_item'), findsOneWidget);
    });

    testWidgets('lays out in RTL, dark mode, phone width, KWD decimals', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          Directionality(
            textDirection: TextDirection.rtl,
            child: ReceiptResultView(
              receiptData: <String, dynamic>{
                'items': [
                  {'name': 'شاورما', 'price': 1.25, 'qty': 2},
                ],
              },
              itemControllers: [
                {'name': c('شاورما'), 'qty': c('2'), 'price': c('1.250')},
              ],
              currencyCode: 'KWD',
              restaurantController: c(''),
              taxController: c(''),
              serviceController: c('0.250'),
              discountController: c('0.5'),
              tipController: c('0.100'),
              deliveryController: c(''),
              onSave: () {},
              onAddItem: (_, _, _) {},
              onUpdateItem: (_, _, _, _) {},
              onDeleteItem: (_) {},
              selectedDate: DateTime(2026, 11, 4),
              onDateChanged: (_) {},
            ),
          ),
          dark: true,
        ),
      );
      expect(tester.takeException(), isNull);
      // 2.500 + 0.250 + 0.100 - 0.500 = 2.350
      final total = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('scan-review-total')),
          matching: find.byType(Text),
        ),
      );
      expect(_plain(total.data!), contains('2.350'));
      // No banner when there is nothing to review.
      expect(find.byType(ReviewBanner), findsNothing);
    });
  });
}
