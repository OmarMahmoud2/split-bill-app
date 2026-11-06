import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/guest_bill_screen.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/screens/guest_bill/guest_bill_repository.dart';
import 'package:split_bill_app/theme/theme.dart';
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

    expect(find.text('Sea Breeze Grill'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget);
    // The host is not offered as a name.
    expect(find.text('Omar'), findsNothing);

    await tester.tap(find.text('Mona'));
    await tester.pumpAndSettle();
    expect(find.text('guest_hi_share_of'), findsOneWidget);
    expect(find.text('Caesar salad'), findsOneWidget);
    expect(find.text('guest_item_shared'), findsOneWidget);
    expect(find.text('guest_tax_rate'), findsOneWidget);
    expect(find.text('guest_see_receipt'), findsOneWidget);

    await tester.tap(find.text('guest_pay_host'));
    await tester.pumpAndSettle();
    expect(find.text('guest_pay_host_amount'), findsOneWidget);
    expect(find.text('InstaPay'), findsOneWidget);
    expect(find.text('guest_add_screenshot'), findsOneWidget);

    await tester.tap(find.text('guest_copy'));
    await tester.pump();
    expect(copied, isNotEmpty);
    expect(find.text('guest_copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    AppToast.hide();
    await tester.pumpAndSettle();

    await tester.tap(find.text('i_ve_paid'));
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
    await tester.tap(find.text('guest_pay_host'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('guest_add_screenshot'));
    await tester.pumpAndSettle();
    expect(find.text('guest_screenshot_added'), findsWidgets);
    await tester.tap(find.text('i_ve_paid'));
    await tester.pumpAndSettle();
    expect(repo.submissions, [('mona', 'data:image/jpeg;base64,AAAA')]);
    expect(repo.notices.single.withProof, isTrue);
  });

  testWidgets('a failed payment keeps the guest on the pay step', (
    tester,
  ) async {
    repo.failSubmit = true;
    await pumpGuest(tester, participant: 'mona');
    await emit(tester, seaBreeze());
    await tester.tap(find.text('guest_pay_host'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('i_ve_paid'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('guest_submit_error'), findsOneWidget);
    expect(find.byType(SuccessScreen), findsNothing);
    expect(find.text('i_ve_paid'), findsOneWidget);
    AppToast.hide();
    await tester.pumpAndSettle();
  });

  testWidgets('personal link skips the picker; "Not Mona?" goes back', (
    tester,
  ) async {
    await pumpGuest(tester, participant: 'mona');
    await emit(tester, seaBreeze());
    expect(find.text('guest_which_one'), findsNothing);
    expect(find.text('guest_hi_share_of'), findsOneWidget);

    await tester.tap(find.text('guest_not_you'));
    await tester.pumpAndSettle();
    expect(find.text('guest_which_one'), findsOneWidget);

    // A later snapshot does not re-apply the link.
    await emit(tester, seaBreeze());
    expect(find.text('guest_which_one'), findsOneWidget);
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

  testWidgets('desktop: two columns with the table and the pay card', (
    tester,
  ) async {
    await pumpGuest(tester, participant: 'mona', size: const Size(1280, 980));
    await emit(tester, seaBreeze());
    expect(find.text('guest_hi_share_is'), findsOneWidget);
    expect(find.text('guest_what_you_had'), findsOneWidget);
    expect(find.text('guest_rate_of'), findsNWidgets(2));
    expect(find.text('guest_total'), findsOneWidget);
    expect(find.text('guest_pay_host'), findsOneWidget);
    expect(find.text('guest_choose_screenshot'), findsOneWidget);
    expect(find.text('i_ve_paid'), findsOneWidget);
    expect(find.text('guest_get_app'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    await tester.tap(find.text('guest_pay_host'));
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
