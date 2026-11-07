import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/screens/activity/activity_screen.dart';
import 'package:split_bill_app/screens/groups/create_group_screen.dart';
import 'package:split_bill_app/screens/groups/group_detail_screen.dart';
import 'package:split_bill_app/screens/settle/settle_up_screen.dart';
import 'package:split_bill_app/widgets/home/home_dashboard.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/layout/adaptive_body.dart';

import '../data/fixtures.dart';
import '../ledger_screens/fake_repo.dart';
import '../ledger_screens/ledger_screens_test.dart' show tripRepo, noActions;

const sizes = {
  'iPad 1024x1366': Size(1024, 1366),
  'landscape phone 844x390': Size(844, 390),
  'small phone 320x568': Size(320, 568),
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LedgerMe.debugOverride = me;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() => LedgerMe.debugOverride = null);

  final screens = <String, Widget Function(FakeLedgerRepository)>{
    'home': (r) => HomeDashboard(
      stream: watchHomeLedger(r, 'me'),
      actions: noActions(),
      onRetry: () {},
    ),
    'activity': (_) => const ActivityScreen(embedded: true),
    'group detail': (_) => const GroupDetailScreen(groupId: 'g1'),
    'settle up': (_) => const SettleUpScreen.group(groupId: 'g1'),
    'create group': (_) => const CreateGroupScreen(),
  };

  for (final size in sizes.entries) {
    for (final screen in screens.entries) {
      testWidgets('${screen.key} fits ${size.key}', (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repo = tripRepo();
        LedgerRepository.instance = repo;
        await tester.pumpWidget(testApp(screen.value(repo)));
        await tester.pumpAndSettle();
      });
    }
  }

  testWidgets('wide screens cap content width', (tester) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(const AdaptiveBody(child: SizedBox.expand(key: Key('c')))),
    );
    expect(tester.getSize(find.byKey(const Key('c'))).width, 720);
  });

  testWidgets('bottom sheets are capped and centered on wide screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showLedgerSheet<void>(
              context,
              title: 'T',
              builder: (_) => const SizedBox(key: Key('sheet'), height: 80),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final r = tester.getRect(find.byKey(const Key('sheet')));
    expect(r.width, lessThanOrEqualTo(560));
    expect(r.center.dx, closeTo(512, 1));
  });
}
