import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/screens/bill_link_error_screen.dart';
import 'package:split_bill_app/widgets/layout/app_background.dart';
import 'package:split_bill_app/widgets/layout/app_scaffold.dart';

void main() {
  for (final width in [320.0, 1024.0]) {
    for (final dark in [false, true]) {
      testWidgets('BillLinkErrorScreen has AppBackground, no overflow '
          '($width, dark: $dark)', (t) async {
        t.view.physicalSize = Size(width, 700);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: const BillLinkErrorScreen(),
          ),
        );
        expect(find.byType(AppBackground), findsOneWidget);
        expect(find.byType(AppScaffold), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
