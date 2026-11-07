import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/motion/motion.dart';

Widget _app(Widget child, {bool reduce = false}) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('Pressable taps and scales while pressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        Pressable(
          onTap: () => taps++,
          child: const SizedBox(width: 80, height: 40),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.97,
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 150));
    expect(taps, 1);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets(
    'CountUpMoney ends on the exact amount; reduced shows it at once',
    (tester) async {
      await tester.pumpWidget(
        _app(const CountUpMoney(minor: 12345, currency: 'USD')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('123.45'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.textContaining('123.45'), findsOneWidget);
      await tester.pumpWidget(
        _app(const CountUpMoney(minor: 500, currency: 'USD'), reduce: true),
      );
      expect(find.textContaining('5.00'), findsOneWidget);
    },
  );

  testWidgets('ShakeOnError moves the child then settles', (tester) async {
    final c = ShakeController();
    await tester.pumpWidget(
      _app(
        ShakeOnError(
          controller: c,
          child: const SizedBox(key: Key('x'), width: 10, height: 10),
        ),
      ),
    );
    final home = tester.getTopLeft(find.byKey(const Key('x')));
    c.shake();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 25));
    expect(tester.getTopLeft(find.byKey(const Key('x'))), isNot(home));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const Key('x'))), home);
  });
}
