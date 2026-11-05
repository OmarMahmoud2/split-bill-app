import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/theme/theme.dart';

Widget _host({required bool disableAnimations, required Widget child}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );

void main() {
  tearDown(() => AppMotion.debugReduceMotionOverride = null);

  test('duration tokens match the spec ranges', () {
    expect(AppMotion.fast.inMilliseconds, 150);
    expect(AppMotion.medium.inMilliseconds, 200);
    expect(AppMotion.slow.inMilliseconds, 250);
    for (final d in [
      AppMotion.moneyShort,
      AppMotion.money,
      AppMotion.moneyLong,
    ]) {
      expect(d.inMilliseconds, inInclusiveRange(300, 450));
    }
    expect(AppMotion.emphasizedDecelerate.transform(1), 1);
  });

  testWidgets('reduceMotion follows MediaQuery.disableAnimations', (
    tester,
  ) async {
    late bool reduced;
    late Duration duration;
    Widget probe() => Builder(
      builder: (context) {
        reduced = AppMotion.reduceMotion(context);
        duration = AppMotion.durationFor(context, AppMotion.money);
        return const SizedBox();
      },
    );

    await tester.pumpWidget(_host(disableAnimations: false, child: probe()));
    expect(reduced, isFalse);
    expect(duration, AppMotion.money);

    await tester.pumpWidget(_host(disableAnimations: true, child: probe()));
    expect(reduced, isTrue);
    expect(duration, AppMotion.reducedCrossfade);
  });

  testWidgets('debugReduceMotionOverride wins', (tester) async {
    AppMotion.debugReduceMotionOverride = true;
    late bool reduced;
    await tester.pumpWidget(
      _host(
        disableAnimations: false,
        child: Builder(
          builder: (context) {
            reduced = AppMotion.reduceMotion(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(reduced, isTrue);
  });

  testWidgets('CountUp ends on the final value; reduced shows it at once', (
    tester,
  ) async {
    Widget countUp(bool reduce) => _host(
      disableAnimations: reduce,
      child: CountUp(
        value: 100,
        builder: (context, v) => Text(v.round().toString()),
      ),
    );

    await tester.pumpWidget(countUp(false));
    expect(find.text('100'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('100'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(countUp(true));
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('StaggeredEntrance, AvatarHop and RollToZero settle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        disableAnimations: false,
        child: Column(
          children: [
            const StaggeredEntrance(index: 3, child: Text('row')),
            const AvatarHop(child: Text('A')),
            SizedBox(
              height: 40,
              child: const RollToZero(from: Text('+41'), to: Text('0')),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('row'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 1);
    final zero = tester.widget<Opacity>(
      find.ancestor(of: find.text('0'), matching: find.byType(Opacity)).first,
    );
    expect(zero.opacity, 1);
  });
}
