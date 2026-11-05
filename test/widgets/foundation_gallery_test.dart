import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/screens/debug/foundation_gallery_screen.dart';
import 'package:split_bill_app/theme/theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('foundation gallery renders (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: const FoundationGalleryScreen(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('v3 foundation'), findsOneWidget);
      if (dark) {
        await tester.tap(find.byTooltip('Toggle dark'));
        await tester.pump();
      }
      // Scroll through every section; layout errors would throw here.
      await tester.drag(find.byType(ListView), const Offset(0, -6000));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      // Stop the shimmer before the test ends.
      await tester.pumpWidget(const SizedBox());
    });
  }
}
