import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/screens/split_bill/bill_roulette_screen.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/app_text_field.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: Padding(padding: const EdgeInsets.all(20), child: child)),
);

void main() {
  group('AppTextField', () {
    testWidgets('shows label above and no error by default', (tester) async {
      await tester.pumpWidget(
        _host(const AppTextField(label: 'Name', hint: 'Sara')),
      );
      expect(find.text('Name'), findsOneWidget);
      expect(tester.getSize(find.byType(AnimatedContainer)).height, 52);
    });

    testWidgets('error state shows the message and shakes', (tester) async {
      var error = false;
      late StateSetter set;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return AppTextField(
                label: 'Amount',
                errorText: error ? 'Enter an amount' : null,
              );
            },
          ),
        ),
      );
      expect(find.text('Enter an amount'), findsNothing);
      set(() => error = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('Enter an amount'), findsOneWidget);
      final start = tester.getTopLeft(find.byType(AnimatedContainer)).dx;
      await tester.pump(const Duration(milliseconds: 20));
      final moved = tester.getTopLeft(find.byType(AnimatedContainer)).dx;
      expect(moved, isNot(start));
      await tester.pumpAndSettle();
    });
  });

  group('roulette landing math', () {
    test('target rotation lands inside the chosen slice', () {
      for (var n = 2; n <= 9; n++) {
        for (var i = 0; i < n; i++) {
          for (final f in [0.15, 0.5, 0.85]) {
            final rot = rouletteTargetRotation(
              from: 1.234,
              index: i,
              count: n,
              fraction: f,
            );
            expect(rot, greaterThan(1.234 + 4 * 2 * math.pi));
            expect(rouletteIndexAt(rot, n), i, reason: 'n=$n i=$i f=$f');
          }
        }
      }
    });

    test('index at rest', () {
      expect(rouletteIndexAt(0, 4), 0);
      // A quarter turn clockwise brings the last slice under the pointer.
      expect(rouletteIndexAt(math.pi / 2 - 0.01, 4), 3);
    });
  });
}
