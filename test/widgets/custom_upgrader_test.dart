import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/custom_upgrader.dart';

Widget _app({String? version, bool reduce = false, ThemeMode mode = ThemeMode.light}) =>
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(
          body: UpdateDialogContent(
            animation: const AlwaysStoppedAnimation(1),
            version: version,
            onUpdate: () {},
            onLater: () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('shows a translated versioned line, no hard-coded English', (
    tester,
  ) async {
    await tester.pumpWidget(_app(version: '2.0.1'));
    expect(find.text('update_version_available'), findsOneWidget);
    expect(find.textContaining('is now available'), findsNothing);
    expect(find.text('update_now'), findsOneWidget);
  });

  testWidgets('falls back to the unversioned line', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.text('update_new_version_available'), findsOneWidget);
  });

  testWidgets('Reduce Motion fades instead of bouncing', (tester) async {
    await tester.pumpWidget(_app(version: '2', reduce: true));
    final inDialog = find.descendant(
      of: find.byType(UpdateDialogContent),
      matching: find.byType(ScaleTransition),
    );
    expect(inDialog, findsNothing);
    await tester.pumpWidget(_app(version: '2'));
    expect(inDialog, findsOneWidget);
  });

  testWidgets('renders in dark mode', (tester) async {
    await tester.pumpWidget(_app(version: '2', mode: ThemeMode.dark));
    expect(tester.takeException(), isNull);
    final context = tester.element(find.byType(UpdateDialogContent));
    expect(context.palette.surface, isNotNull);
  });
}
