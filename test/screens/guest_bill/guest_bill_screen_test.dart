import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/guest_bill_screen.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/screens/guest_bill/widgets/guest_share.dart';
import 'package:split_bill_app/screens/guest_bill/widgets/guest_status_views.dart';
import 'package:split_bill_app/screens/guest_bill/guest_bill_model.dart';
import 'package:split_bill_app/screens/guest_bill/guest_bill_repository.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/pal_avatar.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

import 'guest_bill_model_test.dart' show seaBreeze;

// Without EasyLocalization loaded, `.tr()` returns the key, so these tests
// look for translation keys.

class FakeRepo implements GuestBillRepository {
  final controller = StreamController<Map<String, dynamic>?>.broadcast();
  final submissions = <(String, String?)>[];
  final notices = <GuestPaymentNotice>[];
  bool failSubmit = false;
  GuestProof? nextProof;
  int watchCount = 0;

  @override
  Stream<Map<String, dynamic>?> watch(String billId) {
    watchCount++;
    return controller.stream;
  }

  @override
  Future<void> submitPayment({
    required String billId,
    required String participantId,
    String? proofDataUrl,
    String? method,
  }) async {
    if (failSubmit) throw StateError('offline');
    submissions.add((participantId, proofDataUrl));
  }

  @override
  Future<void> notifyHost(GuestPaymentNotice notice) async =>
      notices.add(notice);

  @override
  Future<GuestProof?> pickProof() async => nextProof;
}

Map<String, dynamic> withStatus(String id, String status) {
  final data = seaBreeze();
  for (final p in data['participants'] as List) {
    if ((p as Map)['id'] == id) p['status'] = status;
  }
  return data;
}

void main() {
  late FakeRepo repo;
  final copied = <String>[];

  setUp(() {
    repo = FakeRepo();
    copied.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  tearDown(() {
    AppToast.hide();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpGuest(
    WidgetTester tester, {
    String? participant,
    Size size = const Size(390, 844),
    bool dark = false,
    TextDirection direction = TextDirection.ltr,
    DateTime Function()? clock,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) =>
            Directionality(textDirection: direction, child: child!),
        home: GuestBillScreen(
          billId: 'b1',
          initialParticipantId: participant,
          repository: repo,
          clock: clock,
          launcher: PaymentLauncher(
            canOpen: (_) async => true,
            open: (_) async => true,
            copy: (text) async => copied.add(text),
          ),
        ),
      ),
    );
  }

  Future<void> emit(WidgetTester tester, Map<String, dynamic>? data) async {
    repo.controller.add(data);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('shows a skeleton until the bill arrives', (tester) async {
    await pumpGuest(tester);
    expect(find.byType(SkeletonShimmer), findsOneWidget);
    await emit(tester, seaBreeze());
    expect(find.byType(SkeletonShimmer), findsNothing);
    expect(find.text('guest_which_one'), findsOneWidget);
  });

  testWidgets('group link: pick a name, see the share, pay, success', (
    tester,
  ) async {
    await pumpGuest(tester);
    await emit(tester, seaBreeze());

    expect(find.text('guest2_split_with_you'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget);
    // The host is not offered as a name.
    expect(find.text('Omar'), findsNothing);

    await tester.tap(find.text('Mona'));
    await tester.pumpAndSettle();
    expect(find.text('guest2_you_owe'), findsOneWidget);
    expect(find.text('guest2_pill_unpaid'), findsOneWidget);
    expect(find.text('Caesar salad'), findsOneWidget);
    expect(find.text('guest_item_shared'), findsOneWidget);
    expect(find.text('guest2_see_bill'), findsOneWidget);
    expect(find.text('guest2_pay_with'), findsOneWidget);
    expect(find.text('InstaPay'), findsOneWidget);
    expect(find.text('guest_add_screenshot'), findsOneWidget);

    await tester.tap(find.text('guest_copy'));
    await tester.pump();
    expect(copied, isNotEmpty);
    expect(find.text('guest_copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    AppToast.hide();
    await tester.pumpAndSettle();

    await tester.tap(find.text('guest2_paid_amount'));
    await tester.pumpAndSettle();
    expect(repo.submissions, [('mona', null)]);
    expect(repo.notices.single.hostId, 'omar');
    expect(repo.notices.single.withProof, isFalse);
    expect(find.byType(SuccessScreen), findsOneWidget);
    expect(find.text('guest_sent_title'), findsOneWidget);

    // The bill doc now says REVIEW: after Done the page shows "waiting".
    await emit(tester, withStatus('mona', 'REVIEW'));
    await tester.tap(find.text('guest_done'));
    await tester.pumpAndSettle();
    expect(find.text('guest_waiting_title'), findsOneWidget);
    expect(find.text('guest_get_app_title'), findsOneWidget);

    // Host confirms: animated success, then the confirmed state.
    await emit(tester, withStatus('mona', 'PAID'));
    await tester.pumpAndSettle();
    expect(find.byType(SuccessScreen), findsOneWidget);
    expect(find.text('guest_confirmed_title'), findsWidgets);
    await tester.tap(find.text('guest_done'));
    await tester.pumpAndSettle();
    expect(find.byType(SuccessScreen), findsNothing);
    expect(find.text('guest_confirmed_message'), findsOneWidget);
  });

  testWidgets('a screenshot is sent with the payment', (tester) async {
    repo.nextProof = GuestProof(
      bytes: Uint8List.fromList(_png),
      dataUrl: 'data:image/jpeg;base64,AAAA',
    );
    await pumpGuest(tester, participant: 'mona');
    await emit(tester, seaBreeze());
    await tester.tap(find.text('guest_add_screenshot'));
    await tester.pumpAndSettle();
    expect(find.text('guest_screenshot_added'), findsWidgets);
    await tester.tap(find.text('guest2_paid_amount'));
    await tester.pumpAndSettle();
    expect(repo.submissions, [('mona', 'data:image/jpeg;base64,AAAA')]);
    expect(repo.notices.single.withProof, isTrue);
  });

  testWidgets('a failed payment keeps the guest on the page', (tester) async {
    repo.failSubmit = true;
    await pumpGuest(tester, participant: 'mona');
    await emit(tester, seaBreeze());
    await tester.tap(find.text('guest2_paid_amount'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('guest_submit_error'), findsOneWidget);
    expect(find.byType(SuccessScreen), findsNothing);
    expect(find.text('guest2_paid_amount'), findsOneWidget);
    AppToast.hide();
    await tester.pumpAndSettle();
  });

  testWidgets('personal link skips the picker; "Not Mona?" goes back', (
    tester,
  ) async {
    await pumpGuest(tester, participant: 'mona');
    await emit(tester, seaBreeze());
    expect(find.text('guest_which_one'), findsNothing);
    expect(find.text('guest2_you_owe'), findsOneWidget);

    await tester.tap(find.text('guest_not_you'));
    await tester.pumpAndSettle();
    expect(find.text('guest_which_one'), findsOneWidget);

    // A later snapshot does not re-apply the link.
    await emit(tester, seaBreeze());
    expect(find.text('guest_which_one'), findsOneWidget);
  });

  testWidgets(
    'personal link: receipt skeleton, then the share card with no picker',
    (tester) async {
      await pumpGuest(tester, participant: 'mona');
      expect(find.byType(GuestLoadingSkeleton), findsOneWidget);
      expect(find.text('guest_which_one'), findsNothing);
      await emit(tester, seaBreeze());
      expect(find.byType(GuestLoadingSkeleton), findsNothing);
      expect(find.byType(GuestShareCard), findsOneWidget);
      expect(find.text('guest_which_one'), findsNothing);
    },
  );

  testWidgets('personal link with an unknown participant shows the picker', (
    tester,
  ) async {
    await pumpGuest(tester, participant: 'nobody');
    await emit(tester, seaBreeze());
    expect(find.text('guest_which_one'), findsOneWidget);
  });

  testWidgets('share card and pay tiles fit 320px wide', (tester) async {
    await pumpGuest(tester, participant: 'mona', size: const Size(320, 568));
    await emit(tester, seaBreeze());
    expect(find.byType(GuestShareCard), findsOneWidget);
  });

  testWidgets('a personal link for someone who already paid shows confirmed', (
    tester,
  ) async {
    await pumpGuest(tester, participant: 'sara');
    await emit(tester, seaBreeze());
    expect(find.text('guest_confirmed_title'), findsOneWidget);
    expect(find.byType(SuccessScreen), findsNothing);
  });

  testWidgets('settled bill', (tester) async {
    await pumpGuest(tester);
    await emit(tester, withStatus('mona', 'PAID'));
    expect(find.text('guest_settled_title'), findsOneWidget);
    // The host's phone is on the bill, so the guest can message them.
    expect(find.text('guest_message_host'), findsOneWidget);
  });

  testWidgets('expired link', (tester) async {
    await pumpGuest(tester, clock: () => DateTime(2026, 12, 1));
    await emit(tester, seaBreeze()..['expiresAt'] = DateTime(2026, 11, 20));
    expect(find.text('guest_expired_title'), findsOneWidget);
  });

  testWidgets('bill not found', (tester) async {
    await pumpGuest(tester);
    await emit(tester, null);
    expect(find.text('guest_not_found_title'), findsOneWidget);
  });

  testWidgets('load error offers a retry', (tester) async {
    await pumpGuest(tester);
    repo.controller.addError(StateError('permission-denied'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('guest_load_error_title'), findsOneWidget);
    await tester.tap(find.text('feedback_try_again'));
    await tester.pump();
    expect(repo.watchCount, 2);
    await emit(tester, seaBreeze());
    expect(find.text('guest_which_one'), findsOneWidget);
  });

  testWidgets('desktop: two columns, sticky pay panel on the right', (
    tester,
  ) async {
    await pumpGuest(tester, participant: 'mona', size: const Size(1440, 900));
    await emit(tester, seaBreeze());
    expect(find.text('guest2_you_owe'), findsOneWidget);
    expect(find.text('guest2_paid_amount'), findsOneWidget);
    expect(find.text('guest_get_app'), findsOneWidget);
    final card = tester.getRect(find.byType(GuestShareCard));
    final pay = tester.getRect(find.text('guest2_paid_amount'));
    expect(pay.left, greaterThan(card.right));
    expect(card.width, lessThan(1120 * 0.62));
    expect(tester.takeException(), isNull);
  });

  group('layout', () {
    int verticalScrollables(WidgetTester tester) => tester
        .widgetList<Scrollable>(find.byType(Scrollable))
        .where((s) => s.axis == Axis.vertical)
        .length;

    for (final size in const [
      Size(375, 812),
      Size(820, 1180),
      Size(1440, 900),
    ]) {
      testWidgets(
        'personal link at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          await pumpGuest(tester, participant: 'mona', size: size);
          await emit(tester, seaBreeze());
          expect(tester.takeException(), isNull);
          expect(verticalScrollables(tester), 1);

          final payFinder = find.text('guest2_paid_amount');
          expect(payFinder, findsOneWidget);
          final pay = tester.getRect(payFinder);
          expect(pay.bottom, lessThanOrEqualTo(size.height));
          expect(pay.top, greaterThanOrEqualTo(0));

          final bill = find.text('guest2_see_bill');
          if (size.width >= 1024) {
            // Right panel next to the share card; no bottom bar.
            final card = tester.getRect(find.byType(GuestShareCard));
            expect(pay.left, greaterThan(card.right));
            expect(find.text('guest3_amount_due'), findsOneWidget);
          } else {
            // The bar sits below the scroll view: scroll to the end and the
            // link is still clear of the button.
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, -2000),
            );
            await tester.pump();
            final link = tester.getRect(bill);
            expect(link.overlaps(tester.getRect(payFinder)), isFalse);
            expect(link.bottom, lessThanOrEqualTo(pay.top));
          }
        },
      );
    }

    testWidgets('long item lists fold after 6 lines on a phone', (
      tester,
    ) async {
      await pumpGuest(tester, participant: 'mona', size: const Size(375, 812));
      final data = seaBreeze();
      await emit(tester, data);
      final lines = GuestShareCard.rows(
        GuestBill.fromMap('b1', data),
        GuestBill.fromMap('b1', data).breakdownFor('mona'),
      ).length;
      if (lines > 6) {
        expect(find.text('guest3_show_all'), findsOneWidget);
        await tester.ensureVisible(find.text('guest3_show_all'));
        await tester.tap(find.text('guest3_show_all'));
        await tester.pump();
        expect(find.text('guest3_show_less'), findsOneWidget);
      } else {
        expect(find.text('guest3_show_all'), findsNothing);
      }
    });

    testWidgets('picker on desktop is a single centred column', (tester) async {
      await pumpGuest(tester, size: const Size(1440, 900));
      await emit(tester, seaBreeze());
      expect(find.text('guest_which_one'), findsOneWidget);
      final left = tester.getRect(find.byType(GuestChips)).left;
      expect(left, greaterThan(300));
      expect(verticalScrollables(tester), 1);
    });

    testWidgets('skeleton matches the layout without overflow', (tester) async {
      await pumpGuest(tester, participant: 'mona', size: const Size(1440, 900));
      expect(find.byType(GuestLoadingSkeleton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('guest chips render pal avatars, not initials', (tester) async {
    await pumpGuest(tester);
    await emit(tester, seaBreeze());
    expect(find.byType(PalAvatar), findsWidgets);
    // Host line + one chip per guest, each a pal.
    final guests = 3;
    expect(
      find.byType(PalAvatar).evaluate().length,
      greaterThanOrEqualTo(guests),
    );
    expect(find.text('S'), findsNothing);
    expect(find.text('M'), findsNothing);
  });

  testWidgets('RTL and dark mode lay out without overflow', (tester) async {
    await pumpGuest(
      tester,
      participant: 'mona',
      dark: true,
      direction: TextDirection.rtl,
    );
    await emit(tester, seaBreeze());
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap targets are at least 44px on the share step', (
    tester,
  ) async {
    await pumpGuest(tester, participant: 'mona');
    await emit(tester, seaBreeze());
    await expectLater(
      tester,
      meetsGuideline(
        const MinimumTapTargetGuideline(
          size: Size(44, 44),
          link: 'v3: 44px targets',
        ),
      ),
    );
  });
}

// 1x1 transparent PNG.
const _png = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
