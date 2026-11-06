import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

class _Obs extends NavigatorObserver {
  Route<dynamic>? pushed;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed = route;
}

void main() {
  tearDown(() => AppMotion.debugReduceMotionOverride = null);

  for (final reduce in [false, true]) {
    testWidgets('SuccessScreen route duration with reduce motion=$reduce', (
      tester,
    ) async {
      AppMotion.debugReduceMotionOverride = reduce;
      final obs = _Obs();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          navigatorObservers: [obs],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => SuccessScreen.show<void>(
                context,
                title: 't',
                primaryLabel: 'ok',
                onPrimary: () {},
                haptic: false,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      final route = obs.pushed as PageRouteBuilder;
      expect(
        route.transitionDuration,
        reduce ? AppMotion.reducedCrossfade : AppMotion.slow,
      );
      await tester.pumpAndSettle();
    });
  }
}
