import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

Widget _app(Widget home, {bool reduceMotion = false, bool dark = false}) =>
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: home,
    );

String _plain(String s) => s.replaceAll(RegExp('[\u2066\u2069]'), '');

Finder _textPlain(String value) => find.byWidgetPredicate(
  (w) => w is Text && w.data != null && _plain(w.data!) == value,
);

final _confetti = find.byWidgetPredicate(
  (w) =>
      w is CustomPaint &&
      w.painter.runtimeType.toString() == '_ConfettiPainter',
);

void main() {
  final haptics = <String>[];

  setUp(() {
    haptics.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add('${call.arguments}');
          }
          return null;
        });
  });

  tearDown(() {
    AppToast.hide();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('SuccessScreen', () {
    testWidgets('renders, animates to the final amount, calls actions and '
        'fires a success haptic', (tester) async {
      var primary = 0;
      var secondary = 0;
      await tester.pumpWidget(
        _app(
          SuccessScreen(
            title: 'Bill saved',
            message: '4 people notified',
            amountMinor: 6240,
            currency: 'USD',
            celebrate: true,
            primaryLabel: 'Share',
            onPrimary: () => primary++,
            secondaryLabel: 'Done',
            onSecondary: () => secondary++,
          ),
        ),
      );
      expect(find.text('Bill saved'), findsOneWidget);
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      // Confetti is painted for big moments.
      expect(_confetti, findsWidgets);

      await tester.pumpAndSettle();
      expect(_textPlain(r'$62.40'), findsOneWidget);

      await tester.tap(find.text('Share'));
      await tester.tap(find.text('Done'));
      expect(primary, 1);
      expect(secondary, 1);
    });

    testWidgets('reduce motion: no confetti, settles in a 150 ms crossfade, '
        'haptic still fires', (tester) async {
      await tester.pumpWidget(
        _app(
          SuccessScreen(
            title: 'Everyone is square',
            rollFromMinor: 4100,
            amountMinor: 0,
            celebrate: true,
            primaryLabel: 'OK',
            onPrimary: () {},
          ),
          reduceMotion: true,
        ),
      );
      expect(haptics, hasLength(1));
      expect(_confetti, findsNothing);
      await tester.pump(AppMotion.reducedCrossfade);
      await tester.pump(const Duration(milliseconds: 400));
      final title = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Everyone is square'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(title.opacity, 1);
      // Rolled to zero.
      final zero = tester.widget<Opacity>(
        find
            .ancestor(of: _textPlain(r'$0.00'), matching: find.byType(Opacity))
            .first,
      );
      expect(zero.opacity, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('show() pushes it as a route', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => SuccessScreen.show<void>(
                  context,
                  title: 'Paid',
                  primaryLabel: 'Close',
                  onPrimary: () => Navigator.of(context).pop(),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Paid'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Paid'), findsNothing);
    });
  });

  group('AppToast', () {
    Future<BuildContext> host(
      WidgetTester tester, {
      bool reduce = false,
    }) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox.expand();
              },
            ),
          ),
          reduceMotion: reduce,
        ),
      );
      return ctx;
    }

    testWidgets('shows, is a live region, and auto-dismisses', (tester) async {
      final ctx = await host(tester);
      final handle = AppToast.show(
        ctx,
        message: 'Bill saved',
        type: AppToastType.success,
      );
      await tester.pump();
      await tester.pump(AppMotion.slow);
      expect(find.text('Bill saved'), findsOneWidget);
      expect(handle.isShowing, isTrue);
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      final live = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      );
      expect(live, findsOneWidget);

      await tester.pump(AppMotion.toastVisible);
      await tester.pumpAndSettle();
      expect(find.text('Bill saved'), findsNothing);
      expect(handle.isShowing, isFalse);
    });

    testWidgets('action runs and closes; dismiss() closes', (tester) async {
      final ctx = await host(tester);
      var undone = 0;
      AppToast.show(
        ctx,
        message: 'Removed',
        position: AppToastPosition.top,
        actionLabel: 'Undo',
        onAction: () => undone++,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text('Removed'), findsNothing);

      final handle = AppToast.show(ctx, message: 'Second');
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsOneWidget);
      // Not awaited: the reverse animation needs frames pumped below.
      handle.dismiss();
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsNothing);
    });

    testWidgets('swipe to dismiss and one toast at a time', (tester) async {
      final ctx = await host(tester, reduce: true);
      AppToast.show(ctx, message: 'First');
      AppToast.show(ctx, message: 'Swipe me', type: AppToastType.error);
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(find.text('Swipe me'), findsOneWidget);
      await tester.drag(find.text('Swipe me'), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Swipe me'), findsNothing);
    });
  });

  group('ErrorState', () {
    testWidgets('full screen retry and secondary', (tester) async {
      var retries = 0;
      var other = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ErrorState(
              title: 'Could not load bills',
              message: 'Check your connection.',
              retryLabel: 'Retry',
              onRetry: () => retries++,
              secondaryLabel: 'Go home',
              onSecondary: () => other++,
            ),
          ),
        ),
      );
      expect(find.text('Could not load bills'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.tap(find.text('Go home'));
      expect(retries, 1);
      expect(other, 1);
    });

    testWidgets('inline variant in dark mode', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ErrorState.inline(
              title: "We couldn't read this receipt",
              message: 'The photo is too dark.',
              retryLabel: 'Retake photo',
              onRetry: () => retries++,
            ),
          ),
          dark: true,
        ),
      );
      await tester.tap(find.text('Retake photo'));
      expect(retries, 1);
    });
  });

  testWidgets('OfflineBanner shows and hides', (tester) async {
    Widget build(bool visible) => _app(
      Scaffold(
        body: Column(
          children: [OfflineBanner(visible: visible, message: 'Offline now')],
        ),
      ),
    );
    await tester.pumpWidget(build(true));
    await tester.pumpAndSettle();
    expect(find.text('Offline now'), findsOneWidget);
    await tester.pumpWidget(build(false));
    await tester.pumpAndSettle();
    expect(find.text('Offline now'), findsNothing);
  });

  testWidgets('Skeleton shimmers, and is static under reduce motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: SkeletonShimmer(
            child: Column(children: [SkeletonCard(), SkeletonListTile()]),
          ),
        ),
      ),
    );
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(
      _app(
        const Scaffold(body: Column(children: [Skeleton.line(width: 100)])),
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('EmptyState action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: EmptyState(
            title: 'No bills yet',
            message: 'Scan a receipt to start.',
            actionLabel: 'Scan',
            onAction: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Scan'));
    expect(taps, 1);
  });
}
