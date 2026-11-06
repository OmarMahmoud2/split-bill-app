import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/utils/dispose_later.dart';

Future<void> _openAndSave(
  WidgetTester tester,
  void Function(TextEditingController) dispose,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final c = TextEditingController(text: '1');
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                content: TextField(controller: c),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
            dispose(c);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle(const Duration(milliseconds: 16));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('disposing after the dialog closes does not throw', (
    tester,
  ) async {
    await _openAndSave(tester, (c) => disposeAfterRouteCloses([c]));
    expect(tester.takeException(), isNull);
  });
}
